extends Spatial

var inventory
var crafting
var save_system
var network
var scripting

var player
var camera
var velocity = Vector3()

var health = 100.0
var hunger = 100.0

var blocks = {}
var loaded_chunks = {}
var chunk_nodes = {}
const MAX_LOADED_CHUNKS = 2
var last_chunk = Vector2(999999, 999999)

var explored_chunks = {}

var mining_block = null
var mining_time = 0.0
var mining_required = 1.0
var mining_bar

var hotbar_slots = []
var debug_label
var debug_visible = false
var debug_timer = 0.0

var loading_layer
var loading_label
var loading_bar

var current_shape = "cube"
var shape_index = 0

var block_shapes = [
	"cube",
	"slab",
	"pillar",
	"sphere",
	"cylinder",
	"cone",
	"prism",
	"capsule"
]

var hardness = {
	"grass": 0.35,
	"dirt": 0.45,
	"wood": 0.9,
	"wood_plank": 0.75,
	"stone": 1.6,
	"coal": 2.0,
	"iron_ore": 2.6,
	"gold_ore": 3.0,
	"crafting_table": 1.2
}

const SPEED = 7.0
const JUMP_SPEED = 7.0
const GRAVITY = 20.0
const CHUNK_SIZE = 16


func _ready():
	randomize()

	inventory = preload("res://scripts/inventory.gd").new()
	crafting = preload("res://scripts/crafting.gd").new()
	save_system = preload("res://scripts/save_system.gd").new()
	network = preload("res://scripts/network.gd").new()
	scripting = preload("res://scripts/scripting.gd").new()

	add_child(inventory)
	add_child(crafting)
	add_child(save_system)
	add_child(network)
	add_child(scripting)

	make_player()
	make_environment()
	make_ui()
	make_loading_screen()

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	call_deferred("start_world_loading")



func make_loading_screen():
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)

	var background = ColorRect.new()
	background.color = Color(0.04, 0.05, 0.07, 1.0)
	background.rect_position = Vector2(0, 0)
	background.rect_size = Vector2(1280, 720)
	loading_layer.add_child(background)

	var title = Label.new()
	title.text = "BLOCKVERSE"
	title.rect_position = Vector2(530, 260)
	title.rect_scale = Vector2(2.0, 2.0)
	loading_layer.add_child(title)

	loading_label = Label.new()
	loading_label.text = "Preparing world..."
	loading_label.rect_position = Vector2(530, 350)
	loading_layer.add_child(loading_label)

	loading_bar = ProgressBar.new()
	loading_bar.rect_position = Vector2(390, 400)
	loading_bar.rect_min_size = Vector2(500, 28)
	loading_bar.min_value = 0
	loading_bar.max_value = 100
	loading_bar.value = 0
	loading_layer.add_child(loading_bar)

	
func _sort_loading_chunks(a, b):
	return a.distance < b.distance


func start_world_loading():
	var chunks = []

	var cx = int(floor(player.translation.x / CHUNK_SIZE))
	var cz = int(floor(player.translation.z / CHUNK_SIZE))

	var candidates = []

	for x in range(cx - 2, cx + 3):
		for z in range(cz - 2, cz + 3):
			var dx = x - cx
			var dz = z - cz

			candidates.append({
				"pos": Vector2(x, z),
				"distance": dx * dx + dz * dz
			})

	candidates.sort_custom(self, "_sort_loading_chunks")

	while candidates.size() > MAX_LOADED_CHUNKS:
		candidates.pop_back()

	for data in candidates:
		chunks.append(data.pos)

	var total = chunks.size()
	var done = 0

	for chunk in chunks:
		var x = int(chunk.x)
		var z = int(chunk.y)

		loading_label.text = "Generating chunk %d, %d" % [x, z]

		if not loaded_chunks.has(chunk_key(x, z)):
			generate_chunk(x, z)

		done += 1

		loading_bar.value = float(done) / float(total) * 100.0

		# Let Godot draw the loading screen between chunks.
		yield(get_tree(), "idle_frame")

	loading_label.text = "World ready!"
	loading_bar.value = 100

	yield(get_tree().create_timer(0.25), "timeout")

	loading_layer.queue_free()
	loading_layer = null

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	last_chunk = Vector2(cx, cz)

