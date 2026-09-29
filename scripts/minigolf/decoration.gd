extends RefCounted
## Local scenery palettes sampled from the existing water panoramas/descriptions.
const PROFILES={
 "lakeside":{"props":["shore_pebbles","coastal_granite"],"border":"97876a","deck":"766b51","soil":"786b4c","accent":"b7a374","bed":["shore_pebbles","dune_grass","coastal_granite"]},
 "lake_pier":{"props":["harbour_bollard","rope_mooring"],"border":"829292","deck":"657273","soil":"667372","accent":"c99b55","bed":["rope_mooring","buoy","channel_marker"]},
 "gray_pier":{"props":["cattail_clump","rope_mooring"],"border":"89887c","deck":"656962","soil":"595d46","accent":"b1aa82","bed":["cattail_clump","cattail_clump","bleached_driftwood"]},
 "bell_park_pier":{"props":["regatta_boat","rope_mooring"],"border":"9d9670","deck":"7a785c","soil":"647254","accent":"c2784a","bed":["channel_marker","meadow_grass","regatta_boat"]},
 "simons_town_rocks":{"props":["coastal_granite","shore_pebbles"],"border":"a9a69a","deck":"7c817a","soil":"8d9183","accent":"769497","bed":["coastal_granite","shell_bank","coastal_granite"]},
 "blouberg_sunrise_2":{"props":["shell_bank","bleached_driftwood"],"border":"c5b69a","deck":"a29883","soil":"c5b596","accent":"c28c6a","bed":["dune_grass","shell_bank","dune_grass"]},
 "secluded_beach":{"props":["coastal_granite","bleached_driftwood"],"border":"aa9c7e","deck":"877d62","soil":"a4946d","accent":"82a19b","bed":["coastal_granite","dune_grass","shell_bank"]},
 "fish_hoek_beach":{"props":["bleached_driftwood","shell_bank"],"border":"b7b5a7","deck":"979b92","soil":"c3c0aa","accent":"7f9baf","bed":["bleached_driftwood","dune_grass","shell_bank"]},
 "meadow_bend":{"props":["meadow_grass","shore_pebbles"],"border":"9a9f76","deck":"747e5d","soil":"6c7752","accent":"d2bc66","bed":["meadow_grass","shore_pebbles","meadow_grass"]},
 "boulder_run":{"props":["coastal_granite","shore_pebbles"],"border":"8b9185","deck":"677667","soil":"636f59","accent":"9eb0a3","bed":["coastal_granite","meadow_grass","coastal_granite"]},
 "cedar_creek":{"props":["mossy_cedar","coastal_granite"],"border":"7d8560","deck":"5c6348","soil":"42503a","accent":"a1ad74","bed":["mossy_cedar","mossy_cedar","coastal_granite"]},
 "glacier_run":{"props":["alpine_granite","coastal_granite"],"border":"bdc8c8","deck":"8b9b9c","soil":"a9b8b9","accent":"97bec7","bed":["alpine_granite","alpine_granite","shore_pebbles"]}
}
static func profile(id:String)->Dictionary:return PROFILES[id]
