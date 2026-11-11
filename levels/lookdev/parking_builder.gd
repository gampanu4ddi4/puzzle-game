## 룩 테스트: 지하 주차장 B2 한 층 (실시간 간접광 SDFGI).
## 편집기에서도 보이도록 @tool로 실행된다 (편집기에서는 플레이어와 화면 효과를 빼고 만든다).
##
## 실행 인자:
##   -- --shots=<폴더>   정해진 시점에서 스크린샷을 찍고 종료한다.
@tool
extends Node3D

const PLAYER_SCRIPT := preload("res://core/player/player.gd")
const W := ParkingFloor.W
const RAMP_Z := ParkingFloor.RAMP_Z


func _ready() -> void:
	for c in get_children():
		c.free()
	LevelEnv.create(self, LevelEnv.GI.SDFGI)
	var f := ParkingFloor.new()
	f.name = "FloorB2"
	f.west_opening = false
	f.collisions = not Engine.is_editor_hint()
	add_child(f)
	f.build(Vector3.ZERO)
	# 위쪽 끝을 막는다 (이 장면에는 위층이 없다)
	var top := ParkingFloor.tunnel_point(ParkingFloor.RAMP_LEN)
	var cap := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 3.0, 6.6)
	cap.mesh = bm
	cap.material_override = ParkingMats.for_floor(Vector3.ZERO)["concrete_paint"]
	cap.position = top + Vector3(0.15, 1.35, 0)
	add_child(cap)

	if Engine.is_editor_hint():
		return
	LevelEnv.add_post_fx(self)
	var shots := LevelEnv.arg_value("--shots")
	if shots != "":
		_run_shots(shots)
	else:
		var p := CharacterBody3D.new()
		p.set_script(PLAYER_SCRIPT)
		p.name = "Player"
		p.position = Vector3(3.0, 0.05, 24.0)
		p.rotation.y = -PI / 2
		add_child(p)


const SHOTS := [
	["01_aisle_south", Vector3(2.5, 1.6, 24.0), Vector3(46.0, 1.3, 24.0)],
	["02_diagonal", Vector3(6.0, 1.6, 8.5), Vector3(40.0, 1.0, 20.0)],
	["03_ramp", Vector3(38.5, 1.6, 23.2), Vector3(60.0, 2.2, 24.2)],
	["04_exit_door", Vector3(7.0, 1.6, 10.0), Vector3(0.0, 1.4, 13.0)],
	["05_stalls", Vector3(14.0, 1.6, 10.0), Vector3(22.0, 0.6, 2.0)],
	["06_aisle_north", Vector3(46.0, 1.6, 8.0), Vector3(0.0, 1.4, 8.0)],
	["07_wall_b2", Vector3(42.0, 1.6, 14.0), Vector3(48.0, 1.5, 11.0)],
	["08_ramp_inside", Vector3(49.0, 1.7, 23.0), Vector3(62.0, 2.6, 24.0)],
]


func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	await get_tree().create_timer(4.0).timeout
	for s in SHOTS:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(s[0] + ".png"))
		print("shot ", s[0], "  fps=", Engine.get_frames_per_second())
	get_tree().quit()
