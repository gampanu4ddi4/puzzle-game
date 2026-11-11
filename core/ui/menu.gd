## 메뉴: 메인 화면, 일시정지, 설정, 크레딧 (docs/GDD.md 10장).
## 게임 장면 위에 겹쳐 뜬다. 메인 화면 뒤로는 실제 게임 장면(프롤로그 거리)이 돌아가고 있어서,
## "새로 시작"을 누르면 메뉴만 걷히고 그 자리에서 바로 시작한다.
class_name Menu
extends CanvasLayer

signal start_requested
signal resume_requested

const TEXT := Color("c9cfc8")
const TEXT_DIM := Color("7d847d")
const TEXT_HOVER := Color("ffffff")
const ACCENT := Color("9fe0bd")

## 게임이 시작된 뒤에는 Esc로 일시정지 메뉴를 연다
var in_game := false

var _font: SystemFont
var _font_light: SystemFont
var _root: Control
var _shade: TextureRect
var _pages := {}
var _page := ""
var _back_to := "main"


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "Noto Sans", "DejaVu Sans", "Arial"])
	_font_light = _font.duplicate()
	_font_light.font_weight = 300

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	# 왼쪽이 짙고 오른쪽으로 옅어지는 그늘
	_shade = TextureRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.025, 0.02, 0.92))
	grad.set_color(1, Color(0.02, 0.025, 0.02, 0.15))
	grad.add_point(0.45, Color(0.02, 0.025, 0.02, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	_shade.texture = gt
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_shade)

	_pages["main"] = _build_main()
	_pages["pause"] = _build_pause()
	_pages["settings"] = _build_settings()
	_pages["credits"] = _build_credits()
	for p in _pages.values():
		_root.add_child(p)
	_hide_all()


func is_open() -> bool:
	return _root.visible


func show_main() -> void:
	in_game = false
	_open("main")


func show_pause() -> void:
	get_tree().paused = true
	_open("pause")


func close() -> void:
	_hide_all()
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != KEY_ESCAPE:
		return
	if _page in ["settings", "credits"]:
		_open(_back_to)
	elif _page == "pause":
		_resume()
	elif _page == "" and in_game:
		show_pause()
	get_viewport().set_input_as_handled()


# ================================================================ 화면 전환

func _open(page: String) -> void:
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for k in _pages:
		(_pages[k] as Control).visible = k == page
	_page = page
	var first := _first_button(_pages[page])
	if first:
		first.grab_focus.call_deferred()
	var c: Control = _pages[page]
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.25)


func _hide_all() -> void:
	_root.visible = false
	_page = ""
	for p in _pages.values():
		(p as Control).visible = false


func _first_button(n: Node) -> Control:
	for c in n.find_children("*", "BaseButton", true, false):
		if (c as Control).visible:
			return c
	return null


func _resume() -> void:
	close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resume_requested.emit()


# ================================================================ 모양

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	# 메뉴 버튼: 배경 없는 글자, 가리키면 밝아진다
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(s, "Button", empty)
	t.set_color("font_color", "Button", TEXT_DIM)
	t.set_color("font_hover_color", "Button", TEXT_HOVER)
	t.set_color("font_focus_color", "Button", TEXT_HOVER)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.4))
	t.set_font_size("font_size", "Button", 28)
	# 설정 화면 컨트롤
	var line := StyleBoxFlat.new()
	line.bg_color = Color(1, 1, 1, 0.15)
	line.content_margin_top = 2
	line.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", line)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.88, 0.74, 0.7)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.set_content_margin_all(6)
	for s in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(s, "OptionButton", box)
	t.set_font_size("font_size", "OptionButton", 20)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_font_size("font_size", "CheckButton", 20)
	t.set_stylebox("focus", "CheckButton", empty)
	t.set_stylebox("focus", "HSlider", empty)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.06, 0.055, 0.95)
	panel.border_color = Color(1, 1, 1, 0.12)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(8)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_font_size("font_size", "PopupMenu", 20)
	return t


func _page_box(left := 120.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = left
	v.offset_right = left + 640.0
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	return v


func _title(parent: Node, text: String, sub: String) -> void:
	var t := Label.new()
	t.text = text
	t.add_theme_font_override("font", _font_light)
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color", Color("e6ebe4"))
	parent.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 16)
	s.add_theme_color_override("font_color", TEXT_DIM)
	parent.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 48)
	parent.add_child(gap)


func _button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _footer(parent: Control, text: String) -> void:
	var f := Label.new()
	f.text = text
	f.add_theme_font_size_override("font_size", 14)
	f.add_theme_color_override("font_color", Color(0.45, 0.48, 0.45))
	f.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	f.position = Vector2(120, -48)
	parent.add_child(f)


# ================================================================ 페이지

func _build_main() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _page_box()
	_title(v, "새솔센터", "S A E S O L   C E N T E R")
	_button(v, "새로 시작", func() -> void:
		_hide_all()
		in_game = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		start_requested.emit())
	_button(v, "설정", func() -> void:
		_back_to = "main"
		_open("settings"))
	_button(v, "크레딧", func() -> void:
		_back_to = "main"
		_open("credits"))
	_button(v, "게임 종료", func() -> void: get_tree().quit())
	page.add_child(v)
	_footer(page, "프로토타입 v0.1  ·  마우스와 키보드")
	return page


