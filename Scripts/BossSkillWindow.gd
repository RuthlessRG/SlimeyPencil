extends CanvasLayer

# ============================================================
#  BossSkillWindow.gd  — P to open/close
#  Click-drag an icon directly onto the action bar slots.
#  This node owns the ghost icon and all drag logic.
# ============================================================

const BASE_SKILLS : Array = [
	{ "id":"sprint",        "name":"Sprint",        "icon":"sprint", "req_level":1, "cooldown":60.0, "desc":"+30% move speed for 15s",      "detail":"60s cooldown" },
	{ "id":"sensu_bean",    "name":"Sensu Bean",     "icon":"sensu",  "req_level":3, "cooldown":60.0, "desc":"Restore full HP & MP over 10s", "detail":"60s cooldown" },
	{ "id":"triple_strike", "name":"Triple Strike",  "icon":"triple", "req_level":5, "cooldown":0.0,  "desc":"Attack 3 times instantly",      "detail":"No cooldown"  },
]

var SKILLS : Array = []

func _build_skills_list() -> void:
	SKILLS = BASE_SKILLS.duplicate(true)
	if _player == null: return
	var learned = _player.get("learned_boxes") as Array
	if learned == null: return
	for box_id in learned:
		var box = ProfessionData.find_box(box_id)
		if box.is_empty(): continue
		var abilities = box.get("abilities", [])
		for ab_id in abilities:
			# Don't add duplicates
			var exists = false
			for s in SKILLS:
				if s.id == ab_id: exists = true; break
			if exists: continue
			SKILLS.append({
				"id": ab_id,
				"name": ab_id.replace("_", " ").capitalize(),
				"icon": ab_id,
				"req_level": 1,
				"cooldown": 15.0,
				"desc": "Unlocked from " + box.name,
				"detail": "Profession ability",
			})

const ICON_SZ  : float = 52.0
const ROW_H    : float = 72.0
const HDR_H    : float = 54.0
const WIN_W    : float = 440.0

var _player        : Node    = null
var _panel         : Panel   = null

# Window drag
var _win_dragging  : bool    = false

# Skill icon drag — ghost follows mouse, polled every frame
var _dragging      : bool    = false
var _drag_skill    : Dictionary = {}
var _ghost         : Control = null

func init(player: Node) -> void:
	layer   = 15
	_player = player
	_build_skills_list()
	_build_ui()
	_build_ghost()

# ── Ghost ──────────────────────────────────────────────────────
func _build_ghost() -> void:
	_ghost              = Control.new()
	_ghost.size         = Vector2(ICON_SZ, ICON_SZ)
	_ghost.visible      = false
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index      = 200
	add_child(_ghost)

func _set_ghost_icon(icon_id: String) -> void:
	for ch in _ghost.get_children():
		ch.queue_free()
	var ic = Control.new()
	ic.size         = Vector2(ICON_SZ, ICON_SZ)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_script(_icon_script(icon_id, false))
	_ghost.add_child(ic)

# ── Per-frame: move ghost + poll for drop ─────────────────────
func _process(_delta: float) -> void:
	if not _dragging:
		return
	var mp = get_viewport().get_mouse_position()
	_ghost.position = mp - Vector2(ICON_SZ * 0.5, ICON_SZ * 0.5)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_do_drop(mp)

func _do_drop(mp: Vector2) -> void:
	_dragging      = false
	_ghost.visible = false
	var bar = _player.get_node_or_null("ActionBar") if _player else null
	if bar and bar.has_method("try_drop_skill"):
		bar.call("try_drop_skill", _drag_skill, mp)
	_drag_skill = {}

# ── Icon mouse-down starts drag ───────────────────────────────
func _on_icon_pressed(skill: Dictionary) -> void:
	_drag_skill = skill
	_set_ghost_icon(skill.get("icon", ""))
	_ghost.visible = true
	_dragging      = true

