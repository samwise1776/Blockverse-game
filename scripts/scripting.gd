extends Node

func execute(source, player, world):
	for raw_line in source.split("\n"):
		var line = raw_line.strip_edges()

		if line == "":
			continue

		var parts = line.split(" ")

		match parts[0]:
			"print":
				print(line.substr(6))

			"heal":
				if parts.size() >= 2:
					player.health += int(parts[1])

			"damage":
				if parts.size() >= 2:
					player.health -= int(parts[1])

			"teleport":
				if parts.size() >= 4:
					player.translation = Vector3(
						float(parts[1]),
						float(parts[2]),
						float(parts[3])
					)

			"give":
				if parts.size() >= 3:
					player.inventory.add_item(
						parts[1],
						int(parts[2])
					)

			"setblock":
				if parts.size() >= 5:
					world.make_block(
						Vector3(
							int(parts[1]),
							int(parts[2]),
							int(parts[3])
						),
						parts[4]
					)

			"spawn":
				print("Spawn command:", parts)

			"destroy":
				print("Destroy command:", parts)
