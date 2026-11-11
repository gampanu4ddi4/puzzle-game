## 퍼즐 1-2 "관리실"과 1-3 "일방통행" (docs/levels/ch1_parking.md).
##
## 1-2: B3 서쪽 벽의 관리실. 들어가면 문이 저절로 닫히고, 문이 닫혀 있는 동안 문 밖이 비상계단으로 바뀐다.
##   - 관리실은 늘 그 자리에 있다. 바뀌는 것은 문 밖이다: 지금까지의 공간(B2, B3, 나선, 지상)을 모두 감추고,
##     같은 자리에 미리 만들어 둔 계단실과 B4(1-3 구역)를 드러낸다. 문이 닫혀 있어 바뀌는 순간은 보이지 않는다.
##     플레이어를 옮기지 않으므로 순간이동에서 생기던 조명 깜빡임이 없다.
## 1-3: 계단을 내려가면 B4의 직선 통로 (40 m, 화살표 →). 화살표를 따라가면 꺾인 연결 통로 가운데의 관문에서
##   서쪽 연결 통로의 같은 자리로 옮겨져 통로 처음으로 돌아온다. 화살표를 거슬러 서쪽 연결 통로로 가면
##   옮겨지지 않고 다음 구역이 나온다.
##   - 양쪽 연결 통로와 그 너머로 보이는 12 m 구간을 똑같이 만들어 두었다 (동쪽에는 통로 시작 부분의 복제,
##     서쪽에는 통로 끝 부분과 똑같이 시작하는 다음 구역).
class_name Ch1B
extends Node3D

const HINT_TIMES := [420.0, 720.0, 1080.0]
const J := Vector3(-44.0, 0.0, -18.0)        # 1-3 관문을 지날 때의 이동량 (B 좌표)
const GI_CONN := "res://levels/ch1_parking/p1_3_conn_voxelgi.res"
const GI_MID := "res://levels/ch1_parking/p1_3_mid_voxelgi.res"

var host: Node                 # p1_1 (player, solved, traces, hint_scale 등을 쓴다)
var player: CharacterBody3D

var room: Ch1bPiece
var room_door: SpringDoor
var group_b: Node3D            # 계단실 + B4. 처음에는 감춰 둔다
var stairs: Ch1bPiece
var aisle: Ch1bPiece
var east_conn: Ch1bPiece
var west_conn: Ch1bPiece
var exit_hall: Ch1bPiece
var stair_door: SpringDoor
var end_door: SpringDoor
var gate: LoopGate
var landing: LoopGate

var swapped := false
var solved12 := false
var stair_locked := false
var solved13 := false
var loops13 := 0
var t12 := 0.0
var t_inside := 0.0
var t13 := 0.0
var hint12 := 0
var hint_inside := false
var hint13 := 0

var _lamp_next := 0.0
var _lamp_on := true
var _wind: AudioStreamPlayer3D
var _door_wind: AudioStreamPlayer3D
var _sfx: AudioStreamPlayer3D
var _green: OmniLight3D
var _end_card: Label
var _rng := RandomNumberGenerator.new()