# ── Build UI ───────────────────────────────────────────────────
func _build_ui() -> void:
	var vp    = get_viewport().get_visible_rect().size
	var win_h = HDR_H + SKILLS.size() * ROW_H + 44.0
	var win_x = vp.x * 0.5 - WIN_W * 0.5
	var win_y = vp.y * 0.5 - win_h * 0.5 - 30.0

	_panel              = Panel.new()
	_panel.position     = Vector2(win_x, win_y)
	_panel.size         = Vector2(WIN_W, win_h)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sty         = StyleBoxFlat.new()
	sty.bg_color    = Color(0.03, 0.04, 0.10, 0.95)
	sty.set_border_width_all(0)
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)
	_panel.gui_input.connect(_on_panel_input)

	_crect(_panel, Vector2(WIN_W, 5),          Vector2(0, 0),          Color(0.55,0.30,1.00,0.92))
	_crect(_panel, Vector2(WIN_W, 4),          Vector2(0, win_h-4),    Color(0.55,0.30,1.00,0.45))

	_lbl(_panel, "S K I L L S",                        Vector2(0,10),  WIN_W, 15, Color(0.75,0.55,1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl(_panel, "DRAG SKILL ICONS ONTO THE ACTION BAR", Vector2(0,32), WIN_W,  9, Color(0.50,0.38,0.75,0.80), HORIZONTAL_ALIGNMENT_CENTER)
	_crect(_panel, Vector2(WIN_W-20,1), Vector2(10,HDR_H-1), Color(0.45,0.25,0.90,0.35))

	for i in SKILLS.size():
		_build_row(i, HDR_H + i * ROW_H)
		if i < SKILLS.size()-1:
			_crect(_panel, Vector2(WIN_W-20,1), Vector2(10, HDR_H+(i+1)*ROW_H-1), Color(0.45,0.25,0.90,0.18))

	_crect(_panel, Vector2(WIN_W-20,1), Vector2(10, HDR_H+SKILLS.size()*ROW_H), Color(0.45,0.25,0.90,0.35))

	var btn         = Button.new()
	btn.text        = "CLOSE  [P]"
	btn.size        = Vector2(100,26)
	btn.position    = Vector2(WIN_W-114, HDR_H+SKILLS.size()*ROW_H+8)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.75,0.55,1.0))
	var bs          = StyleBoxFlat.new()
	bs.bg_color     = Color(0.06,0.04,0.14)
	bs.border_color = Color(0.55,0.30,1.00,0.80)
	bs.set_border_width_all(1); bs.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bs)
	btn.pressed.connect(queue_free)
	_panel.add_child(btn)

func _build_row(idx: int, row_y: float) -> void:
	var skill  = SKILLS[idx]
	var plevel = (_player.get("level") as int) if _player else 1
	var locked = plevel < skill.get("req_level", 1)
	var pad    = 10.0

	# Icon container — MOUSE_FILTER_STOP so it receives mouse-down
	var icon_bg          = Panel.new()
	icon_bg.position     = Vector2(pad, row_y + (ROW_H-ICON_SZ)*0.5)
	icon_bg.size         = Vector2(ICON_SZ, ICON_SZ)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var ibs              = StyleBoxFlat.new()
	ibs.bg_color         = Color(0.08,0.06,0.18,0.92)
	ibs.border_color     = Color(0.45,0.25,0.90,0.60) if not locked else Color(0.3,0.3,0.3,0.4)
	ibs.set_border_width_all(1); ibs.set_corner_radius_all(3)
	icon_bg.add_theme_stylebox_override("panel", ibs)
	_panel.add_child(icon_bg)

	var ic          = Control.new()
	ic.size         = Vector2(ICON_SZ, ICON_SZ)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_script(_icon_script(skill.get("icon",""), locked))
	icon_bg.add_child(ic)

	if not locked:
		icon_bg.mouse_default_cursor_shape = Control.CURSOR_DRAG
		icon_bg.gui_input.connect(_on_icon_gui_input.bind(skill))

	# Text
	var nc = Color(0.70,0.50,1.00) if not locked else Color(0.40,0.40,0.45)
	_lbl(_panel, skill.get("name",""),                               Vector2(pad+ICON_SZ+10,row_y+8),  220,14,nc)
	var rc = Color(0.40,0.75,0.40) if not locked else Color(1.0,0.35,0.35)
	_lbl(_panel, "Req. Level %d" % skill.get("req_level",1),          Vector2(pad+ICON_SZ+12,row_y+28), 160, 9,rc)
	_lbl(_panel, skill.get("desc","")+"  ·  "+skill.get("detail",""), Vector2(pad+ICON_SZ+10,row_y+44), 280,11,
		Color(0.60,0.75,0.60) if not locked else Color(0.35,0.35,0.38))

