"""Build the optional fishing kernels for Linux, Windows, and Quest ARM64.

Requires CMake/Ninja and a C++ toolchain (or --zig for desktop cross builds).
"""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tarfile, tempfile, urllib.request
ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'addons/fishing_native'
REVISION='507ed9d840c01a3c5b2a39af8bb4000bfac30bf5'
ARCHIVE_SHA='30da4ac295997061a6af81ae531510efd4e6a86e506eb4466edc0898ef3fe048'
NAMES={'linux':'libfishing_native.so','windows':'libfishing_native.dll','android':'libfishing_native.android.so'}

def source_hashes():
    return {p.relative_to(ADDON).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted([*(ADDON/'src').glob('*.cpp'),*(ADDON/'src').glob('*.h'),ADDON/'CMakeLists.txt',ADDON/'profile.json'])}

def require_build(target):
    library=ADDON/'bin'/NAMES[target]
    receipt=ADDON/'bin'/(target+'.json')
    if not library.is_file() or not receipt.is_file():raise RuntimeError('Build native kernels first: tools/build_fishing_native.py --target '+target)
    data=json.loads(receipt.read_text())
    if data['source_sha256']!=source_hashes() or data['sha256']!=hashlib.sha256(library.read_bytes()).hexdigest():raise RuntimeError('Stale native kernels; rebuild target '+target)
    return library

def bindings():
    dest=ROOT/'builds/native/godot-cpp'
    if dest.exists():
        if (dest/'.fishing_revision').read_text().strip()!=REVISION:raise RuntimeError('Unexpected bindings revision')
        return dest
    dest.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest.parent) as folder:
        archive=Path(folder)/'source.tar.gz'
        urllib.request.urlretrieve('https://github.com/godotengine/godot-cpp/archive/'+REVISION+'.tar.gz',archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest()!=ARCHIVE_SHA:raise RuntimeError('Bindings archive checksum mismatch')
        with tarfile.open(archive) as tar:tar.extractall(folder,filter='data')
        extracted=Path(folder)/('godot-cpp-'+REVISION)
        (extracted/'.fishing_revision').write_text(REVISION+'\n');os.replace(extracted,dest)
    return dest

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--target',choices=['linux','windows','android'],default='linux')
    p.add_argument('--bindings',type=Path)
    p.add_argument('--zig',type=Path,help='Optional Zig executable for portable Linux/Windows builds')
    p.add_argument('--ndk',type=Path,default=Path(os.environ.get('ANDROID_NDK_HOME',str(Path.home()/'Android/Sdk/ndk/29.0.14206865'))))
    p.add_argument('-j',type=int,default=2)
    a=p.parse_args();src=(a.bindings or bindings()).resolve()
    build=ROOT/'builds/native'/(a.target+('-zig' if a.zig and a.target!='android' else ''));build.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ,ZIG_GLOBAL_CACHE_DIR=str(ROOT/'builds/native/zig-cache'))
    cmd=['cmake','-S',str(ADDON),'-B',str(build),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DGODOT_CPP_PATH='+str(src)]
    if a.zig and a.target!='android':
        triple='x86_64-linux-gnu.2.28' if a.target=='linux' else 'x86_64-windows-gnu'
        for tool,verb in [('cxx','c++'),('ar','ar'),('ranlib','ranlib')]:
            wrapper=build/('zig-'+tool)
            args=[str(a.zig.resolve()),verb]+(['-target',triple] if tool=='cxx' else [])
            # CMake's verbose-link probe is unsupported by Zig 0.13's linker.
            wrapper.write_text('#!/usr/bin/env python3\nimport os,sys\na='+repr(args)+'\nos.execv(a[0],a+[x for x in sys.argv[1:] if x!="-Wl,-v"])\n')
            wrapper.chmod(0o755)
        cmd+=['-DCMAKE_CXX_COMPILER='+str(build/'zig-cxx'),'-DCMAKE_AR='+str(build/'zig-ar'),'-DCMAKE_RANLIB='+str(build/'zig-ranlib')]
    if a.target=='windows':cmd+=['-DCMAKE_SYSTEM_NAME=Windows']
    if a.target=='linux':cmd+=['-DGODOTCPP_USE_STATIC_CPP=OFF','-DFISHING_ZIG_GLIBC='+('ON' if a.zig else 'OFF')]
    if a.target=='android':cmd+=['-DCMAKE_TOOLCHAIN_FILE='+str(a.ndk/'build/cmake/android.toolchain.cmake'),'-DANDROID_ABI=arm64-v8a','-DANDROID_PLATFORM=android-26','-DANDROID_STL=c++_static','-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384']
    subprocess.run(cmd,env=env,check=True)
    subprocess.run(['cmake','--build',str(build),'-j',str(a.j)],env=env,check=True)
    built=build/('libfishing_native.dll' if a.target=='windows' else 'libfishing_native.so')
    dest=ADDON/'bin';dest.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest) as folder:
        staged=Path(folder)/NAMES[a.target];shutil.copy2(built,staged);os.replace(staged,dest/NAMES[a.target])
    shutil.copy2(src/'LICENSE.md',ADDON/'GODOT-CPP-LICENSE.md')
    if a.zig:
        zig_root=a.zig.resolve().parent
        for component in ['libcxx','libcxxabi','libunwind']:
            shutil.copy2(zig_root/'lib'/component/'LICENSE.TXT',ADDON/(component.upper()+'-LICENSE.txt'))
        shutil.copy2(zig_root/'LICENSE',ADDON/'ZIG-LICENSE.txt')
        shutil.copy2(zig_root/'lib/libc/mingw/COPYING',ADDON/'MINGW-COPYING.txt')
    if a.target=='android':shutil.copy2(a.ndk/'NOTICE.toolchain',ADDON/'ANDROID-NOTICE.txt')
    manifest='[configuration]\nentry_symbol="fishing_native_init"\ncompatibility_minimum="4.7"\nreloadable=false\n\n[libraries]\n'
    for target,feature in [('linux','linux.x86_64'),('windows','windows.x86_64'),('android','android.arm64')]:
        if (dest/NAMES[target]).exists():manifest+=feature+'="res://addons/fishing_native/bin/'+NAMES[target]+'"\n'
    (ADDON/'fishing_native.gdextension').write_text(manifest)
    receipt={'target':a.target,'bindings_revision':next((stamp.read_text().strip() for stamp in [src/'.fishing_revision',src/'.fps_revision'] if stamp.exists()),str(src)),'source_sha256':source_hashes(),'sha256':hashlib.sha256((dest/NAMES[a.target]).read_bytes()).hexdigest()}
    (dest/(a.target+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
    print('NATIVE_BUILD',dest/NAMES[a.target])
if __name__=='__main__':main()
