#!/usr/bin/env python3
"""Exercise the built asset-free server, two clients, restart and identity continuity."""
import os,pathlib,subprocess,tempfile,time,argparse,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--server',type=pathlib.Path,default=ROOT/'builds/Server/RealAIFishingServer.x86_64');p.add_argument('--port',type=int,default=28621);a=p.parse_args()
 godot=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
 logs=ROOT/'test-results/server-leaderboard';logs.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='fishing-board-') as tmp:
  data=pathlib.Path(tmp);jobs=[]
  def launch(role,stage=0):
   identity='writer' if role=='return' else role
   env=dict(os.environ,XDG_DATA_HOME=str(data/identity),XDG_CONFIG_HOME=str(data/'config'))
   path=logs/f'{role}-{stage}.log';stream=path.open('w')
   command=[str(a.server),'--','--port',str(a.port),'--leaderboard-path',str(data/'records.json'),'--asset-root',str(data/'assets')] if role=='server' else [godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tests/leaderboard_network.gd','--',role,str(a.port)]
   process=subprocess.Popen(command + (['--xr-test'] if '--script' in command else []),env=env,stdout=stream,stderr=subprocess.STDOUT);jobs.append((process,stream,path));return process,stream,path
  def finish(job):
   process,stream,path=job
   process.wait(timeout=35);stream.close();text=path.read_text()
   if process.returncode or 'SCRIPT ERROR' in text or 'LEADERBOARD_NETWORK_RESULT' not in text:raise RuntimeError(str(path)+'\n'+text)
  try:
   server=launch('server');time.sleep(2)
   writer=launch('writer');observer=launch('observer');finish(writer);finish(observer)
   server[0].terminate();server[0].wait(timeout=5);server[1].close()
   record=json.loads((data/'records.json').read_text());assert sum(r['catches'] for r in record['players'].values())==1
   server=launch('server',1);time.sleep(2);finish(launch('return'))
   server[0].terminate();server[0].wait(timeout=5);server[1].close()
   record=json.loads((data/'records.json').read_text());assert len(record['players'])==2 and sum(r['catches'] for r in record['players'].values())==1
   for log in logs.glob('server-*.log'):
    assert 'SCRIPT ERROR' not in log.read_text(),log.read_text()
   print('PASS asset-free dedicated server: clients, records, duplicate rejection, server restart, renamed reconnect and client-only identity storage')
  finally:
   for process,stream,_ in jobs:
    if process.poll() is None:process.kill();process.wait()
    stream.close()
if __name__=='__main__':main()
