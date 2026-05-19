extends Area3D
class_name TerrainRegion

enum Type {
	GRASSLAND = 0,
	FOREST = 1,
	ROCKY = 2,
	FERTILE_LAND = 3,
	FORD = 4,
	ELEVATED = 5,
}

const TERRAIN_COLORS_3D = {
	Type.GRASSLAND: Color(0.55, 0.75, 0.35, 0.80),
	Type.FOREST: Color(0.15, 0.45, 0.15, 0.80),
	Type.ROCKY: Color(0.55, 0.55, 0.50, 0.80),
	Type.FERTILE_LAND: Color(0.75, 0.62, 0.30, 0.80),
	Type.FORD: Color(0.45, 0.70, 0.85, 0.80),
	Type.ELEVATED: Color(0.50, 0.80, 0.28, 0.80),
}

static var _mat_cache: Dictionary = {}
static var _shadow_mat: StandardMaterial3D = null
static var _conifer_textures: Array = [
	preload("res://assets/textures/terrain/tree_a0001.png"),
	preload("res://assets/textures/terrain/tree_a0002.png"),
	preload("res://assets/textures/terrain/tree_a0003.png"),
	preload("res://assets/textures/terrain/tree_b0001.png"),
	preload("res://assets/textures/terrain/tree_b0002.png"),
	preload("res://assets/textures/terrain/tree_b0003.png"),
	preload("res://assets/textures/terrain/tree_c0001.png"),
	preload("res://assets/textures/terrain/tree_c0002.png"),
	preload("res://assets/textures/terrain/tree_c0003.png"),
]
static var _deciduous_textures: Array = [
	preload("res://assets/textures/terrain/tree_d0001.png"),
	preload("res://assets/textures/terrain/tree_d0002.png"),
	preload("res://assets/textures/terrain/tree_d0003.png"),
	preload("res://assets/textures/terrain/tree_e0001.png"),
	preload("res://assets/textures/terrain/tree_e0002.png"),
	preload("res://assets/textures/terrain/tree_e0003.png"),
	preload("res://assets/textures/terrain/tree_f0001.png"),
	preload("res://assets/textures/terrain/tree_f0002.png"),
	preload("res://assets/textures/terrain/tree_f0003.png"),
	preload("res://assets/textures/terrain/tree_g0001.png"),
	preload("res://assets/textures/terrain/tree_g0002.png"),
	preload("res://assets/textures/terrain/tree_g0003.png"),
]
static var _bare_textures: Array = [
	preload("res://assets/textures/terrain/tree_i0001.png"),
	preload("res://assets/textures/terrain/tree_i0002.png"),
	preload("res://assets/textures/terrain/tree_i0003.png"),
	preload("res://assets/textures/terrain/tree_j0001.png"),
	preload("res://assets/textures/terrain/tree_j0002.png"),
	preload("res://assets/textures/terrain/tree_j0003.png"),
]
static var _tree_mat_cache: Dictionary = {}

@export var terrain_type: Type = Type.GRASSLAND


func _ready():
	input_ray_pickable = false
	TerrainManager.register_region(self)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_add_terrain_visual()
	_add_terrain_details()


