## 나선 경사로 (270도 돌며 한 층 3 m를 오른다). 모양은 tools/blender/parking_kit.py의 helix_mesh와 같다.
##
## 조각 원점 = 아래 진입로 시작점 (아래층 동쪽 벽 입구 가운데 바닥). 조각 좌표:
##   아래 진입로  (0,0,0) → (13,0,0), +X 방향
##   나선        중심 (13, *, 9), 반지름 9, 0 → 270도, 끝점 (4, 3, 9)에서 -Z 방향
##   출구 east   (4,3,9) → (4,3,-4) 곧게 13 m. 아래층 바로 위에 겹쳐 놓은 위층(90도 돌림)의 서쪽 입구에 닿는다.
##   출구 west   (4,3,9) → (4,3,-8) → 오른쪽으로 90도 꺾어 (10,3,-14)에서 +X 방향. 위층(B2) 서쪽 입구에 닿는다.
##
## 나선 가운데(135도)에서는 안쪽 벽(반지름 6) 때문에 양쪽으로 120도까지만 보이므로, 양 끝(0도, 270도)이
## 보이지 않는다. east와 west는 나선 부분이 똑같아서, 이 지점끼리는 평행 이동만으로 이음새 없이 옮길 수 있다.
class_name HelixRamp
extends ParkingFloor

const R := 9.0
const TURN := 1.5 * PI
const RISE := 3.0
const STUB := 13.0
const GATE_PHI := TURN / 2.0        # 135도: 관문 자리

## 층 원점 기준, 동쪽 나선 조각의 원점 (층 동쪽 벽 입구)
const EAST_OFFSET := Vector3(W, 0.0, RAMP_Z)
## 층 원점 기준, 서쪽 나선 조각의 원점 (출구가 층 서쪽 입구 (0, 0, 24)에 +X로 닿는 자리)
const WEST_OFFSET := Vector3(-10.0, -RISE, RAMP_Z + 14.0)
## 위층은 90도 돌려 놓는다 (위층의 +X = 월드 -Z)
const UPPER_ROT_Y := PI / 2.0
## 동쪽 조각 출구 끝 (조각 좌표 z)
const EAST_EXIT_Z := -4.0
## 위층을 1 cm 띄운다. 아래층 천장 판과 위층 바닥 판이 같은 높이에 겹치면 면이 깜빡이기 때문이다.
const UPPER_LIFT := 0.01

var variant := "east"


## 층 원점 기준 위층의 원점: 동쪽 조각 출구 끝이 위층 서쪽 입구 (0, 0, 24)와 맞는다.
## 위층은 아래층 북동쪽 위에 겹쳐 놓인다 (아래층 천장 = 위층 바닥).
static func upper_origin() -> Vector3:
	var entrance := EAST_OFFSET + Vector3(4.0, RISE + UPPER_LIFT, EAST_EXIT_Z)
	return entrance - Basis(Vector3.UP, UPPER_ROT_Y) * Vector3(0.0, 0.0, RAMP_Z)


## 나선 차로 중심선 바닥 (조각 좌표). phi: 0 = 아래 진입로 끝, TURN = 출구 시작
static func point(phi: float) -> Vector3:
	return Vector3(STUB + R * sin(phi), RISE * phi / TURN, R - R * cos(phi))


## phi에서 내려가는 방향 (수평 단위 벡터)
static func downhill(phi: float) -> Vector3:
	return Vector3(-cos(phi), 0.0, -sin(phi))


static func slope() -> float:
	return RISE / (R * TURN)


## 조각을 내려가는 길 (조각 좌표, 테스트 길 안내용): 출구 → 나선 → 아래 진입로
static func route_down(v: String) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	if v == "west":
		for i in range(8, -1, -1):
			var t := PI / 2.0 * i / 8.0
			pts.append(Vector3(10.0 - 6.0 * cos(t), RISE, -8.0 - 6.0 * sin(t)))
	else:
		pts.append(Vector3(4.0, RISE, EAST_EXIT_Z + 0.5))
	for i in range(27, -1, -1):
		pts.append(point(TURN * i / 27.0))
	pts.append(Vector3(6.0, 0.0, 0.0))
	pts.append(Vector3(-6.0, 0.0, 0.0))
	return pts


func build_ramp(world_origin: Vector3, v: String) -> void:
	variant = v
	_rng.seed = light_seed
	_mats = ParkingMats.for_floor(world_origin)
	var g := _group("Helix")
	var ramp := _place("helix_" + v, Vector3.ZERO, 0.0, g)
	if collisions and not Engine.is_editor_hint():
		for mi in ramp.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()
	var s := slope()
	# 바닥 화살표: 내려가는 쪽을 가리킨다 (경사를 따라 기울인다)
	for phi in [TURN * 0.2, TURN * 0.5, TURN * 0.8]:
		var tilt := Node3D.new()
		tilt.position = point(phi) + Vector3(0, 0.006, 0)
		tilt.rotation = Vector3(0.0, PI - phi, -atan(s))
		g.add_child(tilt)
		_place_arrow(tilt, Vector3.ZERO, 0.0)
	_place_arrow(g, Vector3(6.5, 0.005, 0.0), PI)
	_place_arrow(g, Vector3(4.0, RISE + 0.005, 1.0), -PI / 2)
	# 조명: 나선을 따라 45도마다 (두 조각이 똑같은 배치), 진입로와 출구에 하나씩
	for i in 6:
		var phi := deg_to_rad(22.5 + 45.0 * i)
		_fixture(g, point(phi) + Vector3(0, H, 0), -phi, "off" if i == 4 else "on", s, false)
	_fixture(g, Vector3(6.5, H, 0.0), 0.0, "on", 0.0, false)
	if v == "east":
		_fixture(g, Vector3(4.0, RISE + H, 0.5), PI / 2, "flicker", 0.0, false)
	else:
		_fixture(g, Vector3(6.0, RISE + H, -12.0), PI / 4, "on", 0.0, false)
