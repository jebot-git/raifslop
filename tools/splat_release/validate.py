"""Run both locations from the Linux export and verify separate persistent settings."""
import json,os,subprocess
from pathlib import Path
from build import ROOT,BUILD
binary=BUILD/'Linux/RealAIFishing-SplatTesting.x86_64'
env=dict(os.environ,XDG_DATA_HOME=str(BUILD/'test-userdata'))
reports=[]
for index,location in enumerate(['lake_pier','simons_town_rocks','simons_town_rocks']):
 log=BUILD/f'smoke-{index}.log'
 command=[str(binary),'--xr-mode','off','--','--release-smoke']
 if index<2:command+=['--location='+location]
 with log.open('w') as stream:r=subprocess.run(command,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
 output=log.read_text();marker='SPLAT_RELEASE_SMOKE '
 assert r.returncode==0 and 'ERROR:' not in output and marker in output,log
 report=json.loads(next(line[len(marker):] for line in output.splitlines() if line.startswith(marker)))
 assert report['passed'] and report['location']==location and not report['microphone_enabled'],report
 assert report['user_dir']==str(BUILD/'test-userdata/RealAIFishing-SplatTesting'),report
 reports.append(report)
for location in ['lake_pier','simons_town_rocks']:
 log=BUILD/f'validation-{location}.log'
 with log.open('w') as stream:r=subprocess.run([str(binary),'--xr-mode','off','--','--validate','--location='+location],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
 output=log.read_text();marker='LOCATION_VALIDATION '
 assert r.returncode==0 and 'ERROR:' not in output and marker in output,log
 report=json.loads(next(line[len(marker):] for line in output.splitlines() if line.startswith(marker)))
 assert report['passed'],report
 reports.append(report)
(BUILD/'runtime-validation.json').write_text(json.dumps(reports,indent=2)+'\n')
print('Exported Linux viewer: both locations, collision/culling, isolated saves and saved-location restart passed.')