func build(p_host: Node, b3: ParkingFloor) -> void:
	host = p_host
	_rng.randomize()
	var door_w := b3.to_global(Vector3(0, 0, ParkingFloor.DOOR_Z))   # B3 안쪽 벽면의 문 자리

	# ---- 관리실 (늘 있다). 층 2의 조명(B3)도 받도록 레이어 1과 2에 둔다
	room = Ch1bPiece.new()
	room.name = "Room"
	room.position = door_w + Vector3(0, 0, 0.3)
	add_child(room)
	room.build_room(room.position)
	room_door = SpringDoor.new()
	room_door.width = 0.94
	room_door.sfx_bus = "Parking"
	room_door.position = Vector3(0, 0, -0.12)
	room.add_child(room_door)
	room_door.build(Color("8e938f"), Color("5f6461"), 0.38)
	# 문 안쪽 면의 "입구" 표지 (방향이 거꾸로다: 1-2의 단서)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.36, 0.14, 0.01)
	plate.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("16402c")
	gm.emission_enabled = true
	gm.emission = Color("3BD07A")
	gm.emission_energy_multiplier = 1.2
	plate.material_override = gm
	plate.position = Vector3(0.47, 1.92, 0.03)
	room_door.leaf.add_child(plate)
	var txt := Label3D.new()
	txt.text = "입구  ↓"
	txt.font = room.get("_font")
	txt.font_size = 96
	txt.pixel_size = 0.001
	txt.modulate = Color(0.95, 1.0, 0.95)
	txt.outline_size = 0
	txt.position = Vector3(0.47, 1.92, 0.037)
	room_door.leaf.add_child(txt)
	room.set_render_layer(3)
	room.drawer.interacted.connect(_open_drawer)
	room.ledger.interacted.connect(_take_ledger)
	_door_wind = AudioStreamPlayer3D.new()
	_door_wind.stream = ProcAudio.stair_wind()
	_door_wind.bus = "Parking"
	_door_wind.unit_size = 3.0
	_door_wind.volume_db = -10.0
	_door_wind.position = Vector3(0, 1.2, -0.2)
	room.add_child(_door_wind)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = "Parking"
	_sfx.unit_size = 6.0
	add_child(_sfx)

	# ---- B 묶음: 계단실 + B4. 좌표 Q(통로 기준)의 원점을 월드에 놓는다
	group_b = Node3D.new()
	group_b.name = "GroupB"
	group_b.position = door_w + Vector3(-5.0, -3.0, 3.3)
	add_child(group_b)
	var q := group_b.position

	stairs = _piece("Stairs", Vector3(5.0, 3.0, -3.3))
	stairs.rotation.y = PI
	stairs.build_stairs(door_w)

	aisle = _piece("Aisle", Vector3.ZERO)
	aisle.build_aisle(q, 0.0, 40.0, false, false, true)
	var stub := _piece("AisleStartCopy", -J)
	stub.build_aisle(q - J, 0.0, 12.0, false, true, false)
	exit_hall = _piece("ExitHall", J)
	exit_hall.build_aisle(q + J, 28.0, 40.0, true, false, false)
	east_conn = _piece("EastConnector", Vector3(42.0, 0.0, 3.0))
	east_conn.build_connector(q)
	west_conn = _piece("WestConnector", Vector3(42.0, 0.0, 3.0) + J)
	west_conn.build_connector(q + J)

	# 계단실 아래 문 (통로 북쪽 벽 x = 5): 통로 쪽으로 열린다. 지나가면 뒤에서 잠긴다
	stair_door = SpringDoor.new()
	stair_door.width = 0.94
	stair_door.sfx_bus = "Parking"
	stair_door.position = Vector3(5.0, 0.0, -3.15)
	group_b.add_child(stair_door)
	stair_door.build(Color("8e938f"), Color("5f6461"), 0.34)
	stair_door.closed.connect(_on_stair_door_closed)
	# 다음 구역 끝의 문 (아직 만들지 않은 1-4로 가는 문. 잠겨 있다)
	end_door = SpringDoor.new()
	end_door.width = 0.94
	end_door.sfx_bus = "Parking"
	end_door.position = Vector3(28.0, 0.0, 0.0) + J + Vector3(0.02, 0, 0)
	end_door.rotation.y = -PI / 2
	end_door.locked = true
	group_b.add_child(end_door)
	end_door.build(Color("8e938f"), Color("5f6461"), 0.1)

	# 반복 관문: 동쪽 연결 통로 가운데 → 서쪽 연결 통로의 같은 자리
	gate = LoopGate.new()
	gate.name = "Gate13"
	gate.position = Vector3(42.0, 1.0, 9.0)
	gate.rotation.y = PI            # 관문의 정방향(-Z)을 통로의 화살표 방향(+Z)으로
	gate.half_width = 2.2
	group_b.add_child(gate)
	landing = LoopGate.new()
	landing.name = "Landing13"
	landing.position = gate.position + J
	landing.rotation.y = PI
	group_b.add_child(landing)
	gate.forward_target = landing
	gate.crossed.connect(_on_gate)

	# 계단실 바람 소리, 힌트용 초록 불빛
	_wind = AudioStreamPlayer3D.new()
	_wind.stream = ProcAudio.stair_wind()
	_wind.bus = "Parking"
	_wind.unit_size = 5.0
	_wind.volume_db = -14.0
	_wind.position = Vector3(0, -1.0, 3.0)
	stairs.add_child(_wind)
	_green = OmniLight3D.new()
	_green.light_color = Color("3BD07A")
	_green.light_energy = 0.0
	_green.omni_range = 16.0
	_green.position = Vector3(0, 2.0, 0.0)
	west_conn.add_child(_green)

	_bake_gi()
	_set_b(false)
	_build_end_card()


