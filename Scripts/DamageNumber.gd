extends Node2D

# ============================================================
#  DamageNumber.gd — floating hit number that rises and fades
# ============================================================

const DURATION   = 1.4    # seconds on screen
const RISE_SPEED = 38.0   # pixels per second upward
const FONT_SIZE  = 20     # 40% bigger than original 14

var _text  : String = ""
var _color : Color  = Color.WHITE
var _timer : float  = 0.0
var _font  : Font   = null

func init(amount: float, col: Color) -> void:
	_text  = str(int(amount))
	_color = col
	var loaded = load("res://Assets/Fonts/Roboto/static/Roboto-Black.ttf")
	_font = loaded if loaded else ThemeDB.fallback_font

func init_text(text: String, col: Color) -> void:
	_text  = text
	_color = col
	var loaded = load("res://Assets/Fonts/Roboto/static/Roboto-Black.ttf")
	_font = loaded if loaded else ThemeDB.fallback_font

func _process(delta: float) -> void:
	_timer     += delta
	position.y -= RISE_SPEED * delta
	if _timer >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t     = _timer / DURATION
	# Stay fully opaque for first 60%, then fade out
	var alpha = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
	# Small pop on spawn
	var scale_factor = 1.0 + clampf(0.35 - t * 1.5, 0.0, 0.35)
	var size = int(FONT_SIZE * scale_factor)

	var font = _font if _font else load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

	var _ct_sc = get_canvas_transform().get_scale()
	var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)

	# Drop shadow
	var _rend_sz_shadow = maxi(1, int(round(size * _ct_sc.x)))
	draw_set_transform(Vector2(1, 1), 0.0, _inv)
	draw_string(font, Vector2.ZERO, _text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz_shadow,
		Color(0.0, 0.0, 0.0, alpha * 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Main number
	var _rend_sz_main = maxi(1, int(round(size * _ct_sc.x)))
	draw_set_transform(Vector2(0, 0), 0.0, _inv)
	draw_string(font, Vector2.ZERO, _text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz_main,
		Color(_color.r, _color.g, _color.b, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