func _add_terrain_visual() -> void:
	# REPLACED BY TerrainVisualSystem
	# Original code preserved below
	pass
	#var color = TERRAIN_COLORS_3D.get(terrain_type)
	#if color == null:
	#	return
	## Measure world-space extents from the parent transform's basis column lengths.
	## This lets the flat overlay match the region's scale without inheriting its rotation.
	#var sx: float = global_transform.basis.x.length()
	#var sz: float = global_transform.basis.z.length()
	#var mesh_inst := MeshInstance3D.new()
	#var plane := PlaneMesh.new()
	#plane.size = Vector2(10.0 * sx, 10.0 * sz)
	#mesh_inst.mesh = plane
	#var mat := StandardMaterial3D.new()
	#if terrain_type == Type.ROCKY:
	#	const TEX_PATH = "res://assets/textures/terrain/rocky-rugged-terrain_1_albedo.png"
	#	var tex = load(TEX_PATH)
	#	if tex == null:
	#		GameLogger.debug(GameLogger.Category.STARTUP, "Rocky texture failed to load", {"path": TEX_PATH})
	#	else:
	#		GameLogger.debug(GameLogger.Category.STARTUP, "Rocky texture loaded OK", {"size": str(tex.get_size())})
	#	mat.albedo_texture = tex
	#	const TILE_SIZE := 5.0
	#	mat.uv1_scale = Vector3(plane.size.x / TILE_SIZE, plane.size.y / TILE_SIZE, 1.0)
	#	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	#	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	#else:
	#	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	#	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#	mat.albedo_color = color
	#mesh_inst.material_override = mat
	#mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	#add_child(mesh_inst)
	## top_level removes parent transform inheritance so the plane is always world-horizontal.
	#mesh_inst.top_level = true
	#mesh_inst.global_transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.003, 0))


static func _get_shadow_mat() -> StandardMaterial3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.18)
	return _shadow_mat


static func _get_mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _mat_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		_mat_cache[key] = mat
	return _mat_cache[key] as StandardMaterial3D


