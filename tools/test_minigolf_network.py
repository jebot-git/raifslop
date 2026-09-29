#!/usr/bin/env python3
"""Four-process ENet check: dedicated server, golfer, angler and cook at one water."""
import os,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
out=ROOT/'test-results/minigolf-network';out.mkdir(parents=True,exist_ok=True)
jobs=[];failed=[]
with tempfile.TemporaryDirectory(prefix='minigolf-network-') as temp:
 try:
  for role in ['server','golfer','angler','cook']:
   log=(out/(role+'.log')).open('w')
   env=dict(os.environ,XDG_DATA_HOME=str(Path(temp)/role))
   p=subprocess.Popen([GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','tests/minigolf_network.gd','--',role,'28974'],stdout=log,stderr=subprocess.STDOUT,env=env)
   jobs.append((role,p,log));time.sleep(.5)
  for role,p,log in jobs:
   try:p.wait(timeout=50)
   except subprocess.TimeoutExpired:p.kill();p.wait()
   log.close();text=(out/(role+'.log')).read_text()
   ok=p.returncode==0 and 'MINIGOLF_NETWORK' in text and 'SCRIPT ERROR' not in text
   print(('PASS ' if ok else 'FAIL ')+role,flush=True)
   if not ok:failed.append(role);print(text[-4000:])
 finally:
  for role,p,log in jobs:
   if p.poll() is None:p.kill();p.wait()
   log.close()
raise SystemExit(bool(failed))