func _build_pause() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _page_box()
	_title(v, "일시정지", "")
	_button(v, "계속하기", _resume)
	_button(v, "설정", func() -> void:
		_back_to = "pause"
		_open("settings"))
	_button(v, "메인 메뉴로", func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	_button(v, "게임 종료", func() -> void: get_tree().quit())
	page.add_child(v)
	return page


func _build_credits() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _page_box()
	_title(v, "크레딧", "")
	var lines := [
		["새솔센터", ""],
		["", ""],
		["기획 · 개발", "(팀 이름)"],
		["", ""],
		["엔진", "Godot Engine 4.7  (MIT License)"],
		["모델링 · 텍스처", "Blender (스크립트로 생성)"],
		["효과음", "코드로 생성한 임시 소리"],
		["개발 도움", "Claude (Anthropic)"],
		["", ""],
		["플레이해 주셔서 감사합니다.", ""],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	for l in lines:
		var a := Label.new()
		a.text = l[0]
		a.add_theme_color_override("font_color", TEXT_DIM if l[1] != "" else TEXT)
		a.add_theme_font_size_override("font_size", 20)
		var b := Label.new()
		b.text = l[1]
		b.add_theme_font_size_override("font_size", 20)
		grid.add_child(a)
		grid.add_child(b)
	v.add_child(grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	_button(v, "뒤로", func() -> void: _open(_back_to))
	page.add_child(v)
	return page


func _build_settings() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	outer.offset_left = 120
	outer.offset_right = 120 + 760
	outer.offset_top = 70
	outer.offset_bottom = -60
	outer.add_theme_constant_override("separation", 14)
	page.add_child(outer)
	_title(outer, "설정", "")
	(outer.get_child(outer.get_child_count() - 1) as Control).custom_minimum_size = Vector2(0, 8)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	_section(grid, "조작")
	_slider(grid, "마우스 감도", "mouse_sensitivity", 0.2, 3.0, 0.05, "%.2f배")
	_check(grid, "상하 반전", "invert_y")
	_section(grid, "화면")
	_check(grid, "전체 화면", "fullscreen")
	var sizes: Array[String] = []
	for s in Settings.WINDOW_SIZES:
		sizes.append("%d × %d" % [s.x, s.y])
	_option(grid, "창 크기", "window_size", sizes)
	_check(grid, "수직 동기화", "vsync")
	_option(grid, "그래픽 품질", "quality", Settings.QUALITY_NAMES)
	_slider(grid, "시야각", "fov", 60.0, 100.0, 1.0, "%d°")
	_slider(grid, "밝기", "brightness", 0.6, 1.4, 0.05, "%.2f")
	_section(grid, "소리")
	_slider(grid, "전체 음량", "volume_master", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(grid, "효과음", "volume_sfx", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_section(grid, "편의")
	_option(grid, "힌트", "hints", Settings.HINT_NAMES)
	_check(grid, "걸을 때 화면 흔들림", "head_bob")
	_check(grid, "필름 그레인", "film_grain")
	_check(grid, "화면 가운데 점 항상 표시", "crosshair")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	outer.add_child(row)
	_button(row, "뒤로", func() -> void: _open(_back_to))
	_button(row, "기본값으로", func() -> void:
		Settings.reset()
		_refresh_settings())
	return page


var _setting_controls := {}


func _section(grid: GridContainer, text: String) -> void:
	var a := Label.new()
	a.text = text
	a.add_theme_color_override("font_color", ACCENT)
	a.add_theme_font_size_override("font_size", 16)
	var b := Control.new()
	grid.add_child(a)
	grid.add_child(b)


func _row_label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.custom_minimum_size = Vector2(260, 0)
	grid.add_child(l)


func _slider(grid: GridContainer, text: String, key: String, lo: float, hi: float, step: float, fmt: String, show_scale := 1.0) -> void:
	_row_label(grid, text)
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(300, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size = Vector2(80, 0)
	val.add_theme_color_override("font_color", TEXT_DIM)
	val.add_theme_font_size_override("font_size", 18)
	var update := func(v: float) -> void:
		val.text = fmt % (v * show_scale)
	s.value = float(Settings.get_value(key))
	update.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		update.call(v)
		Settings.set_value(key, v))
	h.add_child(s)
	h.add_child(val)
	grid.add_child(h)
	_setting_controls[key] = s


func _check(grid: GridContainer, text: String, key: String) -> void:
	_row_label(grid, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key))
	# 꺼진 스위치는 어두운 배경에서 잘 안 보이므로 글씨로도 알려 준다
	c.text = "켬" if c.button_pressed else "끔"
	c.add_theme_color_override("font_color", TEXT_DIM)
	c.add_theme_color_override("font_pressed_color", ACCENT)
	c.add_theme_color_override("font_hover_pressed_color", ACCENT)
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.toggled.connect(func(on: bool) -> void:
		c.text = "켬" if on else "끔"
		Settings.set_value(key, on))
	grid.add_child(c)
	_setting_controls[key] = c


func _option(grid: GridContainer, text: String, key: String, items: Array) -> void:
	_row_label(grid, text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = int(Settings.get_value(key))
	o.custom_minimum_size = Vector2(220, 0)
	o.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, i))
	grid.add_child(o)
	_setting_controls[key] = o


func _refresh_settings() -> void:
	for key in _setting_controls:
		var c: Control = _setting_controls[key]
		if c is HSlider:
			(c as HSlider).value = float(Settings.get_value(key))
		elif c is CheckButton:
			var on := bool(Settings.get_value(key))
			(c as CheckButton).set_pressed_no_signal(on)
			(c as CheckButton).text = "켬" if on else "끔"
		elif c is OptionButton:
			(c as OptionButton).selected = int(Settings.get_value(key))