func set_player(p: CharacterBody3D) -> void:
	player = p
	room_door.player = p
	stair_door.player = p
	gate.player = p
	landing.player = p


func _piece(node_name: String, local_pos: Vector3) -> Ch1bPiece:
	var p := Ch1bPiece.new()
	p.name = node_name
	p.position = local_pos
	group_b.add_child(p)
	return p


func _set_b(on: bool) -> void:
	group_b.visible = on
	group_b.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## 미리 구운 간접광. 연결 통로 둘은 주변 12 m까지 포함해 한 번 굽고 나눠 쓴다 (관문 양쪽의 밝기가 같도록).
func _bake_gi() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_gi([east_conn, west_conn], Vector3(0, 1.3, 6.0), Vector3(28.6, 3.2, 24.6), GI_CONN)
	_gi([aisle], Vector3(20.0, 1.3, 0.0), Vector3(17.0, 3.2, 6.6), GI_MID)


func _gi(nodes: Array, center: Vector3, size: Vector3, path: String) -> void:
	var data: VoxelGIData = null
	if FileAccess.file_exists(path) and LevelEnv.arg_value("--rebake-gi") == "":
		data = load(path) as VoxelGIData
		if data != null and data.get_bounds().size == Vector3.ZERO:
			data = null
	for n: Node3D in nodes:
		var v := VoxelGI.new()
		v.name = "GI"
		v.subdiv = VoxelGI.SUBDIV_128
		v.size = size
		v.position = center
		n.add_child(v)
	if data == null:
		var t := Time.get_ticks_msec()
		var first: VoxelGI = (nodes[0] as Node3D).get_node("GI")
		first.bake(group_b, false)      # B 묶음의 물체와 조명만 굽는다 (같은 자리에 겹쳐 있는 B2 등은 빼고)
		data = first.data
		if data == null or data.get_bounds().size == Vector3.ZERO:
			push_warning("VoxelGI bake failed: " + path)
			return
		data.interior = true
		data.propagation = 0.65
		data.use_two_bounces = true
		ResourceSaver.save(data, path)
		print("baked %s in %d ms" % [path.get_file(), Time.get_ticks_msec() - t])
	data.energy = 1.0
	for n: Node3D in nodes:
		(n.get_node("GI") as VoxelGI).data = data


func _build_end_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	_end_card = Label.new()
	_end_card.text = "지금은 여기까지입니다.\n플레이해 주셔서 감사합니다.   (Esc: 메뉴)"
	_end_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_end_card.position.y -= 140
	_end_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_card.add_theme_font_size_override("font_size", 22)
	_end_card.add_theme_color_override("font_color", Color(0.85, 0.88, 0.84))
	_end_card.add_theme_color_override("font_outline_color", Color.BLACK)
	_end_card.add_theme_constant_override("outline_size", 6)
	_end_card.modulate.a = 0.0
	layer.add_child(_end_card)
	add_child(layer)


