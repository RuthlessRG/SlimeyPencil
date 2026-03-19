extends CanvasLayer

# ============================================================
#  BossBuffBar.gd
#  Displays active buffs/debuffs as small icons below the
#  player's HP/MP/XP widget. Each icon shows a countdown and
#  blinks when <= 5 seconds remain. Auto-removes on expiry.
#
#  API (called by BossArenaPlayer):
#    add_buff(data: Dictionary)       — data keys: id, icon, label, duration, color
#    update_buff(id: String, remaining: float)
#    remove_buff(id: String)
# ============================================================

const ICON_SZ   : float = 36.0
const ICON_PAD  : float = 6.0
const BLINK_THRESHOLD : float = 5.0

var _player     : Node  = null
var _container  : Control = null   # the row of buff icons
var _buffs      : Dictionary = {}  # id -> { data, icon_ctrl, timer_lbl, remaining }
var _aura_t     : float = 0.0      # drives blink animation

func init(player: Node) -> void:
	layer   = 11   # just above HUD (10), below windows (12+)
	_player = player
	_build_container()

func _build_container() -> void:
	_container               = Control.new()
	_container.size          = Vector2(300, ICON_SZ + 20)
	_container.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	# Position is updated every frame in _process to follow the player frame

func _process(delta: float) -> void:
	_aura_t += delta
	# Track the player frame and sit directly below it
	if is_instance_valid(_player):
		# Walk up to the scene root to find _player_frame
		var scene = _player.get_parent()
		if scene:
			scene = scene.get_parent()  # WorldLayer -> TheedScene/SpaceportScene
		if scene:
			var pf = scene.get("_player_frame")
			if pf and is_instance_valid(pf):
				_container.position = pf.position + Vector2(0, pf.size.y + 4)
	# Redraw blinking icons
	for id in _buffs:
		var b = _buffs[id]
		if b.remaining <= BLINK_THRESHOLD:
			var ic = b.get("icon_ctrl")
			if ic: ic.queue_redraw()

# ── Public API ────────────────────────────────────────────────
func add_buff(data: Dictionary) -> void:
	var id = data.get("id", "")
	if id == "": return
	# Remove existing if re-applied
	if _buffs.has(id):
		remove_buff(id)

	# Outer panel
	var slot_idx = _buffs.size()
	var panel          = Panel.new()
	panel.size         = Vector2(ICON_SZ, ICON_SZ + 16)
	panel.position     = Vector2(slot_idx * (ICON_SZ + ICON_PAD), 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty            = StyleBoxFlat.new()
	sty.bg_color       = Color(0.06, 0.06, 0.12, 0.88)
	sty.border_color   = data.get("color", Color(0.70, 0.70, 0.80))
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", sty)
	_container.add_child(panel)

	# Icon draw area
	var icon_ctrl          = Control.new()
	icon_ctrl.size         = Vector2(ICON_SZ, ICON_SZ)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_ctrl.set_script(_icon_draw_script(
		data.get("icon", ""),
		data.get("color", Color(0.35, 0.80, 1.00))
	))
	panel.add_child(icon_ctrl)

	# Countdown label
	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.size         = Vector2(ICON_SZ, 14)
	lbl.position     = Vector2(0, ICON_SZ + 1)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 1.00))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text         = "%ds" % int(ceil(data.get("duration", 0.0)))
	panel.add_child(lbl)

	_buffs[id] = {
		"data":      data,
		"panel":     panel,
		"icon_ctrl": icon_ctrl,
		"timer_lbl": lbl,
		"remaining": data.get("duration", 0.0),
	}
	_reflow()

func update_buff(id: String, remaining: float) -> void:
	if not _buffs.has(id): return
	var b = _buffs[id]
	b.remaining = remaining
	var lbl = b.get("timer_lbl")
	if lbl:
		lbl.text = "%ds" % int(ceil(remaining))
		# Blink: turn red when low
		if remaining <= BLINK_THRESHOLD:
			var blink_alpha = 0.5 + sin(_aura_t * 8.0) * 0.5   # fast pulse 0–1
			lbl.add_theme_color_override("font_color",
				Color(1.0, 0.30, 0.30, blink_alpha))
		else:
			lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 1.00))
	# Also blink the icon border
	var panel = b.get("panel")
	if panel and remaining <= BLINK_THRESHOLD:
		var blink = 0.4 + sin(_aura_t * 8.0) * 0.4
		var sty = StyleBoxFlat.new()
		sty.bg_color     = Color(0.06, 0.06, 0.12, 0.88)
		sty.border_color = Color(1.0, 0.35, 0.35, blink)
		sty.set_border_width_all(2)
		sty.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", sty)

func remove_buff(id: String) -> void:
	if not _buffs.has(id): return
	var b = _buffs[id]
	var panel = b.get("panel")
	if panel and is_instance_valid(panel):
		panel.queue_free()
	_buffs.erase(id)
	_reflow()

func _reflow() -> void:
	# Re-index panel positions so there are no gaps after removal
	var idx = 0
	for id in _buffs:
		var b     = _buffs[id]
		var panel = b.get("panel")
		if panel and is_instance_valid(panel):
			panel.position = Vector2(idx * (ICON_SZ + ICON_PAD), 0)
			idx += 1

