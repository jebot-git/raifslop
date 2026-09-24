#!/usr/bin/env python3
"""Exercise Golf over Fishing's actual ENet transport in three isolated processes."""
import argparse, os, subprocess, tempfile, time
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--host',type=Path,default=Path(__file__).resolve().parents[1])
parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'))
parser.add_argument('--output',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
out=(args.output or root/'test-results/host-golf-network').resolve();out.mkdir(parents=True,exist_ok=True)
jobs=[];failed=[]
with tempfile.TemporaryDirectory(prefix='golf-network-') as temp:
 try:
  for role in ['server','A','B']:
   path=out/(role+'.log');stream=path.open('w')
   command=[args.godot,'--headless','--xr-mode','off','--path',str(args.host),'--script',str(root/'tests/golf_network.gd'),'--',role,'28973']
   env=dict(os.environ,XDG_DATA_HOME=f'{temp}/{role}')
   jobs.append((role,subprocess.Popen(command + (['--xr-test'] if '--script' in command else []),stdout=stream,stderr=subprocess.STDOUT,env=env),stream,path))
   time.sleep(.8)
  deadline=time.monotonic()+65
  for role,proc,stream,path in jobs:
   try:proc.wait(timeout=max(.1,deadline-time.monotonic()))
   except subprocess.TimeoutExpired:proc.kill();proc.wait()
   stream.close();log=path.read_text()
   ok=proc.returncode==0 and 'HOST GOLF NETWORK' in log and 'SCRIPT ERROR' not in log and '\nERROR:' not in log
   print(('PASS ' if ok else 'FAIL ')+role,flush=True)
   if not ok:failed.append(role);print(log[-5000:],flush=True)
 finally:
  for _,proc,stream,_ in jobs:
   if proc.poll() is None:proc.kill();proc.wait()
   stream.close()
raise SystemExit(bool(failed))