func make_environment():
	var light = DirectionalLight.new()
	light.rotation_degrees = Vector3(-60, -30, 0)
	light.shadow_enabled = true
	add_child(light)

	var env_node = WorldEnvironment.new()
	var env = Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.70, 0.95)

	env.fog_enabled = true
	env.fog_color = Color(0.55, 0.70, 0.80)
	env.fog_depth_begin = 28.0
	env.fog_depth_end = 55.0

	env_node.environment = env
	add_child(env_node)


func make_player():
	player = KinematicBody.new()
	player.translation = Vector3(0, 8, 0)

	var collision = CollisionShape.new()
	var capsule = CapsuleShape.new()

	capsule.radius = 0.4
	capsule.height = 1.8

	collision.shape = capsule
	player.add_child(collision)

	camera = Camera.new()
	camera.translation = Vector3(0, 0.6, 0)
	camera.current = true

	player.add_child(camera)
	add_child(player)


func make_ui():
	var layer = CanvasLayer.new()
	add_child(layer)

	var crosshair = Label.new()
	crosshair.text = "+"
	crosshair.rect_position = Vector2(635, 350)
	layer.add_child(crosshair)

	mining_bar = ProgressBar.new()
	mining_bar.rect_position = Vector2(515, 410)
	mining_bar.rect_min_size = Vector2(250, 14)
	mining_bar.min_value = 0
	mining_bar.max_value = 100
	mining_bar.visible = false
	layer.add_child(mining_bar)

	make_hotbar(layer)

	debug_label = Label.new()
	debug_label.rect_position = Vector2(15, 15)
	debug_label.visible = false
	layer.add_child(debug_label)

	update_hotbar()


func make_hotbar(layer):
	var bar = HBoxContainer.new()
	bar.rect_position = Vector2(365, 650)

	for i in range(9):
		var panel = Panel.new()
		panel.rect_min_size = Vector2(62, 58)

		var label = Label.new()
		label.rect_position = Vector2(5, 5)

		panel.add_child(label)
		bar.add_child(panel)

		hotbar_slots.append({
			"panel": panel,
			"label": label
		})

	layer.add_child(bar)


func update_hotbar():
	for i in range(9):
		var slot = inventory.slots[i]
		var label = hotbar_slots[i]["label"]
		var panel = hotbar_slots[i]["panel"]

		if slot.id == "":
			label.text = str(i + 1)
		else:
			label.text = "%d\n%s\nx%d" % [
				i + 1,
				slot.id,
				slot.amount
			]

		if i == inventory.selected_hotbar:
			panel.modulate = Color(1.0, 1.0, 0.55)
		else:
			panel.modulate = Color(1, 1, 1)


func _physics_process(delta):
	move_player(delta)
	update_mining(delta)
	update_chunk_loading()

	hunger -= delta * 0.02

	if hunger < 0:
		hunger = 0

	if hunger <= 0:
		health -= delta

	debug_timer += delta

	if debug_timer >= 0.2:
		debug_timer = 0.0
		update_debug()


func move_player(delta):
	var direction = Vector3()

	if Input.is_action_pressed("forward"):
		direction -= player.transform.basis.z

	if Input.is_action_pressed("back"):
		direction += player.transform.basis.z

	if Input.is_action_pressed("left"):
		direction -= player.transform.basis.x

	if Input.is_action_pressed("right"):
		direction += player.transform.basis.x

	direction.y = 0
	direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	velocity.y -= GRAVITY * delta

	if player.is_on_floor():
		if velocity.y < 0:
			velocity.y = -0.1

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED

	velocity = player.move_and_slide(
		velocity,
		Vector3.UP
	)


