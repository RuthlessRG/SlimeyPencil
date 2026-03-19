extends CharacterBody2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  BossArenaPlayer.gd — Beyond the Veil | Boss Arena
# ============================================================

const SPEED = 140.0

# ── CLASS & STATS ─────────────────────────────────────────────
var character_class : String = "melee"
var character_name  : String = "Player"
var level           : int    = 1

# ── HAM POOLS (Health / Action / Mind) ───────────────────────
var ham_health     : float = 300.0
var ham_health_max : float = 300.0
var ham_action     : float = 300.0
var ham_action_max : float = 300.0
var ham_mind       : float = 300.0
var ham_mind_max   : float = 300.0

# Base HAM before stat bonuses
var _base_ham_health : float = 300.0
var _base_ham_action : float = 300.0
var _base_ham_mind   : float = 300.0

# Wounds reduce max pool — only healable at doctor/entertainer terminals
var wound_health : float = 0.0
var wound_action : float = 0.0
var wound_mind   : float = 0.0

func get_effective_max_health() -> float: return maxf(1.0, ham_health_max - wound_health)
func get_effective_max_action() -> float: return maxf(1.0, ham_action_max - wound_action)
func get_effective_max_mind() -> float: return maxf(1.0, ham_mind_max - wound_mind)

# Incapacitation: any pool hits 0 → incap, 3 incaps = death
var incap_count    : int   = 0
const MAX_INCAPS   : int   = 3
var _incapped      : bool  = false
var _incap_timer   : float = 0.0
const INCAP_DURATION : float = 10.0

# ── BACKWARD-COMPAT ALIASES (enemy scripts use hp/max_hp) ────
var hp: float:
	get: return ham_health
	set(v): ham_health = v
var max_hp: float:
	get: return get_effective_max_health()
	set(v): ham_health_max = v
var mp: float:
	get: return ham_action
	set(v): ham_action = v
var max_mp: float:
	get: return get_effective_max_action()
	set(v): ham_action_max = v

# ── SWG SECONDARY STATS ─────────────────────────────────────
# Health pool: Strength (pool size), Constitution (regen)
# Action pool: Quickness (pool size), Stamina (regen)
# Mind pool:   Focus (pool size), Willpower (regen)
var stat_strength     : int = 0
var stat_constitution : int = 0
var stat_quickness    : int = 0
var stat_stamina      : int = 0
var stat_focus        : int = 0
var stat_willpower    : int = 0

# ── LEGACY ATTRIBUTE ALIASES (for item/shop compatibility) ───
var attr_str : int:
	get: return stat_strength
	set(v): stat_strength = v
var attr_agi : int:
	get: return stat_quickness
	set(v): stat_quickness = v
var attr_int : int:
	get: return stat_focus
	set(v): stat_focus = v
var attr_spi : int:
	get: return stat_willpower
	set(v): stat_willpower = v
var unspent_points : int = 0

# ── INVENTORY ─────────────────────────────────────────────────
# Each entry is a dict: {id, name, type, rarity, cost,
#   attr_str, attr_agi, attr_int, attr_spi, desc, equipped}
var inventory : Array = []

# Item bonus totals — recomputed in _recalc_stats from equipped items
var _item_str : int = 0
var _item_agi : int = 0
var _item_int : int = 0
var _item_spi : int = 0
var _item_dmg_bonus   : float      = 0.0
var _item_combat_stats : Dictionary = {}  # defense, resist_* bonuses from gear

# ── BANK STORAGE ─────────────────────────────────────────────
var bank_credits  : int = 0
var bank_items    : Array = []

# ── CREDITS & EXPERIENCE ──────────────────────────────────────
var credits       : int = 0
var _float_stack  : int = 0   # tracks stacked floating texts
var exp_points : float = 0.0
var exp_needed : float = 100.0   # scales: 100 * level

# ── SWG SKILL POINT SYSTEM ──────────────────────────────────
var skill_points_total : int = 250
var skill_points_spent : int = 0

var xp_pools : Dictionary = {
	"unarmed": 0, "onehand": 0, "twohand": 0,
	"pistol": 0, "rifle": 0, "carbine": 0, "ranged": 0,
	"medical": 0, "force": 0, "crafting": 0,
}

var learned_boxes : Array = []  # array of box ID strings

func get_skill_points_available() -> int:
	return skill_points_total - skill_points_spent

func add_xp(xp_type: String, amount: int) -> void:
	if not xp_pools.has(xp_type):
		xp_pools[xp_type] = 0
	xp_pools[xp_type] += amount
	_spawn_floating_text("+%d %s XP" % [amount, xp_type.to_upper()], Color(0.75, 0.25, 1.0))
	# Also feed into legacy XP bar for visual progress
	exp_points += amount
	while exp_points >= exp_needed:
		exp_points -= exp_needed
		level += 1
		exp_needed = 100.0 * level

func learn_box(box_id: String) -> bool:
	var box = ProfessionData.find_box(box_id)
	if box.is_empty():
		return false
	var check = ProfessionData.can_learn_box(box, learned_boxes, xp_pools, get_skill_points_available(), credits)
	if not check.can_learn:
		_spawn_floating_text(check.reason, Color(1.0, 0.3, 0.3))
		return false
	# Spend resources
	skill_points_spent += box.cost_sp
	xp_pools[box.xp_type] -= box.xp_cost
	credits -= box.credit_cost
	learned_boxes.append(box_id)
	# Apply modifiers
	_recalc_box_modifiers()
	_spawn_floating_text("LEARNED: " + box.name, Color(0.3, 1.0, 0.5))
	return true

func _recalc_box_modifiers() -> void:
	# Reset combat stats
	for key in _combat_stats:
		_combat_stats[key] = 0
	# Sum all modifiers from learned boxes
	for box_id in learned_boxes:
		var box = ProfessionData.find_box(box_id)
		if box.is_empty():
			continue
		var mods = box.get("modifiers", {})
		for stat_key in mods:
			if _combat_stats.has(stat_key):
				_combat_stats[stat_key] += mods[stat_key]

func _get_weapon_xp_type() -> String:
	match character_class:
		"scrapper", "melee", "streetfighter": return "unarmed"
		"ranged", "smuggler": return "ranged"
		"mage":             return "force"
		"medic":           return "medical"
	return "unarmed"

# ── OUT-OF-COMBAT REGEN ──────────────────────────────────────
# Resets to COMBAT_LINGER on every hit; counts down to 0.
# At 0 → out of combat; pools regen at full rate.
const COMBAT_LINGER : float = 8.0
var _combat_timer   : float = 0.0

# ── COMBAT STATES (SWG Pre-CU) ──────────────────────────────
var state_dizzy      : float = 0.0
var state_knockdown  : float = 0.0
var state_stun       : float = 0.0
var state_blind      : float = 0.0
var state_intimidate : float = 0.0

# ── POSTURE ──────────────────────────────────────────────────
var posture : int = 0  # CombatEngine.Posture.STANDING

# ── COMBAT STATS (from skillboxes + items) ───────────────────
var _combat_stats : Dictionary = {
	"accuracy": 0, "defense": 0,
	"dodge": 0, "block": 0, "counterattack": 0,
	"defense_vs_dizzy": 0, "defense_vs_knockdown": 0,
	"defense_vs_stun": 0, "defense_vs_blind": 0,
	"defense_vs_intimidate": 0,
	"resist_kinetic": 0, "resist_energy": 0,
	"resist_heat": 0, "resist_cold": 0,
	"resist_acid": 0, "resist_electricity": 0,
	"resist_blast": 0, "resist_stun": 0,
}

func get_stat(stat_name: String) -> float:
	return float(_combat_stats.get(stat_name, 0)) + float(_item_combat_stats.get(stat_name, 0))

const STATE_COLORS : Dictionary = {
	"dizzy": Color(1.0, 0.85, 0.2),
	"knockdown": Color(1.0, 0.3, 0.2),
	"stun": Color(0.9, 0.6, 0.1),
	"blind": Color(0.5, 0.5, 0.6),
	"intimidate": Color(0.8, 0.4, 0.8),
}

func apply_combat_state(state_name: String, duration: float) -> void:
	var actual_dur = duration
	if state_name == "knockdown":
		actual_dur = 999.0  # Knockdown lasts until stand up (space bar)
		# Visually lay character on the floor
		var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
		if sprite: sprite.rotation = deg_to_rad(90)
	match state_name:
		"dizzy":      state_dizzy = maxf(state_dizzy, actual_dur)
		"knockdown":  state_knockdown = actual_dur
		"stun":       state_stun = maxf(state_stun, actual_dur)
		"blind":      state_blind = maxf(state_blind, actual_dur)
		"intimidate": state_intimidate = maxf(state_intimidate, actual_dur)
	_spawn_floating_text(state_name.to_upper(), STATE_COLORS.get(state_name, Color(1.0, 0.8, 0.2)))
	# Show as debuff icon on buff bar
	var buff_bar = get_node_or_null("BuffBar")
	if buff_bar and buff_bar.has_method("add_buff"):
		buff_bar.call("add_buff", {
			"id": "state_" + state_name,
			"icon": state_name,
			"label": state_name.capitalize(),
			"duration": actual_dur,
			"color": STATE_COLORS.get(state_name, Color(1.0, 0.5, 0.2)),
		})

func _tick_combat_states(delta: float) -> void:
	var buff_bar = get_node_or_null("BuffBar")
	# Knockdown does NOT tick down — only cleared by space bar stand up
	for sname in ["dizzy", "stun", "blind", "intimidate"]:
		var val = get("state_" + sname) as float
		if val > 0.0:
			set("state_" + sname, maxf(0.0, val - delta))
			if buff_bar and buff_bar.has_method("update_buff"):
				buff_bar.call("update_buff", "state_" + sname, val - delta)
			if val - delta <= 0.0:
				if buff_bar and buff_bar.has_method("remove_buff"):
					buff_bar.call("remove_buff", "state_" + sname)

# ── FACING & ANIMATION ────────────────────────────────────────
var _facing      : String = "s"
var _is_attacking: bool   = false
var _blend_attack_anim: String = ""
var _moving      : bool   = false
var _sf_attack_alt : bool = false  # Street Fighter attack alternation (attack vs attack2)
var _sf_move_timer : float = 0.0   # Street Fighter walk→run transition timer
const SF_WALK_DURATION : float = 0.4  # Seconds of walk before switching to run

# ── COMBAT QUEUE (SWG Pre-CU style) ─────────────────────────
var _combat_queue : Array = []  # Array of skill_id strings
const MAX_QUEUE_SIZE : int = 4
var _queue_timer : float = 0.0
var _queue_speed : float = 1.5  # Base seconds between queue pops (gets faster with skills)

# ── AUTO-ATTACK ───────────────────────────────────────────────
var _attack_timer        : float = 0.0
var _move_lock_timer     : float = 0.0
var _one_shot_kill       : bool  = false
var _ranged_first_attack : bool  = true   # longer bullet delay on first shot from idle

# ── DEATH ─────────────────────────────────────────────────────
const DEATH_DURATION : float = 2.0
var _dying       : bool  = false
var _death_timer : float = 0.0
var _aura_t      : float = 0.0   # drives gold aura animation

# ── SKILL STATE ───────────────────────────────────────────────
var _sprint_active    : bool  = false
var _sprint_timer     : float = 0.0
const SPRINT_DURATION : float = 15.0

