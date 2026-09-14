extends RefCounted
## Local progression; rewards are issued only by the local landed-catch transition.
const PATH := "user://tackle.json"
const RODS = [
	{"name": "Willow", "price": 0, "durability": 1.0, "fatigue": 1.0},
	{"name": "Reed", "price": 150, "durability": 1.25, "fatigue": 1.3},
	{"name": "Heron", "price": 450, "durability": 1.55, "fatigue": 1.65},
	{"name": "Kingfisher", "price": 1000, "durability": 1.9, "fatigue": 2.1},
]
var shekels := 0
var owned: Array[int] = [0]
var equipped := 0
var status := ""

func rod() -> Dictionary:
	return RODS[equipped]

static func reward(species: Dictionary, length: float) -> int:
	return maxi(1, roundi(20.0 * float(species.rarity) * pow(length / float(species.length), 2.0)))

func save_profile(path := PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"shekels": shekels, "owned": owned, "equipped": equipped}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_profile(path := PATH) -> void:
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	var balance = data.get("shekels", 0)
	if (balance is int or balance is float) and is_finite(float(balance)):
		shekels = int(clampf(float(balance), 0, 1000000000))
	owned = [0]
	var rods = data.get("owned", [])
	if rods is Array:
		for index in rods:
			if (index is int or index is float) and is_finite(float(index)) and index == int(index) and int(index) in range(RODS.size()) and not int(index) in owned:
				owned.append(int(index))
	var selected = data.get("equipped", 0)
	equipped = int(selected) if (selected is int or selected is float) and is_finite(float(selected)) and selected == int(selected) and int(selected) in owned else 0

func purchase_or_equip(index: int, allowed: bool, path := PATH) -> bool:
	if not allowed:
		status = "Finish this cast and release your catch to change rods."
		return false
	if index < 0 or index >= RODS.size(): return false
	var price: int = 0 if index in owned else RODS[index].price
	if shekels < price:
		status = "You need %d more shekels." % (price - shekels)
		return false
	var previous_owned := owned.duplicate()
	var previous_equipped := equipped
	shekels -= price
	if not index in owned: owned.append(index)
	equipped = index
	if save_profile(path) != OK:
		shekels += price
		owned = previous_owned
		equipped = previous_equipped
		status = "Could not save your tackle. Purchase cancelled."
		return false
	status = "%s equipped." % rod().name
	return true