# ================================================================ 진행

func _process(delta: float) -> void:
	if player == null or host == null:
		return
	var scale: float = float(host.get("hint_scale")) * Settings.hint_scale()
	if not swapped:
		_update_12_outside(delta * scale)
	elif not stair_locked:
		_update_12_inside(delta * scale)
	elif not solved13:
		_update_13(delta * scale)


func _player_in_room() -> bool:
	var l := room.to_local(player.global_position)
	return absf(l.x) < 2.0 and l.z > 0.15 and l.z < 5.0 and l.y > -0.5 and l.y < 2.5


## 1-2, 바꾸기 전: 플레이어가 관리실 안에 있고 문이 닫히면 문 밖을 바꾼다.
func _update_12_outside(dt: float) -> void:
	if _player_in_room():
		room_door.auto_close = true
		if not room_door.is_open and absf(room_door.get("_hinge").rotation.y) < 0.01:
			_swap()
		return
	if not bool(host.get("solved")):
		return
	t12 += dt
	while hint12 < 3 and t12 >= HINT_TIMES[hint12]:
		hint12 += 1
		print("1-2 hint stage ", hint12)
		if hint12 == 2:
			_door_wind.play()                 # ② 문 너머에서 계단실 바람 소리
		elif hint12 == 3:
			_set_ajar(room_door, 24.0)        # ③ 문이 저절로 조금 열린다
	if hint12 >= 1:
		_flicker_lamp()                       # ① 문 위의 등이 깜빡인다


func _flicker_lamp() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if t < _lamp_next:
		return
	_lamp_on = not _lamp_on
	_lamp_next = t + (_rng.randf_range(0.3, 2.5) if _lamp_on else _rng.randf_range(0.04, 0.2))
	room.door_lamp.light_energy = 0.5 if _lamp_on else 0.0
	room.door_lamp_mat.emission_energy_multiplier = 3.0 if _lamp_on else 0.0


## 문을 조금만 열어 둔다 (완전히 연 것은 아니다: E로 마저 열 수 있다).
func _set_ajar(door: SpringDoor, deg: float) -> void:
	if door.is_open:
		return
	door.auto_close = false
	create_tween().tween_property(door.get("_hinge"), "rotation:y", deg_to_rad(deg) * -door.swing, 1.2)


## 문 밖을 바꾼다: 지금까지의 공간을 감추고 계단실과 B4를 드러낸다.
func _swap() -> void:
	swapped = true
	_door_wind.stop()
	for c in host.get_children():
		if c == self or c == player or not (c is Node3D) or c is AudioStreamPlayer3D:
			continue
		(c as Node3D).visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	_set_b(true)
	_wind.play()
	host.set("stage_b", true)
	print("1-2: door closed with player inside -> outside is now the stairwell")


## 1-2, 바꾼 뒤: 계단을 내려가 아래 문을 지나면 끝. 방 안에 오래 있으면 문이 저절로 조금 열린다.
func _update_12_inside(dt: float) -> void:
	var s := stairs.to_local(player.global_position)
	if not solved12 and s.y < -2.5 and s.z > 0.0:
		solved12 = true
		print("PUZZLE 1-2 SOLVED  time=%.0fs  hint=%d" % [t12, hint12])
	if _player_in_room():
		t_inside += dt
		if not hint_inside and t_inside >= HINT_TIMES[0]:
			hint_inside = true
			_set_ajar(room_door, 24.0)
	else:
		room_door.auto_close = true


func _on_stair_door_closed() -> void:
	if stair_locked or player == null:
		return
	var l := group_b.to_local(player.global_position)
	if l.z > -3.0 and l.y < 1.0:
		# 통로로 나온 뒤 문이 닫혔다: 뒤에서 잠긴다
		stair_door.lock()
		stair_locked = true
		if not solved12:
			solved12 = true
		_sfx.global_position = stair_door.global_position + Vector3(0, 1.0, 0)
		_sfx.stream = ProcAudio.click()
		_sfx.play()
		print("1-3: stair door locked behind the player")


