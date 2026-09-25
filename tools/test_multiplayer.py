#!/usr/bin/env python3
"""Real ENet processes, isolated saves, FPSloppa Opus fixture; no microphone capture."""
import os, pathlib, subprocess, tempfile, time, struct, json, re
ROOT=pathlib.Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
def main():
    with tempfile.TemporaryDirectory(prefix='fishing-network-') as tmp:
        base=pathlib.Path(tmp)
        data=(ROOT/'assets/avatars/vita.vrm').read_bytes()
        size=struct.unpack_from('<I',data,12)[0]
        doc=json.loads(data[20:20+size]); doc['asset']['generator']='Fishing multiplayer custom transfer fixture'
        header=json.dumps(doc,separators=(',',':')).encode(); header+=b' '*((-len(header))%4)
        payload=struct.pack('<II',len(header),0x4e4f534a)+header+data[20+size:]
        avatar=base/'custom.vrm'; avatar.write_bytes(struct.pack('<III',0x46546c67,2,len(payload)+12)+payload)
        # Source upload plus two server-mediated downloads share the content budget.
        budget_source=(ROOT/'scripts/network/bulk_read_budget.gd').read_text()
        rate=int(re.search(r'const RATE := ([0-9_]+)',budget_source)[1].replace('_',''))
        transfer_wait=max(35, 3*avatar.stat().st_size/rate+30)
        failures=[]
        for dedicated,port in [(True,28567),(False,28568)]:
            jobs=[]
            def launch(role,extra=()):
                env=dict(os.environ,XDG_DATA_HOME=str(base/(str(port)+role)),XDG_CONFIG_HOME=str(base/'config'))
                path=base/(str(port)+'-'+role+'.log'); stream=path.open('w')
                args=[GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tests/multiplayer.gd','--',role,str(port),str(avatar),*extra,'--transfer-timeout',str(transfer_wait),'--asset-root',str(base/(str(port)+role)/'data')]
                if role=='server' and os.environ.get('FISHING_SERVER_BIN'):
                    args=['stdbuf','-oL',os.environ['FISHING_SERVER_BIN'],'--verbose','--','--server','--port',str(port),'--asset-root',str(base/(str(port)+role)/'data'),'--leaderboard-path',str(base/'leaderboard.json')]
                elif os.environ.get('TEST_VERBOSE'): args.insert(1,'--verbose')
                process=subprocess.Popen(args + (['--xr-test'] if '--script' in args else []),env=env,stdout=stream,stderr=subprocess.STDOUT)
                jobs.append((role,process,stream,path))
            try:
                launch('server' if dedicated else 'host', ['--server','--port',str(port)] if dedicated else [])
                time.sleep(1.5)
                if dedicated: launch('sender')
                time.sleep(1)
                launch('observer')
                if dedicated:
                    time.sleep(5)
                    launch('late')
                for role,process,stream,path in jobs:
                    if role=='server' and os.environ.get('FISHING_SERVER_BIN'):
                        if process.poll() is not None:failures.append((port,role,'server exited'))
                        continue
                    try: process.wait(timeout=transfer_wait*2+90)
                    except subprocess.TimeoutExpired: process.kill(); process.wait()
                    stream.close(); text=path.read_text()
                    print(f'--- {port} {role} ---\n{text}')
                    if process.returncode or 'SCRIPT ERROR' in text or 'MULTIPLAYER_RESULT' not in text: failures.append((port,role))
            finally:
                for _,process,stream,_ in jobs:
                    if process.poll() is None: process.terminate(); process.wait(timeout=5)
                    stream.close()
                for role,process,stream,path in jobs:
                    if role=='server' and os.environ.get('FISHING_SERVER_BIN'):
                        text=path.read_text();print('--- exported server ---\n'+text)
                        if 'SCRIPT ERROR' in text or 'ERROR:' in text:failures.append((port,role,'runtime error'))
        if failures: raise SystemExit(f'FAILED {failures}')
        print('PASS dedicated and ad-hoc multiplayer integration')
if __name__=='__main__': main()
