## 학교 5층을 평면 데이터(school_layout.gd)로부터 짓는다.
##
## 방법: 층마다 방을 0.5 m 칸에 찍고, 서로 다른 방이 맞닿는 칸 경계에 벽을 세운다.
##   복도끼리, 복도와 트인 공간(미디어스페이스 등) 사이에는 벽이 없다.
##   바깥(또는 중정)과 맞닿으면 바깥벽(창, 바깥은 벽돌), 방끼리는 안벽.
##   문은 방의 문 방향(door)에 있는 복도 쪽 벽에 낸다 (교실·큰 방은 앞뒤 둘).
##   바닥·천장은 같은 재질 칸끼리 직사각형으로 합친다. 계단은 따로 짓는다 (U자 두 줄, 층마다 24단).
## 상자는 층마다 재질별 메시 하나로 합치고(MeshBatch), 충돌은 층마다 StaticBody 하나에 상자 모양을 붙인다.
class_name SchoolBuilder
extends Node3D

const C := 0.5                  # 칸 크기
const GX0 := -60.0              # 칸 격자 시작 (별관 서쪽 바깥 여유)
const GZ0 := -1.0
const NX := 244                 # (-60 .. 62) / 0.5
const NZ := 130                 # (-1 .. 64) / 0.5
const WALL_T := 0.2
const EXT_T := 0.3
const OUTDOOR := ["out", "void", "court", "terrace", "path"]
const STEP_N := 12              # 한 줄 계단 수 (층 높이 3.6 = 24 × 0.15)
const LANDING := 1.5

var mats := {}
var floors_rooms := []          # 층(0..4) → 방 배열 (rect는 칸에 맞춘 srect도 들어 있다)
var grids := []                 # 층 → PackedInt32Array (칸 → 방 번호, -1 = 바깥)
var door_points := {}           # "층:방이름" → 문 가운데 (월드)
var stats := {}

var _font: SystemFont


func build() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "Noto Sans", "DejaVu Sans", "Arial"])
	_font.font_weight = 600
	_make_materials()
	for f in SchoolLayout.FLOORS:
		var rooms := SchoolLayout.rooms(f + 1)
		var grid := _rasterize(rooms)
		floors_rooms.append(rooms)
		grids.append(grid)
	for f in SchoolLayout.FLOORS:
		_build_floor(f)
	for f in SchoolLayout.FLOORS:
		_build_roof(f)
	_build_pillars()
	_build_ground()
	# 문이 없는 방 (들어갈 수 없는 방) 목록
	var sealed: Array = []
	for f in SchoolLayout.FLOORS:
		for room in floors_rooms[f]:
			if String(room["kind"]) in ["corr", "open", "closed", "void", "court", "eps", "out", "terrace", "path"] or String(room["name"]).begins_with("("):
				continue
			if not door_points.has("%d:%s" % [f + 1, room["name"]]):
				sealed.append("%d층 %s" % [f + 1, room["name"]])
	if not sealed.is_empty():
		print("rooms without door: ", sealed)
	var boxes := 0
	for k in stats:
		boxes += stats[k]
	print("school built: %d boxes" % boxes)


# ================================================================ 재질

func _tex(size: int, painter: Callable) -> ImageTexture:
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = size * 7 + 3
	painter.call(img, rng)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tri(color: Color, tex: Texture2D = null, tile := 1.0, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / tile
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _make_materials() -> void:
	# 테라조 타일 (60 cm, 흰 바탕에 검고 회색 점): 텍스처 한 장 = 1.2 m (타일 2 × 2)
	var terrazzo := _tex(256, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 256:
			for x in 256:
				var v := 0.86 + rng.randf_range(-0.03, 0.03)
				var r := rng.randf()
				if r < 0.05:
					v = rng.randf_range(0.25, 0.55)
				elif r < 0.09:
					v = rng.randf_range(0.65, 0.75)
				if x % 128 == 0 or y % 128 == 0:
					v *= 0.8
				img.set_pixel(x, y, Color(v, v * 0.995, v * 0.985)))
	var granite := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var v := 0.38 + rng.randf_range(-0.1, 0.1)
				if rng.randf() < 0.12:
					v = rng.randf_range(0.6, 0.8)
				img.set_pixel(x, y, Color(v, v, v * 1.02)))
	var ceiling := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var v := 0.93 + rng.randf_range(-0.015, 0.015)
				if rng.randf() < 0.03:
					v -= 0.12
				if x % 64 == 0 or y % 64 == 0:
					v = 0.78
				img.set_pixel(x, y, Color(v, v, v)))
	var brick := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var row := int(y / 8.0)
				var xo := x + (8 if row % 2 == 1 else 0)
				var mortar := y % 8 == 0 or xo % 32 == 0
				var base := Color(0.55, 0.32, 0.25) * rng.randf_range(0.85, 1.1)
				img.set_pixel(x, y, Color(0.72, 0.7, 0.66) if mortar else base))
	var tile_small := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var v := 0.8 + rng.randf_range(-0.02, 0.02)
				if x % 32 == 0 or y % 32 == 0:
					v = 0.6
				img.set_pixel(x, y, Color(v * 0.95, v, v)))
	var wood := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var plank := int(x / 16.0)
				var v := 0.75 + 0.06 * sin(y * 0.3 + plank * 2.0) + rng.randf_range(-0.03, 0.03)
				if x % 16 == 0:
					v *= 0.7
				img.set_pixel(x, y, Color(v * 0.95, v * 0.72, v * 0.45)))
	var grass := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var v := rng.randf_range(0.7, 1.0)
				img.set_pixel(x, y, Color(0.25 * v, 0.42 * v, 0.2 * v)))
	var ground := _tex(128, func(img: Image, rng: RandomNumberGenerator) -> void:
		for y in 128:
			for x in 128:
				var v := rng.randf_range(0.5, 0.6)
				img.set_pixel(x, y, Color(v * 1.05, v * 0.95, v * 0.82)))
	mats["floor_corr"] = _tri(Color.WHITE, terrazzo, 1.2, 0.35)
	mats["floor_room"] = _tri(Color(0.93, 0.93, 0.92), terrazzo, 1.2, 0.5)
	mats["band"] = _tri(Color.WHITE, granite, 0.6, 0.3)
	mats["floor_toilet"] = _tri(Color.WHITE, tile_small, 0.6, 0.4)
	mats["floor_wood"] = _tri(Color.WHITE, wood, 1.6, 0.35)
	mats["floor_conc"] = _tri(Color(0.55, 0.55, 0.53), granite, 2.0, 0.9)
	mats["terrace"] = _tri(Color(0.7, 0.68, 0.64), tile_small, 1.2, 0.8)
	mats["grass"] = _tri(Color.WHITE, grass, 2.0, 1.0)
	mats["ground"] = _tri(Color.WHITE, ground, 4.0, 1.0)
	mats["ceiling"] = _tri(Color.WHITE, ceiling, 1.2, 0.9)
	mats["wall"] = _tri(Color(0.94, 0.94, 0.91), null, 1.0, 0.85)
	mats["wall_blue"] = _tri(Color(0.66, 0.82, 0.88), null, 1.0, 0.85)
	mats["wall_green"] = _tri(Color(0.55, 0.78, 0.5), null, 1.0, 0.85)
	mats["base"] = _tri(Color(0.33, 0.34, 0.35), null, 1.0, 0.6)
	mats["brick"] = _tri(Color.WHITE, brick, 1.0, 0.9)
	mats["slab_edge"] = _tri(Color(0.85, 0.84, 0.8), null, 1.0, 0.8)
	mats["frame"] = _tri(Color(0.78, 0.8, 0.8), null, 1.0, 0.4, 0.5)
	mats["wood"] = _tri(Color(0.78, 0.6, 0.4), wood, 1.0, 0.55)
	mats["stair"] = _tri(Color(0.78, 0.78, 0.77), granite, 0.8, 0.5)
	mats["rail"] = _tri(Color(0.55, 0.57, 0.6), null, 1.0, 0.4, 0.6)
	mats["handrail"] = _tri(Color(0.75, 0.55, 0.35), null, 1.0, 0.5)
	mats["steel"] = _tri(Color(0.7, 0.72, 0.73), null, 1.0, 0.3, 0.8)
	mats["board"] = _tri(Color(0.16, 0.3, 0.26), null, 1.0, 0.8)
	mats["tv"] = _tri(Color(0.05, 0.05, 0.06), null, 1.0, 0.2)
	mats["locker_top"] = _tri(Color(0.92, 0.9, 0.82), null, 1.0, 0.6)
	mats["locker_bot"] = _tri(Color(0.36, 0.5, 0.72), null, 1.0, 0.6)
	mats["stall"] = _tri(Color(0.8, 0.78, 0.74), null, 1.0, 0.6)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.7, 0.82, 0.86, 0.18)
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	mats["glass"] = glass
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1, 1, 1)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.99, 0.95)
	lamp.emission_energy_multiplier = 3.0
	mats["lamp"] = lamp


