"""Apply idempotent Store overrides to Godot's generated Android template."""
import xml.etree.ElementTree as ET

ANDROID = 'http://schemas.android.com/apk/res/android'
TOOLS = 'http://schemas.android.com/tools'
A = '{' + ANDROID + '}'
T = '{' + TOOLS + '}'


def configure(path):
    ET.register_namespace('android', ANDROID)
    ET.register_namespace('tools', TOOLS)
    tree = ET.parse(path)
    root = tree.getroot()
    root.set(A + 'installLocation', 'auto')
    feature = next((e for e in root.findall('uses-feature')
                    if e.get(A + 'name') == 'android.hardware.vr.headtracking'), None)
    if feature is None:
        feature = ET.SubElement(root, 'uses-feature', {A + 'name': 'android.hardware.vr.headtracking'})
    feature.set(A + 'required', 'true')
    feature.set(A + 'version', '1')
    feature.set(T + 'replace', 'android:required')
    app = root.find('application')
    if app is None:
        raise ValueError('Android template has no application')
    # AGP's release build sets this; a hardcoded value triggers fatal lint.
    app.attrib.pop(A + 'debuggable', None)
    activities = [e for e in app.findall('activity') if e.get(A + 'name', '').endswith('.GodotApp')]
    if len(activities) != 1:
        raise ValueError('Expected exactly one GodotApp activity')
    activities[0].set(A + 'excludeFromRecents', 'true')
    for node in app.findall('profileable'):
        app.remove(node)
    ET.indent(tree)
    tree.write(path, encoding='utf-8', xml_declaration=True)
