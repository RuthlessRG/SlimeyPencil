extends CanvasLayer

# ============================================================
#  BossCinematic.gd — letterbox + boss name reveal when a
#  boss first aggros a player.
#  Spawned by BossArenaScene.trigger_boss_cinematic().
# ============================================================

const SLIDE_IN  : float = 0.35
const HOLD_TIME : float = 1.80
const SLIDE_OUT : float = 0.35
const BAR_H     : float = 72.0

var _t         : float = 0.0
var _boss_name : String = ""

var _top_bar  : ColorRect = null
var _bot_bar  : ColorRect = null
var _name_lbl : Label     = null
var _sub_lbl  : Label     = null

func init(boss_name: String) -> void:
	layer      = 15
	_boss_name = boss_name
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	_top_bar          = ColorRect.new()
	_top_bar.color    = Color(0.0, 0.0, 0.0, 1.0)
	_top_bar.size     = Vector2(vp.x, BAR_H)
	_top_bar.position = Vector2(0.0, -BAR_H)
	add_child(_top_bar)

	_bot_bar          = ColorRect.new()
	_bot_bar.color    = Color(0.0, 0.0, 0.0, 1.0)
	_bot_bar.size     = Vector2(vp.x, BAR_H)
	_bot_bar.position = Vector2(0.0, vp.y)
	add_child(_bot_bar)

	# Boss name — centred vertically on screen
	_name_lbl = Label.new()
	_name_lbl.text = _boss_name.to_upper()
	_name_lbl.add_theme_font_size_override("font_size", 52)
	_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.82))
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.size     = Vector2(vp.x, 64)
	_name_lbl.position = Vector2(0.0, vp.y * 0.5 - 42)
	_name_lbl.modulate.a = 0.0
	add_child(_name_lbl)

	# Subtitle
	_sub_lbl = Label.new()
	_sub_lbl.text = "— BOSS ENCOUNTERED —"
	_sub_lbl.add_theme_font_size_override("font_size", 16)
	_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 0.85))
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.size     = Vector2(vp.x, 24)
	_sub_lbl.position = Vector2(0.0, vp.y * 0.5 + 26)
	_sub_lbl.modulate.a = 0.0
	add_child(_sub_lbl)

func _process(delta: float) -> void:
	_t += delta
	var vp = get_viewport().get_visible_rect().size

	if _t < SLIDE_IN:
		var p = _t / SLIDE_IN
		_top_bar.position.y = lerpf(-BAR_H, 0.0, p)
		_bot_bar.position.y = lerpf(vp.y, vp.y - BAR_H, p)
		_name_lbl.modulate.a = 0.0
		_sub_lbl.modulate.a  = 0.0

	elif _t < SLIDE_IN + HOLD_TIME:
		_top_bar.position.y = 0.0
		_bot_bar.position.y = vp.y - BAR_H
		var hold_p = (_t - SLIDE_IN) / HOLD_TIME
		# Fade label in quickly, hold, then fade out
		var lbl_a : float
		if hold_p < 0.15:
			lbl_a = hold_p / 0.15
		elif hold_p > 0.80:
			lbl_a = 1.0 - (hold_p - 0.80) / 0.20
		else:
			lbl_a = 1.0
		_name_lbl.modulate.a = lbl_a
		_sub_lbl.modulate.a  = lbl_a

	elif _t < SLIDE_IN + HOLD_TIME + SLIDE_OUT:
		var p = (_t - SLIDE_IN - HOLD_TIME) / SLIDE_OUT
		_top_bar.position.y  = lerpf(0.0, -BAR_H, p)
		_bot_bar.position.y  = lerpf(vp.y - BAR_H, vp.y, p)
		_name_lbl.modulate.a = 0.0
		_sub_lbl.modulate.a  = 0.0

	else:
		queue_free()
