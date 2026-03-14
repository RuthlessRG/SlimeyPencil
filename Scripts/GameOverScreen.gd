extends CanvasLayer

# ============================================================
#  GameOverScreen.gd — Beyond the Veil | Boss Arena
#  Spawned by BossArenaScene.on_player_died().
# ============================================================

const FADE_IN_TIME : float = 1.0
const BUTTON_DELAY : float = 1.2

var _t             : float   = 0.0
var _overlay       : ColorRect = null
var _title_lbl     : Label    = null
var _sub_lbl       : Label    = null
var _btn_again     : Button   = null
var _btn_quit      : Button   = null
var _buttons_shown : bool     = false

func _ready() -> void:
	layer = 18
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	_overlay          = ColorRect.new()
	_overlay.color    = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.size     = vp
	_overlay.position = Vector2.ZERO
	add_child(_overlay)

	_title_lbl = Label.new()
	_title_lbl.text = "GAME OVER"
	_title_lbl.add_theme_font_size_override("font_size", 72)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.size     = Vector2(vp.x, 90)
	_title_lbl.position = Vector2(0.0, vp.y * 0.38)
	_title_lbl.modulate.a = 0.0
	add_child(_title_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.text = "— YOU HAVE FALLEN —"
	_sub_lbl.add_theme_font_size_override("font_size", 18)
	_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 0.85))
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.size     = Vector2(vp.x, 28)
	_sub_lbl.position = Vector2(0.0, vp.y * 0.38 + 96)
	_sub_lbl.modulate.a = 0.0
	add_child(_sub_lbl)

	var btn_w  : float = 240.0
	var btn_h  : float = 52.0
	var btn_x  : float = vp.x * 0.5 - btn_w * 0.5
	var btn_y0 : float = vp.y * 0.60

	_btn_again = _make_button("PLAY AGAIN", btn_x, btn_y0, btn_w, btn_h)
	_btn_again.pressed.connect(_on_play_again)

	_btn_quit = _make_button("QUIT", btn_x, btn_y0 + btn_h + 16.0, btn_w, btn_h)
	_btn_quit.pressed.connect(_on_quit)

func _make_button(label: String, x: float, y: float, w: float, h: float) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.position = Vector2(x, y)
	btn.size     = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 18)
	btn.modulate.a = 0.0
	btn.disabled   = true
	add_child(btn)
	return btn

func _process(delta: float) -> void:
	_t += delta

	var fade = clampf(_t / FADE_IN_TIME, 0.0, 1.0)
	_overlay.color.a      = fade * 0.78
	_title_lbl.modulate.a = fade
	_sub_lbl.modulate.a   = fade

	if _buttons_shown or _t >= BUTTON_DELAY:
		_buttons_shown = true
		var btn_fade = clampf((_t - BUTTON_DELAY) / 0.4, 0.0, 1.0)
		_btn_again.modulate.a = btn_fade
		_btn_quit.modulate.a  = btn_fade
		if btn_fade >= 1.0:
			_btn_again.disabled = false
			_btn_quit.disabled  = false

func _on_play_again() -> void:
	get_tree().change_scene_to_file("res://Scenes/boss_arena.tscn")

func _on_quit() -> void:
	get_tree().quit()