# ── Icon draw scripts — same art as BossSkillWindow ──────────
func _icon_draw_script(icon_id: String, col: Color) -> GDScript:
	var cr = "%.3f" % col.r
	var cg = "%.3f" % col.g
	var cb = "%.3f" % col.b
	var src = """
extends Control
var _t : float = 0.0
func _process(d): _t += d; queue_redraw()
func _draw():
\tvar cx=size.x*0.5; var cy=size.y*0.5; var _c=Vector2(cx,cy)
\tif has_method("_draw_ICONID"): _draw_ICONID(cx,cy)
\telse: _draw_generic(cx,cy)
func _draw_sprint(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.6+sin(_t*4.0)*0.2
\tdraw_circle(c,15.0,Color(0.10,0.40,0.90,0.22))
\tfor i in 4:
\t\tvar fr=float(i)/4.0; var x=cx-9.0+fr*18.0; var sp=1.0-fr*0.3
\t\tvar yo=sin(_t*6.0*sp+fr*2.1)*3.0
\t\tdraw_line(Vector2(x,cy+yo-5),Vector2(x+5.0*sp,cy+yo+5),Color(CRR,CGG,CBB,p),1.8)
\tdraw_colored_polygon(PackedVector2Array([c+Vector2(4,-4),c+Vector2(10,0),c+Vector2(4,4)]),Color(1,1,1,p))
func _draw_sensu(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.7+sin(_t*2.5)*0.18
\tdraw_circle(c,15.0,Color(0.05,0.30,0.10,0.28))
\tvar pts=PackedVector2Array()
\tfor i in 10:
\t\tvar a=float(i)/10.0*6.2832; var r=8.0+sin(a*2.0+_t*1.8)*2.0
\t\tpts.append(c+Vector2(cos(a)*r,sin(a)*r))
\tdraw_colored_polygon(pts,Color(0.15,0.75,0.25,p*0.55))
\tdraw_circle(c,4.0,Color(CRR,CGG,CBB,p))
func _draw_triple(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.65+sin(_t*5.0)*0.20
\tdraw_circle(c,15.0,Color(0.50,0.10,0.10,0.22))
\tfor i in 3:
\t\tvar xoff=float(i-1)*7.0; var oc=c+Vector2(xoff,0)
\t\tvar tip=oc+Vector2(0,-9); var bl=oc+Vector2(-3,3); var br=oc+Vector2(3,3)
\t\tdraw_colored_polygon(PackedVector2Array([tip,bl,br]),Color(CRR,CGG,CBB,p))
func _draw_knockdown(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.7+sin(_t*3.0)*0.20
\tdraw_circle(c,15.0,Color(0.60,0.20,0.05,0.25))
\tdraw_line(Vector2(cx-11,cy+4),Vector2(cx+11,cy+4),Color(CRR,CGG,CBB,p),2.5)
\tdraw_circle(Vector2(cx-6,cy+4),3.5,Color(CRR,CGG,CBB,p*0.7))
\tdraw_line(Vector2(cx-6,cy+4),Vector2(cx-6,cy-5),Color(CRR,CGG,CBB,p),2.0)
\tdraw_line(Vector2(cx-6,cy-1),Vector2(cx-1,cy+2),Color(CRR,CGG,CBB,p),1.8)
func _draw_dizzy(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.65+sin(_t*4.0)*0.22
\tdraw_circle(c,15.0,Color(0.55,0.45,0.05,0.22))
\tfor i in 3:
\t\tvar a=_t*3.0+float(i)*2.094; var r=8.0
\t\tvar sp=Vector2(cos(a)*r+cx,sin(a)*r+cy)
\t\tdraw_line(sp+Vector2(-3,-3),sp+Vector2(3,3),Color(CRR,CGG,CBB,p),2.0)
\t\tdraw_line(sp+Vector2(3,-3),sp+Vector2(-3,3),Color(CRR,CGG,CBB,p),2.0)
func _draw_stun(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.70+sin(_t*5.0)*0.20
\tdraw_circle(c,15.0,Color(0.55,0.55,0.05,0.22))
\tvar pts=PackedVector2Array([Vector2(cx-3,cy-12),Vector2(cx+5,cy-2),Vector2(cx-1,cy-2),Vector2(cx+3,cy+10),Vector2(cx-5,cy+0),Vector2(cx+1,cy+0)])
\tdraw_colored_polygon(pts,Color(CRR,CGG,CBB,p))
func _draw_blind(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.65+sin(_t*2.5)*0.18
\tdraw_circle(c,15.0,Color(0.10,0.10,0.40,0.25))
\tdraw_arc(c,9.0,0.4,2.74,12,Color(CRR,CGG,CBB,p),2.0)
\tdraw_circle(c,3.5,Color(CRR,CGG,CBB,p*0.8))
\tdraw_line(Vector2(cx-10,cy-8),Vector2(cx+10,cy+8),Color(0.9,0.2,0.2,p),2.5)
func _draw_intimidate(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.70+sin(_t*3.5)*0.22
\tdraw_circle(c,15.0,Color(0.50,0.05,0.40,0.22))
\tdraw_rect(Rect2(cx-2.5,cy-12,5,9),Color(CRR,CGG,CBB,p))
\tdraw_circle(Vector2(cx,cy+5),3.0,Color(CRR,CGG,CBB,p))
func _draw_generic(cx,cy):
\tvar c=Vector2(cx,cy); var p=0.65+sin(_t*3.0)*0.20
\tdraw_circle(c,14.0,Color(CRR,CGG,CBB,0.18))
\tdraw_arc(c,9.0,0.0,6.2832,20,Color(CRR,CGG,CBB,p),2.0)
"""
	src = src.replace("ICONID", icon_id)
	src = src.replace("CRR", cr).replace("CGG", cg).replace("CBB", cb)
	var s = GDScript.new(); s.source_code = src; s.reload(); return s