# ── MOUNT STATE ───────────────────────────────────────────────
var _mounted          : bool    = false
var _mount_item       : Dictionary = {}
var _mount_speed      : float   = 0.0      # current throttle speed
var _mount_angle      : float   = 0.0      # facing angle (radians, points toward mouse)
# Parked vehicle (left behind when player presses F to exit)
var _has_parked       : bool    = false
var _parked_pos       : Vector2 = Vector2.ZERO
var _parked_item      : Dictionary = {}
var _parked_angle     : float   = 0.0
var _dismounting      : bool    = false   # true while slowing to a halt before exit
var _fade_t           : float   = 1.0      # 0=invisible 1=fully visible
var _fading_in        : bool    = false
var _fading_out       : bool    = false
var _fade_target_mount: bool    = false    # true=fading into mount, false=fading into player

var _sensu_active     : bool  = false
var _sensu_timer      : float = 0.0
const SENSU_DURATION  : float = 10.0

var _triple_active    : bool  = false
var _triple_hits_left : int   = 0

# ── TARGET SYSTEM ─────────────────────────────────────────────
var _current_target    : Node  = null
var _target_candidates : Array = []
var _target_idx        : int   = -1
var _target_scan_timer : float = 0.0

const TARGET_SCAN_RATE    = 0.10
const TARGET_CONE_RANGE   = 1400.0
const TARGET_CIRCLE_RANGE = 1600.0
const TARGET_CONE_ANGLE   = 60.0

# ── SOUNDS ─────────────────────────────────────────────────────
var _snd_step_port  : AudioStreamPlayer = null
var _snd_step_grass : AudioStreamPlayer = null
var _snd_melee_hits : Array = []   # knife slash sound variants
var _snd_rifle_shot   : AudioStreamPlayer = null
var _snd_medic_attack : AudioStreamPlayer = null
var _snd_hum        : AudioStreamPlayer2D = null   # vehicle engine hum (positional)
var _footstep_timer : float = 0.0
const FOOTSTEP_INTERVAL : float = 0.31

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	_setup_stats()
	_give_starting_items()
	_give_starting_skills()
	_spawn_chat()
	_setup_sounds()

func _give_starting_skills() -> void:
	var novice_id: String
	match character_class:
		"scrapper", "melee":  novice_id = "brawler_novice"
		"smuggler":           novice_id = "marksman_novice"
		"medic":              novice_id = "medic_novice"
		_:                    return
	if novice_id in learned_boxes: return
	var box = ProfessionData.find_box(novice_id)
	if box.is_empty(): return
	skill_points_spent += box.get("cost_sp", 0)
	learned_boxes.append(novice_id)
	_recalc_box_modifiers()

func _give_starting_items() -> void:
	if inventory.size() == 0:
		inventory.append({
			"id": "mount_speeder_mk1",
			"name": "Starfighter MK1",
			"rarity": "blue",
			"type": "mount",
			"cost": 10000,
			"speed_mult": 5.0,
			"mount_variant": "texture_dir",
			"mount_texture_dir": "res://Assets/Sprites/ships/ship1/",
			"attr_str": 0, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
			"desc": "Mount: 5x speed\nStarfighter vessel",
			"equipped": false,
		})

func _spawn_chat() -> void:
	var script = load("res://Scripts/BossChatWindow.gd")
	# Action bar — always present
	var bar_script = load("res://Scripts/BossActionBar.gd")
	var bar        = CanvasLayer.new()
	bar.name       = "ActionBar"
	bar.set_script(bar_script)
	add_child(bar)
	bar.call("init", self)

	# Buff/debuff bar — sits below HUD bars
	var buff_script = load("res://Scripts/BossBuffBar.gd")
	var buff_bar    = CanvasLayer.new()
	buff_bar.name   = "BuffBar"
	buff_bar.set_script(buff_script)
	add_child(buff_bar)
	buff_bar.call("init", self)

	var chat   = CanvasLayer.new()
	chat.name  = "ChatWindow"
	chat.set_script(script)
	add_child(chat)
	chat.call("init", self)

	# Combat queue HUD — shows during combat, hides when out of combat
	var cq_script = load("res://Scripts/CombatQueueHUD.gd")
	var cq_hud    = CanvasLayer.new()
	cq_hud.name   = "CombatQueueHUD"
	cq_hud.set_script(cq_script)
	add_child(cq_hud)
	cq_hud.call("init", self)

	# Tooltip manager — watches inventory slots and action bar slots
	var tip_script = load("res://Scripts/TooltipManager.gd")
	var tip        = CanvasLayer.new()
	tip.name       = "TooltipManager"
	tip.set_script(tip_script)
	add_child(tip)
	tip.call("init")

func _setup_sounds() -> void:
	_snd_step_port  = _make_sfx("res://Sounds/singlefootstep.mp3", -10.5)
	_snd_step_grass = _make_sfx("res://Sounds/footstepgrass.mp3",  -4.0)
	for _ks in ["res://Sounds/knife_slash.mp3", "res://Sounds/knife_slash1.mp3",
			"res://Sounds/knife_slash2.mp3", "res://Sounds/knife_slash3.mp3"]:
		var _kp = _make_sfx(_ks, -4.0)
		if _kp != null: _snd_melee_hits.append(_kp)
	_snd_rifle_shot   = _make_sfx("res://Sounds/rifle_shot.mp3",          -22.0)
	_snd_medic_attack = _make_sfx("res://Sounds/technunbufftest.wav",     -10.0)
	var _hum_stream = load("res://Sounds/hum.wav") as AudioStream
	if _hum_stream != null:
		_snd_hum = AudioStreamPlayer2D.new()
		_snd_hum.stream    = _hum_stream
		_snd_hum.volume_db = -80.0
		_snd_hum.bus       = "Master"
		_snd_hum.max_distance = 400.0  # Audible within 400px
		_snd_hum.attenuation = 1.5
		add_child(_snd_hum)
		_snd_hum.finished.connect(_on_hum_finished)
		_snd_hum.play()

func _on_hum_finished() -> void:
	if _snd_hum != null and (_mounted or _has_parked):
		_snd_hum.play()

func _make_sfx(path: String, vol_db: float) -> AudioStreamPlayer:
	var stream = load(path) as AudioStream
	if stream == null: return null
	var p = AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = vol_db
	p.bus       = "Master"
	add_child(p)
	return p

func _on_grass() -> bool:
	# Returns true when the player is outside the spaceport complex (on grass terrain)
	const PX = 80.0; const PY = 80.0; const PW = 2600.0; const PH = 2400.0
	return (global_position.x < PX or global_position.x > PX + PW or
			global_position.y < PY or global_position.y > PY + PH)

func _setup_stats() -> void:
	match character_class:
		"melee":
			character_name = "Melee Fighter"
			_base_ham_health = 400.0; _base_ham_action = 350.0; _base_ham_mind = 250.0
		"ranged":
			character_name = "Marksman"
			_base_ham_health = 300.0; _base_ham_action = 400.0; _base_ham_mind = 300.0
		"smuggler":
			character_name = "Smuggler"
			_base_ham_health = 300.0; _base_ham_action = 400.0; _base_ham_mind = 300.0
		"mage":
			character_name = "Mage"
			_base_ham_health = 250.0; _base_ham_action = 300.0; _base_ham_mind = 450.0
		"scrapper":
			character_name = "Scrapper"
			_base_ham_health = 500.0; _base_ham_action = 400.0; _base_ham_mind = 200.0
		"medic":
			character_name = "Medic"
			_base_ham_health = 350.0; _base_ham_action = 300.0; _base_ham_mind = 350.0
		"streetfighter":
			character_name = "Street Fighter"
			_base_ham_health = 600.0; _base_ham_action = 450.0; _base_ham_mind = 150.0
	_recalc_stats()
	ham_health = get_effective_max_health()
	ham_action = get_effective_max_action()
	ham_mind   = get_effective_max_mind()

var _mount_dir_textures : Dictionary = {}  # "n" -> AtlasTexture, "ne" -> AtlasTexture, etc.

func _load_mount_dir_textures() -> void:
	_mount_dir_textures.clear()
	var base_path = _mount_item.get("mount_texture_dir", "")
	if base_path == "": return
	for dir in ["n", "ne", "e", "se", "s", "sw", "w", "nw"]:
		var path = base_path + "idle_" + dir + ".png"
		var tex = load(path) as Texture2D
		if tex == null: continue
		# These are 15360x512 strips — grab just the first 512x512 frame
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0, 0, 512, 512)
		_mount_dir_textures[dir] = atlas

