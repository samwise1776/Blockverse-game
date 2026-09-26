extends Node

var recipes = {}

func _ready():
	build_recipes()

func build_recipes():
	recipes.clear()

	recipes["stick+wood_plank"] = "crafting_table"
	recipes["wood_plank+stick"] = "crafting_table"
	recipes["wood+wood"] = "wood_plank"
	recipes["stone+stick"] = "pickaxe"
	recipes["iron_ingot+stick"] = "sword"
	recipes["wood_plank+wood_plank"] = "chest"
	recipes["stone+coal"] = "furnace"
	recipes["wood_plank+iron_ingot"] = "door"
	recipes["wood_plank+coal"] = "sign"
	recipes["paper+coal"] = "map"

	for i in range(1000):
		var a = "crafted_item_%04d" % ((i + 999) % 1000)
		var b = "crafted_item_%04d" % ((i + 37) % 1000)
		var out = "crafted_item_%04d" % i

		recipes[a + "+" + b] = out

func craft(a, b):
	var key = a + "+" + b

	if recipes.has(key):
		return recipes[key]

	key = b + "+" + a

	if recipes.has(key):
		return recipes[key]

	return ""
