## 순간이동 직후 화면 한두 프레임을 직전 화면으로 덮는다.
##
## 이유: 멀리 있던 곳으로 옮기면, 그곳의 조명(특히 처음 보이는 조명과 그림자)이
## 렌더러 안에서 한 프레임 늦게 준비되어 첫 프레임이 어둡게 깜빡인다.
## 직전 화면을 1프레임(1/60초) 보여 주면 그 사이 뒤에서 준비가 끝나고, 사람 눈에는 보이지 않는다.
class_name FrameHold
extends CanvasLayer

var _rect: TextureRect
var _frames_left := 0


func _ready() -> void:
	layer = 100
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)


## 지금 화면에 나와 있는 그림을 frames 프레임 동안 덮어 둔다. 순간이동하기 직전(같은 물리 프레임)에 부른다.
func hold(frames := 1) -> void:
	var img := get_viewport().get_texture().get_image()
	_rect.texture = ImageTexture.create_from_image(img)
	_rect.visible = true
	_frames_left = frames
	_wait()


func _wait() -> void:
	while _frames_left > 0:
		await RenderingServer.frame_post_draw
		_frames_left -= 1
	_rect.visible = false
