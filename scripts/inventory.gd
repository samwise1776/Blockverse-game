extends Node

const SLOT_COUNT = 36
const HOTBAR_COUNT = 9

var slots = []
var selected_hotbar = 0

func _ready():
	for i in range(SLOT_COUNT):
		slots.append({
			"id": "",
			"amount": 0
		})

	add_item("wood", 20)
	add_item("stick", 10)
	add_item("stone", 20)

func add_item(id, amount = 1):
	for slot in slots:
		if slot.id == id:
			slot.amount += amount
			return true

	for slot in slots:
		if slot.id == "":
			slot.id = id
			slot.amount = amount
			return true

	return false

func remove_item(id, amount = 1):
	for slot in slots:
		if slot.id == id and slot.amount >= amount:
			slot.amount -= amount

			if slot.amount <= 0:
				slot.id = ""
				slot.amount = 0

			return true

	return false

func has_item(id, amount = 1):
	var total = 0

	for slot in slots:
		if slot.id == id:
			total += slot.amount

	return total >= amount

func select_hotbar(index):
	selected_hotbar = clamp(index, 0, HOTBAR_COUNT - 1)

func selected_item():
	return slots[selected_hotbar]
