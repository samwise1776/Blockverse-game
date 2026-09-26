extends Node

var items = {}

func _ready():
	build_items()

func build_items():
	var base = [
		"grass","dirt","stone","wood","wood_plank","stick",
		"crafting_table","coal","iron_ore","gold_ore","diamond",
		"iron_ingot","gold_ingot","chest","furnace","door","sign",
		"map","apple","sword","pickaxe","axe","shovel","coin",
		"script_block"
	]

	for id in base:
		items[id] = {
			"name": id.replace("_", " ").capitalize(),
			"stack": 64
		}

	for i in range(1000):
		var id = "crafted_item_%04d" % i
		items[id] = {
			"name": "Crafted Item %04d" % i,
			"stack": 64
		}

func exists(id):
	return items.has(id)
