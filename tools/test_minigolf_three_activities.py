#!/usr/bin/env python3
import os,subprocess,tempfile,time
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'test-results/minigolf-three-activities';out.mkdir(exist_ok=True,parents=True)
godot='/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
failed=[];jobs=[]
with tempfile.TemporaryDirectory(prefix='minigolf-three-scenes-') as temp:
 try:
  for role in ['golfer','angler','cook']:
   log=(out/(role+'.log')).open('w');env=dict(os.environ,DISPLAY=':0',XDG_DATA_HOME=temp+'/'+role)
   p=subprocess.Popen([godot,'--path',str(root),'--xr-mode','off','--resolution','1280x800','--script','tests/minigolf_three_activities.gd','--',role,'--xr-test'],env=env,stdout=log,stderr=subprocess.STDOUT);jobs.append((role,p,log));time.sleep(2)
  for role,p,log in jobs:
   try:p.wait(timeout=160)
   except subprocess.TimeoutExpired:p.kill();p.wait()
   log.close();text=(out/(role+'.log')).read_text();ok=p.returncode==0 and 'THREE_ACTIVITIES' in text and 'SCRIPT ERROR' not in text
   print(('PASS ' if ok else 'FAIL ')+role,flush=True)
   if not ok:failed.append(role);print(text[-2500:])
 finally:
  for role,p,log in jobs:
   if p.poll() is None:p.kill();p.wait()
   log.close()
raise SystemExit(bool(failed))