func _make_detail(mesh: Mesh, color: Color, world_pos: Vector3, rot_y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _get_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_position = world_pos
	mi.rotation = Vector3(0.0, rot_y, 0.0)
	return mi


func _add_terrain_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	var gpos: Vector3 = global_position
	var sx: float = global_transform.basis.x.length()
	var sz: float = global_transform.basis.z.length()
	match terrain_type:
		# FOREST: handled by TerrainVisualSystem MultiMesh system
		Type.ROCKY:
			_add_rocky_details(rng, gpos, sx, sz)
		Type.FERTILE_LAND:
			_add_fertile_details(rng, gpos, sx, sz)
		Type.FORD:
			_add_ford_details(rng, gpos, sx, sz)
		Type.GRASSLAND:
			_add_grassland_details(rng, gpos, sx, sz)
		Type.ELEVATED:
			_add_elevated_details(rng, gpos, sx, sz)


func _add_forest_details(rng: RandomNumberGenerator, gpos: Vector3, sx: float, sz: float) -> void:
	const MIN_SPACING: float = 0.6
	const MAX_TREES: int = 240
	const MIN_TREES: int = 15
	var bx: float = 4.5 * sx
	var bz: float = 4.5 * sz
	var total_count: int = clampi(int((2.0 * bx) * (2.0 * bz) / 2.0), MIN_TREES, MAX_TREES)
	var placed: Array[Vector2] = []
	# Pass 1: treeline — fill the outer border band first
	const INNER: float = 0.75
	const OUTER: float = 0.98
	var perimeter: float = 4.0 * (bx + bz)
	var n_slots: int = int(perimeter / 1.1)
	for _slot in range(n_slots):
		if placed.size() >= total_count:
			break
		if rng.randf() < 0.22:
			continue
		var edge_roll: float = rng.randf() * perimeter
		var r: float = rng.randf_range(INNER, OUTER)
		var wx: float
		var wz: float
		if edge_roll < 2.0 * bx:
			wx = gpos.x + rng.randf_range(-bx, bx)
			wz = gpos.z + r * bz
		elif edge_roll < 2.0 * bx + 2.0 * bz:
			wx = gpos.x + r * bx
			wz = gpos.z + rng.randf_range(-bz, bz)
		elif edge_roll < 4.0 * bx + 2.0 * bz:
			wx = gpos.x + rng.randf_range(-bx, bx)
			wz = gpos.z - r * bz
		else:
			wx = gpos.x - r * bx
			wz = gpos.z + rng.randf_range(-bz, bz)
		var pos2d := Vector2(wx, wz)
		var ok := true
		for p: Vector2 in placed:
			if pos2d.distance_to(p) < MIN_SPACING:
				ok = false
				break
		if ok:
			placed.append(pos2d)
			_spawn_tree(rng, pos2d, gpos.y)
	# Pass 2: interior fill — remaining budget spread across the whole region
	for _i in range(total_count - placed.size()):
		for _attempt in range(20):
			var wx: float = gpos.x + rng.randf_range(-bx, bx)
			var wz: float = gpos.z + rng.randf_range(-bz, bz)
			var pos2d := Vector2(wx, wz)
			var ok := true
			for p: Vector2 in placed:
				if pos2d.distance_to(p) < MIN_SPACING:
					ok = false
					break
			if not ok:
				continue
			placed.append(pos2d)
			_spawn_tree(rng, pos2d, gpos.y)
			break


func _spawn_tree(rng: RandomNumberGenerator, pos2d: Vector2, ground_y: float) -> void:
	var species_roll: float = rng.randf()
	var tex: Texture2D
	var scale_mult: float
	if species_roll < 0.55:
		tex = _conifer_textures[rng.randi() % _conifer_textures.size()]
		scale_mult = 1.10
	elif species_roll < 0.97:
		tex = _deciduous_textures[rng.randi() % _deciduous_textures.size()]
		scale_mult = 1.05
	else:
		tex = _bare_textures[rng.randi() % _bare_textures.size()]
		scale_mult = 1.0
	var tree_scale: float = rng.randf_range(0.9, 1.6) * scale_mult
	_make_billboard_tree(tex, Vector3(pos2d.x, ground_y + 0.75 * tree_scale, pos2d.y), tree_scale)
	_make_tree_shadow(Vector3(pos2d.x + 0.15, ground_y + 0.005, pos2d.y - 0.15), 0.35 * tree_scale)


func _make_billboard_tree(tex: Texture2D, world_pos: Vector3, tree_scale: float) -> void:
	var key: String = tex.resource_path
	if not _tree_mat_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.15
		mat.albedo_texture = tex
		_tree_mat_cache[key] = mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.2, 1.5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _tree_mat_cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_position = world_pos
	mi.scale = Vector3(tree_scale, tree_scale, tree_scale)


func _make_tree_shadow(world_pos: Vector3, radius: float) -> void:
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = radius
	shadow_mesh.bottom_radius = radius
	shadow_mesh.height = 0.01
	shadow_mesh.radial_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = shadow_mesh
	mi.material_override = _get_shadow_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.top_level = true
	mi.global_position = world_pos


func _add_rocky_details(rng: RandomNumberGenerator, gpos: Vector3, sx: float, sz: float) -> void:
	const MAX_ROCKS: int = 30
	var grey_tones: Array[Color] = [
		Color(0.70, 0.68, 0.63),
		Color(0.52, 0.50, 0.47),
		Color(0.35, 0.33, 0.30),
	]
	var rock_count: int = 0
	var cluster_count: int = min(int(100.0 / 3.0), MAX_ROCKS / 2)
	var bx: float = 4.5 * sx
	var bz: float = 4.5 * sz
	for _ci: int in range(cluster_count):
		if rock_count >= MAX_ROCKS:
			break
		var cx: float = gpos.x + rng.randf_range(-bx, bx)
		var cz_w: float = gpos.z + rng.randf_range(-bz, bz)
		var cluster_size: int = rng.randi_range(3, 5)
		for _ri: int in range(cluster_size):
			if rock_count >= MAX_ROCKS:
				break
			var ox: float = rng.randf_range(-0.5, 0.5)
			var oz: float = rng.randf_range(-0.5, 0.5)
			var radius: float = rng.randf_range(0.12, 0.28)
			var color: Color = grey_tones[rng.randi() % 3]
			var rpos := Vector3(cx + ox, gpos.y + radius * 0.5, cz_w + oz)
			var rand_rot := Vector3(
				rng.randf_range(0.0, TAU),
				rng.randf_range(0.0, TAU),
				rng.randf_range(0.0, TAU)
			)
			var mesh := SphereMesh.new()
			mesh.radius = radius
			mesh.height = radius * 2.0
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _get_mat(color)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.top_level = true
			mi.global_position = rpos
			mi.rotation = rand_rot
			var shadow_color := Color(
				maxf(0.0, color.r - 0.15),
				maxf(0.0, color.g - 0.15),
				maxf(0.0, color.b - 0.15)
			)
			var s_radius: float = radius * 0.85
			var s_mesh := SphereMesh.new()
			s_mesh.radius = s_radius
			s_mesh.height = s_radius * 2.0
			var s_mi := MeshInstance3D.new()
			s_mi.mesh = s_mesh
			s_mi.material_override = _get_mat(shadow_color)
			s_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(s_mi)
			s_mi.top_level = true
			s_mi.global_position = Vector3(rpos.x + radius * 0.5, rpos.y, rpos.z - radius * 0.5)
			s_mi.rotation = rand_rot
			rock_count += 1


func _add_fertile_details(rng: RandomNumberGenerator, gpos: Vector3, sx: float, sz: float) -> void:
	const MAX_STALKS: int = 55
	var stalk_color := Color(0.78, 0.82, 0.22)
	var shadow_color := Color(0.45, 0.52, 0.08)
	var bx: float = 4.5 * sx
	var bz: float = 4.5 * sz
	var rows: int = rng.randi_range(6, 9)
	var stalks_per_row: int = rng.randi_range(5, 6)
	var stalk_mesh := BoxMesh.new()
	stalk_mesh.size = Vector3(0.15, 0.12, 0.15)
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.02, 0.20, 0.02)
	var placed: int = 0
	for r in range(rows):
		if placed >= MAX_STALKS:
			break
		var row_x: float = lerp(gpos.x - bx, gpos.x + bx, float(r) / float(maxi(rows - 1, 1)))
		for s in range(stalks_per_row):
			if placed >= MAX_STALKS:
				break
			var stalk_z: float = lerp(gpos.z - bz, gpos.z + bz, float(s) / float(maxi(stalks_per_row - 1, 1)))
			var wx: float = row_x + rng.randf_range(-0.3, 0.3)
			var wz: float = stalk_z + rng.randf_range(-0.3, 0.3)
			_make_detail(stalk_mesh, stalk_color, Vector3(wx, gpos.y + 0.06, wz), 0.0)
			_make_detail(face_mesh, shadow_color, Vector3(wx + 0.025, gpos.y + 0.06, wz - 0.025), 0.0)
			placed += 1
		var row_shadow_mesh := BoxMesh.new()
		row_shadow_mesh.size = Vector3(0.04, 0.01, 2.0 * bz)
		var row_shadow_mi := MeshInstance3D.new()
		row_shadow_mi.mesh = row_shadow_mesh
		row_shadow_mi.material_override = _get_shadow_mat()
		row_shadow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(row_shadow_mi)
		row_shadow_mi.top_level = true
		row_shadow_mi.global_position = Vector3(row_x + 0.08, gpos.y + 0.01, gpos.z - 0.08)