func _input(event):
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			player.rotate_y(
				deg2rad(-event.relative.x * 0.12)
			)

			camera.rotation_degrees.x -= event.relative.y * 0.12

			camera.rotation_degrees.x = clamp(
				camera.rotation_degrees.x,
				-89,
				89
			)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_RIGHT:
			place_selected_block()

		if event.button_index == BUTTON_WHEEL_UP:
			inventory.select_hotbar(
				inventory.selected_hotbar - 1
			)
			update_hotbar()

		if event.button_index == BUTTON_WHEEL_DOWN:
			inventory.select_hotbar(
				inventory.selected_hotbar + 1
			)
			update_hotbar()

	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_ESCAPE:
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE
			)

		if event.scancode == KEY_F3:
			debug_visible = not debug_visible
			debug_label.visible = debug_visible

		if event.scancode == KEY_R:
			shape_index += 1

			if shape_index >= block_shapes.size():
				shape_index = 0

			current_shape = block_shapes[shape_index]

		if event.scancode >= KEY_1 and event.scancode <= KEY_9:
			inventory.select_hotbar(
				event.scancode - KEY_1
			)
			update_hotbar()


func update_mining(delta):
	if not Input.is_mouse_button_pressed(BUTTON_LEFT):
		cancel_mining()
		return

	var hit = get_hit()

	if hit.empty():
		cancel_mining()
		return

	var block = hit.collider

	if not block.is_in_group("blocks"):
		cancel_mining()
		return

	if mining_block != block:
		mining_block = block
		mining_time = 0.0

		var block_type = block.get_meta("block_type")
		mining_required = hardness.get(block_type, 1.0)

	mining_time += delta * get_tool_speed(
		block.get_meta("block_type")
	)

	mining_bar.value = min(
		100,
		(mining_time / mining_required) * 100.0
	)

	mining_bar.visible = true

	if mining_time >= mining_required:
		finish_mining(block)


func get_tool_speed(block_type):
	var selected = inventory.selected_item()

	if selected.id == "pickaxe":
		if block_type in [
			"stone",
			"coal",
			"iron_ore",
			"gold_ore"
		]:
			return 3.0

	if selected.id == "axe":
		if block_type in [
			"wood",
			"wood_plank",
			"crafting_table"
		]:
			return 3.0

	if selected.id == "shovel":
		if block_type in [
			"dirt",
			"grass"
		]:
			return 3.0

	return 1.0


func cancel_mining():
	mining_block = null
	mining_time = 0.0

	if mining_bar:
		mining_bar.visible = false


func finish_mining(block):
	var block_type = block.get_meta("block_type")

	inventory.add_item(
		block_type,
		1
	)

	blocks.erase(
		str(block.translation)
	)

	block.queue_free()

	update_hotbar()
	cancel_mining()


func create_shape_mesh(shape_name):
	match shape_name:

		"cube":
			var m = CubeMesh.new()
			m.size = Vector3.ONE
			return m

		"slab":
			var m = CubeMesh.new()
			m.size = Vector3(1, 0.5, 1)
			return m

		"pillar":
			var m = CubeMesh.new()
			m.size = Vector3(0.5, 1, 0.5)
			return m

		"sphere":
			var m = SphereMesh.new()
			m.radius = 0.5
			m.height = 1
			m.radial_segments = 8
			m.rings = 4
			return m

		"cylinder":
			var m = CylinderMesh.new()
			m.top_radius = 0.5
			m.bottom_radius = 0.5
			m.height = 1
			m.radial_segments = 8
			return m

		"cone":
			var m = CylinderMesh.new()
			m.top_radius = 0
			m.bottom_radius = 0.5
			m.height = 1
			m.radial_segments = 8
			return m

		"prism":
			var m = PrismMesh.new()
			m.size = Vector3.ONE
			return m

		"capsule":
			var m = CapsuleMesh.new()
			m.radius = 0.35
			m.height = 1
			m.radial_segments = 8
			m.rings = 4
			return m

	var fallback = CubeMesh.new()
	fallback.size = Vector3.ONE
	return fallback


