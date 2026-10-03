#!/usr/bin/env python3
"""Isolated regression runner for shared minigolf and the retained fishing systems."""
import os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
suites=['minigolf','minigolf_terrain','minigolf_compile','minigolf_lightmaps','minigolf_address_line','minigolf_fit_invariants','minigolf_runtime','minigolf_locomotion','pose_codec','ranking_pages','online_leaderboards','progress','destinations','network_guards','run_tests']
failed=[]
out=ROOT/'test-results/minigolf';out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='minigolf-tests-') as temp:
 for suite in suites:
  env=dict(os.environ,XDG_DATA_HOME=str(Path(temp)/suite),XDG_CONFIG_HOME=str(Path(temp)/'config'))
  try:
   result=subprocess.run([GODOT,'--headless','--xr-mode','off','--path',str(ROOT),'--script','tests/'+suite+'.gd','--','--xr-test'],capture_output=True,text=True,timeout=90,env=env)
   log=result.stdout+result.stderr;(out/(suite+'.log')).write_text(log)
   ok=result.returncode==0 and 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  except subprocess.TimeoutExpired as error:
   log=(error.stdout or b'').decode(errors='replace')+'\nTimed out';(out/(suite+'.log')).write_text(log);ok=False
  print(('PASS ' if ok else 'FAIL ')+suite,flush=True)
  if not ok:failed.append(suite);print(log[-3500:],flush=True)
raise SystemExit(bool(failed))