func _add_ford_details(rng: RandomNumberGenerator, gpos: Vector3, sx: float, sz: float) -> void:
	const MAX_SHIMMERS: int = 25
	const MAX_DARKS: int = 12
	var shimmer_count: int = min(int(100.0 / 2.0), MAX_SHIMMERS)
	var dark_count: int = min(int(100.0 / 4.0), MAX_DARKS)
	var shimmer_color := Color(0.85, 0.93, 1.0)
	var dark_color := Color(0.30, 0.55, 0.75)
	var bx: float = 4.5 * sx
	var bz: float = 4.5 * sz
	for _i: int in range(shimmer_count):
		var wx: float = gpos.x + rng.randf_range(-bx, bx)
		var wz: float = gpos.z + rng.randf_range(-bz, bz)
		var length: float = rng.randf_range(0.4, 0.8)
		var rot_y: float = rng.randf_range(PI / 6.0, PI / 3.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length, 0.008, 0.03)
		_make_detail(mesh, shimmer_color, Vector3(wx, gpos.y + 0.02, wz), rot_y)
	for _i: int in range(dark_count):
		var wx: float = gpos.x + rng.randf_range(-bx, bx)
		var wz: float = gpos.z + rng.randf_range(-bz, bz)
		var length: float = rng.randf_range(0.4, 0.8)
		var rot_y: float = rng.randf_range(PI / 6.0, PI / 3.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length, 0.008, 0.05)
		_make_detail(mesh, dark_color, Vector3(wx, gpos.y + 0.02, wz), rot_y)


