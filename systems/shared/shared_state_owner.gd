## 공유 상태 하나 (GDD 문법 J "접속과 동일성", TECH 3.2).
## 떨어진 곳에 있는 여러 표현(정비대 A·B 등)이 이 값 하나를 본다. 값은 여기서만 바뀌고,
## 표현은 changed 신호를 받아 화면·충돌·소리를 맞춘다. 표현마다 따로 값을 들고 있지 않는다.
class_name SharedStateOwner
extends RefCounted

signal changed(old_value: int, new_value: int)

var id: String
var value: int
var min_value: int
var max_value: int


func _init(state_id: String, initial: int, lo: int, hi: int) -> void:
	id = state_id
	value = initial
	min_value = lo
	max_value = hi


## 값 변경 요청. 범위 밖이거나 같은 값이면 false (아무 일도 없다).
## 점유 검사(위에 사람이 서 있는지 등)는 요청하는 쪽(방)이 먼저 한다.
func request(new_value: int) -> bool:
	if new_value < min_value or new_value > max_value or new_value == value:
		return false
	var old := value
	value = new_value
	changed.emit(old, new_value)
	return true


## 저장 복구용: 신호 없이 값을 맞춘다 (표현은 호출한 쪽이 즉시 맞춘다).
func restore(v: int) -> void:
	value = clampi(v, min_value, max_value)
