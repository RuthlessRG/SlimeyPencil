extends Node2D

# ============================================================
#  StartScreen.gd — miniSWG
#  Username / password auth via PlayerData autoload.
#  PLAY button illuminates green only when:
#    • relay is connected  AND  • user is logged in
# ============================================================

var _canvas       : CanvasLayer      = null
var _music        : AudioStreamPlayer = null
var _user_field   : LineEdit         = null
var _pass_field   : LineEdit         = null
var _status_lbl   : Label            = null
var _play_btn     : Button           = null
var _logged_in    : bool             = false

func _ready() -> void:
	_start_music()
	_build_ui()
	Relay.connected_to_relay.connect(_on_relay_connected)
	Relay.relay_error.connect(_on_relay_error)
	Relay.connect_to_relay()

func _start_music() -> void:
	var stream = load("res://Sounds/Music/music_battle.mp3") as AudioStream
	if stream == null: return
	_music            = AudioStreamPlayer.new()
	_music.stream     = stream
	_music.volume_db  = -22.0
	_music.bus        = "Master"
	add_child(_music)
	_music.play()

# ── UI BUILD ──────────────────────────────────────────────────
func _build_ui() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)
	var vp = get_viewport().get_visible_rect().size

	# Background
	var bg   = ColorRect.new()
	bg.size  = vp
	bg.color = Color(0.03, 0.04, 0.10, 1.0)
	_canvas.add_child(bg)

	# Title
	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "miniSWG"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.75, 0.88, 1.00))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(vp.x, 80)
	title.position = Vector2(0, vp.y * 0.12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title)

	var sub = Label.new()
	sub.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	sub.text = "CORONET ONLINE"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.45, 0.65, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size     = Vector2(vp.x, 26)
	sub.position = Vector2(0, vp.y * 0.12 + 84)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(sub)

	# Login panel
	var PW   = 380.0
	var PH   = 320.0
	var panel = Panel.new()
	panel.size     = Vector2(PW, PH)
	panel.position = Vector2(vp.x * 0.5 - PW * 0.5, vp.y * 0.5 - PH * 0.5 + 30)
	var sty        = StyleBoxFlat.new()
	sty.bg_color     = Color(0.05, 0.06, 0.14, 0.96)
	sty.border_color = Color(0.30, 0.55, 0.90, 0.80)
	sty.set_border_width_all(2); sty.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sty)
	_canvas.add_child(panel)

	# Username field
	_user_field = _make_field(panel, "USERNAME", 20, PW)

	# Password field
	_pass_field = _make_field(panel, "PASSWORD", 106, PW)
	_pass_field.secret = true

	# Login / Register buttons (side by side)
	var half_w = (PW - 46) * 0.5
	var login_btn = _action_btn("LOGIN",    Color(0.30, 0.60, 1.00, 0.90), panel)
	login_btn.size     = Vector2(half_w, 36)
	login_btn.position = Vector2(15, 196)
	login_btn.pressed.connect(_on_login)

	var reg_btn = _action_btn("REGISTER", Color(0.25, 0.75, 0.45, 0.90), panel)
	reg_btn.size     = Vector2(half_w, 36)
	reg_btn.position = Vector2(PW * 0.5 + 8, 196)
	reg_btn.pressed.connect(_on_register)

	# Status label
	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_status_lbl.text = "Connecting to server…"
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.25))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.size       = Vector2(PW, 20)
	_status_lbl.position   = Vector2(0, 250)
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_status_lbl)

	# PLAY button
	_play_btn          = Button.new()
	_play_btn.text     = "PLAY"
	_play_btn.size     = Vector2(PW - 30, 46)
	_play_btn.position = Vector2(15, 278)
	_play_btn.add_theme_font_size_override("font_size", 20)
	_play_btn.disabled = true
	_apply_play_style()
	_play_btn.pressed.connect(_on_play)
	panel.add_child(_play_btn)

