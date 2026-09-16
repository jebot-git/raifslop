"""Independent ENet processes exercise shared BBQ on dedicated and ad-hoc hosts."""
import os,subprocess,time,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/bbq-network';OUT.mkdir(parents=True,exist_ok=True)
failed=[]
with tempfile.TemporaryDirectory(prefix='raif-bbq-net-') as temp:
 for dedicated,port in [(True,28671),(False,28672)]:
  jobs=[]
  def launch(role):
   path=OUT/f'{port}-{role}.log';stream=path.open('w')
   command=['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tests/bbq_network.gd','--',role,str(port)]
   if role=='server':command+=['--server','--port',str(port)]
   env=dict(os.environ,XDG_DATA_HOME=f'{temp}/{port}-{role}',XDG_CONFIG_HOME=f'{temp}/config')
   jobs.append((role,subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT,env=env),stream,path))
  try:
   launch('server' if dedicated else 'host');time.sleep(1.5)
   if dedicated:launch('leader');time.sleep(1)
   launch('observer');time.sleep(4);launch('late')
   for role,p,stream,path in jobs:
    try:p.wait(timeout=50)
    except subprocess.TimeoutExpired:p.kill();p.wait()
    stream.close();text=path.read_text()
    ok=p.returncode==0 and 'BBQ_NETWORK_RESULT' in text and 'SCRIPT ERROR' not in text and 'FAIL ' not in text
    print(('PASS ' if ok else 'FAIL ')+str(port)+' '+role,flush=True)
    if not ok:failed.append((port,role));print(text[-6500:],flush=True)
  finally:
   for role,p,stream,path in jobs:
    if p.poll() is None:p.terminate();p.wait(timeout=5)
    stream.close()
print('BBQ_NETWORK_FAILURES',failed);raise SystemExit(bool(failed))