func _on_gate(forward: bool, teleported: bool) -> void:
	if forward and teleported:
		loops13 += 1
		print("1-3 loop ", loops13)


func _update_13(dt: float) -> void:
	var l := group_b.to_local(player.global_position)
	if l.x < -5.0 and l.z < -14.5:
		solved13 = true
		print("PUZZLE 1-3 SOLVED  loops=%d  time=%.0fs  hint=%d" % [loops13, t13, hint13])
		create_tween().tween_property(_end_card, "modulate:a", 1.0, 2.0).set_delay(2.0)
		return
	t13 += dt
	while hint13 < 3 and t13 >= HINT_TIMES[hint13]:
		hint13 += 1
		print("1-3 hint stage ", hint13)
		match hint13:
			1:
				# ① 통로 처음과 서쪽 연결 통로의 형광등이 깜빡인다
				aisle.make_fixture_flicker(Vector3(2.0, ParkingFloor.H, 0.0))
				west_conn.make_fixture_flicker(Vector3(0, ParkingFloor.H, 15.0))
			2:
				# ② 서쪽 연결 통로 안쪽에서 바람 소리
				var w := AudioStreamPlayer3D.new()
				w.stream = ProcAudio.stair_wind()
				w.bus = "Parking"
				w.unit_size = 6.0
				w.volume_db = -8.0
				w.position = Vector3(0, 1.5, -3.0)
				west_conn.add_child(w)
				w.play()
			3:
				# ③ 서쪽 연결 통로 안쪽에서 초록 불빛이 새어 나온다
				create_tween().tween_property(_green, "light_energy", 2.2, 3.0)


func _open_drawer() -> void:
	room.drawer.enabled = false
	(room.drawer.get_child(0) as CollisionShape3D).disabled = true
	create_tween().tween_property(room.drawer, "position:x", room.drawer.position.x - 0.32, 0.5).set_trans(Tween.TRANS_SINE)
	room.ledger.enabled = true
	_sfx.global_position = room.drawer.global_position
	_sfx.stream = ProcAudio.door_rattle()
	_sfx.play()


func _take_ledger() -> void:
	room.ledger.enabled = false
	room.ledger.visible = false
	(room.ledger.get_child(0) as CollisionShape3D).disabled = true
	(host.get("traces") as Array).append("분실물 대장 (어린이 수영 가방, 찾아감)")
	_sfx.global_position = room.ledger.global_position
	_sfx.stream = ProcAudio.paper()
	_sfx.play()
	print("TRACE 2: 분실물 대장")


# ================================================================ 바로 가기와 자동 테스트

## B4 통로에서 바로 시작 (--start=b4)
func skip_to_aisle() -> void:
	_swap()
	solved12 = true
	stair_locked = true
	stair_door.lock()
	player.global_position = group_b.to_global(Vector3(6.5, 0.05, 0.0))
	player.rotation.y = -PI / 2      # +X(화살표 방향)를 본다


func _s(x: float, y: float, z: float) -> Vector3:
	return stairs.to_global(Vector3(x, y, z))


func _q(x: float, z: float) -> Vector3:
	return group_b.to_global(Vector3(x, 0.0, z))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func run_test(kind: String, out: String) -> void:
	if kind == "p12":
		await _test_p12(out)
	else:
		await _test_p13(out)


