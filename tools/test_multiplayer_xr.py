#!/usr/bin/env python3
"""Native Monado stereo session plus a separate desktop multiplayer client."""
import os,pathlib,subprocess,tempfile,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
with tempfile.TemporaryDirectory(prefix='fishing-multiplayer-xr-') as tmp:
    jobs=[]
    try:
        for role in ['xr','desktop']:
            env=dict(os.environ,XDG_DATA_HOME=tmp+'/'+role,XR_RUNTIME_JSON='/usr/share/openxr/1/openxr_monado.json',SIMULATED_ENABLE='1',XRT_COMPOSITOR_FORCE_XCB='1')
            path=pathlib.Path(tmp)/(role+'.log'); stream=path.open('w')
            args=[GODOT,'--path',str(ROOT),'--script','res://tests/multiplayer_xr.gd']
            if role=='desktop': args+=['--xr-mode','off']
            args+=['--',role]
            process=subprocess.Popen(args,env=env,stdout=stream,stderr=subprocess.STDOUT)
            jobs.append((role,process,stream,path))
            if role=='xr':
                # First-time shader compilation can exceed a fixed startup delay.
                deadline=time.monotonic()+90
                while time.monotonic()<deadline and process.poll() is None:
                    if 'Hosting on UDP 28570' in path.read_text(): break
                    time.sleep(.2)
            else:
                time.sleep(1)
        failed=False
        for role,process,stream,path in jobs:
            try: process.wait(timeout=90)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
            stream.close(); output=path.read_text(); print(role+'\n'+output)
            failed|=process.returncode!=0 or 'SCRIPT ERROR' in output or 'MULTIPLAYER_XR_RESULT' not in output
        raise SystemExit(1 if failed else 0)
    finally:
        for _,process,stream,_ in jobs:
            if process.poll() is None: process.terminate(); process.wait(timeout=5)
            stream.close()