func create_material(block_type):
	var material = SpatialMaterial.new()

	material.roughness = 1.0
	material.metallic = 0.0

	match block_type:
		"grass":
			material.albedo_color = Color(0.25, 0.72, 0.24)

		"dirt":
			material.albedo_color = Color(0.43, 0.25, 0.10)

		"stone":
			material.albedo_color = Color(0.48, 0.48, 0.50)

		"sand":
			material.albedo_color = Color(0.82, 0.74, 0.48)

		"snow":
			material.albedo_color = Color(0.92, 0.95, 1.0)

		"wood":
			material.albedo_color = Color(0.55, 0.34, 0.15)

		"wood_plank":
			material.albedo_color = Color(0.68, 0.45, 0.21)

		"leaves":
			material.albedo_color = Color(0.12, 0.52, 0.13)

		"coal":
			material.albedo_color = Color(0.08, 0.08, 0.09)

		"iron_ore":
			material.albedo_color = Color(0.65, 0.55, 0.45)

		"gold_ore":
			material.albedo_color = Color(0.90, 0.75, 0.12)

		"crafting_table":
			material.albedo_color = Color(0.65, 0.40, 0.15)

		_:
			material.albedo_color = Color(0.7, 0.7, 0.7)

	return material


func make_block(pos, block_type = "grass", block_shape = "cube"):
	var key = str(pos)

	if blocks.has(key):
		return

	var body = StaticBody.new()

	body.translation = pos
	body.add_to_group("blocks")

	body.set_meta("block_type", block_type)
	body.set_meta("shape", block_shape)

	var mesh_instance = MeshInstance.new()
	var mesh = create_shape_mesh(block_shape)

	mesh.material = create_material(block_type)
	mesh_instance.mesh = mesh

	var collision = CollisionShape.new()

	if block_shape == "sphere":
		var shape = SphereShape.new()
		shape.radius = 0.5
		collision.shape = shape

	elif block_shape == "capsule":
		var shape = CapsuleShape.new()
		shape.radius = 0.35
		shape.height = 1.0
		collision.shape = shape

	else:
		var shape = BoxShape.new()

		if block_shape == "slab":
			shape.extents = Vector3(0.5, 0.25, 0.5)

		elif block_shape == "pillar":
			shape.extents = Vector3(0.25, 0.5, 0.25)

		else:
			shape.extents = Vector3(0.5, 0.5, 0.5)

		collision.shape = shape

	body.add_child(mesh_instance)
	body.add_child(collision)

	add_child(body)

	blocks[key] = body
	return body


func generate_chunks(radius):
	for cx in range(-radius, radius + 1):
		for cz in range(-radius, radius + 1):
			generate_chunk(cx, cz)


func generate_chunk(cx, cz):
	var key = chunk_key(cx, cz)

	if loaded_chunks.has(key):
		return

	loaded_chunks[key] = true
	chunk_nodes[key] = []

	print("Generating chunk ", cx, ", ", cz)

	for lx in range(CHUNK_SIZE):
		for lz in range(CHUNK_SIZE):
			var x = cx * CHUNK_SIZE + lx
			var z = cz * CHUNK_SIZE + lz

			var h = int(
				4
				+ sin(x * 0.07) * 3
				+ cos(z * 0.09) * 3
				+ sin((x + z) * 0.035) * 4
			)

			var biome = get_biome(x, z)

			var top_block = "grass"
			var under_block = "dirt"

			if biome == "desert":
				top_block = "sand"
				under_block = "sand"

			elif biome == "snow":
				top_block = "snow"
				under_block = "dirt"

			make_block(
				Vector3(x, h, z),
				top_block,
				"cube"
			)

			make_block(
				Vector3(x, h - 1, z),
				under_block,
				"cube"
			)

			make_block(
				Vector3(x, h - 2, z),
				"stone",
				"cube"
			)

			# Occasional deeper ore blocks.
			if randi() % 90 == 0:
				make_block(
					Vector3(x, h - 3, z),
					"coal",
					"cube"
				)

			if randi() % 180 == 0:
				make_block(
					Vector3(x, h - 4, z),
					"iron_ore",
					"cube"
				)

			if randi() % 400 == 0:
				make_block(
					Vector3(x, h - 5, z),
					"gold_ore",
					"cube"
				)

	# Record all blocks belonging to this chunk.
	for block_key in blocks.keys():
		var node = blocks[block_key]

		if not is_instance_valid(node):
			continue

		var bx = int(floor(node.translation.x / CHUNK_SIZE))
		var bz = int(floor(node.translation.z / CHUNK_SIZE))

		if bx == cx and bz == cz:
			if not node in chunk_nodes[key]:
				chunk_nodes[key].append(node)