# ================================================================ 칸 격자

func _snap(v: float) -> float:
	return round(v / C) * C


func _cell_index(x: float, z: float) -> int:
	var i := int(floor((x - GX0) / C))
	var j := int(floor((z - GZ0) / C))
	if i < 0 or j < 0 or i >= NX or j >= NZ:
		return -1
	return j * NX + i


func _rasterize(rooms: Array) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(NX * NZ)
	grid.fill(-1)
	for ri in rooms.size():
		var r: Rect2 = rooms[ri]["rect"]
		var i0 := int(round((r.position.x - GX0) / C))
		var i1 := int(round((r.end.x - GX0) / C))
		var j0 := int(round((r.position.y - GZ0) / C))
		var j1 := int(round((r.end.y - GZ0) / C))
		for j in range(j0, j1):
			for i in range(i0, i1):
				grid[j * NX + i] = ri
		rooms[ri]["srect"] = Rect2(GX0 + i0 * C, GZ0 + j0 * C, (i1 - i0) * C, (j1 - j0) * C)
	return grid


func _kind(rooms: Array, idx: int) -> String:
	return "out" if idx < 0 else String(rooms[idx]["kind"])


## 위치 → (층 1..5, 방 이름)
func room_at(p: Vector3) -> Array:
	var f := clampi(int(floor((p.y + 0.5) / SchoolLayout.FLOOR_H)), 0, SchoolLayout.FLOORS - 1)
	var idx := _cell_index(p.x, p.z)
	if idx < 0:
		return [f + 1, "바깥"]
	var ri: int = grids[f][idx]
	return [f + 1, "바깥" if ri < 0 else String(floors_rooms[f][ri]["name"])]


# ================================================================ 층

func _build_floor(f: int) -> void:
	var rooms: Array = floors_rooms[f]
	var grid: PackedInt32Array = grids[f]
	var y := f * SchoolLayout.FLOOR_H
	var root := Node3D.new()
	root.name = "Floor%d" % (f + 1)
	add_child(root)
	var mb := MeshBatch.new()
	var body := StaticBody3D.new()
	body.name = "Collision"
	root.add_child(body)
	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	var ctx := {"f": f, "y": y, "mb": mb, "body": body, "rooms": rooms, "grid": grid, "root": root, "lights": lights}
	var segs := _segments(rooms, grid)
	var doors := _assign_doors(f, rooms, segs)
	for si in segs.size():
		_build_segment(ctx, segs[si], doors.get(si, []))
	_build_posts(ctx, segs)
	_build_slabs(ctx)
	for ri in rooms.size():
		var room: Dictionary = rooms[ri]
		match String(room["kind"]):
			"stair":
				_build_stair(ctx, room)
			"class":
				_furnish_class(ctx, room)
			"open":
				_furnish_open(ctx, room)
			"toilet":
				_furnish_toilet(ctx, room)
			"terrace":
				_railing_terrace(ctx, ri)
		_build_lights(ctx, room)
	_build_signs(ctx, doors)
	stats["floor%d" % (f + 1)] = mb.box_count()
	mb.commit(root, "Mesh")


## 칸 경계를 훑어 벽이 될 선분을 모은다. 같은 두 방 사이의 이어진 경계는 하나로 합친다.
## 선분: {axis: "x"(z 고정, x 방향으로 뻗음) / "z", line, a0, a1, A, B}
func _segments(rooms: Array, grid: PackedInt32Array) -> Array:
	var out: Array = []
	# x 방향으로 뻗는 선 (칸 (i, j)와 (i, j+1) 사이, z = 경계)
	for j in range(NZ - 1):
		var run_start := -1
		var pa := -2
		var pb := -2
		for i in range(NX + 1):
			var a := -9
			var b := -9
			var has := false
			if i < NX:
				a = grid[j * NX + i]
				b = grid[(j + 1) * NX + i]
				has = a != b and _needs_wall(rooms, a, b)
			if has and run_start >= 0 and a == pa and b == pb:
				continue
			if run_start >= 0:
				out.append({"axis": "x", "line": GZ0 + (j + 1) * C, "a0": GX0 + run_start * C, "a1": GX0 + i * C, "A": pa, "B": pb})
				run_start = -1
			if has:
				run_start = i
				pa = a
				pb = b
	# z 방향으로 뻗는 선 (칸 (i, j)와 (i+1, j) 사이, x = 경계)
	for i in range(NX - 1):
		var run_start := -1
		var pa := -2
		var pb := -2
		for j in range(NZ + 1):
			var a := -9
			var b := -9
			var has := false
			if j < NZ:
				a = grid[j * NX + i]
				b = grid[j * NX + i + 1]
				has = a != b and _needs_wall(rooms, a, b)
			if has and run_start >= 0 and a == pa and b == pb:
				continue
			if run_start >= 0:
				out.append({"axis": "z", "line": GX0 + (i + 1) * C, "a0": GZ0 + run_start * C, "a1": GZ0 + j * C, "A": pa, "B": pb})
				run_start = -1
			if has:
				run_start = j
				pa = a
				pb = b
	return out