func _draw_mount_vehicle(alpha: float) -> void:
	var variant = _mount_item.get("mount_variant", "fighter")
	var t       = Time.get_ticks_msec() / 1000.0
	var fwd     = Vector2(cos(_mount_angle), sin(_mount_angle))
	var side    = Vector2(-sin(_mount_angle), cos(_mount_angle))

	# ── 8-directional texture mount ──────────────────────────
	if variant == "texture_dir":
		if _mount_dir_textures.is_empty():
			_load_mount_dir_textures()
		var dir_tex = _mount_dir_textures.get(_mount_facing, null) as Texture2D
		if dir_tex != null:
			var tex_size = dir_tex.get_size()
			var sc = 0.50
			# Ground shadow — uses actual ship texture, squished flat like character shadow
			var sh_scale_x = sc
			var sh_scale_y = sc * 0.25
			var sh_pos = Vector2(6, 90)
			draw_set_transform(sh_pos, 0.0, Vector2(sh_scale_x, sh_scale_y))
			draw_texture(dir_tex, -tex_size * 0.5, Color(0, 0, 0, 0.30 * alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			var spd_pct = clampf(_mount_velocity.length() / (SPEED * 5.0), 0.0, 1.0)

			# Draw ship sprite — hover bob when idle
			var hover_y = sin(t * 2.0) * 4.0 * (1.0 - spd_pct)
			var ship_origin = Vector2(0, -30 + hover_y)
			draw_set_transform(ship_origin, 0.0, Vector2(sc, sc))
			draw_texture(dir_tex, -tex_size * 0.5, Color(1, 1, 1, alpha))



			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		return

	# Engine glow pulse
	var eng_glow = Color(0.30, 0.65, 1.00, (0.55 + sin(t*8.0)*0.30) * alpha)

	if variant == "fighter":
		# ── Fighter speeder (LandSpeeder MK1) ────────────────
		# Shadow
		draw_colored_polygon(
			_mount_ellipse(Vector2(6,68), 55, 14, _mount_angle, 16),
			Color(0,0,0, 0.22 * alpha))
		# Hull
		var hull = PackedVector2Array()
		for i in 21:
			var tv = float(i)/20.0
			var px: float; var py: float
			if tv <= 0.5:
				px = lerpf(-42, 50, tv*2.0)
				py = sin(tv*2.0*PI) * 16.0
			else:
				px = lerpf(50, -42, (tv-0.5)*2.0)
				py = -sin((tv-0.5)*2.0*PI) * 16.0
			hull.append(fwd*px + side*py)
		draw_colored_polygon(hull, Color(0.88, 0.92, 0.96, alpha))
		# Cockpit
		draw_colored_polygon(
			_mount_ellipse(fwd*15, 13, 7, _mount_angle, 12),
			Color(0.35, 0.70, 1.00, 0.80 * alpha))
		draw_colored_polygon(
			_mount_ellipse(fwd*16 + side*(-3), 5, 2.5, _mount_angle, 8),
			Color(1.0, 1.0, 1.0, 0.50 * alpha))
		# Engine nacelles
		for sm in [-1.0, 1.0]:
			var ep = fwd*(-30) + side*sm*13
			draw_colored_polygon(_mount_ellipse(ep, 9, 5, _mount_angle, 10),
				Color(0.45, 0.52, 0.62, alpha))
			draw_colored_polygon(_mount_ellipse(ep - fwd*9, 5, 4.5, _mount_angle, 10), eng_glow)
		# Accent stripes
		draw_line(fwd*(-40)+side*4,  fwd*40+side*4,  Color(0.25,0.60,1.00,0.70*alpha), 2.0)
		draw_line(fwd*(-40)-side*4,  fwd*40-side*4,  Color(0.25,0.60,1.00,0.70*alpha), 2.0)
		# Speed lines (scale with speed)
		var sp_ratio = abs(_mount_speed) / (SPEED * _mount_item.get("speed_mult", 5.0))
		if sp_ratio > 0.15:
			for i in 4:
				var soff = side * (float(i-2) * 5.0)
				var slen = 18.0 + sp_ratio * 22.0
				var sa   = (0.20 + sp_ratio*0.35) * alpha
				draw_line(fwd*(-42)+soff, fwd*(-42)-fwd*slen+soff,
					Color(0.50, 0.80, 1.00, sa), 1.5)
	else:
		# ── Transport speeder (LandSpeeder MK2) ──────────────
		# Shadow
		draw_colored_polygon(
			_mount_ellipse(Vector2(8,72), 48, 24, _mount_angle, 16),
			Color(0,0,0, 0.22 * alpha))
		# Wide hull
		var hull = PackedVector2Array([
			fwd*(-45) - side*22,
			fwd*35    - side*15,
			fwd*45,
			fwd*35    + side*15,
			fwd*(-45) + side*22,
		])
		draw_colored_polygon(hull, Color(0.86, 0.88, 0.92, alpha))
		# Superstructure
		var sup = PackedVector2Array([
			fwd*(-25) - side*10,
			fwd*20    - side*7,
			fwd*20    + side*7,
			fwd*(-25) + side*10,
		])
		draw_colored_polygon(sup, Color(0.76, 0.80, 0.86, alpha))
		# Bridge windows
		for wi in 4:
			var wp = fwd*(5+wi*5) + side*(-6+wi)
			draw_circle(wp, 2.2, Color(0.35,0.70,1.00, 0.85*alpha))
		# Cargo dome
		draw_colored_polygon(_mount_ellipse(fwd*(-10), 15, 9, _mount_angle, 14),
			Color(0.70, 0.75, 0.82, alpha))
		draw_colored_polygon(_mount_ellipse(fwd*(-9) - side*2, 7, 4, _mount_angle, 10),
			Color(0.92, 0.96, 1.0, 0.65*alpha))
		# Engine pods
		for sm in [-1.0, 1.0]:
			var ep = fwd*(-40) + side*sm*16
			draw_colored_polygon(_mount_ellipse(ep, 8,4, _mount_angle, 10),
				Color(0.38,0.42,0.50, alpha))
			draw_colored_polygon(_mount_ellipse(ep-fwd*8, 5,4, _mount_angle, 10), eng_glow)
		# Accent
		draw_line(fwd*(-44), fwd*44, Color(1.00,0.82,0.10, 0.70*alpha), 2.0)
		# Speed lines
		var sp_ratio = abs(_mount_speed) / (SPEED * _mount_item.get("speed_mult", 7.0))
		if sp_ratio > 0.15:
			for i in 4:
				var soff = side * (float(i-2) * 6.0)
				var slen = 20.0 + sp_ratio * 26.0
				var sa   = (0.20 + sp_ratio*0.35) * alpha
				draw_line(fwd*(-46)+soff, fwd*(-46)-fwd*slen+soff,
					Color(1.00, 0.88, 0.30, sa), 1.5)

func _draw_parked_vehicle() -> void:
	# Draw the parked vehicle at its saved world position.
	# Uses draw_set_transform to offset draw calls from the player's local origin.
	var offset : Vector2 = _parked_pos - global_position
	var save_item  = _mount_item
	var save_angle = _mount_angle
	var save_mnt   = _mounted
	_mount_item  = _parked_item
	_mount_angle = _parked_angle
	_mounted     = true
	draw_set_transform(offset, 0.0, Vector2.ONE)
	_draw_mount_vehicle(0.88)   # slightly dimmed = parked/idle
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_mount_item  = save_item
	_mount_angle = save_angle
	_mounted     = save_mnt
	# "Press F" hint when player is close enough
	var dist : float = global_position.distance_to(_parked_pos)
	if dist < 130.0:
		var font = _roboto
		draw_set_transform(offset + Vector2(-38, -52), 0.0, Vector2.ONE)
		draw_string(font, Vector2.ZERO, "[F] Enter Vehicle", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(1.0, 0.95, 0.55, 0.90))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _mount_ellipse(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var cr  = cos(rot); var sr = sin(rot)
	for i in n:
		var a  = float(i)/float(n)*TAU
		var lx = cos(a)*rx; var ly = sin(a)*ry
		pts.append(center + Vector2(lx*cr - ly*sr, lx*sr + ly*cr))
	return pts


func _recalc_stats() -> void:
	# Recompute item bonuses from currently equipped items
	_item_str = 0; _item_agi = 0; _item_int = 0; _item_spi = 0
	_item_dmg_bonus = 0.0
	_item_combat_stats.clear()
	for item in inventory:
		if item.get("equipped", false):
			_item_str += item.get("attr_str", 0)
			_item_agi += item.get("attr_agi", 0)
			_item_int += item.get("attr_int", 0)
			_item_spi += item.get("attr_spi", 0)
			_item_dmg_bonus += float(item.get("damage_bonus", 0))
			for key in ["defense", "resist_kinetic", "resist_energy", "resist_heat",
						"resist_cold", "resist_acid", "resist_electricity",
						"resist_blast", "resist_stun", "accuracy"]:
				if item.has(key):
					_item_combat_stats[key] = _item_combat_stats.get(key, 0) + int(item[key])
	# HAM pool max = base + (secondary stats + item bonuses) * 10
	ham_health_max = _base_ham_health + (stat_strength + stat_constitution + _item_str) * 10.0
	ham_action_max = _base_ham_action + (stat_quickness + stat_stamina + _item_agi) * 10.0
	ham_mind_max   = _base_ham_mind + (stat_focus + stat_willpower + _item_int + _item_spi) * 10.0
	ham_health = minf(ham_health, get_effective_max_health())
	ham_action = minf(ham_action, get_effective_max_action())
	ham_mind   = minf(ham_mind, get_effective_max_mind())

# ── CREDITS & PROGRESSION ─────────────────────────────────────
func add_credits(amount: int) -> void:
	credits += amount
	_spawn_floating_text("+%d ¢" % amount, Color(1.0, 0.85, 0.20))

func add_exp(amount: float) -> void:
	# Route generic XP to weapon-specific pool AND legacy XP bar
	var wt = _get_weapon_xp_type()
	add_xp(wt, int(amount))

func _target_hit_pos() -> Vector2:
	if not is_instance_valid(_current_target): return global_position
	if _current_target.has_method("get_target_position"):
		return _current_target.get_target_position()
	return _current_target.global_position

func _spawn_hit_flash(world_pos: Vector2) -> void:
	var flash = Node2D.new()
	flash.z_index = 20
	var src = """extends Node2D
var _t:float=0.0
func _process(d):
	_t+=d
	if _t>0.35: queue_free(); return
	queue_redraw()
func _draw():
	var a=1.0-_t/0.35
	var r=8.0+_t*40.0
	draw_circle(Vector2.ZERO,r,Color(1.0,1.0,1.0,a*0.5))
	draw_circle(Vector2.ZERO,r*0.5,Color(1.0,0.9,0.5,a*0.8))
	for i in 6:
		var ang=float(i)/6.0*TAU+_t*8.0
		var p=Vector2(cos(ang),sin(ang))*r*0.7
		draw_circle(p,2.0,Color(1.0,0.8,0.3,a*0.6))
"""
	var s = GDScript.new(); s.source_code = src; s.reload()
	flash.set_script(s)
	get_tree().current_scene.add_child(flash)
	flash.global_position = world_pos

func _spawn_floating_text(text: String, color: Color) -> void:
	var script = load("res://Scripts/BossFloatingText.gd")
	var node   = Node2D.new()
	node.set_script(script)
	var scene  = get_tree().current_scene
	if scene == null:
		return
	scene.add_child(node)
	node.global_position = global_position + Vector2(randf_range(-8, 8), -80 - _float_stack * 20)
	_float_stack += 1
	node.call("init", text, color)
	get_tree().create_timer(1.4).timeout.connect(func(): _float_stack = max(0, _float_stack - 1))

func _level_up() -> void:
	level         += 1
	unspent_points += 3
	exp_needed     = 100.0 * level
	_recalc_stats()
	ham_health = get_effective_max_health()  # full heal on level up
	ham_action = get_effective_max_action()
	ham_mind   = get_effective_max_mind()
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("trigger_level_up"):
		arena.call("trigger_level_up", level)

func spend_point(attr: String) -> void:
	if unspent_points <= 0:
		return
	match attr:
		"str": attr_str += 1
		"agi": attr_agi += 1
		"int": attr_int += 1
		"spi": attr_spi += 1
		_: return
	unspent_points -= 1
	_recalc_stats()

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		queue_redraw()
		return

	_tick_incap(delta)
	if _incapped:
		velocity = Vector2.ZERO
		queue_redraw()
		return

	_tick_combat_states(delta)
	# Stunned or knocked down = can't act
	if state_stun > 0.0 or state_knockdown > 0.0:
		velocity = Vector2.ZERO
		queue_redraw()
		return

	_target_scan_timer -= delta
	if _target_scan_timer <= 0.0:
		_target_scan_timer = TARGET_SCAN_RATE
		_refresh_target_candidates()

	if _move_lock_timer > 0.0:
		_move_lock_timer -= delta

	_aura_t += delta
	# ── Vehicle hum volume (scales with speed) ──────────────
	if _snd_hum != null:
		if _mounted:
			var spd_ratio = clampf(_mount_velocity.length() / (SPEED * 5.0), 0.0, 1.0)
			# Idle hum at -25db, max speed at -6db
			_snd_hum.volume_db = lerpf(-25.0, -6.0, spd_ratio)
			if not _snd_hum.playing: _snd_hum.play()
		else:
			_snd_hum.volume_db = -80.0
	_tick_ham_regen(delta)
	_tick_skills(delta)
	_tick_combat_queue(delta)
	_update_animation()
	queue_redraw()

func _tick_death(delta: float) -> void:
	_death_timer += delta
	var blink = absf(sin(_death_timer * 14.0))
	var fade  = 1.0 - clampf((_death_timer - 1.4) / 0.6, 0.0, 1.0)
	modulate.a = blink * fade
	if _death_timer >= DEATH_DURATION:
		queue_free()

func _physics_process(_delta: float) -> void:
	_tick_fade(_delta)

	if _dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Mount mode — spaceship controls take over entirely
	if _mounted:
		_tick_mount_physics(_delta)
		return

	if _move_lock_timer > 0.0:
		velocity = Vector2.ZERO
		_moving  = false
		move_and_slide()
		return

	var input = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0

	_moving = input != Vector2.ZERO
	if _moving:
		var _sprint_mult = 1.65 if _sprint_active else 1.0
		var _class_speed = 1.32 if character_class == "scrapper" else (1.2 if character_class == "ranged" else 1.0)
		velocity = input.normalized() * SPEED * _sprint_mult * _class_speed
		if character_class in ["melee", "medic", "scrapper", "streetfighter", "ranged"]:
			_facing = _facing_8dir(input)
		elif input.y < 0.0:
			_facing = "n"
		elif input.y > 0.0:
			_facing = "s"
		elif input.x > 0.0:
			_facing = "e"
		else:
			_facing = "w"
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Footstep sounds — tick timer while moving
	if _moving:
		_footstep_timer -= _delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			if _on_grass():
				if _snd_step_grass != null: _snd_step_grass.play()
			else:
				if _snd_step_port  != null: _snd_step_port.play()
	else:
		_footstep_timer = 0.0   # reset so first step is immediate next time

func _input(event: InputEvent) -> void:
	if _dying:
		return
	# Don't fire game keys while chat input has keyboard focus
	if event is InputEventKey:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit:
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_cycle_target()
		elif event.keycode == KEY_ESCAPE:
			# Close any open window first; if none, clear target; if none, open settings
			var window_names = ["ShopWindow", "InventoryWindow", "AttributeWindow", "MissionWindow", "SkillWindow", "SWGSkillWindow", "SWGStatsWindow"]
			var closed = false
			for wname in window_names:
				var win = get_node_or_null(wname)
				if win:
					win.queue_free()
					closed = true
					break
			if not closed and _current_target != null:
				_current_target = null
				_target_idx     = -1
				_cancel_attack()
			elif not closed:
				# No windows open, no target — open settings/cogwheel
				var scene_root = get_tree().current_scene
				if scene_root:
					for child in scene_root.get_children():
						var script_path = child.get_script().resource_path if child.get_script() else ""
						if "SettingsWindow" in script_path:
							child.call("_toggle")
							break
		elif event.keycode == KEY_G:
			_one_shot_kill = true
		elif event.keycode == KEY_J:
			_level_up()   # debug: instant level up
		elif event.keycode == KEY_P:
			_toggle_skills()
		elif event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_C:
			_toggle_attributes()
		elif event.keycode == KEY_K:
			_toggle_profession_tree()
		elif event.keycode == KEY_U:
			_toggle_stats_window()
		elif event.keycode == KEY_SPACE:
			_try_stand_up()
		elif event.keycode == KEY_QUOTELEFT:  # Tilde/backtick key
			_toggle_mount_hotkey()
		elif event.keycode == KEY_F:
			if _mounted: return  # No F interaction while mounted
			_try_open_shop()
			_try_open_mission()
			_try_open_loot()
		elif event.keycode == KEY_H:
			credits += 500   # debug: +500 credits
		elif event.keycode == KEY_F11:
			# Debug: reset all skills and grant large XP to all pools for testing
			learned_boxes.clear()
			skill_points_spent = 0
			_recalc_box_modifiers()
			for pool_key in xp_pools:
				xp_pools[pool_key] = 50000
			_spawn_floating_text("SKILLS RESET + XP GRANTED", Color(0.5, 1.0, 0.5))

# ── WINDOW TOGGLES ────────────────────────────────────────────
func _toggle_inventory() -> void:
	var existing = get_node_or_null("InventoryWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossInventoryWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "InventoryWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _toggle_attributes() -> void:
	var existing = get_node_or_null("AttributeWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossAttributeWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "AttributeWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _toggle_profession_tree() -> void:
	var existing = get_node_or_null("SWGSkillWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/SWGSkillWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "SWGSkillWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _toggle_stats_window() -> void:
	var existing = get_node_or_null("SWGStatsWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/SWGStatsWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "SWGStatsWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _try_stand_up() -> void:
	if state_knockdown <= 0.0:
		return  # Not knocked down
	if state_dizzy > 0.0:
		# DIZZY FLOP: pressing space while dizzy = instant knockdown again
		# Punishes spam, rewards waiting for dizzy to wear off
		state_knockdown = 999.0  # Reset knockdown (infinite until stand)
		_spawn_floating_text("DIZZY FLOPPED!", Color(1.0, 0.3, 0.2))
		var bb_flop = get_node_or_null("BuffBar")
		if bb_flop and bb_flop.has_method("update_buff"):
			bb_flop.call("update_buff", "state_knockdown", 999.0)
		return
	# Not dizzy — successfully stand up
	state_knockdown = 0.0
	var bb = get_node_or_null("BuffBar")
	if bb and bb.has_method("remove_buff"):
		bb.call("remove_buff", "state_knockdown")
	_spawn_floating_text("STOOD UP", Color(0.3, 1.0, 0.5))
	# Restore sprite rotation
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite: sprite.rotation = 0.0

func reset_skill_points() -> void:
	learned_boxes.clear()
	skill_points_spent = 0
	_recalc_box_modifiers()
	# Give max XP for testing
	for xp_type in xp_pools:
		xp_pools[xp_type] = 99999
	_spawn_floating_text("SKILLS RESET + 99999 XP", Color(0.3, 1.0, 0.5))

func _get_terminal_pos(t: Node) -> Vector2:
	var spr = t.get_node_or_null("AnimatedSprite2D")
	if spr:
		return spr.global_position
	return t.global_position

func _try_open_shop() -> void:
	var terminals = get_tree().get_nodes_in_group("shop_terminal")
	for t in terminals:
		if is_instance_valid(t) and global_position.distance_to(_get_terminal_pos(t)) <= 100.0:
			_toggle_shop()
			return

func _toggle_shop() -> void:
	var existing = get_node_or_null("ShopWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossShopWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "ShopWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _try_open_mission() -> void:
	var terminals = get_tree().get_nodes_in_group("mission_terminal")
	for t in terminals:
		if is_instance_valid(t) and global_position.distance_to(_get_terminal_pos(t)) <= 100.0:
			_toggle_mission()
			return

func _toggle_mission() -> void:
	var existing = get_node_or_null("MissionWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/MissionWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "MissionWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _try_open_loot() -> void:
	for bag in get_tree().get_nodes_in_group("loot_bag"):
		if not is_instance_valid(bag): continue
		if not bag.get("_arc_done"): continue
		if global_position.distance_to(bag.global_position) <= 60.0:
			var existing = get_node_or_null("LootWindow")
			if existing: existing.queue_free()
			var script = load("res://Scripts/LootWindow.gd")
			var win    = CanvasLayer.new()
			win.name   = "LootWindow"
			win.set_script(script)
			add_child(win)
			win.call("init", self, bag)
			return

func _toggle_skills() -> void:
	var existing = get_node_or_null("SkillWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossSkillWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "SkillWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

# ── INVENTORY / ITEM SYSTEM ───────────────────────────────────
func add_item_to_inventory(item: Dictionary) -> void:
	var copy          = item.duplicate()
	copy["equipped"]  = false
	inventory.append(copy)
	var _rc : Color
	match item.get("rarity", "white"):
		"blue": _rc = Color(0.40, 0.72, 1.00)
		"gold": _rc = Color(1.00, 0.82, 0.15)
		_:      _rc = Color(0.88, 0.88, 0.88)
	_spawn_floating_text("LOOT: " + item.get("name", "Item"), _rc)

func toggle_equip(inv_index: int) -> void:
	if inv_index < 0 or inv_index >= inventory.size():
		return
	var item = inventory[inv_index]
	if item.get("type","") == "mount":
		_toggle_mount(inv_index)
		return
	var already_equipped = item.get("equipped", false)
	if not already_equipped:
		# Un-equip any other item occupying the same slot
		var itype = item.get("type", "")
		for i in inventory.size():
			if i != inv_index and inventory[i].get("type","") == itype:
				inventory[i]["equipped"] = false
	item["equipped"] = not already_equipped
	_recalc_stats()

func _toggle_mount_hotkey() -> void:
	if _fading_out or _fading_in: return
	if _dismounting: return  # Already exiting — wait for halt
	if _mounted:
		if _mount_velocity.length() > 20.0:
			# Start slowing — block all other actions until fully stopped
			_dismounting = true
			_spawn_floating_text("Slowing down...", Color(0.7, 0.8, 1.0))
			return
		# Already stopped — dismount immediately
		_do_dismount()
	else:
		# Not mounted — find first mount in inventory and mount up
		for i in inventory.size():
			if inventory[i].get("type", "") == "mount":
				_toggle_mount(i)
				return
		_spawn_floating_text("No vehicle in inventory", Color(1.0, 0.5, 0.3))

func _do_dismount() -> void:
	_dismounting = false
	for i in inventory.size():
		if inventory[i].get("type", "") == "mount" and inventory[i].get("equipped", false):
			_toggle_mount(i)
			return

func _toggle_mount(inv_index: int) -> void:
	var item = inventory[inv_index]
	var already_equipped = item.get("equipped", false)
	# Unequip any other mount first
	for i in inventory.size():
		if inventory[i].get("type","") == "mount" and inventory[i].get("equipped", false):
			inventory[i]["equipped"] = false
	if not already_equipped:
		item["equipped"] = true
		_mount_item = item
		_start_fade(true)   # fade player out, mount in
	else:
		_start_fade(false)  # fade mount out, player in

func _start_fade(mounting: bool) -> void:
	_fade_target_mount = mounting
	_fading_out = true
	_fading_in  = false
	_fade_t     = 1.0

func _tick_fade(delta: float) -> void:
	if _fading_out:
		_fade_t -= delta * 3.0
		if _fade_t <= 0.0:
			_fade_t     = 0.0
			_fading_out = false
			_fading_in  = true
			if _fade_target_mount:
				_mounted = true
				_mount_speed = 0.0
			else:
				_mounted = false
				_mount_item = {}
				_mount_speed = 0.0
				for i in inventory.size():
					if inventory[i].get("type","") == "mount":
						inventory[i]["equipped"] = false
				_recalc_stats()
	elif _fading_in:
		_fade_t += delta * 3.0
		if _fade_t >= 1.0:
			_fade_t    = 1.0
			_fading_in = false

# ── MOUNT MOVEMENT (WASD 8-dir with acceleration/deceleration) ─
var _mount_facing : String = "s"
var _mount_velocity : Vector2 = Vector2.ZERO  # Actual smoothed velocity
var _mount_last_dir : Vector2 = Vector2.ZERO  # Last input direction (for coasting)

func _tick_mount_physics(delta: float) -> void:
	var max_speed = SPEED * _mount_item.get("speed_mult", 5.0)
	var accel = max_speed * 1.2
	var decel = max_speed * 0.6

	# Dismounting — block all input, brake hard, auto-exit when stopped
	if _dismounting:
		_mount_velocity = _mount_velocity.move_toward(Vector2.ZERO, decel * 2.5 * delta)
		velocity = _mount_velocity
		move_and_slide()
		queue_redraw()
		if _mount_velocity.length() < 5.0:
			_do_dismount()
		return

	# WASD input
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		_mount_last_dir = input_dir
		# Accelerate toward target velocity
		var target_vel = input_dir * max_speed
		_mount_velocity = _mount_velocity.move_toward(target_vel, accel * delta)
		# Update facing from input direction
		var angle = input_dir.angle()
		var deg = fmod(rad_to_deg(angle) + 360.0 + 22.5, 360.0)
		var sector = int(deg / 45.0)
		match sector:
			0: _mount_facing = "n"
			1: _mount_facing = "ne"
			2: _mount_facing = "e"
			3: _mount_facing = "se"
			4: _mount_facing = "s"
			5: _mount_facing = "sw"
			6: _mount_facing = "w"
			7: _mount_facing = "nw"
	else:
		# No input — coast to a stop in the last direction
		_mount_velocity = _mount_velocity.move_toward(Vector2.ZERO, decel * delta)

	velocity = _mount_velocity
	move_and_slide()
	queue_redraw()

# ── ANIMATION ─────────────────────────────────────────────────
func _update_animation() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var upper = get_node_or_null("SpriteUpper") as AnimatedSprite2D
	# Hide character sprite while mounted; show otherwise
	sprite.visible = not _mounted
	sprite.modulate.a = _fade_t if not _mounted else (1.0 - _fade_t)
	if upper:
		# Don't set upper.visible here — blend logic below handles it
		upper.modulate.a = sprite.modulate.a
	if _mounted:
		if upper: upper.visible = false
		return

	# Kiting: moving after firing cancels attack animation for projectile classes
	if _is_attacking and _moving and character_class in ["ranged", "smuggler", "mage", "medic"]:
		_cancel_attack()

	# Brawlernew: run always wins over attack when moving
	if upper:
		upper.visible = false
		sprite.material = null
	if character_class == "streetfighter":
		# Street Fighter: walk → run transition + attack alternation
		# Movement ALWAYS overrides attack animation
		var anim : String
		if _moving:
			_sf_move_timer += get_process_delta_time()
			if _sf_move_timer < SF_WALK_DURATION:
				anim = "walk_" + _facing
			else:
				anim = "run_" + _facing
		elif _is_attacking:
			_sf_move_timer = 0.0
			anim = _blend_attack_anim if _blend_attack_anim != "" else "attack_" + _facing
		else:
			_sf_move_timer = 0.0  # Reset walk timer when stopped
			anim = "idle_" + _facing
		if sprite.sprite_frames.has_animation(anim):
			var cur = sprite.animation
			if cur != anim:
				if cur.begins_with("attack") and anim.begins_with("idle_") and sprite.is_playing():
					pass
				else:
					sprite.play(anim)
		elif sprite.sprite_frames.has_animation("idle_" + _facing):
			sprite.play("idle_" + _facing)
	else:
		# Standard single-sprite animation for all other classes
		# Movement ALWAYS overrides attack animation
		if upper: upper.visible = false
		var anim : String
		if _moving:
			anim = "run_" + _facing
		elif _is_attacking:
			anim = "attack_" + _facing
		else:
			anim = "idle_" + _facing

		if sprite.sprite_frames.has_animation(anim):
			if sprite.animation != anim:
				sprite.play(anim)
		else:
			if sprite.sprite_frames.has_animation("idle_s") and sprite.animation != "idle_s":
				sprite.play("idle_s")
		# ranged: all anims are 5-dir (run/attack) or 3-dir (idle); always flip for w/nw/sw
		if character_class == "ranged":
			sprite.flip_h = _facing in ["w", "nw", "sw"]
		# smuggler: idle+attack are 8-dir, no flip; run is 5-dir, flip when running west
		elif character_class == "smuggler":
			sprite.flip_h = _moving and _facing in ["w", "nw", "sw"]
		# medic all anims are 5-dir only; flip for all west-facing states
		elif character_class == "medic":
			sprite.flip_h = _facing in ["w", "nw", "sw"]

	# Reset rotation unless knocked down
	if state_knockdown <= 0.0:
		sprite.rotation = 0.0
		if upper: upper.rotation = 0.0

# ── PLACEHOLDER DRAW ──────────────────────────────────────────
func _draw() -> void:
	# Parked vehicle — drawn at its world position before mounted player draw
	if _has_parked:
		_draw_parked_vehicle()

	# ── Mount vehicle draw ────────────────────────────────────────
	if _mounted or (_fading_out and _fade_target_mount) or (_fading_in and _fade_target_mount):
		var alpha = _fade_t if (_fading_in and _fade_target_mount) else (1.0 - _fade_t if (_fading_out and _fade_target_mount) else 1.0)
		_draw_mount_vehicle(alpha)
		if _mounted and not _fading_out and not _fading_in:
			return   # skip character draw entirely

	# ── Gold aura — PD2-style soft energy cloud around body ──────
	for _aura_item in inventory:
		if _aura_item.get("equipped", false) and _aura_item.get("rarity", "") == "gold":
			var _body_cy = -20.0 if (character_class == "scrapper") else -12.0
			var _c       = Vector2(0.0, _body_cy)
			# Two independent slow pulses for organic breathing feel
			var _p1v = 0.55 + sin(_aura_t * 1.8) * 0.18
			var _p2v = 0.50 + sin(_aura_t * 2.5 + 1.2) * 0.14
			# ── Filled cloud polygons (size reduced 15%) ──────────────
			const _N : int = 28
			var _outer_pts = PackedVector2Array()
			var _mid_pts   = PackedVector2Array()
			var _inner_pts = PackedVector2Array()
			for _i in _N:
				var _a      = float(_i) / float(_N) * TAU
				var _wobble = sin(_a * 3.0 + _aura_t * 2.2) * 2.1 + sin(_a * 5.0 - _aura_t * 1.4) * 1.3
				var _orx    = 17.0 + _wobble   # was 20
				var _ory    = 22.0 + _wobble   # was 26
				_outer_pts.append(_c + Vector2(cos(_a) * _orx,  sin(_a) * _ory))
				_mid_pts.append(_c   + Vector2(cos(_a) * 12.8,  sin(_a) * 16.2))  # was 15/19
				_inner_pts.append(_c + Vector2(cos(_a) * 7.7,   sin(_a) * 9.4))   # was 9/11
			draw_colored_polygon(_outer_pts, Color(0.90, 0.62, 0.04, _p1v * 0.18))
			draw_colored_polygon(_mid_pts,   Color(1.00, 0.80, 0.10, _p2v * 0.32))
			draw_colored_polygon(_inner_pts, Color(1.00, 0.95, 0.55, _p1v * 0.28))
			draw_circle(_c, 4.3, Color(1.00, 0.98, 0.75, _p2v * 0.22))
			# ── Tendrils: burst from center outward, fade fast ────────
			# Each tendril has its own staggered period so they fire at different times.
			# _life goes 0→1 over the period; tendril shoots out and fades before 1.0.
			const _T_COUNT  : int   = 16   # doubled from 8
			const _T_PERIOD : float = 0.55  # seconds per burst cycle per tendril
			const _T_FADE   : float = 0.65  # fraction of period where it's still visible
			const _T_REACH  : float = 18.0  # max outward distance (px)
			for _ti in _T_COUNT:
				# Stagger start times so they don't all fire at once
				var _offset  = float(_ti) / float(_T_COUNT) * _T_PERIOD
				var _life    = fmod(_aura_t + _offset, _T_PERIOD) / _T_PERIOD  # 0→1
				if _life > _T_FADE:
					continue   # dead — skip drawing
				var _norm    = _life / _T_FADE            # 0→1 normalized within visible window
				var _talpha  = (1.0 - _norm) * 0.80      # bright at birth, gone by end
				# Each tendril fires in a fixed direction (spread evenly + small hash offset)
				var _tangle  = float(_ti) / float(_T_COUNT) * TAU + float(_ti) * 0.37
				var _tdir    = Vector2(cos(_tangle), sin(_tangle))
				# Shoot from near the cloud edge outward
				var _tstart  = _norm * 8.0               # base moves out too (not stuck at center)
				var _tend    = _tstart + _norm * _T_REACH
				var _tp0     = _c + _tdir * _tstart
				var _tp1     = _c + _tdir * _tend
				draw_line(_tp0, _tp1, Color(1.00, 0.88, 0.25, _talpha), 1.4)
			# ── Sparkles: burst from center, scatter outward, vanish ──
			const _S_COUNT  : int   = 10   # doubled from 5
			const _S_PERIOD : float = 0.40  # faster cycle than tendrils
			const _S_FADE   : float = 0.70
			const _S_REACH  : float = 22.0
			for _si in _S_COUNT:
				var _soffset = float(_si) / float(_S_COUNT) * _S_PERIOD
				var _slife   = fmod(_aura_t * 1.3 + _soffset, _S_PERIOD) / _S_PERIOD
				if _slife > _S_FADE:
					continue
				var _snorm   = _slife / _S_FADE
				var _salpha  = (1.0 - _snorm) * 0.95
				var _sangle  = float(_si) / float(_S_COUNT) * TAU + float(_si) * 0.61
				var _sdir    = Vector2(cos(_sangle), sin(_sangle))
				var _sdist   = _snorm * _S_REACH
				var _sp2     = _c + _sdir * _sdist
				var _ssz     = lerpf(2.2, 0.4, _snorm)   # large at birth, tiny at death
				draw_circle(_sp2, _ssz, Color(1.00, 0.97, 0.60, _salpha))
				# Tiny bright hot-white core on young sparkles
				if _snorm < 0.35:
					draw_circle(_sp2, _ssz * 0.45, Color(1.00, 1.00, 1.00, _salpha * 0.80))
			break

	# ── Character ground shadow (sun from NW — shadow falls SE) ─────
	if not _mounted:
		_draw_character_shadow()

	# ── Dizzy stars effect ───────────────────────────────────
	if state_dizzy > 0.0 and not _mounted:
		var t = _aura_t
		var star_y = -60.0  # Above character head
		for i in 5:
			var angle = t * 3.0 + float(i) * TAU / 5.0
			var r = 14.0
			var sx = cos(angle) * r
			var sy = sin(angle) * r * 0.4  # Flatten for isometric
			var star_alpha = 0.6 + sin(t * 5.0 + i * 1.5) * 0.3
			# Yellow star
			draw_circle(Vector2(sx, star_y + sy), 2.5, Color(1.0, 0.9, 0.2, star_alpha))
			# White sparkle core
			draw_circle(Vector2(sx, star_y + sy), 1.0, Color(1.0, 1.0, 1.0, star_alpha * 0.7))

	# ── Knockdown indicator ──────────────────────────────────
	if state_knockdown > 0.0 and not _mounted:
		var kd_alpha = 0.5 + sin(_aura_t * 3.0) * 0.3
		draw_string(_roboto, Vector2(-20, -70), "KNOCKED DOWN", HORIZONTAL_ALIGNMENT_CENTER, 50, 8, Color(1.0, 0.3, 0.2, kd_alpha))

	# Nameplate removed — name shown in target widget only

	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		return

	var col = _get_class_color()
	draw_circle(Vector2.ZERO, 14.0, col)
	draw_circle(Vector2.ZERO, 11.0, col.lightened(0.25))
	var fwd = _facing_to_vec() * 10.0
	draw_circle(fwd, 4.0, Color.WHITE)
	var shadow_pts := PackedVector2Array()
	for i in 12:
		var a = float(i) / 12.0 * TAU
		shadow_pts.append(Vector2(cos(a) * 14.0, sin(a) * 5.0) + Vector2(0, 16))
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.22))

func _draw_character_shadow() -> void:
	# Sprite-based shadow: draw current frame squished & darkened
	var sprite : AnimatedSprite2D = get_node_or_null("Sprite")
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim = sprite.animation
	var frame_idx = sprite.frame
	if not sprite.sprite_frames.has_animation(anim):
		return
	var tex = sprite.sprite_frames.get_frame_texture(anim, frame_idx)
	if tex == null:
		return
	var ts = tex.get_size()
	var sc = sprite.scale
	# Shadow transform: flatten vertically to 25%, shift SE (sun from NW)
	var shadow_scale_x = sc.x * 1.0
	var shadow_scale_y = sc.y * 0.25
	var off = sprite.offset * Vector2(sc.x, shadow_scale_y)
	var shadow_pos = Vector2(4, -2) + off  # SE offset
	draw_set_transform(shadow_pos, 0.0, Vector2(shadow_scale_x, shadow_scale_y))
	draw_texture(tex, -ts * 0.5, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _get_class_color() -> Color:
	match character_class:
		"melee":   return Color(0.9,  0.35, 0.20)
		"ranged":   return Color(0.35, 0.75, 0.90)
		"smuggler": return Color(0.85, 0.65, 0.25)
		"mage":     return Color(0.70, 0.40, 1.00)
		"scrapper": return Color(0.40, 0.85, 0.30)
	return Color.WHITE

func _facing_8dir(v: Vector2) -> String:
	var angle = v.angle()  # -PI..PI, 0 = right
	# Divide circle into 8 sectors of 45°, offset by 22.5°
	var deg = fmod(rad_to_deg(angle) + 360.0 + 22.5, 360.0)
	var sector = int(deg / 45.0)
	match sector:
		0: return "e"
		1: return "se"
		2: return "s"
		3: return "sw"
		4: return "w"
		5: return "nw"
		6: return "n"
		7: return "ne"
	return "s"

func _facing_to_vec() -> Vector2:
	match _facing:
		"n":  return Vector2(0, -1)
		"s":  return Vector2(0,  1)
		"e":  return Vector2(1,  0)
		"w":  return Vector2(-1, 0)
		"ne": return Vector2(1, -1).normalized()
		"nw": return Vector2(-1, -1).normalized()
		"se": return Vector2(1,  1).normalized()
		"sw": return Vector2(-1,  1).normalized()
	return Vector2(0, -1)  # fallback north rather than south

# ── AUTO-ATTACK ───────────────────────────────────────────────
func _tick_auto_attack(delta: float) -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	# Drop target if it left the targetable group (e.g. duel ended)
	if not _current_target.is_in_group("targetable"):
		_current_target = null
		return

	var attack_interval : float
	var attack_range    : float
	match character_class:
		"melee":
			attack_interval = 2.0
			attack_range    = 220.0
		"ranged", "smuggler":
			attack_interval = 2.5
			attack_range    = 700.0
		"mage":
			attack_interval = 4.0
			attack_range    = 700.0
		"scrapper":
			attack_interval = 2.0
			attack_range    = 130.0
		"medic":
			attack_interval = 3.0
			attack_range    = 500.0
		"streetfighter":
			attack_interval = 2.5
			attack_range    = 130.0
		_:
			attack_interval = 2.0
			attack_range    = 130.0

	# AGI (+ item AGI) gives +5% attack speed per point
	attack_interval /= (1.0 + (attr_agi + _item_agi) * 0.05)

	var dist = global_position.distance_to(_current_target.global_position)
	if dist > attack_range:
		_cancel_attack()
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_do_attack()

func _do_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return

	match character_class:
		"melee":             _move_lock_timer = 0.0
		"ranged", "smuggler": _move_lock_timer = 0.0
		"mage":              _move_lock_timer = 0.0
		"scrapper":          _move_lock_timer = 0.0
		"medic":             _move_lock_timer = 0.0

	var to_target = _current_target.global_position - global_position
	if character_class in ["melee", "medic", "scrapper", "streetfighter", "ranged"]:
		_facing = _facing_8dir(to_target)
	elif absf(to_target.x) >= absf(to_target.y):
		_facing = "e" if to_target.x > 0.0 else "w"
	else:
		_facing = "s" if to_target.y > 0.0 else "n"

	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	var anim_name = "attack_" + _facing
	# Street Fighter alternates between attack and attack2
	if character_class == "streetfighter":
		if _sf_attack_alt:
			anim_name = "attack2_" + _facing
		_sf_attack_alt = not _sf_attack_alt
	_is_attacking = true
	_blend_attack_anim = anim_name

	# Play attack animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		if sprite.animation_finished.is_connected(_on_attack_anim_done):
			sprite.animation_finished.disconnect(_on_attack_anim_done)
		sprite.animation_finished.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)

	var dmg : float
	if _one_shot_kill:
		var target_hp = _current_target.get("hp")
		dmg = target_hp if target_hp != null else 99999.0
		_one_shot_kill = false
	else:
		dmg = _get_attack_damage()

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	var is_ranged_atk = character_class in ["ranged", "smuggler", "mage", "medic"]
	var dmg_type = CombatEngine.get_weapon_damage_type(character_class)
	var target_pool = CombatEngine.get_weapon_target_pool(character_class)

	# ── SWG Hit Roll ─────────────────────────────────────────
	var attack_data = {"is_ranged": is_ranged_atk, "accuracy_bonus": 0}
	var hit_result = CombatEngine.roll_to_hit(self, _current_target, attack_data)
	match hit_result.get("result", "hit"):
		"miss":
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(_target_hit_pos(), 0, Color(0.6, 0.6, 0.6), "MISS")
			return
		"dodge":
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(_target_hit_pos(), 0, Color(0.4, 0.9, 1.0), "DODGE")
			return
		"block":
			dmg *= (1.0 - hit_result.get("reduction", 0.75))
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(_target_hit_pos(), 0, Color(0.8, 0.8, 0.2), "BLOCK")
		"counterattack":
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(global_position, 0, Color(1.0, 0.5, 0.2), "COUNTER")
			# Target gets a free hit back
			if _current_target.has_method("_do_attack"):
				pass  # Mobs don't have counter yet, handled in mob AI later

	# Apply armor resistance via CombatEngine
	dmg = CombatEngine.calc_damage(dmg, dmg_type, _current_target, attack_data)

	if character_class == "medic":
		var cap_arena  = arena
		var cap_dmg    = dmg
		var cap_target = _current_target
		var cap_heal   = _current_target.is_in_group("party_member") or _current_target.is_in_group("friendly")
		get_tree().create_timer(0.3).timeout.connect(func():
			if not is_instance_valid(cap_target): return
			var sp = global_position + _facing_to_vec() * 18.0
			if cap_arena and cap_arena.has_method("spawn_canister"):
				cap_arena.spawn_canister(sp, cap_target, cap_dmg, cap_heal)
			if _snd_medic_attack != null: _snd_medic_attack.play()
		)
	elif character_class == "mage":
		var cap_arena  = arena
		var cap_dmg    = dmg
		var cap_target = _current_target
		get_tree().create_timer(0.3).timeout.connect(func():
			if not is_instance_valid(cap_target): return
			var sp = global_position + _facing_to_vec() * 18.0
			if cap_arena and cap_arena.has_method("spawn_fireball"):
				cap_arena.spawn_fireball(sp, cap_target, cap_dmg)
		)
	elif character_class in ["ranged", "smuggler"]:
		var rifle_glow_col = Color(0, 0, 0, 0)
		for item in inventory:
			if item.get("equipped", false) and item.get("type", "") == "rifle":
				match item.get("rarity", ""):
					"white": rifle_glow_col = Color(0.92, 0.95, 1.00)
					"blue":  rifle_glow_col = Color(0.35, 0.72, 1.00)
					"gold":  rifle_glow_col = Color(1.00, 0.82, 0.15)
				break
		var cap_arena  = arena
		var cap_dmg    = dmg
		var cap_target = _current_target
		var cap_glow   = rifle_glow_col
		var fire_delay = 0.75 if _ranged_first_attack else 0.5
		_ranged_first_attack = false
		get_tree().create_timer(fire_delay).timeout.connect(func():
			if not is_instance_valid(cap_target): return
			var sp = global_position + _facing_to_vec() * 18.0
			if cap_arena and cap_arena.has_method("spawn_bullet"):
				var bullet = cap_arena.spawn_bullet(sp, cap_target, cap_dmg)
				if bullet != null and cap_glow.a > 0.0:
					bullet.set("rifle_glow", cap_glow)
			if _snd_rifle_shot != null: _snd_rifle_shot.play()
			_try_spawn_weapon_swing()
		)
	else:
		if _current_target.has_method("take_damage"):
			# Mobs only accept 1 arg; players accept 2 (with pool)
			if _current_target.get("ham_health") != null:
				_current_target.take_damage(dmg, target_pool)
			else:
				_current_target.take_damage(dmg)
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_target_hit_pos(), dmg, _get_dmg_color())
		if arena and arena.has_method("spawn_melee_hit"):
			var hit_pos = _target_hit_pos() + Vector2(randf_range(-12.0, 12.0), randf_range(-18.0, 18.0))
			arena.spawn_melee_hit(hit_pos, _get_dmg_color())
		if _snd_melee_hits.size() > 0:
			_snd_melee_hits[randi() % _snd_melee_hits.size()].play()
		# Weapon swing visual for any equipped knife
		_try_spawn_weapon_swing()

func _try_spawn_weapon_swing() -> void:
	for item in inventory:
		var t = item.get("type", "")
		if item.get("equipped", false) and (t == "knife" or t == "rifle"):
			var script = load("res://Scripts/BossWeaponSwing.gd")
			var swing  = Node2D.new()
			swing.set_script(script)
			swing.position = Vector2(0, -15)
			add_child(swing)
			swing.call("init", item, _facing)
			var _relay = get_node_or_null("/root/Relay")
			if _relay and _relay.has_method("send_game_data"):
				_relay.send_game_data({
					"cmd":    "swing",
					"facing": _facing,
					"itype":  item.get("type",   "knife"),
					"rarity": item.get("rarity", "white"),
				})
			return   # only one swing per attack

func _tick_skills(delta: float) -> void:
	# Sprint
	if _sprint_active:
		_sprint_timer -= delta
		var _bb2 = get_node_or_null("BuffBar")
		if _bb2 and _bb2.has_method("update_buff"):
			_bb2.call("update_buff", "sprint", _sprint_timer)
		if _sprint_timer <= 0.0:
			_sprint_active = false
			if _bb2 and _bb2.has_method("remove_buff"):
				_bb2.call("remove_buff", "sprint")

	# Sensu Bean healing
	if _sensu_active:
		_sensu_timer -= delta
		var heal_rate = max_hp / SENSU_DURATION
		hp = minf(hp + heal_rate * delta, max_hp)
		var mp_rate = max_mp / SENSU_DURATION
		mp = minf(mp + mp_rate * delta, max_mp)
		var _bb_st = get_node_or_null("BuffBar")
		if _bb_st and _bb_st.has_method("update_buff"):
			_bb_st.call("update_buff", "sensu_bean", _sensu_timer)
		if _sensu_timer <= 0.0:
			_sensu_active = false
			if _bb_st and _bb_st.has_method("remove_buff"):
				_bb_st.call("remove_buff", "sensu_bean")

func activate_skill(skill_id: String) -> void:
	if state_knockdown > 0.0:
		return  # KD: only stand up (space bar) allowed
	# Instant utility skills bypass the queue
	match skill_id:
		"sprint":
			_sprint_active = true
			_sprint_timer  = SPRINT_DURATION
			var _bb = get_node_or_null("BuffBar")
			if _bb and _bb.has_method("add_buff"):
				_bb.call("add_buff", {
					"id": "sprint", "icon": "sprint",
					"label": "Sprint", "duration": SPRINT_DURATION,
					"color": Color(0.35, 0.80, 1.00)
				})
			return
		"sensu_bean":
			_sensu_active = true
			_sensu_timer  = SENSU_DURATION
			var _bb_s = get_node_or_null("BuffBar")
			if _bb_s and _bb_s.has_method("add_buff"):
				_bb_s.call("add_buff", {
					"id": "sensu_bean", "icon": "sensu",
					"label": "Sensu Bean", "duration": SENSU_DURATION,
					"color": Color(0.25, 0.85, 0.40)
				})
			return

	# Everything else goes into the combat queue
	_queue_ability(skill_id)

# ── COMBAT QUEUE ─────────────────────────────────────────────
func _queue_ability(skill_id: String) -> void:
	if _combat_queue.size() >= MAX_QUEUE_SIZE:
		_spawn_floating_text("Queue full!", Color(1.0, 0.5, 0.3))
		return
	_combat_queue.append(skill_id)
	_notify_queue_display()

func dequeue_ability(skill_id: String) -> void:
	var idx = _combat_queue.find(skill_id)
	if idx >= 0:
		_combat_queue.remove_at(idx)
		_notify_queue_display()

func _notify_queue_display() -> void:
	var bar = get_node_or_null("ActionBar")
	if bar and bar.has_method("update_queue_display"):
		bar.call("update_queue_display", _combat_queue)

func _tick_combat_queue(delta: float) -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		_combat_queue.clear()
		_is_attacking = false
		return
	if not _current_target.is_in_group("targetable"):
		_current_target = null
		_combat_queue.clear()
		_is_attacking = false
		return
	# Check if target is dying
	var tgt_dying = _current_target.get("_dying")
	if tgt_dying == true:
		_current_target = null
		_combat_queue.clear()
		_is_attacking = false
		return
	if state_stun > 0.0 or state_knockdown > 0.0 or _incapped:
		return

	# Range check
	var attack_range : float = 130.0
	match character_class:
		"ranged", "smuggler", "mage": attack_range = 700.0
		"medic": attack_range = 500.0
		"melee", "scrapper": attack_range = 220.0
	var dist = global_position.distance_to(_current_target.global_position)
	if dist > attack_range:
		_cancel_attack()
		return

	_queue_timer -= delta
	if _queue_timer > 0.0:
		return

	# Calculate attack speed (base interval modified by skills)
	var base_interval = _queue_speed
	match character_class:
		"melee", "scrapper": base_interval = 2.0
		"ranged", "smuggler": base_interval = 2.5
		"mage": base_interval = 3.5
		"streetfighter": base_interval = 2.5
		"medic": base_interval = 3.0
	# Faster with AGI
	base_interval /= (1.0 + (attr_agi + _item_agi) * 0.05)
	# End-game minimum: 1 second
	base_interval = maxf(base_interval, 1.0)
	_queue_timer = base_interval

	if _combat_queue.size() > 0:
		# Pop next ability from queue and execute
		var next_skill = _combat_queue.pop_front()
		_notify_queue_display()

		if next_skill == "triple_strike":
			_triple_active = true
			_triple_hits_left = 3
			_fire_triple_strike()
		else:
			_execute_profession_ability(next_skill)
	else:
		# Queue empty — auto-attack (basic attack)
		_do_attack()

# ── PROFESSION ABILITIES ─────────────────────────────────────
# Ability definitions: damage mult, action/mind cost, state applied, etc.
const ABILITY_DATA : Dictionary = {
	"dizzy_punch":    {"dmg_mult": 1.2, "action_cost": 40, "state": "dizzy", "state_dur": 8.0, "cooldown": 0.0},
	"knockout_blow":  {"dmg_mult": 1.8, "action_cost": 60, "state": "knockdown", "state_dur": 5.0, "cooldown": 0.0},
	"riposte":        {"dmg_mult": 1.3, "action_cost": 35, "state": "", "state_dur": 0.0, "cooldown": 8.0},
	"blade_flurry":   {"dmg_mult": 0.6, "action_cost": 50, "state": "", "state_dur": 0.0, "cooldown": 10.0, "hits": 3},
	"power_attack":   {"dmg_mult": 2.0, "action_cost": 70, "state": "", "state_dur": 0.0, "cooldown": 15.0},
	"cleave":         {"dmg_mult": 1.5, "action_cost": 60, "state": "knockdown", "state_dur": 4.0, "cooldown": 18.0},
	"leg_sweep":      {"dmg_mult": 0.8, "action_cost": 40, "state": "dizzy", "state_dur": 10.0, "cooldown": 14.0},
	"impale":         {"dmg_mult": 2.2, "action_cost": 80, "state": "", "state_dur": 0.0, "cooldown": 22.0},
	"spinning_kick":  {"dmg_mult": 1.4, "action_cost": 45, "state": "dizzy", "state_dur": 6.0, "cooldown": 10.0},
	"intimidate":     {"dmg_mult": 0.5, "action_cost": 30, "state": "intimidate", "state_dur": 15.0, "cooldown": 25.0},
	"warcry":         {"dmg_mult": 0.3, "action_cost": 50, "state": "intimidate", "state_dur": 20.0, "cooldown": 30.0},
	"berserk":        {"dmg_mult": 2.5, "action_cost": 100, "state": "", "state_dur": 0.0, "cooldown": 30.0},
	"body_shot":      {"dmg_mult": 1.3, "action_cost": 35, "state": "", "state_dur": 0.0, "cooldown": 8.0, "pool": "health"},
	"fan_shot":       {"dmg_mult": 0.7, "action_cost": 50, "state": "", "state_dur": 0.0, "cooldown": 12.0, "hits": 3},
	"aimed_shot":     {"dmg_mult": 1.8, "action_cost": 60, "state": "", "state_dur": 0.0, "cooldown": 15.0},
	"headshot":       {"dmg_mult": 2.5, "action_cost": 90, "state": "stun", "state_dur": 4.0, "cooldown": 25.0},
	"scatter_shot":   {"dmg_mult": 1.0, "action_cost": 40, "state": "dizzy", "state_dur": 6.0, "cooldown": 10.0},
	"rapid_fire":     {"dmg_mult": 0.5, "action_cost": 55, "state": "", "state_dur": 0.0, "cooldown": 10.0, "hits": 4},
	"leg_shot":       {"dmg_mult": 0.9, "action_cost": 35, "state": "dizzy", "state_dur": 8.0, "cooldown": 12.0},
	"flash_grenade":  {"dmg_mult": 0.3, "action_cost": 60, "state": "blind", "state_dur": 10.0, "cooldown": 30.0},
	"called_shot":    {"dmg_mult": 2.0, "action_cost": 80, "state": "stun", "state_dur": 5.0, "cooldown": 20.0},
	"stim_health":    {"dmg_mult": 0.0, "action_cost": 30, "state": "", "state_dur": 0.0, "cooldown": 8.0, "heal": "health", "heal_amt": 100},
	"stim_action":    {"dmg_mult": 0.0, "action_cost": 30, "state": "", "state_dur": 0.0, "cooldown": 8.0, "heal": "action", "heal_amt": 100},
	"stim_mind":      {"dmg_mult": 0.0, "action_cost": 30, "state": "", "state_dur": 0.0, "cooldown": 8.0, "heal": "mind", "heal_amt": 100},
	"bacta_infusion": {"dmg_mult": 0.0, "action_cost": 80, "state": "", "state_dur": 0.0, "cooldown": 20.0, "heal": "health", "heal_amt": 300},
	"poison_dart":    {"dmg_mult": 0.8, "action_cost": 40, "state": "", "state_dur": 0.0, "cooldown": 12.0, "pool": "action"},
	"neurotoxin":     {"dmg_mult": 1.0, "action_cost": 60, "state": "stun", "state_dur": 3.0, "cooldown": 18.0, "pool": "mind"},
	"cure_state":     {"dmg_mult": 0.0, "action_cost": 40, "state": "", "state_dur": 0.0, "cooldown": 15.0, "cure": true},
	"revive":         {"dmg_mult": 0.0, "action_cost": 100, "state": "", "state_dur": 0.0, "cooldown": 60.0, "heal": "health", "heal_amt": 200},
	"full_heal":      {"dmg_mult": 0.0, "action_cost": 150, "state": "", "state_dur": 0.0, "cooldown": 45.0, "heal": "all", "heal_amt": 500},
	"force_lightning": {"dmg_mult": 1.8, "mind_cost": 60, "state": "", "state_dur": 0.0, "cooldown": 10.0, "pool": "mind"},
	"force_choke":    {"dmg_mult": 1.2, "mind_cost": 80, "state": "stun", "state_dur": 5.0, "cooldown": 20.0, "pool": "mind"},
	"force_shield":   {"dmg_mult": 0.0, "mind_cost": 50, "state": "", "state_dur": 0.0, "cooldown": 25.0, "self_buff": "shield"},
	"force_absorb":   {"dmg_mult": 0.0, "mind_cost": 70, "state": "", "state_dur": 0.0, "cooldown": 30.0, "self_buff": "absorb"},
	"force_heal":     {"dmg_mult": 0.0, "mind_cost": 40, "state": "", "state_dur": 0.0, "cooldown": 10.0, "heal": "health", "heal_amt": 150},
	"force_revive":   {"dmg_mult": 0.0, "mind_cost": 100, "state": "", "state_dur": 0.0, "cooldown": 45.0, "heal": "all", "heal_amt": 400},
	"mind_trick":     {"dmg_mult": 0.5, "mind_cost": 90, "state": "blind", "state_dur": 12.0, "cooldown": 30.0, "pool": "mind"},
	"saber_throw":    {"dmg_mult": 1.5, "mind_cost": 50, "state": "", "state_dur": 0.0, "cooldown": 12.0},
	"saber_flurry":   {"dmg_mult": 0.6, "mind_cost": 60, "state": "", "state_dur": 0.0, "cooldown": 10.0, "hits": 3},
}

func _execute_profession_ability(skill_id: String) -> void:
	print("[ABILITY] Executing: ", skill_id)
	var data = ABILITY_DATA.get(skill_id, {})
	if data.is_empty():
		print("[ABILITY] Not found in ABILITY_DATA!")
		_spawn_floating_text("Unknown ability: " + skill_id, Color(1.0, 0.3, 0.3))
		return

	# Check cost
	var action_cost = data.get("action_cost", 0)
	var mind_cost = data.get("mind_cost", 0)
	if action_cost > 0 and ham_action < action_cost:
		_spawn_floating_text("Not enough Action", Color(1.0, 0.7, 0.2))
		return
	if mind_cost > 0 and ham_mind < mind_cost:
		_spawn_floating_text("Not enough Mind", Color(0.4, 0.6, 1.0))
		return

	# Pay cost
	if action_cost > 0: ham_action -= action_cost
	if mind_cost > 0: ham_mind -= mind_cost

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")

	# Self-heal abilities
	var heal_type = data.get("heal", "")
	if heal_type != "":
		var amt = data.get("heal_amt", 100)
		match heal_type:
			"health": ham_health = minf(ham_health + amt, get_effective_max_health())
			"action": ham_action = minf(ham_action + amt, get_effective_max_action())
			"mind":   ham_mind = minf(ham_mind + amt, get_effective_max_mind())
			"all":
				ham_health = minf(ham_health + amt, get_effective_max_health())
				ham_action = minf(ham_action + amt, get_effective_max_action())
				ham_mind = minf(ham_mind + amt, get_effective_max_mind())
		_spawn_floating_text("+%d %s" % [amt, heal_type.to_upper()], Color(0.3, 1.0, 0.5))
		return

	# Cure state ability
	if data.get("cure", false):
		state_dizzy = 0.0; state_knockdown = 0.0; state_stun = 0.0
		state_blind = 0.0; state_intimidate = 0.0
		_spawn_floating_text("STATES CURED", Color(0.3, 1.0, 0.5))
		return

	# Self-buff
	var self_buff = data.get("self_buff", "")
	if self_buff != "":
		var bb = get_node_or_null("BuffBar")
		if bb and bb.has_method("add_buff"):
			bb.call("add_buff", {"id": self_buff, "icon": skill_id, "label": skill_id.replace("_"," ").capitalize(), "duration": 30.0, "color": Color(0.4, 0.7, 1.0)})
		_spawn_floating_text(self_buff.to_upper(), Color(0.4, 0.8, 1.0))
		return

	# Combat abilities — need a target
	if _current_target == null or not is_instance_valid(_current_target):
		_spawn_floating_text("No target", Color(1.0, 0.5, 0.3))
		return

	# Hit roll
	var is_ranged = character_class in ["ranged", "smuggler", "mage", "medic"]
	var attack_data = {"is_ranged": is_ranged, "accuracy_bonus": 10}
	var hit_result = CombatEngine.roll_to_hit(self, _current_target, attack_data)
	match hit_result.get("result", "hit"):
		"miss":
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(_target_hit_pos(), 0, Color(0.6, 0.6, 0.6), "MISS")
			return
		"dodge":
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(_target_hit_pos(), 0, Color(0.4, 0.9, 1.0), "DODGE")
			return
		"block":
			pass  # Reduced damage below

	# Calculate damage
	var base_dmg = _get_attack_damage()
	var dmg = base_dmg * data.get("dmg_mult", 1.0)
	if hit_result.get("result") == "block":
		dmg *= 0.25

	var target_pool = data.get("pool", CombatEngine.get_weapon_target_pool(character_class))
	var dmg_type = CombatEngine.get_weapon_damage_type(character_class)
	dmg = CombatEngine.calc_damage(dmg, dmg_type, _current_target)

	# Apply damage (multi-hit or single)
	var hits = data.get("hits", 1)
	for _h in hits:
		if _current_target.has_method("take_damage"):
			if _current_target.get("ham_health") != null:
				_current_target.take_damage(dmg / hits, target_pool)
			else:
				_current_target.take_damage(dmg / hits)
		if arena and arena.has_method("spawn_damage_number"):
			var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
			arena.spawn_damage_number(_target_hit_pos() + offset, dmg / hits, Color(1.0, 0.8, 0.2))

	# Hit flash effect on target
	if is_instance_valid(_current_target):
		_spawn_hit_flash(_target_hit_pos())

	# Apply state
	var state_name = data.get("state", "")
	if state_name != "" and data.get("state_dur", 0.0) > 0.0:
		CombatEngine.try_apply_state(self, _current_target, state_name, data.get("state_dur", 5.0))

	# Play attack animation
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	var to_target = _current_target.global_position - global_position
	_facing = _facing_8dir(to_target)
	var anim_name = "attack_" + _facing
	_is_attacking = true
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		if sprite.animation_finished.is_connected(_on_attack_anim_done):
			sprite.animation_finished.disconnect(_on_attack_anim_done)
		sprite.animation_finished.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)

func _fire_triple_strike() -> void:
	if not _triple_active or _triple_hits_left <= 0:
		_triple_active = false
		return
	if _current_target == null or not is_instance_valid(_current_target):
		_triple_active = false
		return

	# Play (or restart) the attack animation for this hit.
	var ts_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if ts_sprite and ts_sprite.sprite_frames:
		var ts_anim = "attack_" + _facing
		if ts_sprite.sprite_frames.has_animation(ts_anim):
			# Disconnect any pending done-callback so it doesn't fire mid-sequence
			if ts_sprite.animation_finished.is_connected(_on_attack_anim_done):
				ts_sprite.animation_finished.disconnect(_on_attack_anim_done)
			ts_sprite.stop()
			ts_sprite.play(ts_anim)
			_is_attacking = true
			# Only hook cleanup on the last hit so _is_attacking clears correctly
			if _triple_hits_left == 1:
				ts_sprite.animation_finished.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	var dmg = _get_attack_damage()
	# All classes fire their natural attack type
	if character_class == "medic":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		var is_heal = _current_target.is_in_group("party_member") or _current_target.is_in_group("friendly")
		if arena and arena.has_method("spawn_canister"):
			arena.spawn_canister(spawn_pos, _current_target, dmg, is_heal)
	elif character_class == "mage":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		if arena and arena.has_method("spawn_fireball"):
			arena.spawn_fireball(spawn_pos, _current_target, dmg)
	elif character_class in ["ranged", "smuggler"]:
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		if arena and arena.has_method("spawn_bullet"):
			var bullet = arena.spawn_bullet(spawn_pos, _current_target, dmg)
			var rifle_glow_col = Color(0,0,0,0)
			for item in inventory:
				if item.get("equipped", false) and item.get("type","") == "rifle":
					match item.get("rarity",""):
						"white": rifle_glow_col = Color(0.92,0.95,1.00)
						"blue":  rifle_glow_col = Color(0.35,0.72,1.00)
						"gold":  rifle_glow_col = Color(1.00,0.82,0.15)
					break
			if bullet != null and rifle_glow_col.a > 0.0:
				bullet.set("rifle_glow", rifle_glow_col)
		if _snd_rifle_shot != null: _snd_rifle_shot.play()
	else:
		if _current_target.has_method("take_damage"):
			_current_target.take_damage(dmg)
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_target_hit_pos(), dmg, _get_dmg_color())
		if arena and arena.has_method("spawn_melee_hit"):
			var hit_pos = _target_hit_pos() + Vector2(randf_range(-12.0,12.0), randf_range(-18.0,18.0))
			arena.spawn_melee_hit(hit_pos, _get_dmg_color())
		if _snd_melee_hits.size() > 0:
			_snd_melee_hits[randi() % _snd_melee_hits.size()].play()
		_try_spawn_weapon_swing()
	_triple_hits_left -= 1
	if _triple_hits_left > 0:
		# Fire next hit after a short delay
		get_tree().create_timer(0.18).timeout.connect(_fire_triple_strike)
	else:
		_triple_active = false

func _get_attack_damage() -> float:
	var eff_str = attr_str + _item_str
	var eff_agi = attr_agi + _item_agi
	var eff_int = attr_int + _item_int
	var eff_spi = attr_spi + _item_spi

	var base : float
	match character_class:
		"melee":
			base = randf_range(18.0, 28.0) + eff_str * 5.0
		"ranged", "smuggler":
			base = randf_range(12.0, 20.0)
		"mage":
			base = randf_range(22.0, 35.0)
			base *= (1.0 + eff_int * 0.05)
			base += eff_spi * 5.0
		"scrapper":
			base = randf_range(20.0, 32.0) + eff_str * 5.0
		"streetfighter":
			base = randf_range(28.0, 42.0) + eff_str * 6.0
		"medic":
			base = 25.0 + eff_spi * 3.0
		_:
			base = 10.0

	# AGI crit: +2% crit chance per point, crits deal 1.5x
	if randf() < eff_agi * 0.02:
		base *= 1.5

	return base + _item_dmg_bonus

func _get_dmg_color() -> Color:
	match character_class:
		"melee":   return Color(1.0, 0.55, 0.1)
		"ranged", "smuggler": return Color(0.4, 0.95, 1.0)
		"mage":               return Color(0.9, 0.5,  1.0)
		"scrapper": return Color(1.0, 0.55, 0.1)
		"medic":   return Color(0.30, 0.85, 0.95)
	return Color.WHITE

var _post_attack_hold : float = 0.0

func _on_attack_anim_done() -> void:
	_is_attacking = false
	_post_attack_hold = 0.15  # Hold last attack frame briefly before switching to idle

var _lower_clip_mat : ShaderMaterial = null
func _get_lower_clip_material() -> ShaderMaterial:
	if _lower_clip_mat == null:
		var sh = Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tif (UV.y < 0.45) discard;\n}\n"
		_lower_clip_mat = ShaderMaterial.new()
		_lower_clip_mat.shader = sh
	return _lower_clip_mat

func _cancel_attack() -> void:
	_is_attacking = false
	_blend_attack_anim = ""
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite:
		if sprite.animation_finished.is_connected(_on_attack_anim_done):
			sprite.animation_finished.disconnect(_on_attack_anim_done)
		sprite.material = null
	var upper = get_node_or_null("SpriteUpper") as AnimatedSprite2D
	if upper:
		if upper.animation_finished.is_connected(_on_attack_anim_done):
			upper.animation_finished.disconnect(_on_attack_anim_done)
		upper.visible = false

# ── TARGET SYSTEM ─────────────────────────────────────────────
func _refresh_target_candidates() -> void:
	var all_targets = get_tree().get_nodes_in_group("targetable")

	var fwd = _facing_to_vec()
	var cone_hits   : Array = []
	var circle_hits : Array = []

	for node in all_targets:
		if not is_instance_valid(node):
			continue
		if node == self:
			continue
		var to_node = node.global_position - global_position
		var dist    = to_node.length()

		if dist < TARGET_CONE_RANGE:
			var angle_diff = fwd.angle_to(to_node.normalized())
			if absf(angle_diff) < deg_to_rad(TARGET_CONE_ANGLE):
				cone_hits.append({"node": node, "dist": dist})

		if dist < TARGET_CIRCLE_RANGE:
			circle_hits.append({"node": node, "dist": dist})

	cone_hits.sort_custom(func(a, b): return a.dist < b.dist)
	circle_hits.sort_custom(func(a, b): return a.dist < b.dist)

	var new_candidates : Array = []
	for h in cone_hits:
		new_candidates.append(h.node)
	for h in circle_hits:
		if not new_candidates.has(h.node):
			new_candidates.append(h.node)

	_target_candidates = new_candidates

	if _current_target != null:
		if not is_instance_valid(_current_target) or not _target_candidates.has(_current_target):
			_current_target = null
			_target_idx = -1
		else:
			_target_idx = _target_candidates.find(_current_target)

func _cycle_target() -> void:
	if _target_candidates.is_empty():
		_current_target = null
		return
	_target_idx = (_target_idx + 1) % _target_candidates.size()
	_current_target = _target_candidates[_target_idx]
	_attack_timer        = 0.5
	_queue_timer         = 0.5  # short pre-combat delay, clears any leftover timer from prev fight
	_ranged_first_attack = true

# ── PUBLIC INTERFACE ──────────────────────────────────────────
func get_current_target() -> Node:
	return _current_target

func is_targeted(node: Node) -> bool:
	return node == _current_target

# ── DAMAGE / DEATH ────────────────────────────────────────────
func _tick_ham_regen(delta: float) -> void:
	if _dying or _incapped:
		return
	if _combat_timer > 0.0:
		_combat_timer -= delta
	var in_combat = _combat_timer > 0.0
	var h_rate : float
	var a_rate : float
	var m_rate : float
	if in_combat:
		# Very slow trickle during combat — ~0.25 HP/s
		h_rate = 0.25; a_rate = 0.25; m_rate = 0.25
	else:
		# Out of combat: 2 base + secondary stat bonus per second
		h_rate = 2.0 + stat_constitution * 1.5
		a_rate = 2.0 + stat_stamina      * 1.5
		m_rate = 2.0 + stat_willpower    * 1.5
	ham_health = minf(ham_health + h_rate * delta, get_effective_max_health())
	ham_action = minf(ham_action + a_rate * delta, get_effective_max_action())
	ham_mind   = minf(ham_mind   + m_rate * delta, get_effective_max_mind())

func take_damage(amount: float, target_pool: String = "health") -> void:
	if _dying or _incapped:
		return
	_combat_timer = COMBAT_LINGER  # Enter/extend combat window
	# STR (+ item STR): +5% damage reduction per point
	var reduction = (stat_strength + _item_str) * 0.05
	amount *= maxf(0.0, 1.0 - reduction)
	match target_pool:
		"health": ham_health = maxf(0.0, ham_health - amount)
		"action": ham_action = maxf(0.0, ham_action - amount)
		"mind":   ham_mind   = maxf(0.0, ham_mind - amount)
		_:        ham_health = maxf(0.0, ham_health - amount)
	# Any pool hitting 0 → incapacitation
	if ham_health <= 0.0 or ham_action <= 0.0 or ham_mind <= 0.0:
		_incapacitate()

func _incapacitate() -> void:
	incap_count += 1
	# Each incap adds wounds — reduces max pools until healed at a terminal
	var w_amt = randf_range(10.0, 25.0)
	wound_health = minf(wound_health + w_amt, _base_ham_health * 0.5)
	wound_action = minf(wound_action + randf_range(8.0, 20.0), _base_ham_action * 0.5)
	wound_mind   = minf(wound_mind   + randf_range(8.0, 20.0), _base_ham_mind * 0.5)
	if incap_count >= MAX_INCAPS:
		_die()
		return
	_incapped = true
	_incap_timer = INCAP_DURATION
	# Restore to 25% of each pool
	ham_health = get_effective_max_health() * 0.25
	ham_action = get_effective_max_action() * 0.25
	ham_mind   = get_effective_max_mind() * 0.25
	_current_target = null
	_spawn_floating_text("INCAPACITATED (%d/%d)" % [incap_count, MAX_INCAPS], Color(1.0, 0.2, 0.2))

func _tick_incap(delta: float) -> void:
	if not _incapped: return
	_incap_timer -= delta
	if _incap_timer <= 0.0:
		_incapped = false
		_spawn_floating_text("RECOVERED", Color(0.3, 1.0, 0.4))

func _die() -> void:
	_dying = true
	_current_target = null
	var _relay = get_node_or_null("/root/Relay")
	if _relay and _relay.has_method("send_game_data"):
		_relay.send_game_data({"cmd": "death"})
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("on_player_died"):
		arena.call("on_player_died")
