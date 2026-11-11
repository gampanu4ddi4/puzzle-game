## 상호작용할 수 있는 물체. 플레이어가 화면 가운데로 보고 2 m 안에서 E를 누르면 interacted 신호를 낸다.
## 충돌 모양(CollisionShape3D)을 자식으로 붙여 쓴다.
class_name Interactable
extends StaticBody3D

signal interacted

## false면 가리켜도 점이 나오지 않고 눌러도 반응하지 않는다
var enabled := true


func can_interact() -> bool:
	return enabled


func interact() -> void:
	if enabled:
		interacted.emit()