func _needs_wall(rooms: Array, a: int, b: int) -> bool:
	var ka := _kind(rooms, a)
	var kb := _kind(rooms, b)
	var oa := ka in OUTDOOR
	var ob := kb in OUTDOOR
	if oa and ob:
		return false
	if not oa and not ob:
		var soft := ["corr", "open"]
		if ka in soft and kb in soft:
			return false
	return true


## 방마다 문 자리를 정한다. 결과: 선분 번호 → [{at, w, h, kind}]
func _assign_doors(f: int, rooms: Array, segs: Array) -> Dictionary:
	var doors := {}
	for ri in rooms.size():
		var room: Dictionary = rooms[ri]
		var kind := String(room["kind"])
		if kind in ["corr", "open", "closed", "void", "court", "eps"]:
			continue
		var sr: Rect2 = room["srect"]
		var best := -1
		var best_len := 0.0
		var any_best := -1
		var any_len := 0.0
		var best_rank := 0
		for si in segs.size():
			var s: Dictionary = segs[si]
			var other := -1
			if s["A"] == ri:
				other = s["B"]
			elif s["B"] == ri:
				other = s["A"]
			else:
				continue
			# 복도 쪽 문이 먼저, 없으면 큰 방(식당·강당·주차장)이나 트인 공간 쪽
			var ok_kind := _kind(rooms, other)
			var rank := 2 if ok_kind == "corr" else (1 if ok_kind in ["hall", "open", "path"] and kind != "hall" else 0)
			if rank == 0 and kind == "room" and ok_kind == "class":
				rank = 1   # 복도에 닿지 않는 준비실 등: 옆 교실(실험실)로 통하는 문
			if rank > 0 and float(room.get("frac", -1.0)) >= 0.0 and _side_of(sr, s) == room["door"]:
				rank = 3   # 피난안내도에서 읽은 문: 지정한 벽
			if rank == 0 or rank < best_rank:
				continue
			if rank > best_rank:
				best_rank = rank
				best = -1
				best_len = 0.0
				any_best = -1
				any_len = 0.0
			var length: float = s["a1"] - s["a0"]
			if length > any_len:
				any_len = length
				any_best = si
			if _side_of(sr, s) == room["door"] and length > best_len:
				best_len = length
				best = si
		if best < 0:
			best = any_best
		if best < 0:
			continue
		var s: Dictionary = segs[best]
		var a0: float = s["a0"]
		var a1: float = s["a1"]
		var list: Array = doors.get(best, [])
		match kind:
			"class", "hall":
				if a1 - a0 >= 5.0:
					list.append({"at": a0 + 1.2, "w": 1.0, "h": 2.1, "kind": kind})
					list.append({"at": a1 - 1.2, "w": 1.0, "h": 2.1, "kind": kind})
				else:
					list.append({"at": (a0 + a1) / 2.0, "w": 1.0, "h": 2.1, "kind": kind})
			"stair":
				var at := (a0 + a1) / 2.0
				var spec := _stair_spec(String(room["name"]))
				var landing := _landing_along(spec, room["srect"], s)
				if not is_nan(landing):
					at = clampf(landing, a0 + 0.8, a1 - 0.8)
				list.append({"at": at, "w": 1.4, "h": 2.2, "kind": kind})
			"terrace":
				list.append({"at": (a0 + a1) / 2.0, "w": 1.6, "h": 2.2, "kind": kind})
			"ev":
				list.append({"at": (a0 + a1) / 2.0, "w": 1.2, "h": 2.1, "kind": kind})
			_:
				var at := (a0 + a1) / 2.0
				var frac := float(room.get("frac", -1.0))
				if frac >= 0.0:
					# 방의 벽 길이에서 frac 자리, 선분 안으로 (문틀 여유 0.6 m)
					var r0 := sr.position.x if s["axis"] == "x" else sr.position.y
					var r1 := sr.end.x if s["axis"] == "x" else sr.end.y
					var lo := maxf(a0, r0) + 0.6
					var hi := minf(a1, r1) - 0.6
					at = clampf(lerpf(r0, r1, frac), lo, hi) if hi > lo else (a0 + a1) / 2.0
				list.append({"at": at, "w": 0.95, "h": 2.1, "kind": kind})
		doors[best] = list
		var d: Dictionary = list[0]
		door_points["%d:%s" % [f + 1, room["name"]]] = _seg_point(s, d["at"], f * SchoolLayout.FLOOR_H)
	# 바깥으로 나가는 문
	for ed in SchoolLayout.exterior_doors(f + 1):
		var side: String = ed[0]
		var pos: float = ed[1]
		for si in segs.size():
			var s: Dictionary = segs[si]
			var ka := _kind(rooms, s["A"])
			var kb := _kind(rooms, s["B"])
			if not ((ka in OUTDOOR) != (kb in OUTDOOR)):
				continue
			var on_side := false
			if side.begins_with("x=") or side.begins_with("z="):
				var axis_needed := "z" if side.begins_with("x=") else "x"
				on_side = s["axis"] == axis_needed and absf(s["line"] - _snap(float(side.substr(2)))) < 0.01
			match side:
				"S":
					on_side = s["axis"] == "x" and absf(s["line"] - _snap(SchoolLayout.D)) < 0.01
				"N":
					on_side = s["axis"] == "x" and absf(s["line"] - _snap(0.0)) < 0.01
				"W":
					on_side = s["axis"] == "z" and absf(s["line"] - _snap(0.0)) < 0.01
				"E":
					on_side = s["axis"] == "z" and absf(s["line"] - _snap(SchoolLayout.W)) < 0.01
			if on_side and pos > s["a0"] and pos < s["a1"]:
				var list: Array = doors.get(si, [])
				list.append({"at": pos, "w": ed[2], "h": 2.4, "kind": "exterior"})
				doors[si] = list
				door_points["%d:exterior_%s" % [f + 1, side]] = _seg_point(s, pos, 0.0)
	return doors


func _stair_spec(name: String) -> Dictionary:
	for s in SchoolLayout.STAIRS:
		if s["name"] == name:
			return s
	return {}


## 선분이 계단의 옆벽이면, 층계참 가운데의 선분 방향 좌표. 끝벽이면 NAN.
func _landing_along(spec: Dictionary, r: Rect2, s: Dictionary) -> float:
	if spec.is_empty():
		return NAN
	var axis: String = spec["axis"]
	if s["axis"] != axis:
		return NAN   # 계단의 끝벽: 문은 벽 가운데
	match String(spec["near"]):
		"S":
			return r.end.y - LANDING / 2.0
		"N":
			return r.position.y + LANDING / 2.0
		"E":
			return r.end.x - LANDING / 2.0
		_:
			return r.position.x + LANDING / 2.0