## 1-2: 관리실에 들어갔다 나와 계단을 내려가 B4 통로까지.
func _test_p12(out: String) -> void:
	var door_c := room_door.global_position + Vector3(0, 1.1, 0)
	player.global_position = room.to_global(Vector3(0.0, 0.05, -2.2))
	host.call("_aim_at", door_c)
	await _wait(0.8)
	await host.call("_save", out.path_join("12_a_door_b3.png"))
	player.global_position = room.to_global(Vector3(0.0, 0.05, -1.5))
	host.call("_aim_at", door_c)
	await _wait(0.2)
	print("open room door: ", player.call("try_interact"))
	await _wait(0.9)
	var pts1: Array[Vector3] = [room.to_global(Vector3(0, 0, 1.2)), room.to_global(Vector3(-0.6, 0, 2.6))]
	await host.call("_walk_to", pts1)
	host.call("_aim_at", room.to_global(Vector3(1.6, 0.9, 3.4)))
	var t0 := Time.get_ticks_msec()
	while not swapped and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	print("swapped after door closed: %s (%.1fs)" % [swapped, (Time.get_ticks_msec() - t0) / 1000.0])
	print("  room local=%s  door_open=%s  hinge=%.3f" % [room.to_local(player.global_position), room_door.is_open, room_door.get("_hinge").rotation.y])
	await _wait(0.5)
	await host.call("_save", out.path_join("12_b_room.png"))
	# 서랍 → 분실물 대장
	player.global_position = room.to_global(Vector3(0.45, 0.05, 2.76))
	host.call("_aim_at", room.drawer.global_position + Vector3(-0.2, 0, 0))
	await _wait(0.3)
	print("open drawer: ", player.call("try_interact"))
	await _wait(0.8)
	host.call("_aim_at", room.ledger.global_position)
	await _wait(0.3)
	await host.call("_save", out.path_join("12_c_drawer.png"))
	print("take ledger: ", player.call("try_interact"), "  traces=", host.get("traces"))
	# 문을 안쪽에서 본다 → 연다 → 계단실
	player.global_position = room.to_global(Vector3(0.0, 0.05, 2.0))
	host.call("_aim_at", door_c)
	await _wait(0.4)
	await host.call("_save", out.path_join("12_d_door_inside.png"))
	player.global_position = room.to_global(Vector3(0.3, 0.05, 1.45))
	host.call("_aim_at", door_c + Vector3(0.2, 0, 0))
	await _wait(0.2)
	print("open room door from inside: ", player.call("try_interact"))
	await _wait(0.9)
	player.global_position = room.to_global(Vector3(0.0, 0.05, 1.7))
	host.call("_aim_at", _s(0, 0.9, 3.0))
	await _wait(0.3)
	await host.call("_save", out.path_join("12_e_stairwell.png"))
	# 계단을 내려간다
	host.set("_route_accept", 0.35)
	var pts2: Array[Vector3] = [_s(0, 0, 0.7), _s(-0.68, 0, 1.3), _s(-0.68, -1.5, 4.5), _s(0, -1.5, 4.85), _s(0.68, -1.5, 4.5),
		_s(0.68, -3, 1.2), _s(0, -3, 0.9)]
	await host.call("_walk_to", pts2, 40.0)
	var sl := stairs.to_local(player.global_position)
	print("bottom of stairs: local=(%.2f, %.2f, %.2f)  solved12=%s" % [sl.x, sl.y, sl.z, solved12])
	host.call("_aim_at", _s(0.6, -1.8, 0.0))
	await _wait(0.4)
	await host.call("_save", out.path_join("12_f_bottom.png"))
	host.call("_aim_at", stair_door.global_position + Vector3(0, 1.1, 0))
	await _wait(0.2)
	print("open stair door: ", player.call("try_interact"))
	await _wait(0.9)
	var pts3: Array[Vector3] = [_q(5.0, -2.2), _q(6.5, 0.0)]
	await host.call("_walk_to", pts3, 15.0)
	host.set("_route_accept", 1.0)
	t0 = Time.get_ticks_msec()
	while not stair_locked and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	print("stair door locked behind: ", stair_locked)
	host.call("_aim_at", _q(30.0, 0.0) + Vector3(0, 1.3, 0))
	await _wait(0.6)
	await host.call("_save", out.path_join("12_g_aisle.png"))
	host.call("_aim_at", stair_door.global_position + Vector3(0, 1.1, 0))
	await _wait(0.2)
	player.global_position = _q(5.0, -1.8) + Vector3(0, 0.05, 0)
	host.call("_aim_at", stair_door.global_position + Vector3(0, 1.1, 0))
	await _wait(0.2)
	player.call("try_interact")
	await _wait(0.3)
	print("door stays shut when tried again: ", not stair_door.is_open)


