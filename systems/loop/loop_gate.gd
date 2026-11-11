## R1 반복 관문 (docs/GDD.md 4장 R1, docs/TECH.md 3.1).
##
## 관문은 보이지 않는 면이다. 이 노드의 -Z 방향이 화살표 방향(정방향)이고, 면은 로컬 XY 평면.
## 플레이어가 면을 넘어가는 순간의 이동 방향으로 판정한다:
##   정방향(+Z → -Z)으로 넘으면 forward_target, 역방향이면 reverse_target으로 옮긴다.
##   대상이 없으면 아무 일도 없다.
## 옮길 때는 이 관문 기준의 상대 위치, 방향, 속도를 대상 관문 기준으로 그대로 옮긴다.
## 그래서 두 관문 주변 풍경이 같으면 옮긴 티가 나지 않는다.
class_name LoopGate
extends Node3D

## 넘어간 순간 알린다. teleported: 실제로 옮겼는지
signal crossed(forward: bool, teleported: bool)

@export var forward_target: LoopGate
@export var reverse_target: LoopGate
@export var half_width := 3.0
@export var half_height := 2.0

var player: Node3D

var _last_side := 0.0


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var local := to_local(player.global_position)
	if absf(local.x) > half_width or absf(local.y) > half_height:
		_last_side = 0.0
		return
	var side := 1.0 if local.z >= 0.0 else -1.0
	if _last_side != 0.0 and side != _last_side:
		var forward := side < 0.0
		var target := forward_target if forward else reverse_target
		if target != null:
			_teleport(target, side)
			crossed.emit(forward, true)
			return
		crossed.emit(forward, false)
	_last_side = side


func _teleport(target: LoopGate, side: float) -> void:
	var xf := target.global_transform * global_transform.affine_inverse()
	player.global_transform = xf * player.global_transform
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		body.velocity = xf.basis * body.velocity
	if player.has_method("on_teleported"):
		player.on_teleported(xf)
	# 도착한 관문은 플레이어가 이미 넘어간 쪽에 있다고 기억한다 (곧바로 다시 옮겨지지 않게)
	target._last_side = side
	_last_side = 0.0
