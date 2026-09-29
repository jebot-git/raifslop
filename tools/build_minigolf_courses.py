#!/usr/bin/env python3
"""Reproducible original waterfront minigolf layouts; metres, X/Z ground plane."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
THEMES = [
 ('lakeside','Cove & Pebble','#477458','#aa8b61','stone',['Cove','Pebble','Rope','Shore','Island','Lighthouse']),
 ('lake_pier','Mooring Masters','#397e83','#ba8b4f','buoy',['Mooring','Bollard','Harbour','Quay','Slipway','Beacon']),
 ('gray_pier','Reedwalk','#557260','#8a7560','reed',['Reed','Boardwalk','Marsh','Heron','Jetty','Shelter']),
 ('bell_park_pier','Reservoir Regatta','#4d8754','#cfad63','boat',['Regatta','Sail','Pontoon','Anchor','Spinnaker','Homeward']),
 ('simons_town_rocks','Granite Galleys','#587c77','#aba397','stone',['Granite','Penguin','Tidepool','Galley','Lookout','Cape']),
 ('blouberg_sunrise_2','Dawn Dunes','#6e9882','#e2b584','dune',['Dawn','Dune','Surf','Windward','Sunrise','Horizon']),
 ('secluded_beach','Smuggler’s Cove','#398575','#c7a476','arch',['Smuggler','Shell','Grotto','Secret','Lagoon','Treasure']),
 ('fish_hoek_beach','Driftwood Strand','#649396','#c0b399','timber',['Driftwood','Strand','Wrack','Mist','Tide','Bay']),
 ('meadow_bend','Meadow Meanders','#719453','#c2a76b','reed',['Meadow','Mayfly','Meander','Willow','Riffle','Bend']),
 ('boulder_run','Rapids & Ricochets','#638676','#9a9e9b','stone',['Boulder','Rapid','Cascade','Eddy','Chute','Run']),
 ('cedar_creek','Cedar Canopy','#3e735a','#9b795b','timber',['Cedar','Moss','Root','Canopy','Fern','Creek']),
 ('glacier_run','Glacier Express','#7daab0','#c3d9de','ice',['Glacier','Moraine','Crevasse','Frost','Summit','Aurora']),
]
# Progression stays in three difficulty bands; each water permutes within a band.
PATTERNS = ['Opening Bank','Dogleg','Twin Gates','Crossfall','Crest','Split Decision',
 'Causeway','Switchback','Sunken Garden','Double Cushion','Keyhole','Saddle',
 'Island Hopping','Needle Ridge','Terraces','Ricochet Alley','Volcano','Final Approach']

def layout(ci,i,width,length):
 sign=-1 if (ci+i)%2 else 1
 # Preserve the introductory hole and finale, progressively remix the other puzzles.
 motif=0 if i==0 else 17 if i==17 else (1+(i-1+ci)%5 if i<6 else 6+(i-6+ci*2)%6 if i<12 else 12+(i-12+ci)%5)
 half=width/2
 obstacles=[];hazards=[];bumps=[];rails=[];ramps=[]
 def point(x,t):return [round(sign*x,3),round(-length*t,3)]
 def bank(x,t,xx,tt,r=.075):rails.append({'a':point(x,t),'b':point(xx,tt),'radius':r})
 def post(x,t,r=.28):obstacles.append({'center':point(x,t),'radius':r})
 def pond(x,t,w,l):hazards.append({'center':point(x,t),'size':[round(w,3),round(l,3)]})
 def mound(x,t,rx,rz,h):bumps.append({'center':point(x,t),'radius':max(rx,rz),'axes':[rx,rz],'height':round(h,3)})
 def ramp(a,b,h):ramps.append({'start':round(length*a,3),'end':round(length*b,3),'height':round(h,3)})
 elevation=.38+.045*(ci%4)
 cup=point(.48,1-.75/length)
 tee=point(-.38,.65/length)
 hint=''
 if motif==0:
  bank(-.55,.43,.55,.54);post(-.75,.65,.22)
  hint='Bank off the right rail, or leave a short approach left.'
 elif motif==1:
  bank(-half,.36,.58,.36);bank(.58,.36,.58,.60)
  post(-.62,.72,.3)
  hint='Play around the dogleg, then use the far cushion.'
 elif motif==2:
  for t,gap in [(.36,-.55),(.64,.55)]:
   bank(-half,t,gap-.34,t);bank(gap+.34,t,half,t)
  hint='Staggered gates reward a placed first shot.'
 elif motif==3:
  mound(-.65,.49,2.3,length*.30,.42);post(.48,.55,.34)
  hint='Aim uphill of your line: the crossfall bends the putt.'
 elif motif==4:
  ramp(.24,.44,elevation);ramp(.53,.74,-elevation)
  bank(-half,.51,-.45,.51);bank(.45,.51,half,.51)
  hint='Clear the crest with enough pace, then let it run downhill.'
 elif motif==5:
  bank(-.35,.28,-.35,.69);bank(.35,.28,.35,.69)
  pond(0,.48,.54,1.0);mound(.97,.53,.66,length*.24,.26)
  hint='The middle is water. Choose the flat left or raised right route.'
 elif motif==6:
  for side in [-1,1]:pond(side*(half+.38)/2,.52,half-.38,length*.36)
  ramp(.26,.43,elevation);ramp(.62,.78,-elevation)
  hint='Stay on the narrow raised causeway and control the downhill exit.'
 elif motif==7:
  for n,t in enumerate([.28,.48,.68]):
   if n%2:bank(half,t,-.55,t)
   else:bank(-half,t,.55,t)
  hint='Three alternating corners: plan your next resting place.'
 elif motif==8:
  ramp(.23,.43,-elevation);ramp(.64,.83,elevation)
  post(0,.5,.47);bank(-half,.70,-.45,.70)
  hint='Descend around the island, saving pace for the climb out.'
 elif motif==9:
  bank(-half,.3,.3,.43);bank(half,.62,-.3,.52)
  post(.65,.77,.25)
  hint='Two angled cushions can set up the final approach.'
 elif motif==10:
  bank(-half,.5,-.27,.5);bank(.27,.5,half,.5)
  bank(-.8,.30,-.27,.5);bank(.8,.30,.27,.5)
  ramp(.24,.44,elevation)
  hint='The funnel leads to a tight gate and a raised finishing green.'
 elif motif==11:
  mound(-.9,.48,1.2,length*.30,.40);mound(.9,.58,1.2,length*.26,.40)
  post(0,.68,.25)
  hint='Read both side slopes and choose which way around the marker.'
 elif motif==12:
  for n,t in enumerate([.32,.52,.72]):pond((-.6 if n%2 else .6),t,width*.48,length*.115)
  mound(-.72,.5,.7,1.35,.22)
  hint='Alternating water pockets leave a winding dry route.'
 elif motif==13:
  bank(-.35,.3,-.35,.72);bank(.35,.3,.35,.72)
  mound(0,.51,.34,length*.22,.4)
  post(-.95,.47,.32);post(.95,.64,.32)
  hint='Take the narrow ridge shortcut or go around the outside.'
 elif motif==14:
  ramp(.19,.34,elevation*.65);ramp(.48,.64,elevation*.65)
  bank(-half,.40,.45,.40);bank(half,.71,-.45,.71)
  hint='Two climbs and offset exits: pace each landing separately.'
 elif motif==15:
  for n,t in enumerate([.27,.46,.65]):
   side=1 if n%2 else -1
   bank(side*half,t,-side*.45,t+.09)
  post(.65,.81,.24)
  hint='Use the diagonal banks; a straight blast returns toward you.'
 elif motif==16:
  ramp(.38,.68,elevation*1.35)
  bank(-half,.42,-.48,.56);bank(half,.42,.48,.56)
  cup=point(0,1-.75/length)
  hint='Climb through the throat onto the high, flat cup plateau.'
 else:
  ramp(.20,.37,elevation);ramp(.54,.73,-elevation*.65)
  bank(-half,.42,.35,.48);bank(half,.68,-.35,.62)
  pond(-half+.32,.79,.6,1.0);post(.75,.79,.26)
  hint='Combine an uphill bank with a controlled downhill approach.'
 # Mirror directions in coaching along with the actual geometry.
 if sign<0:hint=hint.replace('left','TEMP').replace('right','left').replace('TEMP','right')
 return dict(number=i+1,name=PATTERNS[motif],par=2 if i==0 else 3 if motif<12 else 4,
  width=width,length=length,tee=tee,cup=cup,obstacles=obstacles,rails=rails,hazards=hazards,
  bumps=bumps,ramps=ramps,lost_ball=point(half+.6,.2+(i%4)*.17),hint=hint,design=PATTERNS[motif])

def build():
 out=ROOT/'assets/minigolf/courses';out.mkdir(parents=True,exist_ok=True)
 for ci,(water,title,turf,trim,prop,words) in enumerate(THEMES):
  holes=[]
  for i in range(18):
   width=round(3.4+(ci%3)*.3+(i%3)*.15,2)
   length=round(7+(i%5)*1.15+(ci%4)*.25,2)
   hole=layout(ci,i,width,length)
   hole['name']=words[(i//3)%6]+' '+hole['name']
   holes.append(hole)
  data={'version':2,'id':water,'water':water,'name':title,'theme':prop,'turf':turf,'trim':trim,'holes':holes}
  (out/(water+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':build()