## 계단을 한 층 오르는 길 (월드 점들): 층계참 → 첫 줄 → 먼 쪽 참 → 둘째 줄 → 위층 층계참
func stair_route(name: String, floor: int) -> Array:
	var spec := _stair_spec(name)
	var r: Rect2 = room_rect(floor, name)
	var axis: String = spec["axis"]
	var near: String = spec["near"]
	var length := r.size.y if axis == "z" else r.size.x
	var width := r.size.x if axis == "z" else r.size.y
	var half := (width - 0.2) / 2.0
	var far := LANDING + STEP_N * minf((length - 2.0 * LANDING) / STEP_N, 0.3)
	var y := (floor - 1) * SchoolLayout.FLOOR_H
	var pts: Array = []
	for uv in [[0.75, half / 2.0], [far + 0.5, half / 2.0], [far + 0.5, half + 0.2 + half / 2.0], [0.75, half + 0.2 + half / 2.0], [0.75, half / 2.0]]:
		var u: float = uv[0]
		var v: float = uv[1]
		var p := Vector3.ZERO
		match near:
			"S":
				p = Vector3(r.position.x + v, y, r.end.y - u)
			"N":
				p = Vector3(r.end.x - v, y, r.position.y + u)
			"E":
				p = Vector3(r.end.x - u, y, r.position.y + v)
			_:
				p = Vector3(r.position.x + u, y, r.end.y - v)
		pts.append(p)
	return pts


## 층(1..5)에서 이름이 같은 첫 방의 사각형
func room_rect(floor: int, name: String) -> Rect2:
	for room in floors_rooms[floor - 1]:
		if room["name"] == name:
			return room["srect"]
	return Rect2()


func _side_of(sr: Rect2, s: Dictionary) -> String:
	var line: float = s["line"]
	if s["axis"] == "x":
		return "N" if absf(line - sr.position.y) < 0.01 else "S"
	return "W" if absf(line - sr.position.x) < 0.01 else "E"


func _seg_point(s: Dictionary, at: float, y: float) -> Vector3:
	return Vector3(at, y, s["line"]) if s["axis"] == "x" else Vector3(s["line"], y, at)


# ================================================================ 벽

func _build_segment(ctx: Dictionary, s: Dictionary, door_list: Array) -> void:
	var rooms: Array = ctx["rooms"]
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"]
	var ka := _kind(rooms, s["A"])
	var kb := _kind(rooms, s["B"])
	var oa := ka in OUTDOOR
	var ob := kb in OUTDOOR
	var exterior := oa != ob
	var shaft := ka in ["stair", "ev", "eps"] or kb in ["stair", "ev", "eps"]
	# 층 높이 벽은 위층 바닥판 속 2 cm 아래에서 끝나고, 모든 벽은 바닥판 속 2 cm 아래에서 시작한다 (면이 겹쳐 깜박이지 않게)
	var h := SchoolLayout.FLOOR_H - 0.02 if (exterior or shaft) else SchoolLayout.CEIL_H
	var openings: Array = []      # [a0, a1, y0, y1, kind]
	for d in door_list:
		openings.append([d["at"] - d["w"] / 2.0, d["at"] + d["w"] / 2.0, 0.0, d["h"], "door"])
	var indoor_kind := kb if oa else ka
	var windows := exterior and not (indoor_kind in ["eps", "ev"])
	if windows:
		# 창: 기둥 사이마다 (최대 3.6 m 간격), 창턱 0.9, 높이 0.9..2.5
		var a0: float = s["a0"]
		var a1: float = s["a1"]
		var n := maxi(1, int(ceil((a1 - a0) / 3.6)))
		var bay := (a1 - a0) / n
		for k in n:
			var w0 := a0 + k * bay + 0.25
			var w1 := a0 + (k + 1) * bay - 0.25
			if w1 - w0 < 0.6:
				continue
			# 문과 겹치면 창을 줄이거나 뺀다
			var cut := false
			for o in openings:
				if o[4] == "door" and o[1] > w0 - 0.2 and o[0] < w1 + 0.2:
					cut = true
			if not cut:
				openings.append([w0, w1, 0.9, 2.5, "window"])
	# 실내 쪽과 바깥 쪽을 구분 (바깥벽은 안쪽 회반죽 + 바깥 벽돌)
	var thick := EXT_T if exterior else WALL_T
	var inner_mat: Material = mats["wall"]
	var pieces := _wall_pieces(s["a0"], s["a1"], h, openings)
	for p in pieces:
		if p[2] < 0.001:
			p[2] = -0.02
	for p in pieces:
		var a_mid: float = (p[0] + p[1]) / 2.0
		var len_a: float = p[1] - p[0]
		var y_mid: float = y + (p[2] + p[3]) / 2.0
		var hh: float = p[3] - p[2]
		if exterior:
			# 실내 쪽 반은 흰 벽, 바깥 쪽 반은 벽돌
			var out_sign := _outward_sign(s, oa)
			_wall_box(mb, s, a_mid, len_a, y_mid, hh, -out_sign * EXT_T / 4.0, EXT_T / 2.0, inner_mat)
			_wall_box(mb, s, a_mid, len_a, y_mid, hh, out_sign * EXT_T / 4.0, EXT_T / 2.0, mats["brick"] if not ("void" in [ka, kb] or "court" in [ka, kb]) else mats["wall"])
		else:
			_wall_box(mb, s, a_mid, len_a, y_mid, hh, 0.0, thick, inner_mat)
		_collide_wall(ctx, s, a_mid, len_a, y_mid, hh, thick, exterior, oa)
	# 걸레받이 (실내 쪽 양면, 문 자리 빼고)
	for p in pieces:
		if p[2] > -0.01:
			continue
		var a_mid: float = (p[0] + p[1]) / 2.0
		var len_a: float = p[1] - p[0]
		if exterior:
			var out_sign := _outward_sign(s, oa)
			_wall_box(mb, s, a_mid, len_a, y + 0.06, 0.12, -out_sign * (EXT_T / 2.0 + 0.006), 0.012, mats["base"])
		else:
			for sign in [-1.0, 1.0]:
				_wall_box(mb, s, a_mid, len_a, y + 0.06, 0.12, sign * (thick / 2.0 + 0.006), 0.012, mats["base"])
	# 창: 유리와 창틀, 문: 문틀
	for o in openings:
		var a0: float = o[0]
		var a1: float = o[1]
		if o[4] == "window":
			var mid := (a0 + a1) / 2.0
			_wall_box(mb, s, mid, a1 - a0, y + (o[2] + o[3]) / 2.0, o[3] - o[2], 0.0, 0.02, mats["glass"])
			_wall_box(mb, s, mid, a1 - a0, y + o[2] + 0.03, 0.06, 0.0, thick + 0.04, mats["frame"])
			_wall_box(mb, s, mid, a1 - a0, y + o[3] - 0.03, 0.06, 0.0, thick + 0.02, mats["frame"])
			var nm := maxi(1, int(round((a1 - a0) / 1.0)))
			for k in nm + 1:
				var am := a0 + (a1 - a0) * k / nm
				_wall_box(mb, s, am, 0.06, y + (o[2] + o[3]) / 2.0, o[3] - o[2], 0.0, thick + 0.02, mats["frame"])
			_wall_box(mb, s, mid, a1 - a0, y + 1.7, 0.05, 0.0, thick + 0.02, mats["frame"])
			_collide_wall(ctx, s, mid, a1 - a0, y + (o[2] + o[3]) / 2.0, o[3] - o[2], 0.06, false, false)
		else:
			var fm: Material = mats["wood"] if o[4] == "door" else mats["frame"]
			for am in [a0 - 0.04, a1 + 0.04]:
				_wall_box(mb, s, am, 0.08, y + o[3] / 2.0, o[3], 0.0, thick + 0.06, fm)
			_wall_box(mb, s, (a0 + a1) / 2.0, a1 - a0 + 0.16, y + o[3] + 0.04, 0.08, 0.0, thick + 0.06, fm)