func _on_icon_gui_input(event: InputEvent, skill: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_icon_pressed(skill)

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y <= HDR_H:
			_win_dragging = true
		else:
			_win_dragging = false
	elif event is InputEventMouseMotion and _win_dragging:
		var np = _panel.position + event.relative
		var vp = get_viewport().get_visible_rect().size
		np.x   = clampf(np.x, 0.0, vp.x - _panel.size.x)
		np.y   = clampf(np.y, 0.0, vp.y - _panel.size.y)
		_panel.position = np

# ── Helpers ────────────────────────────────────────────────────
func _crect(p:Control, sz:Vector2, pos:Vector2, col:Color) -> void:
	var r=ColorRect.new(); r.size=sz; r.position=pos; r.color=col
	r.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(r)

func _lbl(p:Control, txt:String, pos:Vector2, w:float, sz:int, col:Color,
		align:int=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l=Label.new(); l.text=txt
	l.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	l.add_theme_font_size_override("font_size",sz)
	l.add_theme_color_override("font_color",col)
	l.position=pos; l.size=Vector2(w,sz+6)
	l.horizontal_alignment=align
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(l)

# ── Icon draw script ───────────────────────────────────────────
func _icon_script(icon_id:String, locked:bool) -> GDScript:
	var src = """
extends Control
var _t:float=0.0
var _locked:bool=LOCKVAL
func _process(d): _t+=d; queue_redraw()
func _draw():
\tvar cx=size.x*0.5;var cy=size.y*0.5;var c=Vector2(cx,cy)
\tif _locked:
\t\tdraw_circle(c,18.0,Color(0.15,0.15,0.20))
\t\tdraw_line(c+Vector2(-8,-8),c+Vector2(8,8),Color(0.4,0.4,0.4,0.8),2.0)
\t\tdraw_line(c+Vector2(8,-8),c+Vector2(-8,8),Color(0.4,0.4,0.4,0.8),2.0)
\t\treturn
\t_draw_ICONID(cx,cy)
func _draw_sprint(cx,cy):
\tvar c=Vector2(cx,cy);var p=0.6+sin(_t*4.0)*0.2
\tdraw_circle(c,18.0,Color(0.10,0.40,0.90,0.25))
\tfor i in 5:
\t\tvar fr=float(i)/5.0;var x=cx-12.0+fr*24.0;var sp=1.0-fr*0.35
\t\tvar yo=sin(_t*6.0*sp+fr*2.1)*4.0
\t\tdraw_line(Vector2(x,cy+yo-7),Vector2(x+6.0*sp,cy+yo+7),Color(0.35,0.80,1.00,p),2.0)
\tdraw_colored_polygon(PackedVector2Array([c+Vector2(6,-5),c+Vector2(14,0),c+Vector2(6,5)]),Color(1,1,1,p))
func _draw_sensu(cx,cy):
\tvar c=Vector2(cx,cy);var p=0.7+sin(_t*2.5)*0.18
\tdraw_circle(c,18.0,Color(0.05,0.30,0.10,0.30))
\tvar pts=PackedVector2Array()
\tfor i in 12:
\t\tvar a=float(i)/12.0*6.2832;var r=10.0+sin(a*2.0+_t*1.8)*3.0
\t\tpts.append(c+Vector2(cos(a)*r,sin(a)*r))
\tdraw_colored_polygon(pts,Color(0.15,0.75,0.25,p*0.55))
\tdraw_circle(c,5.5,Color(0.55,1.0,0.55,p));draw_circle(c,3.0,Color(1,1,1,p*0.70))
func _draw_triple(cx,cy):
\tvar c=Vector2(cx,cy);var p=0.65+sin(_t*5.0)*0.20
\tdraw_circle(c,18.0,Color(0.50,0.10,0.10,0.25))
\tfor i in 3:
\t\tvar xoff=float(i-1)*10.0
\t\tvar oc=c+Vector2(xoff,0)
\t\tvar tip=oc+Vector2(0,-12);var bl=oc+Vector2(-4,4);var br=oc+Vector2(4,4)
\t\tdraw_colored_polygon(PackedVector2Array([tip,bl,br]),Color(1.0,0.35,0.35,p))
\t\tdraw_circle(oc+Vector2(0,5),2.5,Color(1.0,0.60,0.20,p))
"""
	src = src.replace("LOCKVAL", "true" if locked else "false")
	# Only replace ICONID if we have a draw function for it, otherwise use generic
	if icon_id in ["sprint", "sensu", "triple"]:
		src = src.replace("ICONID", icon_id)
	else:
		# Replace the _draw_ICONID call with a generic icon draw
		src = src.replace("\t_draw_ICONID(cx,cy)", "\t_draw_generic(cx,cy)")
		src += """
func _draw_generic(cx,cy):
\tvar c=Vector2(cx,cy);var p=0.6+sin(_t*3.0)*0.2
\tdraw_circle(c,18.0,Color(0.20,0.50,0.80,0.3))
\tdraw_circle(c,12.0,Color(0.30,0.65,0.95,p*0.5))
\tdraw_circle(c,3.0,Color(0.50,0.85,1.00,p))
\tfor i in 4:
\t\tvar a=float(i)/4.0*TAU+_t*1.5
\t\tvar r=10.0
\t\tdraw_circle(c+Vector2(cos(a)*r,sin(a)*r),2.0,Color(0.40,0.75,1.00,p*0.6))
"""
	var s=GDScript.new(); s.source_code=src; s.reload(); return s
