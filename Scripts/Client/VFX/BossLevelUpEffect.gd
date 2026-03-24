extends CanvasLayer

# ============================================================
#  BossLevelUpEffect.gd — Golden "LEVEL UP!" cinematic
#  Spawned by BossArenaScene.trigger_level_up()
# ============================================================

const SLIDE_IN  : float = 0.30
const HOLD_TIME : float = 2.20
const SLIDE_OUT : float = 0.35
const BAR_H     : float = 68.0

var _t         : float = 0.0
var _new_level : int   = 2

var _top_bar   : ColorRect = null
var _bot_bar   : ColorRect = null
var _title_lbl : Label     = null
var _sub_lbl   : Label     = null
var _pts_lbl   : Label     = null

func init(new_level: int) -> void:
	layer      = 16   # above boss cinematic (15) if they somehow overlap
	_new_level = new_level
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	_top_bar          = ColorRect.new()
	_top_bar.color    = Color(0.08, 0.06, 0.0, 1.0)
	_top_bar.size     = Vector2(vp.x, BAR_H)
	_top_bar.position = Vector2(0.0, -BAR_H)
	add_child(_top_bar)

	_bot_bar          = ColorRect.new()
	_bot_bar.color    = Color(0.08, 0.06, 0.0, 1.0)
	_bot_bar.size     = Vector2(vp.x, BAR_H)
	_bot_bar.position = Vector2(0.0, vp.y)
	add_child(_bot_bar)

	# Golden "LEVEL UP!" text
	_title_lbl = Label.new()
	_title_lbl.text = "LEVEL UP!"
	_title_lbl.add_theme_font_size_override("font_size", 58)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.size     = Vector2(vp.x, 72)
	_title_lbl.position = Vector2(0.0, vp.y * 0.5 - 48)
	_title_lbl.modulate.a = 0.0
	add_child(_title_lbl)

	# Level reached
	_sub_lbl = Label.new()
	_sub_lbl.text = "— LEVEL %d —" % _new_level
	_sub_lbl.add_theme_font_size_override("font_size", 18)
	_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 0.90))
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.size     = Vector2(vp.x, 26)
	_sub_lbl.position = Vector2(0.0, vp.y * 0.5 + 28)
	_sub_lbl.modulate.a = 0.0
	add_child(_sub_lbl)

	# Attribute points notice
	_pts_lbl = Label.new()
	_pts_lbl.text = "+ 3 Attribute Points  (press C)"
	_pts_lbl.add_theme_font_size_override("font_size", 14)
	_pts_lbl.add_theme_color_override("font_color", Color(0.8, 0.95, 0.6, 0.90))
	_pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pts_lbl.size     = Vector2(vp.x, 22)
	_pts_lbl.position = Vector2(0.0, vp.y * 0.5 + 58)
	_pts_lbl.modulate.a = 0.0
	add_child(_pts_lbl)

func _process(delta: float) -> void:
	_t += delta
	var vp = get_viewport().get_visible_rect().size

	if _t < SLIDE_IN:
		var p = _t / SLIDE_IN
		_top_bar.position.y = lerpf(-BAR_H, 0.0, p)
		_bot_bar.position.y = lerpf(vp.y, vp.y - BAR_H, p)
		_title_lbl.modulate.a = 0.0
		_sub_lbl.modulate.a   = 0.0
		_pts_lbl.modulate.a   = 0.0

	elif _t < SLIDE_IN + HOLD_TIME:
		_top_bar.position.y = 0.0
		_bot_bar.position.y = vp.y - BAR_H
		var hold_p = (_t - SLIDE_IN) / HOLD_TIME

		# Shimmer: title brightness pulses
		var shimmer = 0.85 + sin(_t * 6.0) * 0.15
		_title_lbl.modulate = Color(shimmer, shimmer * 0.95, shimmer * 0.5, 1.0)

		var lbl_a : float
		if hold_p < 0.12:
			lbl_a = hold_p / 0.12
		elif hold_p > 0.82:
			lbl_a = 1.0 - (hold_p - 0.82) / 0.18
		else:
			lbl_a = 1.0
		_sub_lbl.modulate.a = lbl_a
		_pts_lbl.modulate.a = lbl_a

	elif _t < SLIDE_IN + HOLD_TIME + SLIDE_OUT:
		var p = (_t - SLIDE_IN - HOLD_TIME) / SLIDE_OUT
		_top_bar.position.y   = lerpf(0.0, -BAR_H, p)
		_bot_bar.position.y   = lerpf(vp.y - BAR_H, vp.y, p)
		_title_lbl.modulate.a = 0.0
		_sub_lbl.modulate.a   = 0.0
		_pts_lbl.modulate.a   = 0.0

	else:
		queue_free()
