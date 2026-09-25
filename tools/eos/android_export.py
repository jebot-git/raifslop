"""Reproducible EOS Android bootstrap and APK checks; never log credentials."""
import configparser
import json
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET
import zipfile

FIELDS = {'eos': ('product_id', 'sandbox_id', 'deployment_id', 'client_id', 'client_secret', 'relay'),
          'identity': ('provider',), 'meta': ('app_id', 'destination')}


def read_config(path, app_id):
    source = configparser.ConfigParser(interpolation=None)
    source.read_string(Path(path).read_text())
    values = {}
    for section, keys in FIELDS.items():
        values[section] = {}
        for key in keys:
            try:
                value = json.loads(source.get(section, key))
            except (ValueError, configparser.Error):
                raise ValueError('Missing or invalid EOS configuration field: ' + section + '.' + key) from None
            if not isinstance(value, str) or not value.strip():
                raise ValueError('Empty EOS configuration field: ' + section + '.' + key)
            values[section][key] = value
    if values['identity']['provider'] != 'meta':
        raise ValueError('Quest EOS builds require Meta identity; device test credentials are forbidden')
    if values['meta']['app_id'] != app_id:
        raise ValueError('EOS Meta app ID must match the entitled Quest application')
    if values['eos']['relay'] not in ('auto', 'force'):
        raise ValueError('Invalid EOS relay setting')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', values['eos']['client_id']):
        raise ValueError('Invalid EOS client ID for Android login scheme')
    return values


def block(text, label, content):
    begin, end = '// UBS EOS ' + label + ' BEGIN', '// UBS EOS ' + label + ' END'
    text = re.sub(re.escape(begin) + r'.*?' + re.escape(end) + r'\n?', '', text, flags=re.S)
    return text, begin + '\n' + content + '\n' + end + '\n'


def configure(android, project, values=None):
    """Patch the generated Godot 4.7 activity; remove hooks for non-EOS exports."""
    gradle = android / 'build.gradle'
    activity = android / 'src/main/java/com/godot/game/GodotApp.java'
    resource = android / 'res/values/ubs_eos.xml'
    gradle_text, gradle_block = block(gradle.read_text(), 'DEPENDENCIES', '''dependencies {
    implementation 'androidx.appcompat:appcompat:1.5.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'androidx.security:security-crypto:1.0.0'
    implementation 'androidx.browser:browser:1.4.0'
    implementation files('../../addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar')
}''')
    activity_text, activity_block = block(activity.read_text(), 'BOOTSTRAP', '''        System.loadLibrary("EOSSDK");
        com.epicgames.mobile.eossdk.EOSSDK.init(this);''')
    if values is not None:
        native = project / 'addons/epic-online-services-godot/bin/android'
        for name in ['eossdk-StaticSTDC-release.aar', 'libeosg.android.template_release.arm64.so']:
            if not (native / name).is_file():
                raise ValueError('Install pinned Android EOSG first: tools/eos/setup_lab.py --game --platform android')
        anchor = '\t\tsuper.onCreate(savedInstanceState);'
        if activity_text.count(anchor) != 1:
            raise ValueError('Unrecognized Godot Android activity; cannot insert EOS bootstrap safely')
        activity_text = activity_text.replace(anchor, activity_block + anchor)
        gradle_text = gradle_text.rstrip() + '\n\n' + gradle_block
        resources = ET.Element('resources')
        ET.SubElement(resources, 'string', {'name': 'eos_login_protocol_scheme', 'translatable': 'false'}).text = 'eos.' + values['eos']['client_id'].lower()
        resource.parent.mkdir(parents=True, exist_ok=True)
        ET.ElementTree(resources).write(resource, encoding='utf-8', xml_declaration=True)
    else:
        resource.unlink(missing_ok=True)
    gradle.write_text(gradle_text)
    activity.write_text(activity_text)


def elf_dependencies(data):
    """Inspect ARM64 ELF DT_NEEDED and PT_LOAD alignment without executing code."""
    if data[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', data, 18)[0] != 183:
        raise ValueError('Expected little-endian ARM64 ELF')
    phoff = struct.unpack_from('<Q', data, 32)[0]
    entsize, count = struct.unpack_from('<HH', data, 54)
    segments = [struct.unpack_from('<IIQQQQQQ', data, phoff + i * entsize) for i in range(count)]
    loads = [s for s in segments if s[0] == 1]
    if not loads or any(s[7] < 16384 for s in loads):raise ValueError('EOS library is not 16 KiB ELF aligned')
    dynamic = next(s for s in segments if s[0] == 2)
    entries = [struct.unpack_from('<qQ', data, pos) for pos in range(dynamic[2], dynamic[2] + dynamic[5], 16)]
    string_va = next(v for k, v in entries if k == 5)
    segment = next(s for s in loads if s[3] <= string_va < s[3] + s[5])
    strings = segment[2] + string_va - segment[3]
    return [data[strings + v:data.index(b'\0', strings + v)].decode() for k, v in entries if k == 1]


def inspect_apk(apk, expected):
    with zipfile.ZipFile(apk) as z:
        names = set(z.namelist())
        prefix = 'lib/arm64-v8a/'
        required = [prefix + 'libEOSSDK.so', prefix + 'libeosg.android.template_release.arm64.so', 'assets/eos.cfg']
        if not set(required) <= names:raise ValueError('APK is missing EOS native libraries or configuration')
        parsed = configparser.ConfigParser(interpolation=None)
        parsed.read_string(z.read('assets/eos.cfg').decode())
        actual = {section: {key: json.loads(value) for key, value in parsed.items(section)} for section in parsed.sections()}
        if actual != expected:raise ValueError('Packaged EOS config differs from the validated local config')
        system = {'libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libandroid.so', 'libz.so'}
        for name in required[:2]:
            dependencies = elf_dependencies(z.read(name))
            if any(dep not in system and prefix + dep not in names for dep in dependencies):
                raise ValueError('Unresolved EOS native dependency')
        dex = b''.join(z.read(n) for n in names if re.fullmatch(r'classes\d*\.dex', n))
        for marker in [b'Lcom/epicgames/mobile/eossdk/EOSSDK;', b'EOSAuthHandlerActivity']:
            if marker not in dex:raise ValueError('APK is missing EOS Android Java classes')
    return {'provider': 'meta', 'abi': 'arm64-v8a', 'elf_alignment': 16384, 'config_matches': True, 'native_dependencies_resolved': True}
