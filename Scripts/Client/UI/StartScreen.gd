extends Node2D

# ============================================================
#  StartScreen.gd — miniSWG
#  Username / password auth via PlayerData autoload.
#  PLAY button illuminates green only when:
#    • relay is connected  AND  • user is logged in
# ============================================================

var _canvas       : CanvasLayer      = null
var _music        : AudioStreamPlayer = null
var _music_tracks : Array = []
var _music_idx    : int = 0
const MUSIC_FADE_TIME := 2.0
const MUSIC_VOLUME := -28.0
var _user_field   : LineEdit         = null
var _pass_field   : LineEdit         = null
var _status_lbl   : Label            = null
var _play_btn     : Button           = null
var _spinner_lbl  : Label            = null
var _logged_in    : bool             = false
var _auto_play    : bool             = false
var _busy         : bool             = false
var _spin_tick    : float            = 0.0
const _SPIN_FRAMES = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
var _spin_idx     : int              = 0
const _SAVE_PATH  = "user://login.cfg"

func _ready() -> void:
	_start_music()
	_build_ui()
	_load_saved_username()
	Relay.connected_to_relay.connect(_on_relay_connected)
	Relay.relay_error.connect(_on_relay_error)
	Relay.connect_to_relay()

func _start_music() -> void:
	var s1 = load("res://Sounds/startscreenmusic.mp3") as AudioStream
	var s2 = load("res://Sounds/startscreenmusic2.mp3") as AudioStream
	_music_tracks.clear()
	if s1: _music_tracks.append(s1)
	if s2: _music_tracks.append(s2)
	if _music_tracks.is_empty():
		return
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0  # start silent, fade in
	_music.bus = "Master"
	add_child(_music)
	_music_idx = 0
	_play_next_track()

func _play_next_track() -> void:
	if _music_tracks.is_empty() or _music == null:
		return
	_music.stream = _music_tracks[_music_idx]
	_music.play()
	# Fade in
	var fade_in := create_tween()
	fade_in.tween_property(_music, "volume_db", MUSIC_VOLUME, MUSIC_FADE_TIME)
	# Wait for track to near its end, then fade out and switch
	var track_length : float = _music_tracks[_music_idx].get_length()
	var wait_time := maxf(0.1, track_length - MUSIC_FADE_TIME)
	get_tree().create_timer(wait_time).timeout.connect(_fade_to_next_track)

func _fade_to_next_track() -> void:
	if _music == null or not is_instance_valid(_music):
		return
	# Fade out current
	var fade_out := create_tween()
	fade_out.tween_property(_music, "volume_db", -80.0, MUSIC_FADE_TIME)
	await fade_out.finished
	if _music == null or not is_instance_valid(_music):
		return
	_music.stop()
	# Advance to next track (loop)
	_music_idx = (_music_idx + 1) % _music_tracks.size()
	_play_next_track()

# ── UI BUILD ──────────────────────────────────────────────────
func _build_ui() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)
	var vp = get_viewport().get_visible_rect().size

	# Background image
	var bg_tex = load("res://Coronet/gamecover.png") as Texture2D
	if bg_tex:
		var bg_img = TextureRect.new()
		bg_img.texture = bg_tex
		bg_img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.size = vp
		bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(bg_img)
	# Dark overlay so login panel stays readable
	var overlay = ColorRect.new()
	overlay.size  = vp
	overlay.color = Color(0.0, 0.0, 0.05, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	# Title — sci-fi glow effect (shadow layer + main layer)
	var title_font = load("res://Assets/Fonts/Bebas_Neue/BebasNeue-Regular.ttf")
	var title_y = vp.y * 0.08

	# Glow shadow behind the title
	var title_glow = Label.new()
	title_glow.add_theme_font_override("font", title_font)
	title_glow.text = "GALACTIC WAR OF THE STARS"
	title_glow.add_theme_font_size_override("font_size", 72)
	title_glow.add_theme_color_override("font_color", Color(0.20, 0.55, 1.00, 0.35))
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.size     = Vector2(vp.x, 90)
	title_glow.position = Vector2(0, title_y + 2)
	title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title_glow)

	# Main title
	var title = Label.new()
	title.add_theme_font_override("font", title_font)
	title.text = "GALACTIC WAR OF THE STARS"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.00))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.45, 0.95, 0.90))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(vp.x, 90)
	title.position = Vector2(0, title_y)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title)

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

	# Enter key: play if logged in, otherwise login
	_user_field.text_submitted.connect(func(_t): _on_enter_pressed())
	_pass_field.text_submitted.connect(func(_t): _on_enter_pressed())

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

	# Spinner label (hidden until busy)
	_spinner_lbl = Label.new()
	_spinner_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_spinner_lbl.add_theme_font_size_override("font_size", 18)
	_spinner_lbl.add_theme_color_override("font_color", Color(0.50, 0.80, 1.00))
	_spinner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spinner_lbl.size     = Vector2(PW, 28)
	_spinner_lbl.position = Vector2(0, 244)
	_spinner_lbl.visible  = false
	_spinner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_spinner_lbl)

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

	# Auto-focus: password if username saved, otherwise username
	_user_field.call_deferred("grab_focus")

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

