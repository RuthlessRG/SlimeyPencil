extends Node2D

# ============================================================
#  BossFloatingText.gd — floating combat text
#  Spawned in world space. Drifts upward and fades out.
# ============================================================

const DURATION : float = 1.2
const RISE     : float = 38.0   # pixels to drift upward

var _text  : String = ""
var _color : Color  = Color.WHITE
var _t     : float  = 0.0
var _font  : Font   = null

func init(text: String, color: Color) -> void:
	_text  = text
	_color = color
	_font  = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	position.y -= RISE * delta / DURATION
	queue_redraw()

func _draw() -> void:
	if _font == null or _text == "":
		return
	var p     = _t / DURATION
	var alpha = 1.0 - p * p   # stays bright then drops off fast at end
	var col   = Color(_color.r, _color.g, _color.b, alpha)
	var _ct_sc = get_canvas_transform().get_scale()
	var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
	var _rend_sz = maxi(1, int(round(13 * _ct_sc.x)))
	# Shadow
	draw_set_transform(Vector2(1, 1), 0.0, _inv)
	draw_string(_font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, _rend_sz, Color(0, 0, 0, alpha * 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Text
	draw_set_transform(Vector2(0, 0), 0.0, _inv)
	draw_string(_font, Vector2.ZERO, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, _rend_sz, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