# ── UI helpers ─────────────────────────────────────────────────
func _make_field(parent: Panel, label_text: String, y: float, pw: float) -> LineEdit:
	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 1.00))
	lbl.position    = Vector2(15, y)
	lbl.size        = Vector2(pw - 30, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

	var field = LineEdit.new()
	field.position = Vector2(15, y + 20)
	field.size     = Vector2(pw - 30, 38)
	field.add_theme_font_size_override("font_size", 15)
	field.add_theme_color_override("font_color", Color(1, 1, 1))
	field.add_theme_color_override("font_placeholder_color", Color(0.40, 0.40, 0.45))
	var fs = StyleBoxFlat.new()
	fs.bg_color     = Color(0.08, 0.06, 0.16)
	fs.border_color = Color(0.30, 0.50, 0.85, 0.70)
	fs.set_border_width_all(1)
	field.add_theme_stylebox_override("normal", fs)
	field.add_theme_stylebox_override("focus",  fs)
	parent.add_child(field)
	return field

func _action_btn(text: String, border_col: Color, parent: Panel) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.88, 0.92, 1.00))
	var bs = StyleBoxFlat.new()
	bs.bg_color     = Color(0.06, 0.10, 0.22, 0.92)
	bs.border_color = border_col
	bs.set_border_width_all(1); bs.set_corner_radius_all(4)
	var bsh = bs.duplicate() as StyleBoxFlat
	bsh.bg_color = Color(0.12, 0.20, 0.38, 0.98)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover",  bsh)
	parent.add_child(btn)
	return btn

func _apply_play_style() -> void:
	var _play_ready = Relay.connected and _logged_in
	_play_btn.disabled = not _play_ready
	var bs = StyleBoxFlat.new()
	if _play_ready:
		bs.bg_color     = Color(0.06, 0.24, 0.10, 0.95)
		bs.border_color = Color(0.20, 0.90, 0.35, 1.00)
	else:
		bs.bg_color     = Color(0.10, 0.10, 0.12, 0.85)
		bs.border_color = Color(0.35, 0.35, 0.40, 0.60)
	bs.set_border_width_all(2); bs.set_corner_radius_all(6)
	var bsh = bs.duplicate() as StyleBoxFlat
	bsh.bg_color = bs.bg_color.lightened(0.08)
	_play_btn.add_theme_stylebox_override("normal",   bs)
	_play_btn.add_theme_stylebox_override("disabled", bs)
	_play_btn.add_theme_stylebox_override("hover",    bsh)
	var col = Color(0.30, 0.95, 0.45) if _play_ready else Color(0.45, 0.45, 0.50)
	_play_btn.add_theme_color_override("font_color",          col)
	_play_btn.add_theme_color_override("font_disabled_color", col)

# ── Relay callbacks ────────────────────────────────────────────
func _on_relay_connected() -> void:
	_set_status("Connected  •  Log in or register to play.", Color(0.30, 0.85, 0.45))
	_apply_play_style()

func _on_relay_error(_msg: String) -> void:
	_set_status("Server error — retrying…", Color(0.90, 0.35, 0.25))

# ── Auth actions ───────────────────────────────────────────────
func _on_login() -> void:
	var uname = _user_field.text.strip_edges()
	var pwd   = _pass_field.text
	if uname.length() == 0 or pwd.length() == 0:
		_set_status("Enter username and password.", Color(0.90, 0.60, 0.20))
		return
	if PlayerData.login(uname, pwd):
		_logged_in = true
		_set_status("Logged in as  %s" % uname, Color(0.30, 0.85, 0.45))
		_apply_play_style()
	else:
		_set_status("Wrong username or password.", Color(0.90, 0.35, 0.25))

func _on_register() -> void:
	var uname = _user_field.text.strip_edges()
	var pwd   = _pass_field.text
	if uname.length() < 3:
		_set_status("Username must be 3+ characters.", Color(0.90, 0.60, 0.20))
		return
	if pwd.length() < 4:
		_set_status("Password must be 4+ characters.", Color(0.90, 0.60, 0.20))
		return
	if PlayerData.register(uname, pwd):
		_logged_in = true
		_set_status("Account created!  Welcome,  %s" % uname, Color(0.30, 0.85, 0.45))
		_apply_play_style()
	else:
		_set_status("Username already taken.", Color(0.90, 0.35, 0.25))

func _set_status(msg: String, col: Color) -> void:
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color", col)

func _on_play() -> void:
	if _music:
		_music.stop()
	get_tree().change_scene_to_file("res://Scenes/spaceport.tscn")
