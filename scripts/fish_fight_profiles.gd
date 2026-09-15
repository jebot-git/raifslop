extends RefCounted
## Authored gameplay tendencies, not a biological prediction of every hooked fish.
# Directions: 0/1 lateral, 2 outward. Dives: 1 deep pull, 2 inward slack rush.
const FAMILIES = {
 "dart": {"directions":[0,1,0,1,2], "dives":[1,2], "cycle":9.0, "run":3.5, "speed":.35, "hold":.90, "rest":1.0, "dive_gap":13.0},
 "bottom": {"directions":[2,2,0,2,1], "dives":[1,1,1,2], "cycle":12.0, "run":2.5, "speed":.25, "hold":1.12, "rest":1.1, "dive_gap":9.0},
 "cruiser": {"directions":[2,0,2,1], "dives":[1,1,2], "cycle":10.0, "run":4.0, "speed":.48, "hold":1.08, "rest":1.0, "dive_gap":12.0},
 "ambush": {"directions":[0,0,2,1,1,2], "dives":[1,2,1], "cycle":11.0, "run":2.8, "speed":.60, "hold":1.0, "rest":1.15, "dive_gap":12.0},
 "agile": {"directions":[0,1,2,1,0], "dives":[2,1,2], "cycle":8.5, "run":3.0, "speed":.48, "hold":.85, "rest":.9, "dive_gap":10.0},
 "reef": {"directions":[2,0,2,1,2], "dives":[1,1,2], "cycle":10.0, "run":2.5, "speed":.40, "hold":1.05, "rest":1.0, "dive_gap":9.0},
 "runner": {"directions":[2,0,2,1], "dives":[2,1,2], "cycle":10.0, "run":4.5, "speed":.65, "hold":.95, "rest":1.0, "dive_gap":13.0}
}
# Stable species index: family and tempo. Smaller tempo means quicker cadence.
const SPECIES = [
 ["dart",1.0], ["cruiser",1.08], ["ambush",.96], ["dart",.94],
 ["bottom",1.05], ["bottom",1.15], ["ambush",1.08], ["dart",.90],
 ["bottom",.97], ["cruiser",.94], ["agile",.92], ["agile",1.06],
 ["agile",1.0], ["bottom",.90], ["dart",.84], ["dart",.80],
 ["bottom",.85], ["agile",.96], ["reef",.92], ["reef",1.0],
 ["reef",1.08], ["reef",.96], ["cruiser",1.0], ["agile",.88],
 ["runner",1.0], ["runner",.90]
]
static func profile(index: int) -> Dictionary:
 var entry: Array=SPECIES[clampi(index,0,SPECIES.size()-1)]
 return FAMILIES[entry[0]]
static func tempo(index: int) -> float:
 return SPECIES[clampi(index,0,SPECIES.size()-1)][1]
