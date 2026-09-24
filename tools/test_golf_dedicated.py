#!/usr/bin/env python3
"""Exercise the actual exported server, two golf clients, BBQ, and restart."""
import argparse,json,os,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--server',type=Path,default=ROOT/'builds/Server/UltimateBoomerSimulatorServer.x86_64');p.add_argument('--godot',default='/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64');args=p.parse_args()
logs=ROOT/'test-results/golf-dedicated';logs.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='golf-dedicated-') as temp:
 jobs=[]
 def launch(role,stage=0):
  stream=(logs/f'{role}-{stage}.log').open('w');env=dict(os.environ,XDG_DATA_HOME=f'{temp}/{role}')
  command=[str(args.server),'--headless','--','--port','28977','--bind','127.0.0.1','--leaderboard-path',f'{temp}/records.json'] if role=='server' else [args.godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','tests/golf_dedicated_client.gd','--',role,'28977']
  proc=subprocess.Popen(command + (['--xr-test'] if '--script' in command else []),env=env,stdout=stream,stderr=subprocess.STDOUT);jobs.append((proc,stream));return proc,stream
 def finish(job,role):
  proc,stream=job;proc.wait(timeout=95);stream.close();text=(logs/f'{role}-0.log').read_text()
  if proc.returncode or 'SCRIPT ERROR' in text or 'GOLF_DEDICATED_RESULT' not in text:raise RuntimeError(text)
 try:
  server=launch('server');time.sleep(1)
  a=launch('A');b=launch('B');finish(a,'A');finish(b,'B')
  server[0].terminate();server[0].wait(timeout=5);server[1].close()
  data=json.loads(Path(temp,'records.json').read_text());assert len(data['players'])==2
  assert all(row['golf']['spyglass']['best']==18 for row in data['players'].values())
  server=launch('server',1);time.sleep(1);finish(launch('verify'),'verify')
  server[0].terminate();server[0].wait(timeout=5);server[1].close()
  for path in logs.glob('server-*.log'):
   assert 'SCRIPT ERROR' not in path.read_text() and 'ERROR:' not in path.read_text(),path.read_text()
  print('PASS exported dedicated server: golf/BBQ hooks, malformed commands, 18-hole turns, retirement, persisted rankings and restart')
 finally:
  for proc,stream in jobs:
   if proc.poll() is None:proc.kill();proc.wait()
   stream.close()