func chunk_key(cx, cz):
	return str(cx) + ":" + str(cz)


func update_chunk_loading(force = false):
	var cx = int(floor(player.translation.x / CHUNK_SIZE))
	var cz = int(floor(player.translation.z / CHUNK_SIZE))
	var here = Vector2(cx, cz)

	if not force and here == last_chunk:
		return

	last_chunk = here

	# Closest 10 chunks around player.
	var wanted = []

	for x in range(cx - 2, cx + 3):
		for z in range(cz - 2, cz + 3):
			var dx = x - cx
			var dz = z - cz
			var distance = dx * dx + dz * dz

			wanted.append({
				"x": x,
				"z": z,
				"distance": distance
			})

	wanted.sort_custom(self, "_sort_chunks")

	# Only keep the closest 10.
	while wanted.size() > MAX_LOADED_CHUNKS:
		wanted.pop_back()

	var wanted_keys = {}

	for data in wanted:
		var key = chunk_key(data.x, data.z)
		wanted_keys[key] = true

		if not loaded_chunks.has(key):
			generate_chunk(data.x, data.z)

	# Unload chunks that are no longer in the closest 10.
	var remove_keys = []

	for key in loaded_chunks.keys():
		if not wanted_keys.has(key):
			remove_keys.append(key)

	for key in remove_keys:
		unload_chunk(key)


func _sort_chunks(a, b):
	return a.distance < b.distance


func unload_chunk(key):
	if not chunk_nodes.has(key):
		loaded_chunks.erase(key)
		return

	var nodes = chunk_nodes[key]

	for node in nodes:
		if is_instance_valid(node):
			blocks.erase(str(node.translation))
			node.queue_free()

	chunk_nodes.erase(key)
	loaded_chunks.erase(key)


func get_biome(x, z):
	var value = (
		sin(x * 0.01)
		+ cos(z * 0.013)
	)

	if value > 1.0:
		return "desert"

	if value < -1.0:
		return "snow"

	return "plains"


func get_hit():
	var center = get_viewport().size / 2

	var origin = camera.project_ray_origin(center)
	var direction = camera.project_ray_normal(center)

	return get_world().direct_space_state.intersect_ray(
		origin,
		origin + direction * 8,
		[player]
	)


func place_selected_block():
	var hit = get_hit()

	if hit.empty():
		return

	var selected = inventory.selected_item()

	if selected.id == "":
		return

	var pos = hit.position + hit.normal * 0.51

	pos = Vector3(
		round(pos.x),
		round(pos.y),
		round(pos.z)
	)

	make_block(
		pos,
		selected.id,
		current_shape
	)

	inventory.remove_item(
		selected.id,
		1
	)

	update_hotbar()


func update_debug():
	if not debug_visible:
		return

	var p = player.translation

	var cx = int(
		floor(p.x / CHUNK_SIZE)
	)

	var cz = int(
		floor(p.z / CHUNK_SIZE)
	)

	var selected = inventory.selected_item()

	debug_label.text = \
		"BLOCKVERSE DEBUG\n" + \
		"FPS: " + str(
			Engine.get_frames_per_second()
		) + "\n" + \
		"XYZ: %.1f %.1f %.1f\n" % [
			p.x,
			p.y,
			p.z
		] + \
		"Chunk: %d %d\n" % [
			cx,
			cz
		] + \
		"Blocks: " + \
		str(blocks.size()) + "\n" + \
		"Health: " + \
		str(int(health)) + "\n" + \
		"Hunger: " + \
		str(int(hunger)) + "\n" + \
		"Item: " + \
		selected.id + "\n" + \
		"Shape: " + \
		current_shape