func _process(delta: float) -> void:
	if not _busy or _spinner_lbl == null:
		return
	_spin_tick += delta
	if _spin_tick >= 0.08:
		_spin_tick = 0.0
		_spin_idx = (_spin_idx + 1) % _SPIN_FRAMES.size()
		_spinner_lbl.text = _SPIN_FRAMES[_spin_idx]

# ── Relay callbacks ────────────────────────────────────────────
func _on_relay_connected() -> void:
	_set_status("Connected  •  Log in or register to play.", Color(0.30, 0.85, 0.45))
	_apply_play_style()

func _on_relay_error(_msg: String) -> void:
	_set_status("Server error — retrying…", Color(0.90, 0.35, 0.25))

# ── Auth actions ───────────────────────────────────────────────
func _on_enter_pressed() -> void:
	if _logged_in and not _play_btn.disabled:
		_on_play()
	else:
		_auto_play = true
		_on_login()

func _on_login() -> void:
	var uname = _user_field.text.strip_edges()
	var pwd   = _pass_field.text
	if uname.length() == 0 or pwd.length() == 0:
		_set_status("Enter username and password.", Color(0.90, 0.60, 0.20))
		_auto_play = false
		return
	_set_busy(true, "Logging in…")
	if await PlayerData.login(uname, pwd):
		_logged_in = true
		_save_username(uname)
		_set_busy(false)
		_apply_play_style()
		if _auto_play:
			_auto_play = false
			_set_status("Logged in — launching…", Color(0.30, 0.85, 0.45))
			_on_play()
		else:
			_set_status("Logged in as  %s  — press PLAY" % uname, Color(0.30, 0.85, 0.45))
	else:
		_auto_play = false
		_set_busy(false)
		_set_status(PlayerData.last_error, Color(0.90, 0.35, 0.25))

func _on_register() -> void:
	var uname = _user_field.text.strip_edges()
	var pwd   = _pass_field.text
	if uname.length() < 3:
		_set_status("Username must be 3+ characters.", Color(0.90, 0.60, 0.20))
		return
	if pwd.length() < 4:
		_set_status("Password must be 4+ characters.", Color(0.90, 0.60, 0.20))
		return
	_set_busy(true, "Creating account…")
	if await PlayerData.register(uname, pwd):
		_logged_in = true
		_set_busy(false)
		_set_status("Welcome,  %s!  Press PLAY to enter." % uname, Color(0.30, 0.85, 0.45))
		_apply_play_style()
	else:
		_set_busy(false)
		_set_status(PlayerData.last_error, Color(0.90, 0.35, 0.25))

# Disable UI and show spinner during async auth
func _set_busy(busy: bool, msg: String = "") -> void:
	_busy = busy
	if _user_field: _user_field.editable = not busy
	if _pass_field: _pass_field.editable = not busy
	if _spinner_lbl:
		_spinner_lbl.visible = busy
	if busy and msg != "":
		_set_status(msg, Color(0.75, 0.78, 0.95))

func _set_status(msg: String, col: Color) -> void:
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color", col)

func _load_saved_username() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(_SAVE_PATH) == OK:
		var saved = cfg.get_value("login", "username", "")
		if saved != "":
			_user_field.text = saved
			_pass_field.call_deferred("grab_focus")

func _save_username(uname: String) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("login", "username", uname)
	cfg.save(_SAVE_PATH)

func _on_play() -> void:
	_play_btn.disabled = true
	_set_status("Loading world…", Color(0.55, 0.75, 1.00))
	if _music:
		var tween = create_tween()
		tween.tween_property(_music, "volume_db", -80.0, 0.8)
		await tween.finished
		_music.stop()
	get_tree().change_scene_to_file("res://Scenes/character_list.tscn")