## 선분의 바깥(실외) 쪽 부호: x 방향 선분이면 +z가 바깥일 때 +1
func _outward_sign(s: Dictionary, a_is_outdoor: bool) -> float:
	# A는 선의 작은 좌표 쪽(위 칸 / 왼쪽 칸), B는 큰 쪽
	return -1.0 if a_is_outdoor else 1.0


## 선분을 따라 a 위치에 상자 하나. off는 선에 수직인 방향으로 밀기.
func _wall_box(mb: MeshBatch, s: Dictionary, a_mid: float, len_a: float, y_mid: float, h: float, off: float, thick: float, mat: Material) -> void:
	var line: float = s["line"]
	if s["axis"] == "x":
		mb.add_box(mat, Vector3(a_mid, y_mid, line + off), Vector3(len_a, h, thick))
	else:
		mb.add_box(mat, Vector3(line + off, y_mid, a_mid), Vector3(thick, h, len_a))


func _collide_wall(ctx: Dictionary, s: Dictionary, a_mid: float, len_a: float, y_mid: float, h: float, thick: float, _ext: bool, _oa: bool) -> void:
	var line: float = s["line"]
	if s["axis"] == "x":
		_col(ctx, Vector3(a_mid, y_mid, line), Vector3(len_a, h, thick))
	else:
		_col(ctx, Vector3(line, y_mid, a_mid), Vector3(thick, h, len_a))