## 1-3: 화살표를 따라가 반복을 겪고(관문 이음새 측정), 거슬러 가서 다음 구역에 도착한다.
func _test_p13(out: String) -> void:
	await _wait(1.0)
	await host.call("_save", out.path_join("13_a_start.png"))
	# 계단실 문 둘레 벽 (계단실 벽과 통로 벽이 겹치지 않는지)
	var keep := player.global_transform
	player.global_position = group_b.to_global(Vector3(7.5, 0.05, -0.5))
	host.call("_aim_at", group_b.to_global(Vector3(5.0, 1.3, -3.0)))
	await _wait(0.6)
	await host.call("_save", out.path_join("13_a_door_wall.png"))
	player.global_transform = keep
	await _wait(0.3)
	var state := {"hit": false}
	gate.crossed.connect(func(_f: bool, tp: bool) -> void:
		if tp:
			state["hit"] = true
			var r: Array = host.get("_route")
			for i in r.size():
				r[i] += group_b.global_transform.basis * J)
	# 동쪽으로: 통로 끝 → 연결 통로 → (관문) → 남쪽 모퉁이 → 통로 처음
	var route: Array[Vector3] = [_q(38.0, 0.0), _q(42.0, 1.0), _q(42.0, 9.0), _q(42.0, 17.0), _q(46.0, 18.0), _q(50.0, 18.0)]
	host.set("_route", route)
	var prev: Image = null
	var prev2: Image = null
	var frames_after := -1
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if frames_after < 0 and state["hit"] and prev != null:
			frames_after = 1
			prev.save_png(out.path_join("13_b_before.png"))
			img.save_png(out.path_join("13_b_after.png"))
			print("1-3 seam: baseline=%.4f  teleport frame=%.4f" % [host.call("_diff", prev2, prev), host.call("_diff", prev, img)])
		elif frames_after >= 1:
			frames_after += 1
			if frames_after <= 3:
				print("1-3 seam: after_%02d = %.4f" % [frames_after, host.call("_diff", prev, img)])
			if frames_after >= 6:
				break
		prev2 = prev
		prev = img
	while not (host.get("_route") as Array).is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var l := group_b.to_local(player.global_position)
	print("after one loop: Q=(%.1f, %.1f)  loops=%d (통로 처음 x≈6이어야 함)" % [l.x, l.z, loops13])
	await host.call("_save", out.path_join("13_c_looped.png"))
	# 화살표를 거슬러: 통로 처음 → 서쪽 연결 통로 → 북쪽 모퉁이 → 다음 구역
	var pts4: Array[Vector3] = [_q(-2.0, 0.5)]
	await host.call("_walk_to", pts4, 20.0)
	host.call("_aim_at", _q(-2.0, -18.0) + Vector3(0, 1.4, 0))
	await _wait(0.5)
	await host.call("_save", out.path_join("13_d_west_connector.png"))
	var pts5: Array[Vector3] = [_q(-2.0, -17.0), _q(-7.0, -18.0), _q(-12.0, -18.0)]
	await host.call("_walk_to", pts5, 30.0)
	await _wait(0.5)
	l = group_b.to_local(player.global_position)
	print("against the arrows: Q=(%.1f, %.1f)  solved13=%s  loops=%d" % [l.x, l.z, solved13, loops13])
	await host.call("_save", out.path_join("13_e_exit_hall.png"))
	print("fps=", Engine.get_frames_per_second())