func _add_grassland_details(rng: RandomNumberGenerator, gpos: Vector3, sx: float, sz: float) -> void:
	const MAX_TUFTS: int = 10
	var count: int = min(int(100.0 / 10.0), MAX_TUFTS)
	var blade_color := Color(0.42, 0.68, 0.22)
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.03, 0.18, 0.03)
	var bx: float = 4.5 * sx
	var bz: float = 4.5 * sz
	for _i: int in range(count):
		var wx: float = gpos.x + rng.randf_range(-bx, bx)
		var wz: float = gpos.z + rng.randf_range(-bz, bz)
		var base_rot: float = rng.randf_range(0.0, TAU)
		for b: int in range(3):
			_make_detail(
				blade_mesh, blade_color,
				Vector3(wx, gpos.y + 0.09, wz),
				base_rot + b * (PI / 12.0)
			)


func _add_elevated_details(rng: RandomNumberGenerator, gpos: Vector3, sx: float, sz: float) -> void:
	const MAX_STONES: int = 12
	const INSET: float = 1.5
	var stone_color := Color(0.60, 0.58, 0.54)
	var hx: float = 5.0 * sx
	var hz: float = 5.0 * sz
	for _i: int in range(MAX_STONES):
		var edge: int = rng.randi() % 4
		var wx: float
		var wz: float
		match edge:
			0:
				wx = gpos.x + rng.randf_range(-hx + 0.5, hx - 0.5)
				wz = gpos.z + rng.randf_range(-hz, -hz + INSET * sz)
			1:
				wx = gpos.x + rng.randf_range(-hx + 0.5, hx - 0.5)
				wz = gpos.z + rng.randf_range(hz - INSET * sz, hz)
			2:
				wx = gpos.x + rng.randf_range(hx - INSET * sx, hx)
				wz = gpos.z + rng.randf_range(-hz + 0.5, hz - 0.5)
			_:
				wx = gpos.x + rng.randf_range(-hx, -hx + INSET * sx)
				wz = gpos.z + rng.randf_range(-hz + 0.5, hz - 0.5)
		var radius: float = rng.randf_range(0.08, 0.15)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _get_mat(stone_color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.top_level = true
		mi.global_position = Vector3(wx, gpos.y + radius * 0.5, wz)
		mi.rotation = Vector3(
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU)
		)


func _exit_tree():
	TerrainManager.unregister_region(self)


func contains_point(world_pos: Vector3) -> bool:
	var local_pos = to_local(world_pos)
	for child in get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			if shape is BoxShape3D:
				var half = shape.size / 2.0
				return (
					abs(local_pos.x) <= half.x
					and abs(local_pos.z) <= half.z
				)
	return false


func _on_area_entered(area: Area3D):
	if not area.is_in_group("units"):
		return
	TerrainManager._on_unit_entered_region(area, self)


func _on_area_exited(area: Area3D):
	if not area.is_in_group("units"):
		return
	TerrainManager._on_unit_exited_region(area, self)