func _col(ctx: Dictionary, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = center
	(ctx["body"] as StaticBody3D).add_child(cs)


## 구멍(문·창)을 뺀 벽 조각들: [a0, a1, y0, y1]
func _wall_pieces(a0: float, a1: float, h: float, openings: Array) -> Array:
	var cuts := [a0, a1]
	for o in openings:
		cuts.append(clampf(o[0], a0, a1))
		cuts.append(clampf(o[1], a0, a1))
	cuts.sort()
	var out: Array = []
	for k in range(cuts.size() - 1):
		var c0: float = cuts[k]
		var c1: float = cuts[k + 1]
		if c1 - c0 < 0.001:
			continue
		var mid := (c0 + c1) / 2.0
		var holes: Array = []
		for o in openings:
			if mid > o[0] and mid < o[1]:
				holes.append([o[2], o[3]])
		holes.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var yb := 0.0
		for hole in holes:
			if hole[0] > yb + 0.001:
				out.append([c0, c1, yb, hole[0]])
			yb = maxf(yb, hole[1])
		if h > yb + 0.001:
			out.append([c0, c1, yb, h])
	return out


## 선분 끝마다 모서리 기둥 (벽이 만나는 곳의 빈틈을 메운다)
func _build_posts(ctx: Dictionary, segs: Array) -> void:
	var rooms: Array = ctx["rooms"]
	var seen := {}
	for s in segs:
		var ka := _kind(rooms, s["A"])
		var kb := _kind(rooms, s["B"])
		var exterior := (ka in OUTDOOR) != (kb in OUTDOOR)
		var shaft := ka in ["stair", "ev", "eps"] or kb in ["stair", "ev", "eps"]
		var h := SchoolLayout.FLOOR_H - 0.02 if (exterior or shaft) else SchoolLayout.CEIL_H
		var t := EXT_T if exterior else WALL_T
		for a in [s["a0"], s["a1"]]:
			var p := _seg_point(s, a, 0.0)
			var key := "%.2f,%.2f" % [p.x, p.z]
			if seen.has(key) and seen[key][0] >= h and seen[key][1] >= t:
				continue
			var prev: Array = seen.get(key, [0.0, 0.0])
			seen[key] = [maxf(prev[0], h), maxf(prev[1], t)]
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"]
	for key in seen:
		var xz: PackedStringArray = (key as String).split(",")
		var hv: float = seen[key][0]
		var tv: float = seen[key][1]
		var c := Vector3(float(xz[0]), y + (hv - 0.02) / 2.0, float(xz[1]))
		mb.add_box(mats["wall"], c, Vector3(tv - 0.02, hv + 0.02, tv - 0.02))
		_col(ctx, c, Vector3(tv, hv + 0.02, tv))


# ================================================================ 바닥, 천장

func _floor_mat(kind: String, name: String) -> String:
	match kind:
		"corr":
			return "floor_corr"
		"toilet":
			return "floor_toilet"
		"open":
			return "floor_wood" if name.begins_with("Media") or name.begins_with("포켓") else "floor_corr"
		"eps", "ev":
			return "floor_conc"
		"terrace":
			return "terrace"
		"path":
			return "floor_conc"
		"court":
			return "grass"
		"hall":
			return "floor_wood" if name in ["다목적강당", "무대"] else "floor_room"
	return "floor_room"


func _build_slabs(ctx: Dictionary) -> void:
	var rooms: Array = ctx["rooms"]
	var grid: PackedInt32Array = ctx["grid"]
	var y: float = ctx["y"]
	var mb: MeshBatch = ctx["mb"]
	# 칸 → 바닥 재질 이름 (계단·빈 공간·바깥은 "")
	var fm := PackedStringArray()
	var cm := PackedByteArray()
	fm.resize(NX * NZ)
	cm.resize(NX * NZ)
	for idx in NX * NZ:
		var ri := grid[idx]
		var k := _kind(rooms, ri)
		if k in ["out", "void", "stair"]:
			fm[idx] = ""
			cm[idx] = 0
			continue
		fm[idx] = _floor_mat(k, rooms[ri]["name"])
		cm[idx] = 0 if k in ["terrace", "court"] else 1
	for r in _merge_rects(fm):
		var rect: Rect2 = r[0]
		var mname: String = r[1]
		var top := y
		var c := Vector3(rect.get_center().x, top - 0.1, rect.get_center().y)
		var size := Vector3(rect.size.x, 0.2, rect.size.y)
		mb.add_box(mats[mname], c, size)
		_col(ctx, c, size)
		# 아래층에서 보이는 바닥판 아랫면 (천장 사이 공간) — 위층 바닥판이 아래층 천장 위를 덮는다
	var cmn := PackedStringArray()
	cmn.resize(NX * NZ)
	for idx in NX * NZ:
		cmn[idx] = "ceiling" if cm[idx] == 1 else ""
	for r in _merge_rects(cmn):
		var rect: Rect2 = r[0]
		mb.add_box(mats["ceiling"], Vector3(rect.get_center().x, y + SchoolLayout.CEIL_H + 0.04, rect.get_center().y), Vector3(rect.size.x, 0.08, rect.size.y))
	# 복도 바닥의 짙은 화강석 띠 (복도를 가로질러 3 m마다)
	for room in rooms:
		if room["kind"] != "corr":
			continue
		var sr: Rect2 = room["srect"]
		var along_x := sr.size.x > sr.size.y
		var length := sr.size.x if along_x else sr.size.y
		var n := int(length / 3.0)
		for k in n:
			var a := (sr.position.x if along_x else sr.position.y) + 1.5 + k * 3.0
			if along_x:
				mb.add_box(mats["band"], Vector3(a, y + 0.002, sr.get_center().y), Vector3(0.6, 0.004, sr.size.y * 0.7))
			else:
				mb.add_box(mats["band"], Vector3(sr.get_center().x, y + 0.002, a), Vector3(sr.size.x * 0.7, 0.004, 0.6))


## 같은 이름 칸끼리 직사각형으로 합친다 (행마다 같은 구간을 모은 뒤 위아래로 이어 붙임).
func _merge_rects(names: PackedStringArray) -> Array:
	var out: Array = []
	var open := {}            # "i0,i1,name" → [j0]
	for j in NZ + 1:
		var runs := {}
		if j < NZ:
			var i := 0
			while i < NX:
				var n := names[j * NX + i]
				if n == "":
					i += 1
					continue
				var i0 := i
				while i < NX and names[j * NX + i] == n:
					i += 1
				runs["%d,%d,%s" % [i0, i, n]] = true
		for key in open.keys():
			if not runs.has(key):
				var parts: PackedStringArray = (key as String).split(",")
				var i0 := int(parts[0])
				var i1 := int(parts[1])
				var j0: int = open[key]
				out.append([Rect2(GX0 + i0 * C, GZ0 + j0 * C, (i1 - i0) * C, (j - j0) * C), parts[2]])
				open.erase(key)
		for key in runs:
			if not open.has(key):
				open[key] = j
	return out


## 층 f의 실내 칸 중 바로 위층이 바깥(테라스 제외)인 곳에 지붕판 (맨 위층, 별관·특별교실동 위 등)
func _build_roof(f: int) -> void:
	var rooms: Array = floors_rooms[f]
	var grid: PackedInt32Array = grids[f]
	var above_rooms: Array = floors_rooms[f + 1] if f + 1 < SchoolLayout.FLOORS else []
	var above_grid: PackedInt32Array = grids[f + 1] if f + 1 < SchoolLayout.FLOORS else PackedInt32Array()
	var names := PackedStringArray()
	names.resize(NX * NZ)
	var any := false
	for idx in NX * NZ:
		var k := _kind(rooms, grid[idx])
		var ka := "out" if above_grid.is_empty() else _kind(above_rooms, above_grid[idx])
		if k in OUTDOOR or not (ka in ["out", "void", "court"]):
			names[idx] = ""
		else:
			names[idx] = "roof"
			any = true
	if not any:
		return
	var mb := MeshBatch.new()
	var body := StaticBody3D.new()
	var root := Node3D.new()
	root.name = "Roof%d" % (f + 1)
	add_child(root)
	root.add_child(body)
	var ctx := {"body": body}
	var y := (f + 1) * SchoolLayout.FLOOR_H
	for r in _merge_rects(names):
		var rect: Rect2 = r[0]
		var c := Vector3(rect.get_center().x, y + 0.14, rect.get_center().y)
		mb.add_box(mats["slab_edge"], c, Vector3(rect.size.x + 0.3, 0.32, rect.size.y + 0.3))
		_col(ctx, c, Vector3(rect.size.x, 0.32, rect.size.y))
	mb.commit(root, "Mesh")


## 별관 1층: 기둥 (2층 식당 아래는 트인 필로티)
func _build_pillars() -> void:
	var mb := MeshBatch.new()
	var body := StaticBody3D.new()
	var root := Node3D.new()
	root.name = "Pillars"
	add_child(root)
	root.add_child(body)
	var ctx := {"body": body}
	var an := SchoolLayout.ANNEX
	var nx := int(an.size.x / 8.1)
	var nz := int(an.size.y / 8.0)
	for i in range(1, nx):
		for j in range(1, nz):
			var c := Vector3(an.position.x + 0.3 + i * (an.size.x - 0.6) / nx, SchoolLayout.FLOOR_H / 2.0, an.position.y + 0.3 + j * (an.size.y - 0.6) / nz)
			mb.add_box(mats["slab_edge"], c, Vector3(0.6, SchoolLayout.FLOOR_H, 0.6))
			_col(ctx, c, Vector3(0.6, SchoolLayout.FLOOR_H, 0.6))
	mb.commit(root, "Mesh")


func _build_ground() -> void:
	var mb := MeshBatch.new()
	var root := Node3D.new()
	root.name = "Ground"
	add_child(root)
	var body := StaticBody3D.new()
	root.add_child(body)
	var c := Vector3(18.0, -0.11, 34.0)
	mb.add_box(mats["ground"], c, Vector3(260.0, 0.2, 260.0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(260.0, 0.2, 260.0)
	cs.shape = sh
	cs.position = c
	body.add_child(cs)
	mb.commit(root, "Mesh")


# ================================================================ 계단 (U자, 층마다 두 줄 × 12단)

func _build_stair(ctx: Dictionary, room: Dictionary) -> void:
	var mb: MeshBatch = ctx["mb"]
	var f: int = ctx["f"]
	var y: float = ctx["y"]
	var sr: Rect2 = room["srect"]
	var spec: Dictionary = {}
	for s in SchoolLayout.STAIRS:
		if s["name"] == room["name"]:
			spec = s
	var axis: String = spec["axis"]
	var near: String = spec["near"]
	var length := sr.size.y if axis == "z" else sr.size.x
	var width := sr.size.x if axis == "z" else sr.size.y
	var run := minf((length - 2.0 * LANDING) / STEP_N, 0.3)
	var far := LANDING + STEP_N * run          # 먼 쪽 참이 시작하는 곳
	var rise := SchoolLayout.FLOOR_H / (2.0 * STEP_N)
	var half := (width - 0.2) / 2.0
	# 로컬 (u: 가까운 끝에서 먼 끝으로, v: 가로) → 월드
	var to_w := func(u: float, v: float, yy: float) -> Vector3:
		var uu := u
		var vv := v
		match near:
			"S":
				return Vector3(sr.position.x + vv, yy, sr.end.y - uu)
			"N":
				return Vector3(sr.end.x - vv, yy, sr.position.y + uu)
			"E":
				return Vector3(sr.end.x - uu, yy, sr.position.y + vv)
			_:
				return Vector3(sr.position.x + uu, yy, sr.end.y - vv)
	var box := func(u0: float, u1: float, v0: float, v1: float, y0: float, y1: float, mat: Material, collide: bool) -> void:
		var a: Vector3 = to_w.call(u0, v0, y0)
		var b: Vector3 = to_w.call(u1, v1, y1)
		var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
		var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
		mb.add_box(mat, (lo + hi) / 2.0, hi - lo)
		if collide:
			_col(ctx, (lo + hi) / 2.0, hi - lo)
	# 가까운 끝 층계참 (이 층 바닥)
	box.call(0.0, LANDING, 0.0, width, y - 0.25, y, mats["stair"], true)
	if f >= SchoolLayout.FLOORS - 1:
		return
	# 먼 끝 중간 참
	box.call(far, length, 0.0, width, y + 1.8 - 0.25, y + 1.8, mats["stair"], true)
	# 첫 줄 (v 0..half): 가까운 끝 → 먼 끝으로 올라간다. 둘째 줄 (v half+0.2..width): 먼 끝 → 가까운 끝
	for k in STEP_N:
		var top1 := y + (k + 1) * rise
		var u0 := LANDING + k * run
		box.call(u0, u0 + run, 0.0, half, top1 - 0.3, top1, mats["stair"], true)
		box.call(u0, u0 + 0.04, 0.0, half, top1 - 0.004, top1 + 0.004, mats["rail"], false)
		var top2 := y + 1.8 + (k + 1) * rise
		var u1 := far - (k + 1) * run
		box.call(u1, u1 + run, half + 0.2, width, top2 - 0.3, top2, mats["stair"], true)
		box.call(u1 + run - 0.04, u1 + run, half + 0.2, width, top2 - 0.004, top2 + 0.004, mats["rail"], false)
	# 두 줄 사이 난간: 철제 살 + 나무 손잡이 (충돌은 판 하나)
	var v_mid := half + 0.1
	for k in range(0, STEP_N + 1, 2):
		var u := LANDING + k * run
		var y1 := y + k * rise
		var y2 := y + 1.8 + (STEP_N - k) * rise
		box.call(u - 0.02, u + 0.02, v_mid - 0.02, v_mid + 0.02, y1, y2 + 0.95, mats["rail"], false)
	box.call(LANDING, far, v_mid - 0.08, v_mid + 0.08, y, y + 3.6 + 0.9, mats["rail"], false)
	var a: Vector3 = to_w.call(LANDING, v_mid - 0.06, y)
	var b: Vector3 = to_w.call(far, v_mid + 0.06, y + 3.6 + 0.9)
	_col(ctx, (a + b) / 2.0, (b - a).abs())


# ================================================================ 가구 (단순 상자. 자세한 것은 나중에)

func _furnish_class(ctx: Dictionary, room: Dictionary) -> void:
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"]
	var sr: Rect2 = room["srect"]
	# 칠판은 복도(문) 벽과 직각인 벽 (북쪽 또는 서쪽 끝). 문이 동·서쪽이면 칠판은 북쪽 벽
	var along_z := String(room["door"]) in ["E", "W"]
	var length := sr.size.y if along_z else sr.size.x
	var width := sr.size.x if along_z else sr.size.y
	var p := func(u: float, v: float, yy: float) -> Vector3:
		return Vector3(sr.position.x + v, yy, sr.position.y + u) if along_z else Vector3(sr.position.x + u, yy, sr.position.y + v)
	var sz := func(su: float, sv: float, sy: float) -> Vector3:
		return Vector3(sv, sy, su) if along_z else Vector3(su, sy, sv)
	# 칠판, TV, 교탁, 게시판
	mb.add_box(mats["board"], p.call(0.12, width / 2.0 - 1.6, y + 1.55), sz.call(0.04, 1.6, 1.15))
	mb.add_box(mats["board"], p.call(0.12, width / 2.0 + 1.6, y + 1.55), sz.call(0.04, 1.6, 1.15))
	mb.add_box(mats["tv"], p.call(0.12, width / 2.0, y + 1.6), sz.call(0.06, 1.4, 0.82))
	mb.add_box(mats["frame"], p.call(0.11, width / 2.0, y + 1.55), sz.call(0.02, 5.4, 1.3))
	mb.add_box(mats["wood"], p.call(1.3, width / 2.0, y + 0.55), sz.call(0.6, 1.0, 1.1))
	_col(ctx, p.call(1.3, width / 2.0, y + 0.55), sz.call(0.6, 1.0, 1.1))
	# 연두색 허리벽 띠 (긴 벽 양쪽, 바닥에서 1.1 m) — 벽에 붙은 얇은 판
	for v in [0.11, width - 0.11]:
		mb.add_box(mats["wall_green"], p.call(length / 2.0, v, y + 0.45), sz.call(length - 0.3, 0.012, 0.8))
	mb.add_box(mats["wall_green"], p.call(length - 0.11, width / 2.0, y + 0.45), sz.call(0.012, width - 0.3, 0.8))
	# 책상·의자: 2인 짝, 가로 3짝 × 세로 6줄
	var rows := int((length - 3.0) / 1.05)
	for r in rows:
		var u := 2.6 + r * 1.05
		for c in 3:
			for side in [-0.33, 0.33]:
				var v: float = width / 2.0 + (c - 1) * 2.1 + side
				mb.add_box(mats["wood"], p.call(u, v, y + 0.72), sz.call(0.5, 0.62, 0.03))
				mb.add_box(mats["rail"], p.call(u, v, y + 0.36), sz.call(0.4, 0.04, 0.7))
				mb.add_box(mats["wood"], p.call(u + 0.45, v, y + 0.44), sz.call(0.38, 0.4, 0.03))
				mb.add_box(mats["wood"], p.call(u + 0.63, v, y + 0.66), sz.call(0.02, 0.38, 0.38))
				mb.add_box(mats["rail"], p.call(u + 0.45, v, y + 0.22), sz.call(0.3, 0.03, 0.44))
				_col(ctx, p.call(u, v, y + 0.37), sz.call(0.5, 0.62, 0.74))


func _furnish_open(ctx: Dictionary, room: Dictionary) -> void:
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"]
	var sr: Rect2 = room["srect"]
	var name := String(room["name"])
	if not (name.begins_with("Media") or name.begins_with("포켓")):
		return
	# 사물함 줄 (아이보리 위칸 + 파란 아래칸), 마루 단 의자
	var along_z := sr.size.y >= sr.size.x
	var length := sr.size.y if along_z else sr.size.x
	var n := int((length - 4.0) / 5.0)
	for k in n:
		var a := 2.5 + k * 5.0
		var c := Vector3(sr.get_center().x, y, sr.position.y + a) if along_z else Vector3(sr.position.x + a, y, sr.get_center().y)
		var size := Vector3(3.2, 0, 0.55) if along_z else Vector3(0.55, 0, 3.2)
		mb.add_box(mats["locker_bot"], c + Vector3(0, 0.55, 0), size + Vector3(0, 1.1, 0))
		mb.add_box(mats["locker_top"], c + Vector3(0, 1.55, 0), size + Vector3(0, 0.9, 0))
		_col(ctx, c + Vector3(0, 1.0, 0), size + Vector3(0, 2.0, 0))
	# 벽 쪽 마루 단 (중정 쪽 벽을 따라)
	var bench := Vector3(sr.end.x - 0.6, y + 0.22, sr.get_center().y) if along_z else Vector3(sr.get_center().x, y + 0.22, sr.end.y - 0.6)
	var bsize := Vector3(1.0, 0.44, sr.size.y - 2.0) if along_z else Vector3(sr.size.x - 2.0, 0.44, 1.0)
	mb.add_box(mats["floor_wood"], bench, bsize)
	_col(ctx, bench, bsize)


func _furnish_toilet(ctx: Dictionary, room: Dictionary) -> void:
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"]
	var sr: Rect2 = room["srect"]
	if sr.size.x < 2.5 or sr.size.y < 2.5:
		return
	# 칸막이 (안쪽 벽을 따라)
	var along_z := sr.size.y >= sr.size.x
	var n := int(((sr.size.y if along_z else sr.size.x) - 1.0) / 1.2)
	for k in n + 1:
		var a := 0.5 + k * 1.2
		if along_z:
			mb.add_box(mats["stall"], Vector3(sr.get_center().x + sr.size.x / 4.0, y + 1.0, sr.position.y + a), Vector3(sr.size.x / 2.0, 1.8, 0.04))
		else:
			mb.add_box(mats["stall"], Vector3(sr.position.x + a, y + 1.0, sr.get_center().y - sr.size.y / 4.0), Vector3(0.04, 1.8, sr.size.y / 2.0))


func _railing_terrace(ctx: Dictionary, ri: int) -> void:
	var rooms: Array = ctx["rooms"]
	var grid: PackedInt32Array = ctx["grid"]
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"]
	var sr: Rect2 = rooms[ri]["srect"]
	# 바깥과 맞닿는 테라스 가장자리에 난간 (높이 1.1)
	for edge in [["x", sr.position.y, -1], ["x", sr.end.y, 1], ["z", sr.position.x, -1], ["z", sr.end.x, 1]]:
		var probe: float = 0.25 * float(edge[2])
		var a0 := sr.position.x if edge[0] == "x" else sr.position.y
		var a1 := sr.end.x if edge[0] == "x" else sr.end.y
		var a := a0 + 0.25
		while a < a1:
			var line: float = edge[1]
			var px: float = a if edge[0] == "x" else line + probe
			var pz: float = line + probe if edge[0] == "x" else a
			var idx := _cell_index(px, pz)
			var k := _kind(rooms, grid[idx] if idx >= 0 else -1)
			if k == "out" or k == "void":
				var c := Vector3(a, y + 0.55, line) if edge[0] == "x" else Vector3(line, y + 0.55, a)
				var size := Vector3(0.5, 1.1, 0.06) if edge[0] == "x" else Vector3(0.06, 1.1, 0.5)
				mb.add_box(mats["rail"], c, size)
				_col(ctx, c, size)
			a += 0.5


# ================================================================ 조명 (천장 등판. 실제 빛은 하늘·해 + 간접광)

func _build_lights(ctx: Dictionary, room: Dictionary) -> void:
	var kind := String(room["kind"])
	if kind in OUTDOOR or kind in ["eps", "ev"]:
		return
	var sr: Rect2 = room["srect"]
	var lights: Node3D = ctx["lights"]
	var base_y: float = ctx["y"]
	if kind == "stair":
		lights.add_child(_omni(Vector3(sr.get_center().x, base_y + 2.9, sr.get_center().y), 7.0, 0.9))
		return
	if kind == "corr":
		var along_x := sr.size.x > sr.size.y
		var length := sr.size.x if along_x else sr.size.y
		var n := maxi(1, int(length / 7.0))
		for k in n:
			var a := (k + 0.5) * length / n
			var pos := Vector3(sr.position.x + a, base_y + 2.7, sr.get_center().y) if along_x else Vector3(sr.get_center().x, base_y + 2.7, sr.position.y + a)
			lights.add_child(_omni(pos, 5.5, 0.8))
	else:
		var big := maxf(sr.size.x, sr.size.y)
		if big > 14.0:
			var along_x2 := sr.size.x > sr.size.y
			var n2 := int(ceil(big / 10.0))
			for k in n2:
				var a := (k + 0.5) * big / n2
				var pos := Vector3(sr.position.x + a, base_y + 2.7, sr.get_center().y) if along_x2 else Vector3(sr.get_center().x, base_y + 2.7, sr.position.y + a)
				lights.add_child(_omni(pos, 8.0, 1.0))
		else:
			lights.add_child(_omni(Vector3(sr.get_center().x, base_y + 2.7, sr.get_center().y), clampf(big * 0.75 + 1.5, 4.0, 9.0), 1.0))
	var mb: MeshBatch = ctx["mb"]
	var y: float = ctx["y"] + SchoolLayout.CEIL_H - 0.005
	var nx := maxi(1, int(sr.size.x / 2.4))
	var nz := maxi(1, int(sr.size.y / 2.4))
	for i in nx:
		for j in nz:
			var x := sr.position.x + (i + 0.5) * sr.size.x / nx
			var z := sr.position.y + (j + 0.5) * sr.size.y / nz
			mb.add_box(mats["lamp"], Vector3(x, y, z), Vector3(0.3, 0.01, 1.2) if sr.size.x < sr.size.y else Vector3(1.2, 0.01, 0.3))


func _omni(pos: Vector3, rng: float, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = rng
	l.light_energy = energy
	l.light_color = Color(1.0, 0.98, 0.94)
	l.shadow_enabled = false
	l.light_specular = 0.3
	return l


# ================================================================ 표지

func _build_signs(ctx: Dictionary, doors: Dictionary) -> void:
	var f: int = ctx["f"]
	var rooms: Array = ctx["rooms"]
	var root: Node3D = ctx["root"]
	for key in door_points:
		var parts := (key as String).split(":")
		if int(parts[0]) != f + 1 or parts[1].begins_with("exterior"):
			continue
		var p: Vector3 = door_points[key]
		var info := room_at(p + Vector3(0, 1.0, 0))
		# 문 바깥(복도) 쪽으로 붙인다: 문 둘레 네 방향 중 복도인 쪽
		for dir in [Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3)]:
			var q: Vector3 = p + dir
			var idx := _cell_index(q.x, q.z)
			if idx < 0:
				continue
			var ri: int = grids[f][idx]
			if _kind(rooms, ri) != "corr":
				continue
			var l := Label3D.new()
			l.text = parts[1]
			l.font = _font
			l.font_size = 64
			l.pixel_size = 0.0035 if parts[1].length() <= 5 else 0.0022
			l.modulate = Color(0.15, 0.16, 0.18)
			l.outline_size = 0
			l.position = p + dir.normalized() * 0.19 + Vector3(0, 2.45, 0)
			l.rotation.y = atan2(dir.x, dir.z)
			l.double_sided = false
			root.add_child(l)
			var plate := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var pw := maxf(0.5, parts[1].length() * (0.2 if parts[1].length() <= 5 else 0.14) + 0.12)
			bm.size = Vector3(pw, 0.24, 0.02) if absf(dir.z) > 0.0 else Vector3(0.02, 0.24, pw)
			plate.mesh = bm
			plate.material_override = mats["locker_top"]
			plate.position = p + dir.normalized() * 0.16 + Vector3(0, 2.45, 0)
			root.add_child(plate)
			break
	# 층 번호 (계단 문 옆)
	for key in door_points:
		var parts := (key as String).split(":")
		if int(parts[0]) != f + 1 or not parts[1].begins_with("계단"):
			continue
		var p: Vector3 = door_points[key]
		var l := Label3D.new()
		l.text = "%dF" % (f + 1)
		l.font = _font
		l.font_size = 96
		l.pixel_size = 0.006
		l.modulate = Color(0.3, 0.55, 0.75)
		l.position = p + Vector3(0, 2.6, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		root.add_child(l)
