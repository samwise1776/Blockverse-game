extends Node

func save_world(world_data, name = "world1"):
	var file = File.new()

	if not Directory.new().dir_exists("user://worlds"):
		Directory.new().make_dir("user://worlds")

	file.open(
		"user://worlds/" + name + ".save",
		File.WRITE
	)

	file.store_var(world_data)
	file.close()

func load_world(name = "world1"):
	var path = "user://worlds/" + name + ".save"

	var file = File.new()

	if not file.file_exists(path):
		return {}

	file.open(path, File.READ)

	var data = file.get_var()

	file.close()

	return data
