extends Node3D

## 3D player controller for Coronet scene with combat + HUD.
## Attach to the root "Coronet" node.

# ── MOVEMENT ────────────────────────────────────────────────
const MOVE_SPEED := 5.0
const SPRINT_SPEED := 8.25  # 1.65x move speed
const ROTATION_SPEED := 25.0
const CAM_MOUSE_SENSITIVITY := 0.003
const CAM_DISTANCE := 12.0
const CAM_LOOK_OFFSET := Vector3(0.0, 1.0, 0.0)

# ── SPRINT ─────────────────────────────────────────────────
const SPRINT_DURATION := 15.0
const SPRINT_COOLDOWN := 30.0

# ── VEHICLE ────────────────────────────────────────────────
const VEHICLE_SPEED := 28.0
const VEHICLE_BOOST_SPEED := 70.0
const VEHICLE_FLY_SPEED := 8.0
const VEHICLE_MOUNT_RANGE := 5.0
const VEHICLE_CAM_DISTANCE := 20.0
const VEHICLE_TURN_SPEED := 4.0        # slower than character (25.0)
const VEHICLE_ACCEL := 8.0             # units/s² for normal speed ramp
const VEHICLE_BOOST_ACCEL := 12.0      # units/s² for boost ramp

# ── COMBAT ──────────────────────────────────────────────────
const ATTACK_RANGE_MELEE := 9.0
const ATTACK_RANGE_RANGED := 23.0
var ATTACK_COOLDOWN := 5.0        # seconds between auto-attacks (modified by equipped weapon)
const ATTACK_ANIM_DURATION := 1.0 # how long attack anim plays before resuming move
const BASE_DAMAGE := 40.0
const TARGET_CYCLE_RANGE := 30.0

# ── ANIMATION FBX PATHS ────────────────────────────────────
# ── MASTER ANIMATION SETS (new unified skeleton) ─────────────
# Shared animations (same for all professions)
const MASTER_SHARED_ANIMS := {
	"idle":    "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Idle_11_frame_rate_60.fbx",
	"idle2":   "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Idle_10_frame_rate_60.fbx",
	"walk":    "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Walking_frame_rate_60.fbx",
	"run":     "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Running_frame_rate_60.fbx",
	"kd":      "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Knock_Down_1_frame_rate_60.fbx",
	"dead":    "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Dead_frame_rate_60.fbx",
}
# Street Fighter (melee) attacks
const MELEE_ATTACK_ANIMS := {
	"attack":  "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Right_Hand_Sword_Slash_frame_rate_60.fbx",
	"dizzy":   "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Charged_Slash_frame_rate_60.fbx",
}
# Gunslinger (ranged) attacks
const RANGED_ATTACK_ANIMS := {
	"attack":     "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Cowboy_Quick_Draw_Shooting_frame_rate_60.fbx",
	"run_attack": "res://Coronet/Character/animations/Meshy_AI_biped_Animation_Run_and_Shoot_frame_rate_60.fbx",
}

# ── LEGACY ANIMATION SETS (old characters) ───────────────────
const SILVER_ANIMS := {
	"run":     "res://Coronet/silverarmor/run/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Running_withSkin.fbx",
	"walk":    "res://Coronet/silverarmor/walk/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Walking_withSkin.fbx",
	"attack":  "res://Coronet/silverarmor/attack/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Right_Hand_Sword_Slash_withSkin.fbx",
	"attack2": "res://Coronet/silverarmor/attack2/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Weapon_Combo_1_withSkin.fbx",
	"dodge":   "res://Coronet/silverarmor/dodge/Meshy_AI_Iron_Sentinel_biped_Animation_Counterstrike_withSkin.fbx",
	"kd":      "res://Coronet/silverarmor/kd/Meshy_AI_Iron_Sentinel_biped_Animation_Knock_Down_1_withSkin.fbx",
}
const RED_ANIMS := {
	"run":     "res://Coronet/Redarmor/run/Meshy_AI_Ember_Guard_biped/Meshy_AI_Ember_Guard_biped_Animation_Running_withSkin.fbx",
	"walk":    "res://Coronet/Redarmor/walk/Meshy_AI_Ember_Guard_biped/Meshy_AI_Ember_Guard_biped_Animation_Walking_withSkin.fbx",
	"attack":  "res://Coronet/Redarmor/attack/shootfromhip.fbx",
	"attack2": "res://Coronet/Redarmor/attack/shootfromhip.fbx",
	"dodge":   "res://Coronet/Redarmor/dodge/Meshy_AI_Ember_Guard_biped_Animation_Roll_Dodge_3_withSkin.fbx",
	"kd":      "res://Coronet/Redarmor/kd/Meshy_AI_Ember_Guard_biped_Animation_Knock_Down_1_withSkin.fbx",
}
const REDSOLDIER_ANIMS := {
	"walk":    "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Walking_frame_rate_60.fbx",
	"run":     "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Running_frame_rate_60.fbx",
	"attack":  "res://Coronet/redsoldier/shootingRGEDIT.fbx",
	"attack2": "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Draw_and_Shoot_Left_frame_rate_60.fbx",
	"dodge":   "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Stand_Dodge_frame_rate_60.fbx",
	"kd":      "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Knock_Down_1_frame_rate_60.fbx",
}
const WHITESOLDIER_ANIMS := {
	"walk":    "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Walking_frame_rate_60.fbx",
	"run":     "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Running_frame_rate_60.fbx",
	"attack":  "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Right_Hand_Sword_Slash_frame_rate_60.fbx",
	"attack2": "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Weapon_Combo_frame_rate_60.fbx",
	"dodge":   "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Stand_Dodge_frame_rate_60.fbx",
	"kd":      "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Knock_Down_1_frame_rate_60.fbx",
}

# Map character select ID → idle FBX path (for runtime spawning)
const CHAR_IDLE_FBX := {
	"RedArmor":     "res://Coronet/Redarmor/idle/Meshy_AI_Ember_Guard_biped/Meshy_AI_Ember_Guard_biped_Animation_Idle_11_withSkin.fbx",
	"SilverArmor":  "res://Coronet/silverarmor/idle/Meshy_AI_Iron_Sentinel_biped_Animation_Idle_frame_rate_60.fbx",
	"RedSoldier":   "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Idle_11_frame_rate_60.fbx",
	"WhiteSoldier":  "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Idle_11_frame_rate_60.fbx",
}
const CHAR_ANIM_SETS := {
	"RedArmor":     "RED",
	"SilverArmor":  "SILVER",
	"RedSoldier":   "REDSOLDIER",
	"WhiteSoldier":  "WHITESOLDIER",
}
const CHAR_CLASSES := {
	"RedArmor":     "ranged",
	"SilverArmor":  "melee",
	"RedSoldier":   "ranged",
	"WhiteSoldier":  "melee",
}
# Soldiers use walk for normal movement and run only for sprint
const CHAR_HAS_WALK := {
	"RedArmor":     false,
	"SilverArmor":  false,
	"RedSoldier":   true,
	"WhiteSoldier":  true,
}
const WALK_SPEED := 2.5  # slower than MOVE_SPEED (5.0)
const CHAR_DISPLAY_NAMES := {
	"RedArmor":     "Red Armor",
	"SilverArmor":  "Silver Sentinel",
	"RedSoldier":   "Red Soldier",
	"WhiteSoldier":  "White Soldier",
}

# Skins that have rigged FBX (skeleton + correct textures — work fully)
const SKIN_RIGGED_FBX := {
	"CloudTrooper": "res://Coronet/charactercolors/CloudTrooper/Meshy_AI_Azure_Sentinel_biped/Meshy_AI_Azure_Sentinel_biped_Animation_Walking_withSkin.fbx",
	"RedWedding": "res://Coronet/charactercolors/RedWedding/Meshy_AI_Azure_Sentinel_biped/Meshy_AI_Azure_Sentinel_biped_Animation_Walking_withSkin.fbx",
	"CyberBH": "res://Coronet/charactercolors/CyberBH/CyberBH_rigged.fbx",
	"DarkForest": "res://Coronet/charactercolors/DarkForest/DarkForest_rigged.fbx",
	"DesertStorm": "res://Coronet/charactercolors/DesertStorm/DesertStorm_rigged.fbx",
	"GilleCamo": "res://Coronet/charactercolors/GilleCamo/GilleCamo_rigged.fbx",
	"MoltenCore": "res://Coronet/charactercolors/MoltenCore/MoltenCore_rigged.fbx",
	"Silverium": "res://Coronet/charactercolors/Silverium/Silverium_rigged.fbx",
	"Tron": "res://Coronet/charactercolors/Tron/Tron_rigged.fbx",
	"TindremicSteel": "res://Coronet/charactercolors/TindremicSteel/TindremicSteel_rigged.fbx",
}

# Color tint for skins without rigged FBX (applied on top of profession's idle model)
const SKIN_TINT := {
	"CyberBH": Color(0.25, 0.85, 0.95),
	"DarkForest": Color(0.35, 0.55, 0.30),
	"DesertStorm": Color(0.90, 0.80, 0.55),
	"MoltenCore": Color(0.95, 0.55, 0.15),
	"Silverium": Color(0.78, 0.80, 0.85),
	"GilleCamo": Color(0.50, 0.58, 0.38),
	"Tron": Color(0.15, 0.90, 1.00),
	"TindremicSteel": Color(0.62, 0.64, 0.70),
}

# Skin ID → base color texture path (applied at runtime to master rigged model)
const SKIN_TEXTURE := {
	"TindremicSteel": "res://Coronet/Character/Skins/TindremicSteel/Meshy_AI__0325134432_texture_fbx/Meshy_AI__0325134432_texture.png",
	"CyberHunter": "res://Coronet/Character/Skins/CyberHunter/Meshy_AI__0325135932_texture_fbx/Meshy_AI__0325135932_texture_fbx/Meshy_AI__0325135932_texture.png",
	"DesertStorm": "res://Coronet/Character/Skins/DesertStorm/Meshy_AI__0325135607_texture_fbx/Meshy_AI__0325135607_texture_fbx/Meshy_AI__0325135607_texture.png",
	"RedWedding": "res://Coronet/Character/Skins/RedWedding/Meshy_AI__0325135906_texture_fbx/Meshy_AI__0325135906_texture_fbx/Meshy_AI__0325135906_texture.png",
}

# ── NODES ───────────────────────────────────────────────────
var _silver : Node3D
var _red    : Node3D
var _camera : Camera3D
var _active : Node3D
var _selected_char_id : String = ""
var _uses_walk := false  # true = currently in walk mode (toggled by ALT)
var _can_walk := false   # true = character has walk anim available
var _auto_run := false   # middle mouse toggles auto-run
var _in_combat : bool = false    # true when auto-attacking a target

var _silver_anim : AnimationPlayer
var _red_anim    : AnimationPlayer
var _silver_armature : Node3D
var _red_armature    : Node3D

# ── CAMERA ──────────────────────────────────────────────────
var _cam_zoom := 1.0
var _first_person := false
var _cam_yaw := 0.0
var _cam_pitch := 0.0
var _rmb_held := false
var _rmb_press_pos := Vector2.ZERO
var _rmb_press_time : int = 0
var _rmb_dragged := false

# ── PLAYER STATS ────────────────────────────────────────────
var ham_health : float = 1000.0
var max_health : float = 1000.0
var ham_action : float = 800.0
var max_action_stat : float = 800.0
var ham_mind   : float = 600.0
var max_mind   : float = 600.0
var accuracy   : float = 60.0
var defense    : float = 40.0
var character_class : String = "melee"

# ── WOUNDS ─────────────────────────────────────────────────
# Wounds reduce effective max HAM. They accumulate from combat.
var wound_health : float = 0.0
var wound_action : float = 0.0
var wound_mind   : float = 0.0
const WOUND_CHANCE := 0.15          # 15% chance per hit to inflict wounds
const WOUND_HEAL_RATE := 2.0        # points healed per second (passive regen)
const WOUND_AMOUNT_MIN := 5.0
const WOUND_AMOUNT_MAX := 20.0

# ── XP & LEVELING ──────────────────────────────────────────
var level : int = 1
var exp_points : float = 0.0
var exp_needed : float = 100.0      # 100 * level
var unspent_points : int = 0

# ── PROFESSION SYSTEM ─────────────────────────────────────
var _learned_boxes : Array = []         # box IDs the player has learned
var _xp_pools : Dictionary = {"melee": 0, "ranged": 0}
var _skill_points_available : int = 250
var _credits : int = 1000

# ── INVENTORY & EQUIPMENT ──────────────────────────────────
var inventory : Array = []  # Array of item dicts (from ItemData.create_instance)
var _equipped_weapon_node : Node3D = null  # visual mesh attached to hand

# Combat states
var state_dizzy : float = 0.0
var state_knockdown : float = 0.0
var state_stun : float = 0.0
var state_blind : float = 0.0
var state_intimidate : float = 0.0

# ── COMBAT ──────────────────────────────────────────────────
var _current_target : Node3D = null
var _auto_attacking := false
var _attack_timer := 0.0
var _attack_anim_timer := 0.0  # countdown for attack anim, then resume move anim
var _attack_cycle := 0         # alternates between 0 and 1 for melee attack swap
var _anim_state := "idle"  # idle, run, attack

# ── COMBAT QUEUE ────────────────────────────────────────────
var _combat_queue : Array = []   # skill IDs queued up
var _queue_timer : float = 0.0   # countdown to execute next queued skill
const QUEUE_MAX := 4
const QUEUE_INTERVAL := 3.0      # seconds between queued executions

# Queue HUD
var _queue_panel : Panel
var _queue_timer_bar : ColorRect
var _queue_rows : Array = []     # labels for each queue slot

# ── VEHICLE ─────────────────────────────────────────────────
var _vehicle_mount : Node3D = null
var _vehicle_base_y := 0.0
var _vehicle_hover_time := 0.0
var _mounted := false
var _mount_tween : Tween = null
var _vehicle_boosting := false
var _vehicle_cur_speed := 0.0  # current speed (ramps up/down)
var _vehicle_last_dir := Vector3.ZERO  # last horizontal movement direction
var _vehicle_can_fly := true  # false = ground only (landspeeder)
var _vehicle_prompt : Label3D = null
var _speed_lines : Array = []  # speed effect meshes

# ── SPRINT ────────────────────────────────────────────────
var _sprint_active := false
var _sprint_timer := 0.0
var _sprint_cooldown_timer := 0.0

# ── AMBIENT MUSIC + FOOTSTEPS ─────────────────────────────
var _music_player : AudioStreamPlayer = null
var _footstep_player : AudioStreamPlayer3D = null
var _footstep_playing := false

# ── RAIN ───────────────────────────────────────────────────
var _rain_particles : GPUParticles3D = null
var _rain_audio : AudioStreamPlayer = null
var _rain_enabled := false
var _lightning_timer := 0.0
var _lightning_flash_timer := 0.0
var _lightning_bolt : MeshInstance3D = null

# ── HUD ─────────────────────────────────────────────────────
var _hud : CanvasLayer
var _hp_bar : ProgressBar
var _action_bar : ProgressBar
var _mind_bar : ProgressBar
var _player_name_lbl : Label
var _tgt_panel : Panel
var _tgt_name_lbl : Label
var _tgt_hp_bar : ProgressBar
var _tgt_action_bar : ProgressBar
var _tgt_mind_bar : ProgressBar
var _combat_log : RichTextLabel
var _target_indicator : Node3D  # visual ring under target
var _player_buff_row : HBoxContainer
var _tgt_debuff_row : HBoxContainer
var _hp_wound_ov : ColorRect
var _action_wound_ov : ColorRect
var _mind_wound_ov : ColorRect
var _xp_bar : ProgressBar
var _xp_bar_lbl : Label
var _stats_window : Panel
var _stats_visible := false

# ── POSTURE ICON ──────────────────────────────────────────
var _posture_label : Label
var _posture_box : Panel
var _player_frame : Panel  # reference to pf for posture tracking
const _STANDING_ICON := "🧍"
const _KNOCKDOWN_ICON := "🧎"

# ── RADIAL MENU ───────────────────────────────────────────
var _radial_menu : Control = null
var _radial_menu_visible := false
var _radial_target_node : Node3D = null
var _radial_target_type : String = ""

# ── MINIMAP ────────────────────────────────────────────────
const MMAP_SIZE := 180
var _minimap_panel : Panel
var _minimap_draw : Control
var _minimap_zoom := 0.5  # world units per pixel
var _coord_label : Label
var _options_btn : Button
var _options_panel : Panel
var _options_visible := false

# ── CHAT ──────────────────────────────────────────────────
var _chat_panel : Panel
var _chat_log : RichTextLabel
var _chat_input : LineEdit
var _chat_visible := true

# ── MULTIPLAYER ───────────────────────────────────────────
var _remote_players : Dictionary = {}  # peer_id -> Node3D

# ── HOTBAR ─────────────────────────────────────────────────
const HOTBAR_SLOTS := 8
const SLOT_SIZE := 44
const SLOT_PAD := 4
var _hotbar_panel : Panel
var _hotbar_slots : Array = []      # Array of Panel (visual slots)
var _hotbar_skills : Array = []     # Array of Dictionary (skill data per slot)
var _hotbar_cooldowns : Array = []  # Array of float (cooldown timers)
var _hotbar_labels : Array = []     # Array of Label (key number labels)
var _hotbar_icons : Array = []      # Array of TextureRect (skill icons)
var _hotbar_cd_labels : Array = []  # Array of Label (cooldown text)
# ── SKILLS WINDOW ──────────────────────────────────────────
var _skills_window : Panel = null
var _skills_visible := false

# ── SKILL DEFINITIONS ──────────────────────────────────────
const SKILL_DATA := {
	"dizzy": {
		"id": "dizzy",
		"name": "Dizzy",
		"desc": "Disorients the target for 15 seconds, reducing accuracy.",
		"dmg_mult": 1.0,
		"action_cost": 40.0,
		"state": "dizzy",
		"state_dur": 15.0,
		"cooldown": 0.0,
		"color": Color(0.9, 0.8, 0.2),
		"icon": "res://Coronet/icons/dizzy.png",
	},
	"knockdown": {
		"id": "knockdown",
		"name": "Knockdown",
		"desc": "Knocks the target down. They must press SPACE to stand.",
		"dmg_mult": 1.5,
		"action_cost": 60.0,
		"state": "knockdown",
		"state_dur": 999.0,
		"cooldown": 0.0,
		"color": Color(0.9, 0.3, 0.2),
		"icon": "res://Coronet/icons/kd.png",
	},
	"sprint": {
		"id": "sprint",
		"name": "Sprint",
		"desc": "Run 65% faster for 15 seconds.",
		"dmg_mult": 0.0,
		"action_cost": 50.0,
		"state": "",
		"state_dur": 0.0,
		"cooldown": 30.0,
		"color": Color(0.3, 0.8, 1.0),
		"self_cast": true,
		"icon": "res://Coronet/icons/sprint.png",
	},
	"sensu_bean": {
		"id": "sensu_bean",
		"name": "Sensu Bean",
		"desc": "Heals all HAM pools to full over 10 seconds.",
		"dmg_mult": 0.0,
		"action_cost": 0.0,
		"state": "",
		"state_dur": 0.0,
		"cooldown": 30.0,
		"color": Color(0.2, 0.9, 0.3),
		"self_cast": true,
		"icon": "res://Coronet/icons/heal.png",
	},
}

# ── SENSU BEAN (heal over time) ────────────────────────────
var _sensu_active := false
var _sensu_timer := 0.0
const SENSU_DURATION := 10.0

# ── KD IMMUNITY ────────────────────────────────────────────
var _kd_immunity_timer := 0.0
const KD_IMMUNITY_DURATION := 30.0

# ════════════════════════════════════════════════════════════
#  READY
# ════════════════════════════════════════════════════════════
func _ready() -> void:
	_camera = $Camera3D

	# Check if character was selected from character select screen
	_selected_char_id = ""
	if get_tree().root.has_meta("selected_character"):
		_selected_char_id = get_tree().root.get_meta("selected_character")

	# If coming from character select, hide pre-placed scene characters and spawn selected
	if _selected_char_id != "" and _selected_char_id in CHAR_IDLE_FBX:
		# Hide all pre-placed character models
		for child in get_children():
			var n : String = child.name
			if "Iron_Sentinel" in n or "Ember_Guard" in n:
				child.visible = false
				child.process_mode = Node.PROCESS_MODE_DISABLED
		# Load the master rigged model
		var master_fbx : String = "res://Coronet/Character/mastermeshrigged.fbx"
		var fbx_path : String = master_fbx if ResourceLoader.exists(master_fbx) else CHAR_IDLE_FBX.get(_selected_char_id, "")
		if fbx_path != "" and ResourceLoader.exists(fbx_path):
			var scene : PackedScene = load(fbx_path)
			var inst : Node3D = scene.instantiate()
			inst.name = "PlayerCharacter"
			inst.position = Vector3(0, 0, 1.5)
			add_child(inst)
			_active = inst
			# Apply skin texture if available
			if PlayerData.skin != "" and PlayerData.skin in SKIN_TEXTURE:
				_apply_skin_texture(inst, SKIN_TEXTURE[PlayerData.skin])
		character_class = CHAR_CLASSES.get(_selected_char_id, PlayerData.char_class if PlayerData.char_class != "" else "melee")
		_can_walk = CHAR_HAS_WALK.get(_selected_char_id, true)
		_uses_walk = false
	else:
		# Default: use pre-placed scene characters (for testing without char select)
		_selected_char_id = "SilverArmor"
		for child in get_children():
			var n : String = child.name
			if "Iron_Sentinel" in n:
				_silver = child
			elif "Ember_Guard" in n:
				_red = child
		# Fall back: if neither found, spawn SilverArmor from FBX
		if _silver == null and _red == null:
			var fbx_path : String = CHAR_IDLE_FBX["SilverArmor"]
			if ResourceLoader.exists(fbx_path):
				var scene : PackedScene = load(fbx_path)
				var inst : Node3D = scene.instantiate()
				inst.name = "PlayerCharacter"
				inst.position = Vector3(0, 0, 1.5)
				add_child(inst)
				_silver = inst
		_active = _silver if _silver else _red
		character_class = "melee" if _silver else "ranged"
		_uses_walk = false

	if _active == null:
		push_error("No player character found or spawned!")
		return

	# Setup the active character
	var active_anim := _find_anim_player(_active)
	var active_armature : Node3D = _active.get_node_or_null("Armature") if _active else null

	# Store in _silver/_red slots for compatibility
	if _selected_char_id in ["SilverArmor", "WhiteSoldier"]:
		_silver = _active
		_silver_anim = active_anim
		_silver_armature = active_armature
		if _silver_armature:
			_silver_armature_rot = _silver_armature.rotation
	else:
		_red = _active
		_red_anim = active_anim
		_red_armature = active_armature
		if _red_armature:
			_red_armature_rot = _red_armature.rotation

	# Also set up the non-active default character if in test mode (no char select)
	if _selected_char_id == "SilverArmor" and _red:
		_red_anim = _find_anim_player(_red)
		_red_armature = _red.get_node_or_null("Armature")
		if _red_armature:
			_red_armature_rot = _red_armature.rotation

	# Pick the right anim set — use MASTER for new character system
	var _using_master : bool = ResourceLoader.exists("res://Coronet/Character/mastermeshrigged.fbx") and PlayerData.skin != ""
	var anim_dict : Dictionary
	if _using_master:
		# Merge shared + profession-specific attack anims
		anim_dict = MASTER_SHARED_ANIMS.duplicate()
		if PlayerData.char_class == "ranged":
			anim_dict.merge(RANGED_ATTACK_ANIMS)
		else:
			anim_dict.merge(MELEE_ATTACK_ANIMS)
	else:
		var anim_set_name : String = CHAR_ANIM_SETS.get(_selected_char_id, "SILVER")
		match anim_set_name:
			"RED": anim_dict = RED_ANIMS
			"REDSOLDIER": anim_dict = REDSOLDIER_ANIMS
			"WHITESOLDIER": anim_dict = WHITESOLDIER_ANIMS
			_: anim_dict = SILVER_ANIMS

	# Load animations
	var active_skel : Skeleton3D = _find_skeleton(_active) if _active else null
	var active_skel_path := _get_skel_path(active_anim, active_skel)
	_load_anims(active_anim, anim_dict, active_skel, active_skel_path)
	# Trim gunslinger idle attack to frames 120-180 (2.0s to 3.0s at 60fps)
	if PlayerData.char_class == "ranged" and active_anim:
		_trim_anim_range(active_anim, "attack", 2.0, 3.0)
	_strip_all_anims(active_anim)
	_set_loop_modes(active_anim)

	# Also load anims for non-active in test mode
	if _selected_char_id == "SilverArmor" and _red_anim:
		var red_skel : Skeleton3D = _find_skeleton(_red) if _red else null
		var red_skel_path := _get_skel_path(_red_anim, red_skel)
		_load_anims(_red_anim, RED_ANIMS, red_skel, red_skel_path)
		_strip_all_anims(_red_anim)
		_set_loop_modes(_red_anim)

	# Set up meta stats on active character
	if _active:
		_active.set_meta("ham_health", 1000.0)
		_active.set_meta("max_hp", 1000.0)
		_active.set_meta("ham_action", 800.0)
		_active.set_meta("max_action", 800.0)
		_active.set_meta("ham_mind", 600.0)
		_active.set_meta("max_mind", 600.0)
		_active.set_meta("is_dead", false)
		var _display_name : String = PlayerData.nickname if PlayerData.nickname != "" else CHAR_DISPLAY_NAMES.get(_selected_char_id, "Player")
		_active.set_meta("display_name", _display_name)
		_active.set_meta("accuracy", 60.0)
		_active.set_meta("defense", 40.0)
	# Spawn at the starport (near Transport Shuttle) — shifted -100 Z
	_active.position = Vector3(-3.0, 0.0, 70.0)
	_play_anim("idle")
	# Give streetfighter starter weapon and novice box
	if character_class == "melee":
		if inventory.is_empty():
			inventory.append(ItemData.create_instance("novice_baton"))
		if "sf_novice" not in _learned_boxes:
			_learned_boxes.append("sf_novice")
	# Start in first person mode
	_cam_zoom = 0.15
	_first_person = true
	_update_camera(0.0)
	_build_hud()
	_build_hotbar()
	_build_xp_bar_under_hotbar()
	_build_combat_queue_hud()
	_build_skills_window()
	_build_minimap()
	_build_chat()
	_connect_relay()
	#_spawn_test_mobs()  # Disabled — use F5/F6 to spawn mobs manually
	_setup_vehicle()
	_paint_starport()  # Only paint the starport grey
	_setup_rain()
	_setup_ambient_traffic()
	_setup_ambient_music()
	_setup_footsteps()

# ════════════════════════════════════════════════════════════
#  ANIMATION HELPERS
# ════════════════════════════════════════════════════════════
func _apply_skin_tint(model: Node3D, tint: Color) -> void:
	var meshes := _find_all_mesh_instances(model)
	for mi in meshes:
		var mi_node : MeshInstance3D = mi as MeshInstance3D
		if mi_node.mesh == null:
			continue
		for surf_idx in range(mi_node.mesh.get_surface_count()):
			var base_mat : Material = mi_node.mesh.surface_get_material(surf_idx)
			if base_mat is StandardMaterial3D:
				var new_mat : StandardMaterial3D = base_mat.duplicate() as StandardMaterial3D
				new_mat.albedo_color = tint
				mi_node.set_surface_override_material(surf_idx, new_mat)
	print("[SKIN] Applied tint ", tint, " to ", meshes.size(), " meshes")

func _apply_skin_texture(model: Node3D, texture_path: String) -> void:
	var tex : Texture2D = load(texture_path) as Texture2D
	if tex == null:
		print("[SKIN] Could not load texture: ", texture_path)
		return
	var meshes := _find_all_mesh_instances(model)
	var count := 0
	for mi in meshes:
		var mi_node : MeshInstance3D = mi as MeshInstance3D
		if mi_node.mesh == null:
			continue
		for surf_idx in range(mi_node.mesh.get_surface_count()):
			var new_mat := StandardMaterial3D.new()
			new_mat.albedo_texture = tex
			new_mat.metallic = 0.3
			new_mat.roughness = 0.7
			mi_node.set_surface_override_material(surf_idx, new_mat)
			count += 1
	print("[SKIN] Applied texture '", texture_path.get_file(), "' to ", count, " surfaces across ", meshes.size(), " meshes")

func _find_all_mesh_instances(node: Node) -> Array:
	var result := []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result

# ── ONESHOT ANIMATION BLENDER ────────────────────────────────────
func _find_skeleton(root : Node) -> Skeleton3D:
	for child in root.get_children():
		if child is Skeleton3D:
			return child
		for gc in child.get_children():
			if gc is Skeleton3D:
				return gc
			for ggc in gc.get_children():
				if ggc is Skeleton3D:
					return ggc
	return null

func _get_bone_names(skel : Skeleton3D) -> Array:
	var names := []
	for i in range(skel.get_bone_count()):
		names.append(skel.get_bone_name(i))
	return names

func _get_skel_path(ap : AnimationPlayer, skel : Skeleton3D) -> String:
	if ap == null or skel == null:
		return ""
	var root_node : Node = ap.get_node(ap.root_node)
	if root_node == null:
		return ""
	var path : String = str(root_node.get_path_to(skel))
	return path

func _find_anim_player(root : Node) -> AnimationPlayer:
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
		for gc in child.get_children():
			if gc is AnimationPlayer:
				return gc
			for ggc in gc.get_children():
				if ggc is AnimationPlayer:
					return ggc
	return null

func _load_anims(ap : AnimationPlayer, anim_dict : Dictionary, target_skel : Skeleton3D = null, skel_path : String = "") -> void:
	if ap == null:
		print("LOAD_ANIMS: AnimationPlayer is null!")
		return
	# Build bone name lookup for remapping
	var target_bones := {}  # lowercase stripped name -> actual bone name
	if target_skel:
		for i in range(target_skel.get_bone_count()):
			var bname : String = target_skel.get_bone_name(i)
			# Store with and without common prefixes stripped
			target_bones[bname.to_lower()] = bname
			var stripped : String = bname.replace("mixamorig_", "").replace("mixamorig:", "")
			target_bones[stripped.to_lower()] = bname

	for anim_name in anim_dict:
		var path : String = anim_dict[anim_name]
		if not ResourceLoader.exists(path):
			print("LOAD_ANIMS: file not found: ", path)
			continue
		var scene : PackedScene = load(path)
		if scene == null:
			print("LOAD_ANIMS: could not load: ", path)
			continue
		var temp : Node = scene.instantiate()
		var temp_ap := _find_anim_player(temp)
		if temp_ap == null:
			print("LOAD_ANIMS: no AnimationPlayer in: ", path)
			if temp is AnimationPlayer:
				temp_ap = temp
			else:
				temp.queue_free()
				continue
		var loaded := false
		for src_name in temp_ap.get_animation_list():
			if src_name == "RESET":
				continue
			var anim : Animation = temp_ap.get_animation(src_name)
			if anim:
				var dupe : Animation = anim.duplicate(true)
				# Only remap bone tracks if they don't already match target skeleton
				if target_skel and target_bones.size() > 0:
					if _needs_remap(dupe, target_skel, skel_path):
						_remap_anim_tracks(dupe, target_bones, skel_path)
						print("  -> remapped tracks for '", anim_name, "'")
					else:
						print("  -> tracks already match, no remap for '", anim_name, "'")
				var lib := ap.get_animation_library("")
				if lib == null:
					lib = AnimationLibrary.new()
					ap.add_animation_library("", lib)
				if lib.has_animation(anim_name):
					lib.remove_animation(anim_name)
				lib.add_animation(anim_name, dupe)
				print("LOAD_ANIMS: loaded '", anim_name, "' from '", src_name, "' (", dupe.length, "s, ", dupe.get_track_count(), " tracks)")
				loaded = true
				break
		if not loaded:
			print("LOAD_ANIMS: no valid animation found in: ", path, " anims: ", temp_ap.get_animation_list())
		temp.queue_free()

func _needs_remap(anim : Animation, target_skel : Skeleton3D, _skel_path : String) -> bool:
	# Check if the first bone track already matches the target skeleton
	for i in range(anim.get_track_count()):
		var t := anim.track_get_type(i)
		if t != Animation.TYPE_ROTATION_3D and t != Animation.TYPE_POSITION_3D and t != Animation.TYPE_SCALE_3D:
			continue
		var track_path : String = str(anim.track_get_path(i))
		var colon_idx : int = track_path.rfind(":")
		if colon_idx < 0:
			continue
		var bone_name : String = track_path.substr(colon_idx + 1)
		# Check if this bone exists in the target skeleton
		if target_skel.find_bone(bone_name) >= 0:
			return false  # bones match, no remap needed
		else:
			return true   # first bone doesn't match, needs remap
	return false

func _remap_anim_tracks(anim : Animation, target_bones : Dictionary, skel_path : String = "") -> void:
	for i in range(anim.get_track_count()):
		var track_path : String = str(anim.track_get_path(i))
		var colon_idx : int = track_path.rfind(":")
		if colon_idx < 0:
			continue
		var prefix : String = track_path.substr(0, colon_idx + 1)  # e.g. "Armature/Skeleton3D:"
		var bone_part : String = track_path.substr(colon_idx + 1)
		# Strip mixamorig_ prefix for matching
		var stripped : String = bone_part.replace("mixamorig_", "").replace("mixamorig:", "")
		var lookup : String = stripped.to_lower()
		if lookup in target_bones:
			var new_bone : String = target_bones[lookup]
			# Use target skeleton path if provided, otherwise keep original prefix
			var new_prefix : String = skel_path + ":" if skel_path != "" else prefix
			anim.track_set_path(i, NodePath(new_prefix + new_bone))


func _strip_root_motion(anim : Animation, ref_anim : Animation = null) -> void:
	# Copy Hips Y position from reference animation (idle) to keep all anims grounded
	# Strip position tracks from all OTHER bones (they cause sliding/floating)
	var hips_ref_y := 0.0
	if ref_anim:
		for i in range(ref_anim.get_track_count()):
			if ref_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				var path := str(ref_anim.track_get_path(i))
				if "Hips" in path or "hips" in path:
					var pos : Vector3 = ref_anim.position_track_interpolate(i, 0.0)
					hips_ref_y = pos.y
					break

	for i in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path := str(anim.track_get_path(i))
		if "Hips" in path or "hips" in path:
			# Zero out Hips Y to match idle — keep X/Z for natural sway
			for k in range(anim.track_get_key_count(i)):
				var pos : Vector3 = anim.track_get_key_value(i, k)
				pos.y = hips_ref_y
				anim.track_set_key_value(i, k, pos)
		else:
			anim.remove_track(i)


func _trim_anim_range(ap : AnimationPlayer, anim_name : String, start_time : float, end_time : float) -> void:
	# Trim animation to only keep keyframes between start_time and end_time
	var lib := ap.get_animation_library("")
	if lib == null or not lib.has_animation(anim_name):
		return
	var src := lib.get_animation(anim_name)
	var new_len := end_time - start_time
	var trimmed := Animation.new()
	trimmed.length = new_len
	trimmed.loop_mode = src.loop_mode
	for t in range(src.get_track_count()):
		var ti := trimmed.add_track(src.track_get_type(t))
		trimmed.track_set_path(ti, src.track_get_path(t))
		trimmed.track_set_interpolation_type(ti, src.track_get_interpolation_type(t))
		for k in range(src.track_get_key_count(t)):
			var time : float = src.track_get_key_time(t, k)
			if time < start_time or time > end_time:
				continue
			var val = src.track_get_key_value(t, k)
			trimmed.track_insert_key(ti, time - start_time, val)
	lib.remove_animation(anim_name)
	lib.add_animation(anim_name, trimmed)
	print("TRIM_ANIM: '", anim_name, "' trimmed to ", start_time, "s-", end_time, "s -> ", trimmed.length, "s")

func _strip_all_anims(ap : AnimationPlayer) -> void:
	if ap == null:
		return
	# Find idle animation first to use as height reference
	var idle_ref : Animation = null
	if ap.has_animation("idle"):
		idle_ref = ap.get_animation("idle")
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			if anim_name == "RESET":
				continue
			var anim := lib.get_animation(anim_name)
			if anim:
				var dupe : Animation = anim.duplicate(true)
				_strip_root_motion(dupe, idle_ref)
				lib.remove_animation(anim_name)
				lib.add_animation(anim_name, dupe)

func _set_loop_modes(ap : AnimationPlayer) -> void:
	if ap == null:
		return
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null or anim_name == "RESET":
				continue
			var lower := anim_name.to_lower()
			if "idle" in lower or "run" in lower or "walk" in lower:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE

func _get_active_anim() -> AnimationPlayer:
	if _active == _silver:
		return _silver_anim
	return _red_anim

func _play_anim(anim_name : String) -> void:
	var ap := _get_active_anim()
	if ap == null:
		return

	# Resolve idle — use combat idle (idle2) when in combat
	var resolved_name := anim_name
	if anim_name == "idle":
		if _in_combat and ap.has_animation("idle2"):
			resolved_name = "idle2"
		elif not ap.has_animation("idle"):
			for a in ap.get_animation_list():
				if a != "RESET" and a not in ["run","walk","attack","dodge","kd","idle2","hit","dizzy","dead"]:
					resolved_name = a
					break

	# Gunslinger moving attack: play run_attack instead of attack
	if anim_name == "attack" and character_class == "ranged":
		var is_moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or _auto_run
		if is_moving and ap.has_animation("run_attack"):
			resolved_name = "run_attack"

	if not ap.has_animation(resolved_name):
		print("ANIM NOT FOUND: ", resolved_name, " available: ", ap.get_animation_list())
		return

	ap.speed_scale = 1.0
	ap.stop()
	ap.play(resolved_name)

	# Gunslinger run_attack: play for 0.7 seconds then return to run
	if resolved_name == "run_attack":
		_attack_anim_timer = 0.7
		_anim_state = "run_attack"
		return
	# If attacking while moving (non-gunslinger), cap anim then fade back to movement
	if anim_name in ["attack", "dizzy"]:
		var is_moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or _auto_run
		if is_moving:
			_attack_anim_timer = 0.7
			_anim_state = "attack"
			return

func _get_anim_priority(anim_name: String) -> int:
	match anim_name:
		"dead": return 6
		"kd": return 5
		"attack", "dizzy", "run_attack": return 4
		"dodge": return 3
		"hit": return 2
		"run", "walk": return 1
		_: return 0  # idle

func _play_anim_on_node(node : Node3D, anim_name : String) -> void:
	# Play an animation on a specific character node (not necessarily the active one)
	var ap : AnimationPlayer = null
	if node == _silver:
		ap = _silver_anim
	elif node == _red:
		ap = _red_anim
	else:
		return  # mobs don't have loaded anims yet
	if ap == null:
		return
	if ap.has_animation(anim_name):
		ap.stop()
		ap.play(anim_name)

# ════════════════════════════════════════════════════════════
#  BUILDINGS
# ════════════════════════════════════════════════════════════
func _paint_starport() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.27, 1.0)
	mat.roughness = 0.95
	mat.metallic = 0.0
	for child in get_children():
		if "starport" in child.name.to_lower() or "cnet" in child.name.to_lower():
			_apply_mat_recursive(child, mat)

func _paint_buildings() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.27, 1.0)
	mat.roughness = 0.95
	mat.metallic = 0.0
	# Only paint nodes with these keywords in the name
	var paint_keywords := ["starport", "building", "cnet"]
	for child in get_children():
		var lower := child.name.to_lower()
		for keyword in paint_keywords:
			if keyword in lower:
				_apply_mat_recursive(child, mat)
				break

func _apply_mat_recursive(node : Node, mat : StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_mat_recursive(child, mat)

# ════════════════════════════════════════════════════════════
#  RAIN
# ════════════════════════════════════════════════════════════
func _setup_ambient_traffic() -> void:
	var traffic := Node3D.new()
	traffic.set_script(load("res://Scripts/Client/VFX/AmbientTraffic.gd"))
	traffic.name = "AmbientTraffic"
	add_child(traffic)

func _setup_ambient_music() -> void:
	_music_player = AudioStreamPlayer.new()
	var music := load("res://Sounds/spaceportambience.mp3")
	if music:
		_music_player.stream = music
		_music_player.volume_db = -15.0
		_music_player.autoplay = true
		_music_player.bus = "Master"
		add_child(_music_player)
		_music_player.play()

func _setup_footsteps() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	var footsteps := load("res://Sounds/footstepslong.mp3")
	if footsteps:
		_footstep_player.stream = footsteps
		_footstep_player.volume_db = -8.0
		_footstep_player.max_distance = 20.0
		_footstep_player.bus = "Master"
		if _active:
			_active.add_child(_footstep_player)
		else:
			add_child(_footstep_player)

func _setup_rain() -> void:
	_rain_particles = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -30, 0)
	# Emit from a wide box above the player
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(25, 0.5, 25)
	mat.scale_min = 1.0
	mat.scale_max = 1.0
	mat.color = Color(0.75, 0.8, 0.9, 0.5)
	_rain_particles.process_material = mat
	_rain_particles.amount = 6000
	_rain_particles.lifetime = 1.2
	_rain_particles.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	# Raindrop mesh — thin stretched box
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.03, 0.5, 0.03)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.7, 0.75, 0.85, 0.4)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh.material = drop_mat
	_rain_particles.draw_pass_1 = drop_mesh
	_rain_particles.emitting = false
	add_child(_rain_particles)

	# Audio — looping rain sound
	_rain_audio = AudioStreamPlayer.new()
	var stream = load("res://Sounds/rain.mp3")
	if stream:
		_rain_audio.stream = stream
		_rain_audio.volume_db = -6.0
	add_child(_rain_audio)

func _toggle_rain() -> void:
	_rain_enabled = !_rain_enabled
	if _rain_particles:
		_rain_particles.emitting = _rain_enabled
	if _rain_audio and _rain_audio.stream:
		if _rain_enabled:
			_rain_audio.play()
		else:
			_rain_audio.stop()
	# Darken scene for storm effect
	var env_node = get_node_or_null("WorldEnvironment")
	if env_node and env_node is WorldEnvironment and env_node.environment:
		var env : Environment = env_node.environment
		if _rain_enabled:
			env.ambient_light_energy = 0.45
			env.tonemap_white = 1.5
			env.fog_enabled = true
			env.fog_light_color = Color(0.4, 0.42, 0.48)
			env.fog_density = 0.015
			env.volumetric_fog_enabled = false
		else:
			env.ambient_light_energy = 0.5
			env.tonemap_white = 1.0
			env.fog_enabled = false
	# Darken sun for storm
	var sun = get_node_or_null("Sun")
	if sun and sun is DirectionalLight3D:
		if _rain_enabled:
			sun.light_energy = 0.6
			sun.light_color = Color(0.6, 0.62, 0.7)
		else:
			sun.light_energy = 1.0
			sun.light_color = Color(1, 1, 1)
	# Darken sky
	var sky_mat = null
	if env_node and env_node is WorldEnvironment and env_node.environment and env_node.environment.sky:
		sky_mat = env_node.environment.sky.sky_material
	if sky_mat and sky_mat is ProceduralSkyMaterial:
		if _rain_enabled:
			sky_mat.sky_top_color = Color(0.25, 0.28, 0.35)
			sky_mat.sky_horizon_color = Color(0.35, 0.38, 0.42)
			sky_mat.ground_horizon_color = Color(0.3, 0.32, 0.36)
		else:
			sky_mat.sky_top_color = Color(0.25, 0.47, 0.85)
			sky_mat.sky_horizon_color = Color(0.55, 0.7, 0.9)
			sky_mat.ground_horizon_color = Color(0.45, 0.55, 0.7)
	print("Rain: ", "ON" if _rain_enabled else "OFF")

# ════════════════════════════════════════════════════════════
#  VEHICLE
# ════════════════════════════════════════════════════════════
func _setup_vehicle() -> void:
	# Find first vehicle as default mount
	for child in get_children():
		if "vehiclemount" in child.name.to_lower() or "vehicle" in child.name.to_lower():
			_vehicle_mount = child
			_vehicle_base_y = child.position.y
			break
	if _vehicle_mount == null:
		var ground := get_node_or_null("Ground")
		if ground:
			for child in ground.get_children():
				if "vehicle" in child.name.to_lower():
					_vehicle_mount = child
					_vehicle_base_y = child.position.y
					break
	if _vehicle_mount:
		print("Vehicle mount found: ", _vehicle_mount.name, " base_y=", _vehicle_base_y)
	# Add collision bodies to ALL mountable vehicles so raycasts can detect them
	_add_vehicle_collision_to_all()

func _add_vehicle_collision_to_all() -> void:
	var vehicle_keywords := ["vehicle", "landspeeder", "speeder", "mount", "voyager", "shuttle"]
	for child in get_children():
		var cname := child.name.to_lower()
		var is_vehicle := false
		for kw in vehicle_keywords:
			if kw in cname:
				is_vehicle = true
				break
		if not is_vehicle:
			continue
		# Check if already has a collision body
		var has_body := false
		for gc in child.get_children():
			if gc is StaticBody3D or gc is Area3D:
				has_body = true
				break
		if not has_body:
			var body := StaticBody3D.new()
			var coll := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(3.0, 1.5, 5.0)
			coll.shape = shape
			coll.position = Vector3(0, 0.75, 0)
			body.add_child(coll)
			child.add_child(body)
			print("Added collision to vehicle: ", child.name)
	# Also check under Ground node
	var ground := get_node_or_null("Ground")
	if ground:
		for child in ground.get_children():
			var cname := child.name.to_lower()
			var is_vehicle := false
			for kw in vehicle_keywords:
				if kw in cname:
					is_vehicle = true
					break
			if not is_vehicle:
				continue
			var has_body := false
			for gc in child.get_children():
				if gc is StaticBody3D or gc is Area3D:
					has_body = true
					break
			if not has_body:
				var body := StaticBody3D.new()
				var coll := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3(3.0, 1.5, 5.0)
				coll.shape = shape
				coll.position = Vector3(0, 0.75, 0)
				body.add_child(coll)
				child.add_child(body)
				print("Added collision to vehicle: ", child.name)

func _tick_vehicle_hover(delta : float) -> void:
	if _vehicle_mount == null or not is_instance_valid(_vehicle_mount):
		return
	_vehicle_hover_time += delta
	var hover_offset := sin(_vehicle_hover_time * 1.5) * 0.3
	if not _mounted:
		_vehicle_mount.position.y = _vehicle_base_y + hover_offset
	# When mounted, hover bob is applied on top of current Y in the movement code

func _toggle_mount(force_mount := false) -> void:
	if _vehicle_mount == null or not is_instance_valid(_vehicle_mount):
		_log_combat("[color=gray]No vehicle nearby[/color]")
		return

	if _mounted:
		# ── DISMOUNT ──
		_mounted = false
		# Fade character back in
		_set_character_visible(_active, true)
		# Place character next to vehicle
		var dismount_side := _vehicle_mount.global_transform.basis.z.normalized()
		_active.position = _vehicle_mount.position + dismount_side * 3.0
		_active.position.y = 0.0
		# Raise idle vehicle slightly
		_vehicle_base_y = 5.0
		_vehicle_mount.position.y = _vehicle_base_y
		# Clean ion glow
		if _ion_glow and is_instance_valid(_ion_glow):
			_ion_glow.queue_free()
			_ion_glow = null
		_play_anim("idle")
		_anim_state = "idle"
		_log_combat("[color=yellow]Dismounted vehicle.[/color]")
	else:
		# ── MOUNT ──
		if not force_mount:
			var dist := _active.global_position.distance_to(_vehicle_mount.global_position)
			if dist > VEHICLE_MOUNT_RANGE:
				_log_combat("[color=gray]Too far from vehicle (get closer)[/color]")
				return
		_mounted = true
		# Remove prompt
		if _vehicle_prompt and is_instance_valid(_vehicle_prompt):
			_vehicle_prompt.queue_free()
			_vehicle_prompt = null
		# Stop combat
		_auto_attacking = false
		_current_target = null
		_update_target_indicator()
		# Fade character out
		_set_character_visible(_active, false)
		# Move vehicle to player's position
		_vehicle_mount.position.x = _active.position.x
		_vehicle_mount.position.z = _active.position.z
		_vehicle_base_y = 5.0  # match dismount height
		_vehicle_cur_speed = 0.0
		# Create ion engine glow
		_create_ion_glow()
		_vehicle_mount.position.y = _vehicle_base_y
		_log_combat("[color=yellow]Mounted vehicle! WASD to move, SPACE/CTRL to fly up/down, F to dismount.[/color]")

func _set_character_visible(character : Node3D, vis : bool) -> void:
	if character == null:
		return
	# Find MeshInstance3D children and toggle visibility
	for child in character.get_children():
		_set_node_visible_recursive(child, vis)

func _set_node_visible_recursive(node : Node, vis : bool) -> void:
	if node is MeshInstance3D:
		node.visible = vis
	for child in node.get_children():
		_set_node_visible_recursive(child, vis)

var _ion_glow : Node3D = null
var _ion_glow_mat : StandardMaterial3D = null

func _create_ion_glow() -> void:
	if _ion_glow and is_instance_valid(_ion_glow):
		return  # already exists
	if _vehicle_mount == null:
		return
	_ion_glow = Node3D.new()
	_ion_glow.name = "IonGlow"
	_vehicle_mount.add_child(_ion_glow)
	_ion_glow.position = Vector3(0.73, -0.05, 0.0)

	# Layer 1: Inner white-hot core
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.95)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.8, 0.9, 1.0)
	core_mat.emission_energy_multiplier = 25.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core_mesh.material = core_mat
	core.mesh = core_mesh
	core.name = "Core"
	_ion_glow.add_child(core)

	# Layer 2: Mid glow (blue-white)
	var mid := MeshInstance3D.new()
	var mid_mesh := SphereMesh.new()
	mid_mesh.radius = 0.35
	mid_mesh.height = 0.7
	_ion_glow_mat = StandardMaterial3D.new()
	_ion_glow_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	_ion_glow_mat.emission_enabled = true
	_ion_glow_mat.emission = Color(0.2, 0.5, 1.0)
	_ion_glow_mat.emission_energy_multiplier = 12.0
	_ion_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ion_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ion_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mid_mesh.material = _ion_glow_mat
	mid.mesh = mid_mesh
	mid.name = "MidGlow"
	_ion_glow.add_child(mid)

	# Layer 3: Outer halo
	var outer := MeshInstance3D.new()
	var outer_mesh := SphereMesh.new()
	outer_mesh.radius = 0.7
	outer_mesh.height = 1.4
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.15, 0.35, 0.9, 0.2)
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(0.1, 0.3, 0.8)
	outer_mat.emission_energy_multiplier = 6.0
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	outer_mesh.material = outer_mat
	outer.mesh = outer_mesh
	outer.name = "OuterHalo"
	_ion_glow.add_child(outer)

	# Layer 4: Exhaust particles
	var particles := GPUParticles3D.new()
	particles.name = "ExhaustParticles"
	particles.amount = 30
	particles.lifetime = 0.4
	particles.explosiveness = 0.1
	particles.fixed_fps = 60
	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3(1, 0, 0)
	p_mat.spread = 15.0
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3.ZERO
	p_mat.scale_min = 0.03
	p_mat.scale_max = 0.08
	p_mat.color = Color(0.4, 0.7, 1.0, 0.8)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.8, 0.9, 1.0, 1.0))
	color_ramp.set_color(1, Color(0.2, 0.4, 1.0, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	p_mat.color_ramp = color_tex
	particles.process_material = p_mat
	var p_draw := SphereMesh.new()
	p_draw.radius = 0.04
	p_draw.height = 0.08
	var p_draw_mat := StandardMaterial3D.new()
	p_draw_mat.albedo_color = Color(0.5, 0.7, 1.0, 0.9)
	p_draw_mat.emission_enabled = true
	p_draw_mat.emission = Color(0.3, 0.6, 1.0)
	p_draw_mat.emission_energy_multiplier = 8.0
	p_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_draw.material = p_draw_mat
	particles.draw_pass_1 = p_draw
	_ion_glow.add_child(particles)

func _tick_ion_glow() -> void:
	if _ion_glow == null or not is_instance_valid(_ion_glow) or _ion_glow_mat == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var speed_frac := clampf(_vehicle_cur_speed / VEHICLE_BOOST_SPEED, 0.0, 1.0)
	var glow_scale := lerpf(0.4, 1.0, speed_frac)
	var glow_energy := lerpf(4.0, 18.0, speed_frac)

	var pulse := glow_energy + sin(t * 6.0) * (2.0 + speed_frac * 3.0)
	_ion_glow_mat.emission_energy_multiplier = pulse
	_ion_glow_mat.emission = Color(0.2, 0.45 + sin(t * 3.0) * 0.1, 1.0)

	var core_node = _ion_glow.get_node_or_null("Core")
	var mid_node = _ion_glow.get_node_or_null("MidGlow")
	var outer_node = _ion_glow.get_node_or_null("OuterHalo")
	if core_node:
		var cs := glow_scale * (0.9 + sin(t * 20.0) * 0.1)
		core_node.scale = Vector3(cs, cs, cs)
		# Also dim/brighten core material
		var core_mat = core_node.mesh.material as StandardMaterial3D
		if core_mat:
			core_mat.emission_energy_multiplier = lerpf(5.0, 25.0, speed_frac)
			core_mat.albedo_color.a = lerpf(0.3, 0.95, speed_frac)
	if mid_node:
		mid_node.scale = Vector3(glow_scale, glow_scale, glow_scale)
		_ion_glow_mat.albedo_color.a = lerpf(0.15, 0.6, speed_frac)
	if outer_node:
		outer_node.scale = Vector3(glow_scale, glow_scale, glow_scale)
		var outer_mat = outer_node.mesh.material as StandardMaterial3D
		if outer_mat:
			outer_mat.emission_energy_multiplier = lerpf(1.0, 6.0, speed_frac)
			outer_mat.albedo_color.a = lerpf(0.05, 0.2, speed_frac)

func _tick_speed_lines(_delta : float, active : bool) -> void:
	# Clean old speed lines
	for line in _speed_lines:
		if is_instance_valid(line):
			line.queue_free()
	_speed_lines.clear()

	if not active or _vehicle_mount == null:
		return

	var vpos := _vehicle_mount.global_position
	var forward := -_vehicle_mount.global_transform.basis.x.normalized()

	# ── SPEED LINES ──
	for i in range(12):
		var line := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = randf_range(2.0, 5.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.9, 1.0, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.85, 1.0)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cyl.material = mat
		line.mesh = cyl
		add_child(line)
		var behind := -forward * randf_range(2.0, 5.0)
		var scatter := Vector3(randf_range(-1.5, 1.5), randf_range(-0.8, 1.0), randf_range(-1.5, 1.5))
		line.global_position = vpos + behind + scatter
		line.look_at(line.global_position + forward)
		line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		_speed_lines.append(line)

func _tick_rain() -> void:
	if not _rain_enabled:
		return
	if _rain_particles and _active:
		_rain_particles.global_position = _active.global_position + Vector3(0, 15, 0)

	# Lightning system
	var delta := get_process_delta_time()
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(4.0, 12.0)
		_trigger_lightning()

	# Flash fade out
	if _lightning_flash_timer > 0.0:
		_lightning_flash_timer -= delta
		if _lightning_flash_timer <= 0.0:
			# Restore storm lighting
			var sun = get_node_or_null("Sun")
			if sun and sun is DirectionalLight3D:
				sun.light_energy = 0.4
			# Remove bolt
			if _lightning_bolt and is_instance_valid(_lightning_bolt):
				_lightning_bolt.queue_free()
				_lightning_bolt = null

func _trigger_lightning() -> void:
	if not _active or not is_inside_tree():
		return
	# Flash — briefly max out the sun
	var sun = get_node_or_null("Sun")
	if sun and sun is DirectionalLight3D:
		sun.light_energy = 4.0
	_lightning_flash_timer = 0.15

	# Create a lightning bolt mesh
	if _lightning_bolt and is_instance_valid(_lightning_bolt):
		_lightning_bolt.queue_free()
	_lightning_bolt = MeshInstance3D.new()
	var bolt_mesh := BoxMesh.new()
	bolt_mesh.size = Vector3(0.15, 20.0, 0.15)
	_lightning_bolt.mesh = bolt_mesh
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.9, 0.92, 1.0, 0.9)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.8, 0.85, 1.0)
	bolt_mat.emission_energy_multiplier = 8.0
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mesh.material = bolt_mat
	var offset := Vector3(randf_range(-20, 20), 10, randf_range(-20, 20))
	_lightning_bolt.global_position = _active.global_position + offset
	# Slight random tilt
	_lightning_bolt.rotation.x = randf_range(-0.1, 0.1)
	_lightning_bolt.rotation.z = randf_range(-0.15, 0.15)
	add_child(_lightning_bolt)

# ════════════════════════════════════════════════════════════
#  TEST MOBS
# ════════════════════════════════════════════════════════════
func _spawn_machine_walker() -> void:
	var mw := Node3D.new()
	mw.set_script(load("res://Scripts/Gameplay/Mobs/MachineWalker.gd"))
	mw.name = "MachineWalker_" + str(randi() % 9999)
	add_child(mw)
	# Spawn 8 units in front of player (based on camera facing direction)
	var cam_forward := -_camera.global_transform.basis.z.normalized()
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	mw.global_position = _active.global_position + cam_forward * 8.0
	mw.position.y = 0.0
	_log_combat("[color=green]Machine Walker spawned![/color]")

func _spawn_test_dummy() -> void:
	# Toggle — if one exists, despawn it
	for child in get_children():
		if "TestDummy" in child.name:
			if _current_target == child:
				_current_target = null
				_auto_attacking = false
				_update_target_indicator()
			child.queue_free()
			_log_combat("[color=gray]Test Dummy despawned.[/color]")
			return
	# Spawn new
	var td := Node3D.new()
	td.set_script(load("res://Scripts/Gameplay/Mobs/TestDummy.gd"))
	td.name = "TestDummy_" + str(randi() % 9999)
	add_child(td)
	var cam_forward := -_camera.global_transform.basis.z.normalized()
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	td.global_position = _active.global_position + cam_forward * 8.0
	td.position.y = 0.0
	_log_combat("[color=green]Test Dummy spawned! (F6 to despawn)[/color]")

# ════════════════════════════════════════════════════════════
#  EFFECTIVE STATS (wounds + attributes)
# ════════════════════════════════════════════════════════════
func get_effective_max_health() -> float:
	return maxf(1.0, max_health - wound_health + _get_prof_stat("max_health_bonus"))

func get_effective_max_action() -> float:
	return maxf(1.0, max_action_stat - wound_action + _get_prof_stat("max_action_bonus"))

func get_effective_max_mind() -> float:
	return maxf(1.0, max_mind - wound_mind + _get_prof_stat("max_mind_bonus"))

func get_effective_accuracy() -> float:
	return accuracy + _get_prof_stat("accuracy")

func get_effective_defense() -> float:
	return defense + _get_prof_stat("melee_defense") + _get_prof_stat("ranged_defense")

func get_effective_damage() -> float:
	# Check equipped weapon for damage override
	for item in inventory:
		if item.get("equipped", false):
			var stats : Dictionary = item.get("stats", {})
			if stats.has("damage_min") and stats.has("damage_max"):
				var weapon_dmg := randf_range(stats["damage_min"], stats["damage_max"])
				if character_class == "melee":
					return weapon_dmg + _get_prof_stat("melee_damage")
				return weapon_dmg + _get_prof_stat("ranged_damage")
	# No weapon equipped — use base damage
	if character_class == "melee":
		return BASE_DAMAGE + _get_prof_stat("melee_damage")
	return BASE_DAMAGE + _get_prof_stat("ranged_damage")

# ════════════════════════════════════════════════════════════
#  WOUNDS
# ════════════════════════════════════════════════════════════
func apply_wound(pool : String, amount : float) -> void:
	match pool:
		"health": wound_health = minf(wound_health + amount, max_health * 0.8)
		"action": wound_action = minf(wound_action + amount, max_action_stat * 0.8)
		"mind":   wound_mind = minf(wound_mind + amount, max_mind * 0.8)

func _tick_wound_regen(delta : float) -> void:
	var rate : float = WOUND_HEAL_RATE + 2.0
	if wound_health > 0.0:
		wound_health = maxf(0.0, wound_health - rate * delta)
	if wound_action > 0.0:
		wound_action = maxf(0.0, wound_action - rate * delta)
	if wound_mind > 0.0:
		wound_mind = maxf(0.0, wound_mind - rate * delta)
	# Clamp current HAM to effective max
	ham_health = minf(ham_health, get_effective_max_health())
	ham_action = minf(ham_action, get_effective_max_action())
	ham_mind = minf(ham_mind, get_effective_max_mind())

# ════════════════════════════════════════════════════════════
#  XP & LEVELING
# ════════════════════════════════════════════════════════════
func grant_xp(amount : float) -> void:
	exp_points += amount
	_spawn_damage_text(_active, "+%d XP" % int(amount), Color(0.75, 0.25, 1.0))
	_log_combat("[color=purple]+%d XP[/color]" % int(amount))
	while exp_points >= exp_needed:
		exp_points -= exp_needed
		_level_up()

func _level_up() -> void:
	level += 1
	unspent_points += 3
	exp_needed = 100.0 * level
	# Full heal on level up
	ham_health = get_effective_max_health()
	ham_action = get_effective_max_action()
	ham_mind = get_effective_max_mind()
	# Clear wounds
	wound_health = 0.0
	wound_action = 0.0
	wound_mind = 0.0
	_log_combat("[color=yellow]LEVEL UP! You are now level %d! +3 stat points.[/color]" % level)
	_spawn_damage_text(_active, "LEVEL %d!" % level, Color(1.0, 0.85, 0.2))

func spend_stat_point(_attr : String) -> void:
	pass  # Old attribute system removed — stats come from profession tree now

func _spawn_test_mobs() -> void:
	var mob_positions := [
		Vector3(8.0, 0.0, 0.0),
		Vector3(-6.0, 0.0, -5.0),
		Vector3(3.0, 0.0, -10.0),
	]
	var mob_names := ["Rogue Sentry", "Patrol Droid", "Outlaw Scout"]
	for i in range(mob_positions.size()):
		var mob := Node3D.new()
		mob.set_script(load("res://Scripts/Gameplay/Mobs/CoronetMob.gd"))
		mob.name = mob_names[i]
		mob.set("mob_name", mob_names[i])
		mob.set("max_hp", 300.0 + i * 100.0)
		mob.set("max_action", 200.0)
		mob.set("max_mind", 150.0)
		mob.set("level", 3 + i * 2)
		add_child(mob)
		mob.global_position = mob_positions[i]

		# Create a simple visual — colored cube
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 1.8, 0.8)
		mesh_inst.mesh = box
		mesh_inst.position.y = 0.9
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.2, 0.2, 1.0) if i == 0 else (Color(0.2, 0.6, 0.8, 1.0) if i == 1 else Color(0.7, 0.5, 0.2, 1.0))
		mesh_inst.material_override = mat
		mob.add_child(mesh_inst)

		# Name label above mob
		var lbl3d := Label3D.new()
		lbl3d.text = mob_names[i] + " [Lv" + str(3 + i * 2) + "]"
		lbl3d.position.y = 2.2
		lbl3d.font_size = 32
		lbl3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl3d.modulate = Color(1.0, 0.8, 0.3, 1.0)
		mob.add_child(lbl3d)

# ════════════════════════════════════════════════════════════
#  HUD
# ════════════════════════════════════════════════════════════
func _make_draggable(panel : Panel) -> void:
	var drag_data := {"dragging": false}
	panel.gui_input.connect(func(event : InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			drag_data.dragging = event.pressed
		if event is InputEventMouseMotion and drag_data.dragging:
			panel.position += event.relative
	)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	# ── Player Frame ──
	var pf := Panel.new()
	pf.position = Vector2(38, 10)
	pf.size = Vector2(220, 52)
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	pf_style.border_color = Color(0.2, 0.4, 0.6, 0.75)
	pf_style.set_border_width_all(1)
	pf_style.set_corner_radius_all(3)
	pf.add_theme_stylebox_override("panel", pf_style)
	pf.clip_contents = true
	_make_draggable(pf)
	_hud.add_child(pf)
	_player_frame = pf

	# Posture indicator — separate panel, follows player frame position
	_posture_box = Panel.new()
	_posture_box.position = Vector2(pf.position.x - 28, pf.position.y + 2)
	_posture_box.size = Vector2(26, 48)
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color(0.06, 0.1, 0.14, 0.9)
	pb_style.border_color = Color(0.2, 0.4, 0.6, 0.75)
	pb_style.set_border_width_all(1)
	pb_style.set_corner_radius_all(3)
	_posture_box.add_theme_stylebox_override("panel", pb_style)
	_posture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_posture_box)
	_posture_label = Label.new()
	_posture_label.text = _STANDING_ICON
	_posture_label.position = Vector2(0, 0)
	_posture_label.size = Vector2(26, 48)
	_posture_label.add_theme_font_size_override("font_size", 22)
	_posture_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	_posture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_posture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_posture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_posture_box.add_child(_posture_label)

	_player_name_lbl = Label.new()
	_player_name_lbl.text = PlayerData.nickname if PlayerData.nickname != "" else CHAR_DISPLAY_NAMES.get(_selected_char_id, "Player")
	_player_name_lbl.position = Vector2(6, 1)
	_player_name_lbl.size = Vector2(208, 14)
	_player_name_lbl.add_theme_font_size_override("font_size", 10)
	_player_name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	pf.add_child(_player_name_lbl)

	# HAM bars — compact, all fit inside the frame
	var bar_x := 6.0
	var bar_w := 208.0
	var bar_h := 10.0
	_hp_bar = _make_bar(pf, Vector2(bar_x, 16), Vector2(bar_w, bar_h), Color(0.8, 0.15, 0.15))
	_action_bar = _make_bar(pf, Vector2(bar_x, 28), Vector2(bar_w, bar_h), Color(0.85, 0.75, 0.1))
	_mind_bar = _make_bar(pf, Vector2(bar_x, 40), Vector2(bar_w, bar_h), Color(0.15, 0.4, 0.85))

	# Wound overlays — black bar on right side of each HAM bar
	_hp_wound_ov = _make_wound_overlay(Vector2(bar_x + bar_w, 16), bar_h)
	pf.add_child(_hp_wound_ov)
	_action_wound_ov = _make_wound_overlay(Vector2(bar_x + bar_w, 28), bar_h)
	pf.add_child(_action_wound_ov)
	_mind_wound_ov = _make_wound_overlay(Vector2(bar_x + bar_w, 40), bar_h)
	pf.add_child(_mind_wound_ov)

	# ── Player Buff/Debuff Row ──
	# Player buff/debuff row — separate from frame to avoid clip_contents
	_player_buff_row = HBoxContainer.new()
	_player_buff_row.position = Vector2(pf.position.x, pf.position.y + 54)
	_player_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_player_buff_row)

	# ── Target Frame ──
	_tgt_panel = Panel.new()
	_tgt_panel.position = Vector2(300, 10)
	_tgt_panel.size = Vector2(220, 52)
	var tgt_style := StyleBoxFlat.new()
	tgt_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	tgt_style.border_color = Color(0.2, 0.4, 0.6, 0.75)
	tgt_style.set_border_width_all(1)
	tgt_style.set_corner_radius_all(3)
	_tgt_panel.add_theme_stylebox_override("panel", tgt_style)
	_tgt_panel.clip_contents = true
	_make_draggable(_tgt_panel)
	_tgt_panel.visible = false
	_hud.add_child(_tgt_panel)

	_tgt_name_lbl = Label.new()
	_tgt_name_lbl.text = ""
	_tgt_name_lbl.position = Vector2(6, 1)
	_tgt_name_lbl.size = Vector2(208, 14)
	_tgt_name_lbl.add_theme_font_size_override("font_size", 10)
	_tgt_name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	_tgt_panel.add_child(_tgt_name_lbl)

	var tbar_x := 6.0
	var tbar_w := 208.0
	var tbar_h := 10.0
	_tgt_hp_bar = _make_bar(_tgt_panel, Vector2(tbar_x, 16), Vector2(tbar_w, tbar_h), Color(0.8, 0.15, 0.15))
	_tgt_action_bar = _make_bar(_tgt_panel, Vector2(tbar_x, 28), Vector2(tbar_w, tbar_h), Color(0.85, 0.75, 0.1))
	_tgt_mind_bar = _make_bar(_tgt_panel, Vector2(tbar_x, 40), Vector2(tbar_w, tbar_h), Color(0.15, 0.4, 0.85))

	# ── Target Debuff Row — separate from frame to avoid clip
	_tgt_debuff_row = HBoxContainer.new()
	_tgt_debuff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tgt_debuff_row)

	# ── Combat Log ──
	_combat_log = RichTextLabel.new()
	_combat_log.position = Vector2(10, 500)
	_combat_log.size = Vector2(400, 150)
	_combat_log.bbcode_enabled = true
	_combat_log.scroll_following = true
	_combat_log.modulate = Color(1, 1, 1, 0.7)
	_combat_log.add_theme_font_size_override("normal_font_size", 11)
	_hud.add_child(_combat_log)

func _make_bar(parent : Control, pos : Vector2, sz : Vector2, color : Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = sz
	bar.size = sz
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.clip_contents = true
	# Force exact height via theme constant
	bar.add_theme_constant_override("outline_size", 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_content_margin_all(0)
	sb.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("fill", sb)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	sb_bg.set_content_margin_all(0)
	sb_bg.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", sb_bg)
	# Override all other styleboxes to prevent expansion
	var sb_empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("grabber_area", sb_empty)
	bar.add_theme_stylebox_override("grabber_area_highlight", sb_empty)
	parent.add_child(bar)
	return bar

func _apply_wound_overlay(ov : ColorRect, wound : float, raw_max : float, bar_x : float, bar_w : float) -> void:
	if ov == null or raw_max <= 0.0:
		return
	var frac := clampf(wound / raw_max, 0.0, 1.0)
	var w := frac * bar_w
	ov.size.x = w
	ov.position.x = bar_x + bar_w - w

func _make_wound_overlay(right_edge : Vector2, h : float) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = Color(0.0, 0.0, 0.0, 0.88)
	cr.size = Vector2(0.0, h)
	cr.position = right_edge
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr

func _log_combat(text : String) -> void:
	if _combat_log:
		_combat_log.append_text(text + "\n")

# ════════════════════════════════════════════════════════════
#  HOTBAR
# ════════════════════════════════════════════════════════════
func _build_hotbar() -> void:
	var vp := get_viewport().get_visible_rect().size
	var total_w : float = HOTBAR_SLOTS * (SLOT_SIZE + SLOT_PAD) - SLOT_PAD
	_hotbar_panel = Panel.new()
	_hotbar_panel.position = Vector2((vp.x - total_w) * 0.5, vp.y - SLOT_SIZE - 70)
	_hotbar_panel.size = Vector2(total_w + 16, SLOT_SIZE + 16)
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	hb_style.border_color = Color(0.3, 0.3, 0.35)
	hb_style.set_border_width_all(1)
	hb_style.set_corner_radius_all(4)
	_hotbar_panel.add_theme_stylebox_override("panel", hb_style)
	_make_draggable(_hotbar_panel)
	_hud.add_child(_hotbar_panel)

	_hotbar_slots.clear()
	_hotbar_skills.clear()
	_hotbar_cooldowns.clear()
	_hotbar_labels.clear()
	_hotbar_icons.clear()
	_hotbar_cd_labels.clear()

	for i in range(HOTBAR_SLOTS):
		var slot := Panel.new()
		slot.position = Vector2(8 + i * (SLOT_SIZE + SLOT_PAD), 8)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		slot_style.border_color = Color(0.35, 0.35, 0.4)
		slot_style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", slot_style)
		_hotbar_panel.add_child(slot)
		_hotbar_slots.append(slot)

		# Key number label
		var key_lbl := Label.new()
		key_lbl.text = str(i + 1)
		key_lbl.position = Vector2(2, 1)
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot.add_child(key_lbl)
		_hotbar_labels.append(key_lbl)

		# Skill icon (texture or colored fallback)
		var icon := TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_hotbar_icons.append(icon)

		# Cooldown label
		var cd_lbl := Label.new()
		cd_lbl.text = ""
		cd_lbl.position = Vector2(8, 14)
		cd_lbl.add_theme_font_size_override("font_size", 14)
		cd_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		cd_lbl.visible = false
		slot.add_child(cd_lbl)
		_hotbar_cd_labels.append(cd_lbl)

		_hotbar_skills.append({})
		_hotbar_cooldowns.append(0.0)

	# Pre-load default hotbar: dizzy, knockdown, sprint, sensu bean
	_set_hotbar_slot(0, SKILL_DATA["dizzy"])
	_set_hotbar_slot(1, SKILL_DATA["knockdown"])
	_set_hotbar_slot(2, SKILL_DATA["sprint"])
	_set_hotbar_slot(3, SKILL_DATA["sensu_bean"])

func _build_combat_queue_hud() -> void:
	var vp := get_viewport().get_visible_rect().size
	_queue_panel = Panel.new()
	_queue_panel.position = Vector2(vp.x - 210, vp.y * 0.5 - 60)
	_queue_panel.size = Vector2(190, 120)
	var qp_style := StyleBoxFlat.new()
	qp_style.bg_color = Color(0.04, 0.04, 0.06, 0.85)
	qp_style.border_color = Color(0.4, 0.35, 0.2, 0.7)
	qp_style.set_border_width_all(1)
	qp_style.set_corner_radius_all(4)
	_queue_panel.add_theme_stylebox_override("panel", qp_style)
	_queue_panel.visible = false
	_make_draggable(_queue_panel)
	_hud.add_child(_queue_panel)

	# Title
	var title := Label.new()
	title.text = "COMBAT QUEUE"
	title.position = Vector2(6, 2)
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	_queue_panel.add_child(title)

	# Timer bar
	var timer_bg := ColorRect.new()
	timer_bg.position = Vector2(6, 16)
	timer_bg.size = Vector2(178, 6)
	timer_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_queue_panel.add_child(timer_bg)
	_queue_timer_bar = ColorRect.new()
	_queue_timer_bar.position = Vector2(6, 16)
	_queue_timer_bar.size = Vector2(0, 6)
	_queue_timer_bar.color = Color(0.7, 0.55, 0.15)
	_queue_panel.add_child(_queue_timer_bar)

	# Queue slot rows
	_queue_rows.clear()
	for i in range(QUEUE_MAX):
		var row := Label.new()
		row.position = Vector2(10, 26 + i * 22)
		row.size = Vector2(170, 20)
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		row.text = "—"
		_queue_panel.add_child(row)
		_queue_rows.append(row)

func _update_combat_queue_hud() -> void:
	if _queue_panel == null:
		return
	# Show when in combat (have target and auto-attacking)
	var in_combat : bool = _auto_attacking and _current_target != null and is_instance_valid(_current_target)
	_queue_panel.visible = in_combat
	if not in_combat:
		return
	# Timer bar
	if _queue_timer_bar:
		var frac := clampf(1.0 - _queue_timer / QUEUE_INTERVAL, 0.0, 1.0)
		_queue_timer_bar.size.x = frac * 178.0
		_queue_timer_bar.color = Color(0.5 + frac * 0.3, 0.4 + frac * 0.2, 0.1, 0.9)
	# Rows
	for i in range(QUEUE_MAX):
		if i >= _queue_rows.size():
			break
		var row : Label = _queue_rows[i]
		if i < _combat_queue.size():
			var skill_id : String = _combat_queue[i]
			var skill : Dictionary = SKILL_DATA.get(skill_id, {})
			var display : String = str(skill.get("name", skill_id)).to_upper()
			row.text = str(i + 1) + ". " + display
			if i == 0:
				row.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			else:
				row.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		else:
			row.text = "—"
			row.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))

func _build_xp_bar_under_hotbar() -> void:
	if _hotbar_panel == null:
		return
	var hb_w : float = _hotbar_panel.size.x
	var xp_w : float = hb_w * 0.5
	var xp_x : float = (hb_w - xp_w) * 0.5
	var xp_y : float = _hotbar_panel.size.y + 2
	_xp_bar = _make_bar(_hotbar_panel, Vector2(xp_x, xp_y), Vector2(xp_w, 10), Color(0.55, 0.2, 0.85))
	# Add border to XP bar
	var xp_border := StyleBoxFlat.new()
	xp_border.bg_color = Color(0.55, 0.2, 0.85)
	xp_border.border_color = Color(0.7, 0.4, 1.0, 0.8)
	xp_border.set_border_width_all(1)
	xp_border.set_content_margin_all(0)
	xp_border.set_corner_radius_all(0)
	_xp_bar.add_theme_stylebox_override("fill", xp_border)
	var xp_bg_border := StyleBoxFlat.new()
	xp_bg_border.bg_color = Color(0.1, 0.05, 0.15, 0.8)
	xp_bg_border.border_color = Color(0.4, 0.2, 0.6, 0.6)
	xp_bg_border.set_border_width_all(1)
	xp_bg_border.set_content_margin_all(0)
	xp_bg_border.set_corner_radius_all(0)
	_xp_bar.add_theme_stylebox_override("background", xp_bg_border)
	_xp_bar_lbl = Label.new()
	_xp_bar_lbl.position = Vector2(xp_x, xp_y - 1)
	_xp_bar_lbl.size = Vector2(xp_w, 10)
	_xp_bar_lbl.add_theme_font_size_override("font_size", 11)
	_xp_bar_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_xp_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_panel.add_child(_xp_bar_lbl)

func _set_hotbar_slot(idx : int, skill : Dictionary) -> void:
	if idx < 0 or idx >= HOTBAR_SLOTS:
		return
	_hotbar_skills[idx] = skill
	var icon_node : TextureRect = _hotbar_icons[idx]
	if skill.is_empty():
		icon_node.texture = null
	else:
		var icon_path : String = skill.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_node.texture = load(icon_path)
		else:
			icon_node.texture = null

func _activate_hotbar_slot(idx : int) -> void:
	if idx < 0 or idx >= HOTBAR_SLOTS:
		return
	var skill : Dictionary = _hotbar_skills[idx]
	if skill.is_empty():
		return
	# Check cooldown
	if _hotbar_cooldowns[idx] > 0.0:
		_log_combat("[color=gray]" + skill.get("name", "") + " is on cooldown (" + str(int(_hotbar_cooldowns[idx])) + "s)[/color]")
		return
	# Self-cast skills fire immediately (not queued)
	var is_self_cast : bool = skill.get("self_cast", false)
	if is_self_cast:
		var cost : float = skill.get("action_cost", 0.0)
		if ham_action < cost:
			_log_combat("[color=gray]Not enough action[/color]")
			return
		ham_action -= cost
		_hotbar_cooldowns[idx] = skill.get("cooldown", 10.0)
		_execute_self_cast(skill)
		return

	# Combat skills — queue them
	if _combat_queue.size() >= QUEUE_MAX:
		_log_combat("[color=gray]Queue full! (max %d)[/color]" % QUEUE_MAX)
		return
	# Check target exists
	if _current_target == null or not is_instance_valid(_current_target) or _tgt_stat(_current_target, "is_dead", false):
		_log_combat("[color=gray]No valid target[/color]")
		return
	# Check action cost
	var cost : float = skill.get("action_cost", 0.0)
	if ham_action < cost:
		_log_combat("[color=gray]Not enough action[/color]")
		return

	_combat_queue.append(skill.get("id", ""))
	_log_combat("[color=cyan]Queued: " + skill.get("name", "") + " (" + str(_combat_queue.size()) + "/" + str(QUEUE_MAX) + ")[/color]")
	# Start queue timer if this is the first skill queued
	if _combat_queue.size() == 1:
		_queue_timer = 0.5  # short delay before first execute

func _execute_self_cast(skill : Dictionary) -> void:
	if skill.get("id", "") == "sensu_bean":
		_sensu_active = true
		_sensu_timer = SENSU_DURATION
		_log_combat("[color=green]Sensu Bean activated! Healing over " + str(int(SENSU_DURATION)) + "s[/color]")
		_spawn_damage_text(_active, "SENSU BEAN", Color(0.2, 1.0, 0.3))
		_spawn_heal_effect(_active)
	elif skill.get("id", "") == "sprint":
		_sprint_active = true
		_sprint_timer = SPRINT_DURATION
		_log_combat("[color=aqua]Sprint activated! Moving 65% faster for " + str(int(SPRINT_DURATION)) + "s[/color]")
		_spawn_damage_text(_active, "SPRINT", Color(0.3, 0.8, 1.0))

func _tick_combat_queue(delta : float) -> void:
	if _combat_queue.is_empty():
		return
	if _current_target == null or not is_instance_valid(_current_target) or _tgt_stat(_current_target, "is_dead", false):
		_combat_queue.clear()
		return
	_queue_timer -= delta
	if _queue_timer <= 0.0:
		_execute_queued_skill()
		_queue_timer = QUEUE_INTERVAL

func _execute_queued_skill() -> void:
	if _combat_queue.is_empty():
		return
	var skill_id : String = _combat_queue.pop_front()
	var skill : Dictionary = SKILL_DATA.get(skill_id, {})
	if skill.is_empty():
		return
	# Check target and range
	if _current_target == null or not is_instance_valid(_current_target) or _tgt_stat(_current_target, "is_dead", false):
		_log_combat("[color=gray]Target lost — queue cleared[/color]")
		_combat_queue.clear()
		return
	var dist : float = _active.global_position.distance_to(_current_target.global_position)
	var atk_range : float = ATTACK_RANGE_MELEE if character_class == "melee" else ATTACK_RANGE_RANGED
	if dist > atk_range:
		_log_combat("[color=gray]Target out of range — " + skill.get("name", "") + " failed[/color]")
		return
	# Check and spend action cost
	var cost : float = skill.get("action_cost", 0.0)
	if ham_action < cost:
		_log_combat("[color=gray]Not enough action for " + skill.get("name", "") + "[/color]")
		return
	ham_action -= cost
	# Find hotbar slot to set cooldown
	for i in range(HOTBAR_SLOTS):
		if _hotbar_skills[i].get("id", "") == skill_id:
			_hotbar_cooldowns[i] = skill.get("cooldown", 10.0)
			break
	# Apply damage
	var dmg : float = get_effective_damage() * skill.get("dmg_mult", 1.0) + randf_range(-5, 10)
	if dmg > 0.0:
		_tgt_take_damage(_current_target, dmg, "health")
	# Apply state
	var state_name : String = skill.get("state", "")
	var state_dur : float = skill.get("state_dur", 0.0)
	if state_name != "":
		_tgt_apply_state(_current_target, state_name, state_dur)
	# Enter combat when using offensive skills on a target
	_auto_attacking = true
	_in_combat = true

	# Play ability anim — use "dizzy" anim for dizzy skills, "attack" for everything else
	var ability_anim := "dizzy" if state_name == "dizzy" else "attack"
	_play_anim(ability_anim)
	_anim_state = "attack"
	# _play_anim sets timer to 1.0s if moving; only set full length if standing still
	if _attack_anim_timer <= 0.0:
		var _skill_ap := _get_active_anim()
		if _skill_ap and _skill_ap.has_animation(ability_anim):
			_attack_anim_timer = _skill_ap.get_animation(ability_anim).length
		else:
			_attack_anim_timer = 2.0
	# Effects and logging
	var sn := _tgt_display_name(_current_target)
	if dmg > 0.0:
		_log_combat("[color=yellow]" + skill.get("name", "") + " → " + sn + " for " + str(int(dmg)) + " dmg[/color]")
		_spawn_damage_text(_current_target, str(int(dmg)), Color(1.0, 1.0, 0.2))
	if character_class == "ranged":
		_spawn_laser_effect(_active, _current_target, 0.4)
	else:
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(_current_target):
				_spawn_melee_hit_effect(_current_target)
		)
	if state_name == "dizzy":
		_log_combat("[color=orange]" + sn + " is dizzied for " + str(int(state_dur)) + "s![/color]")
		_spawn_damage_text(_current_target, "DIZZY", Color(0.9, 0.8, 0.2))
		_spawn_dizzy_effect(_current_target)
	elif state_name == "knockdown":
		_log_combat("[color=red]" + sn + " is knocked down![/color]")
		_spawn_damage_text(_current_target, "KNOCKDOWN", Color(1, 0.3, 0.2))
		_play_anim_on_node(_current_target, "kd")

func _tick_hotbar(delta : float) -> void:
	for i in range(HOTBAR_SLOTS):
		if _hotbar_cooldowns[i] > 0.0:
			_hotbar_cooldowns[i] -= delta
			_hotbar_cd_labels[i].text = str(int(ceilf(_hotbar_cooldowns[i])))
			_hotbar_cd_labels[i].visible = true
		else:
			_hotbar_cooldowns[i] = 0.0
			_hotbar_cd_labels[i].visible = false

# ════════════════════════════════════════════════════════════
#  SKILLS WINDOW (P)
# ════════════════════════════════════════════════════════════
func _build_skills_window() -> void:
	_skills_window = Panel.new()
	var vp := get_viewport().get_visible_rect().size
	_skills_window.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.5 - 180)
	_skills_window.size = Vector2(400, 360)
	var sw_style := StyleBoxFlat.new()
	sw_style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sw_style.border_color = Color(0.4, 0.35, 0.25)
	sw_style.set_border_width_all(2)
	sw_style.set_corner_radius_all(6)
	_skills_window.add_theme_stylebox_override("panel", sw_style)
	_skills_window.visible = false
	_hud.add_child(_skills_window)

	# Title
	var title := Label.new()
	title.text = "Skills"
	title.position = Vector2(160, 8)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_skills_window.add_child(title)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(370, 5)
	close_btn.size = Vector2(24, 24)
	close_btn.pressed.connect(_toggle_skills_window)
	_skills_window.add_child(close_btn)

	# Skill entries
	var y_off := 45
	for skill_id in SKILL_DATA:
		var skill : Dictionary = SKILL_DATA[skill_id]
		_build_skill_entry(_skills_window, skill, y_off)
		y_off += 100

	# Instructions
	var instr := Label.new()
	instr.text = "Click a skill to place it on your hotbar (slots 1-8)"
	instr.position = Vector2(20, y_off + 20)
	instr.add_theme_font_size_override("font_size", 10)
	instr.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_skills_window.add_child(instr)

func _build_skill_entry(parent : Panel, skill : Dictionary, y : int) -> void:
	var entry := Panel.new()
	entry.position = Vector2(15, y)
	entry.size = Vector2(370, 85)
	var e_style := StyleBoxFlat.new()
	e_style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	e_style.border_color = skill.get("color", Color(0.4, 0.4, 0.4))
	e_style.set_border_width_all(1)
	e_style.set_corner_radius_all(3)
	entry.add_theme_stylebox_override("panel", e_style)
	parent.add_child(entry)

	# Icon
	var icon_path : String = skill.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.position = Vector2(8, 8)
		icon.size = Vector2(40, 40)
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry.add_child(icon)
	else:
		var icon := ColorRect.new()
		icon.position = Vector2(8, 8)
		icon.size = Vector2(40, 40)
		icon.color = skill.get("color", Color(0.5, 0.5, 0.5))
		entry.add_child(icon)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = skill.get("name", "")
	name_lbl.position = Vector2(58, 5)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	entry.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = skill.get("desc", "")
	desc_lbl.position = Vector2(58, 25)
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	entry.add_child(desc_lbl)

	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Action: " + str(int(skill.get("action_cost", 0))) + "  |  CD: " + str(int(skill.get("cooldown", 0))) + "s  |  DMG: " + str(skill.get("dmg_mult", 1.0)) + "x"
	stats_lbl.position = Vector2(58, 45)
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	entry.add_child(stats_lbl)

	# Click to add to hotbar
	var btn := Button.new()
	btn.text = "Add to Hotbar"
	btn.position = Vector2(260, 55)
	btn.size = Vector2(100, 24)
	var sk_copy := skill.duplicate()
	btn.pressed.connect(func(): _add_skill_to_next_slot(sk_copy))
	entry.add_child(btn)

func _add_skill_to_next_slot(skill : Dictionary) -> void:
	# Find first empty slot, or first slot with same skill to replace
	for i in range(HOTBAR_SLOTS):
		if _hotbar_skills[i].is_empty():
			_set_hotbar_slot(i, skill)
			_log_combat("[color=green]" + skill.get("name", "") + " placed on slot " + str(i + 1) + "[/color]")
			return
		if _hotbar_skills[i].get("id", "") == skill.get("id", ""):
			return  # already on hotbar
	_log_combat("[color=gray]Hotbar full[/color]")

func _toggle_skills_window() -> void:
	_skills_visible = !_skills_visible
	if _skills_window:
		_skills_window.visible = _skills_visible

# ════════════════════════════════════════════════════════════
#  RADIAL MENU (SWG-style right-click pie menu)
# ════════════════════════════════════════════════════════════
func _open_radial_menu(screen_pos : Vector2) -> void:
	_close_radial_menu()
	# Raycast to see what we right-clicked
	var hit := _raycast_from_mouse(screen_pos)
	print("RADIAL: right-click at ", screen_pos, " hit type=", hit.type, " node=", hit.node)
	if hit.type == "ground" or hit.type == "none":
		return  # Don't open on empty ground

	_radial_target_node = hit.node
	_radial_target_type = hit.type

	# Determine options based on what was clicked
	var options : Array = []
	match hit.type:
		"mob":
			options = [{"label": "Attack", "action": "attack"}]
		"vehicle":
			if _mounted:
				options = [{"label": "Dismount", "action": "dismount"}]
			else:
				options = [
					{"label": "Mount", "action": "mount"},
					{"label": "Stash", "action": "stash"},
				]
		"terminal":
			options = [{"label": "Use", "action": "use_terminal"}]
		"player":
			options = [
				{"label": "Party Invite", "action": "party_invite"},
				{"label": "Trade", "action": "trade"},
				{"label": "Duel", "action": "duel"},
			]
		_:
			options = [{"label": "Examine", "action": "examine"}]

	if options.is_empty():
		return

	# Build the radial menu UI — compact buttons, no background glass
	_radial_menu = Control.new()
	_radial_menu.z_index = 100
	_hud.add_child(_radial_menu)
	_radial_menu_visible = true

	var center := screen_pos
	var count := options.size()

	# Stack buttons vertically centered on click position, tight spacing
	var btn_h := 28.0
	var btn_w := 100.0
	var gap := 4.0
	var total_h := count * btn_h + (count - 1) * gap
	var start_y := center.y - total_h * 0.5

	for i in range(count):
		var btn := Button.new()
		btn.text = options[i].label
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.position = Vector2(center.x - btn_w * 0.5, start_y + i * (btn_h + gap))
		btn.add_theme_font_size_override("font_size", 11)

		# Style — dark blue translucent like SWG
		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.06, 0.15, 0.25, 0.9)
		btn_sb.border_color = Color(0.2, 0.5, 0.7, 0.8)
		btn_sb.set_border_width_all(1)
		btn_sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_sb)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.1, 0.3, 0.45, 0.95)
		btn_hover.border_color = Color(0.3, 0.7, 0.9, 1.0)
		btn_hover.set_border_width_all(1)
		btn_hover.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", btn_hover)

		btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1.0))

		var action : String = options[i].action
		btn.pressed.connect(_on_radial_action.bind(action))
		_radial_menu.add_child(btn)

func _make_radial_circle(center : Vector2, radius : float, color : Color) -> ColorRect:
	# Approximation — use a ColorRect with rounded corners (true circle would need a shader)
	var cr := ColorRect.new()
	cr.size = Vector2(radius * 2, radius * 2)
	cr.position = center - Vector2(radius, radius)
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr

func _close_radial_menu() -> void:
	if _radial_menu and is_instance_valid(_radial_menu):
		_radial_menu.queue_free()
		_radial_menu = null
	_radial_menu_visible = false
	_radial_target_node = null
	_radial_target_type = ""

func _on_radial_action(action : String) -> void:
	var target := _radial_target_node
	var target_type := _radial_target_type
	_close_radial_menu()

	match action:
		"attack":
			# Set target and start auto-attacking
			if target and is_instance_valid(target):
				_current_target = target
				_auto_attacking = true
				_attack_timer = 0.0  # attack immediately
				_update_target_indicator()
				var dist : float = _active.global_position.distance_to(target.global_position)
				var atk_range : float = ATTACK_RANGE_MELEE if character_class == "melee" else ATTACK_RANGE_RANGED
				_log_combat("[color=yellow]Target: " + _tgt_display_name(target) + " (dist: " + str(int(dist)) + ", range: " + str(int(atk_range)) + ")[/color]")
		"mount":
			print("MOUNT ACTION: target=", target, " valid=", is_instance_valid(target) if target else false)
			if target and is_instance_valid(target):
				_vehicle_mount = target
				_vehicle_base_y = target.position.y
				var vname := target.name.to_lower()
				_vehicle_can_fly = not ("landspeeder" in vname or "speeder" in vname)
				print("MOUNT: setting vehicle=", target.name, " can_fly=", _vehicle_can_fly)
				_toggle_mount(true)
			else:
				print("MOUNT: target is null or invalid!")
		"dismount":
			_toggle_mount()
		"stash":
			if target and not _mounted:
				_log_combat("[color=gray]Vehicle stashed.[/color]")
				target.visible = false
		"use_terminal":
			if target and is_instance_valid(target) and target.has_method("interact"):
				target.interact(self)
			else:
				_log_combat("[color=yellow]You must be closer to use this.[/color]")
		"party_invite":
			_log_combat("[color=cyan]Party invite sent.[/color]")
		"trade":
			_log_combat("[color=cyan]Trade request sent.[/color]")
		"duel":
			_log_combat("[color=cyan]Duel request sent.[/color]")
		"examine":
			if target:
				_log_combat("[color=gray]You examine " + str(target.name) + ".[/color]")

# ════════════════════════════════════════════════════════════
#  STATS WINDOW (L key)
# ════════════════════════════════════════════════════════════
var _stats_content : VBoxContainer = null

func _toggle_stats_window() -> void:
	_stats_visible = !_stats_visible
	if _stats_window == null:
		_build_stats_window()
	_stats_window.visible = _stats_visible
	if _stats_visible:
		_refresh_stats_window()

func _build_stats_window() -> void:
	var vp := get_viewport().get_visible_rect().size
	_stats_window = Panel.new()
	_stats_window.position = Vector2(vp.x * 0.5 - 180, vp.y * 0.5 - 250)
	_stats_window.size = Vector2(360, 500)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.06, 0.07, 0.12, 0.95)
	sty.border_color = Color(0.35, 0.55, 0.85, 0.75)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(5)
	_stats_window.add_theme_stylebox_override("panel", sty)
	_stats_window.visible = false
	_hud.add_child(_stats_window)

	# Title
	var title := Label.new()
	title.text = "CHARACTER STATS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	title.position = Vector2(12, 8)
	title.size = Vector2(300, 24)
	_stats_window.add_child(title)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(330, 5)
	close_btn.size = Vector2(24, 24)
	close_btn.pressed.connect(func(): _stats_visible = false; _stats_window.visible = false)
	_stats_window.add_child(close_btn)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 36)
	scroll.size = Vector2(344, 455)
	_stats_window.add_child(scroll)

	_stats_content = VBoxContainer.new()
	_stats_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stats_content)

func _refresh_stats_window() -> void:
	if _stats_content == null:
		return
	# Clear old
	for c in _stats_content.get_children():
		c.queue_free()

	var name_str : String = PlayerData.nickname if PlayerData.nickname != "" else CHAR_DISPLAY_NAMES.get(_selected_char_id, "Player")
	_add_stat_header(name_str + "  —  Level " + str(level))
	_add_stat_row("Class", character_class.to_upper())
	_add_stat_row("XP", "%d / %d" % [int(exp_points), int(exp_needed)])
	_add_stat_row("Unspent Points", str(unspent_points))

	_add_stat_header("HAM")
	_add_stat_row("Health", "%d / %d" % [int(ham_health), int(get_effective_max_health())])
	_add_stat_row("Action", "%d / %d" % [int(ham_action), int(get_effective_max_action())])
	_add_stat_row("Mind", "%d / %d" % [int(ham_mind), int(get_effective_max_mind())])

	_add_stat_header("OFFENSE")
	_add_stat_row("Accuracy", str(int(get_effective_accuracy())))
	_add_stat_row("Damage", str(int(get_effective_damage())))

	_add_stat_header("DEFENSE")
	_add_stat_row("Melee Defense", str(int(_get_prof_stat("melee_defense"))))
	_add_stat_row("Ranged Defense", str(int(_get_prof_stat("ranged_defense"))))
	_add_stat_row("Dodge", str(int(_get_prof_stat("dodge"))))
	_add_stat_row("Block", str(int(_get_prof_stat("block"))))
	_add_stat_row("Counterattack", str(int(_get_prof_stat("counterattack"))))

	_add_stat_header("STATE DEFENSE")
	_add_stat_row("Def vs Dizzy", str(int(_get_prof_stat("defense_vs_dizzy"))))
	_add_stat_row("Def vs Knockdown", str(int(_get_prof_stat("defense_vs_knockdown"))))
	_add_stat_row("Def vs Stun", str(int(_get_prof_stat("defense_vs_stun"))))
	_add_stat_row("Def vs Blind", str(int(_get_prof_stat("defense_vs_blind"))))

	_add_stat_header("WOUNDS")
	_add_stat_row("Health Wounds", str(int(wound_health)))
	_add_stat_row("Action Wounds", str(int(wound_action)))
	_add_stat_row("Mind Wounds", str(int(wound_mind)))

func _add_stat_header(text : String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_stats_content.add_child(lbl)
	var sep := HSeparator.new()
	_stats_content.add_child(sep)

func _add_stat_row(label_text : String, value_text : String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size.x = 120
	hbox.add_child(val)
	_stats_content.add_child(hbox)

func _add_stat_row_with_btn(label_text : String, value_text : String, attr_id : String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size.x = 80
	hbox.add_child(val)
	var btn := Button.new()
	btn.text = "+"
	btn.custom_minimum_size = Vector2(28, 22)
	btn.disabled = unspent_points <= 0
	btn.pressed.connect(func():
		spend_stat_point(attr_id)
		_refresh_stats_window()
	)
	hbox.add_child(btn)
	_stats_content.add_child(hbox)

func _get_prof_stat(stat_name : String) -> float:
	var totals := ProfessionData.compute_total_modifiers(_learned_boxes)
	return totals.get(stat_name, 0.0)

# ════════════════════════════════════════════════════════════
#  INVENTORY
# ════════════════════════════════════════════════════════════
var _inv_window : Panel = null
var _inv_visible := false
var _inv_drag := false
const INV_COLS := 5
const INV_ROWS := 5
const INV_SLOT_SIZE := 52
const INV_SLOT_GAP := 6
const INV_PAD := 14

func _toggle_inventory() -> void:
	_inv_visible = !_inv_visible
	if _inv_window == null:
		_build_inventory()
	else:
		_refresh_inv_slots()
	_inv_window.visible = _inv_visible

func _build_inventory() -> void:
	var vp := get_viewport().get_visible_rect().size
	var grid_w := INV_COLS * (INV_SLOT_SIZE + INV_SLOT_GAP) - INV_SLOT_GAP
	var grid_h := INV_ROWS * (INV_SLOT_SIZE + INV_SLOT_GAP) - INV_SLOT_GAP
	var win_w := grid_w + INV_PAD * 2
	var win_h := grid_h + INV_PAD * 2 + 70

	_inv_window = Panel.new()
	_inv_window.position = Vector2(vp.x * 0.5 - win_w * 0.5, vp.y * 0.5 - win_h * 0.5 + 60)
	_inv_window.size = Vector2(win_w, win_h)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.03, 0.04, 0.10, 0.94)
	sty.border_color = Color(0.35, 0.55, 0.85, 0.70)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(5)
	_inv_window.add_theme_stylebox_override("panel", sty)
	_inv_window.visible = false
	_inv_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_inv_window.gui_input.connect(_on_inv_drag)
	_hud.add_child(_inv_window)

	# Top glow bar
	var top_bar := ColorRect.new()
	top_bar.size = Vector2(win_w, 3)
	top_bar.color = Color(0.22, 0.78, 1.0, 0.85)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_window.add_child(top_bar)

	# Title
	var title := Label.new()
	title.text = "I N V E N T O R Y"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(win_w, 18)
	title.position = Vector2(0, 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_window.add_child(title)

	# Hint
	var hint := Label.new()
	hint.text = "double-click to equip / unequip"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(win_w, 12)
	hint.position = Vector2(0, 22)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_window.add_child(hint)

	# Grid container
	var grid := Control.new()
	grid.name = "Grid"
	grid.position = Vector2(INV_PAD, 38)
	grid.size = Vector2(grid_w, grid_h)
	_inv_window.add_child(grid)

	# Credit label
	var credit_lbl := Label.new()
	credit_lbl.name = "CreditLabel"
	credit_lbl.add_theme_font_size_override("font_size", 12)
	credit_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	credit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_lbl.size = Vector2(win_w, 20)
	credit_lbl.position = Vector2(0, win_h - 32)
	_inv_window.add_child(credit_lbl)

	# Bottom bar
	var bot_bar := ColorRect.new()
	bot_bar.size = Vector2(win_w, 2)
	bot_bar.position = Vector2(0, win_h - 2)
	bot_bar.color = Color(0.22, 0.78, 1.0, 0.50)
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_window.add_child(bot_bar)

	# Close hint
	var close_hint := Label.new()
	close_hint.text = "Press I to close"
	close_hint.add_theme_font_size_override("font_size", 9)
	close_hint.add_theme_color_override("font_color", Color(0.35, 0.4, 0.5))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.size = Vector2(win_w, 14)
	close_hint.position = Vector2(0, win_h - 14)
	close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_window.add_child(close_hint)

	_refresh_inv_slots()

func _refresh_inv_slots() -> void:
	if _inv_window == null:
		return
	var grid := _inv_window.get_node_or_null("Grid")
	if grid == null:
		return
	# Clear old slots
	for ch in grid.get_children():
		ch.queue_free()
	# Build slots
	for row in range(INV_ROWS):
		for col in range(INV_COLS):
			var idx := row * INV_COLS + col
			var slot := Panel.new()
			slot.position = Vector2(col * (INV_SLOT_SIZE + INV_SLOT_GAP), row * (INV_SLOT_SIZE + INV_SLOT_GAP))
			slot.size = Vector2(INV_SLOT_SIZE, INV_SLOT_SIZE)

			var has_item : bool = idx < inventory.size()
			var equipped : bool = has_item and inventory[idx].get("equipped", false)

			var ssty := StyleBoxFlat.new()
			if equipped:
				ssty.bg_color = Color(0.07, 0.22, 0.38, 0.96)
				ssty.border_color = Color(0.28, 0.85, 1.0, 1.0)
				ssty.set_border_width_all(2)
			else:
				ssty.bg_color = Color(0.10, 0.08, 0.16, 0.90)
				ssty.border_color = Color(0.28, 0.24, 0.46, 0.80)
				ssty.set_border_width_all(1)
			ssty.set_corner_radius_all(3)
			slot.add_theme_stylebox_override("panel", ssty)

			if has_item:
				var item : Dictionary = inventory[idx]
				# Item name label
				var name_lbl := Label.new()
				name_lbl.text = item.get("name", "?")
				name_lbl.add_theme_font_size_override("font_size", 8)
				name_lbl.add_theme_color_override("font_color", item.get("icon_color", Color.WHITE))
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				name_lbl.size = Vector2(INV_SLOT_SIZE, INV_SLOT_SIZE)
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(name_lbl)

				# Equipped badge
				if equipped:
					var eq_lbl := Label.new()
					eq_lbl.text = "EQ"
					eq_lbl.add_theme_font_size_override("font_size", 7)
					eq_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
					eq_lbl.position = Vector2(2, 2)
					eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					slot.add_child(eq_lbl)

				slot.mouse_filter = Control.MOUSE_FILTER_STOP
				slot.gui_input.connect(_on_inv_slot_input.bind(idx))
			else:
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

			grid.add_child(slot)

	# Update credits
	var credit_lbl := _inv_window.get_node_or_null("CreditLabel") as Label
	if credit_lbl:
		credit_lbl.text = "Credits:  %d ¢" % _credits

func _on_inv_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_inv_drag = event.pressed and event.position.y <= 36.0
	elif event is InputEventMouseMotion and _inv_drag:
		var vp := get_viewport().get_visible_rect().size
		var new_pos : Vector2 = _inv_window.position + event.relative
		_inv_window.position = Vector2(
			clampf(new_pos.x, 0.0, vp.x - _inv_window.size.x),
			clampf(new_pos.y, 0.0, vp.y - _inv_window.size.y)
		)

func _on_inv_slot_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		toggle_equip(idx)

func toggle_equip(idx: int) -> void:
	if idx < 0 or idx >= inventory.size():
		return
	var item : Dictionary = inventory[idx]
	var equipping : bool = not item.get("equipped", false)

	# Unequip any other item in the same slot first
	if equipping:
		var slot_type = item.get("slot", 0)
		for i in range(inventory.size()):
			if i != idx and inventory[i].get("slot", 0) == slot_type and inventory[i].get("equipped", false):
				inventory[i]["equipped"] = false
				_on_item_unequipped(inventory[i])

	item["equipped"] = equipping
	if equipping:
		_on_item_equipped(item)
	else:
		_on_item_unequipped(item)
	_refresh_inv_slots()

func _on_item_equipped(item: Dictionary) -> void:
	var stats : Dictionary = item.get("stats", {})
	# Apply attack speed
	if stats.has("attack_speed"):
		ATTACK_COOLDOWN = stats["attack_speed"]
		print("EQUIP: attack speed set to ", ATTACK_COOLDOWN, "s")
	# Apply damage
	if stats.has("damage_min") and stats.has("damage_max"):
		print("EQUIP: damage set to ", stats["damage_min"], "-", stats["damage_max"])
	# Attach weapon mesh to hand
	_attach_weapon_to_hand(item)

func _on_item_unequipped(_item: Dictionary) -> void:
	# Reset attack speed to default
	ATTACK_COOLDOWN = 5.0
	print("UNEQUIP: attack speed reset to 5.0s")
	# Remove weapon mesh
	_detach_weapon_from_hand()

func _attach_weapon_to_hand(item: Dictionary) -> void:
	_detach_weapon_from_hand()
	var mesh_path : String = item.get("mesh_path", "")
	if mesh_path == "" or not ResourceLoader.exists(mesh_path):
		print("EQUIP: no mesh at ", mesh_path)
		return
	var skel : Skeleton3D = _find_skeleton(_active) if _active else null
	if skel == null:
		print("EQUIP: no skeleton found")
		return
	# Find right hand bone
	var hand_idx := -1
	for i in range(skel.get_bone_count()):
		var bname : String = skel.get_bone_name(i)
		if "RightHand" in bname or "Right_Hand" in bname or "righthand" in bname.to_lower():
			hand_idx = i
			break
	if hand_idx < 0:
		# Fallback: try partial match
		for i in range(skel.get_bone_count()):
			var bname : String = skel.get_bone_name(i).to_lower()
			if "hand" in bname and "right" in bname:
				hand_idx = i
				break
	if hand_idx < 0:
		print("EQUIP: no right hand bone found. Bones: ", _get_bone_names(skel))
		return
	# Create BoneAttachment3D
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = hand_idx
	attachment.name = "WeaponAttachment"
	skel.add_child(attachment)
	# Load weapon mesh
	var weapon_scene : PackedScene = load(mesh_path)
	var weapon := weapon_scene.instantiate()
	# Position/rotation/scale relative to BoneAttachment3D (RightHand bone)
	weapon.position = Vector3(0.239, 0.174, -0.281)
	weapon.rotation_degrees = Vector3(18.6, 54.1, -177.9)
	weapon.scale = Vector3(1.0, 1.0, 1.0)
	attachment.add_child(weapon)
	# Apply textures from the same folder if the mesh is untextured
	var folder := mesh_path.get_base_dir() + "/"
	_apply_weapon_textures(weapon, folder)
	_equipped_weapon_node = attachment
	print("EQUIP: attached '", item.get("name", ""), "' to bone '", skel.get_bone_name(hand_idx), "'")

func _apply_weapon_textures(node: Node, folder: String) -> void:
	# Find texture PNGs in the folder and apply to any MeshInstance3D children
	var albedo_path := ""
	var normal_path := ""
	var metallic_path := ""
	var roughness_path := ""
	# Search for texture files — use the _texture.png (albedo), _normal, _metallic, _roughness
	for suffix in ["_texture.png", "_texture_0.png"]:
		for f in DirAccess.get_files_at(folder):
			if f.ends_with(suffix) and "normal" not in f and "metallic" not in f and "roughness" not in f:
				albedo_path = folder + f
				break
	for f in DirAccess.get_files_at(folder):
		if f.ends_with("_normal.png"):
			normal_path = folder + f
		elif f.ends_with("_metallic.png"):
			metallic_path = folder + f
		elif f.ends_with("_roughness.png"):
			roughness_path = folder + f

	if albedo_path == "":
		return

	var albedo_tex : Texture2D = load(albedo_path) if ResourceLoader.exists(albedo_path) else null
	var normal_tex : Texture2D = load(normal_path) if normal_path != "" and ResourceLoader.exists(normal_path) else null
	var metallic_tex : Texture2D = load(metallic_path) if metallic_path != "" and ResourceLoader.exists(metallic_path) else null
	var roughness_tex : Texture2D = load(roughness_path) if roughness_path != "" and ResourceLoader.exists(roughness_path) else null

	# Apply to all mesh instances in the weapon
	for child in node.get_children():
		_apply_weapon_textures(child, folder)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for surf_idx in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = albedo_tex
			if normal_tex:
				mat.normal_enabled = true
				mat.normal_texture = normal_tex
			if metallic_tex:
				mat.metallic = 1.0
				mat.metallic_texture = metallic_tex
			if roughness_tex:
				mat.roughness_texture = roughness_tex
			mi.set_surface_override_material(surf_idx, mat)
		print("EQUIP_TEX: applied textures to '", mi.name, "' albedo=", albedo_path)

func _detach_weapon_from_hand() -> void:
	if _equipped_weapon_node and is_instance_valid(_equipped_weapon_node):
		_equipped_weapon_node.queue_free()
		_equipped_weapon_node = null

# ════════════════════════════════════════════════════════════
#  PROFESSION TREE
# ════════════════════════════════════════════════════════════
var _prof_window : Panel = null
var _prof_visible := false
var _prof_content : Control = null

func _toggle_profession_window() -> void:
	_prof_visible = !_prof_visible
	if _prof_window == null:
		_build_profession_window()
	_prof_window.visible = _prof_visible
	if _prof_visible:
		_refresh_profession_window()

var _prof_drag := false

func _build_profession_window() -> void:
	var vp := get_viewport().get_visible_rect().size
	var box_w := 190.0
	var box_h := 55.0
	var box_gap := 8.0
	var box_count := 6  # novice + 4 tiers + master
	var win_w := box_w + 40.0
	var win_h := box_count * (box_h + box_gap) + 100.0

	_prof_window = Panel.new()
	_prof_window.position = Vector2(vp.x * 0.5 - win_w * 0.5, vp.y * 0.5 - win_h * 0.5)
	_prof_window.size = Vector2(win_w, win_h)
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.02, 0.06, 0.10, 0.95)
	sty.border_color = Color(0.15, 0.40, 0.50, 0.80)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(3)
	_prof_window.add_theme_stylebox_override("panel", sty)
	_prof_window.visible = false
	_prof_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_prof_window.gui_input.connect(_on_prof_drag)
	_hud.add_child(_prof_window)

	# Title
	var title := Label.new()
	title.text = "Street Fighter"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.5, 0.85, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(win_w, 24)
	title.position = Vector2(0, 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prof_window.add_child(title)

	# Content area for boxes
	_prof_content = Control.new()
	_prof_content.name = "BoxContent"
	_prof_content.position = Vector2(20, 38)
	_prof_content.size = Vector2(box_w, win_h - 80)
	_prof_window.add_child(_prof_content)

	# Advances to hint
	var adv_lbl := Label.new()
	adv_lbl.text = "Advances to: MMA, Fencer"
	adv_lbl.add_theme_font_size_override("font_size", 9)
	adv_lbl.add_theme_color_override("font_color", Color(0.35, 0.45, 0.55, 0.6))
	adv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv_lbl.size = Vector2(win_w, 14)
	adv_lbl.position = Vector2(0, win_h - 18)
	adv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prof_window.add_child(adv_lbl)

func _on_prof_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_prof_drag = event.pressed and event.position.y <= 36.0
	elif event is InputEventMouseMotion and _prof_drag:
		var vp := get_viewport().get_visible_rect().size
		var new_pos : Vector2 = _prof_window.position + event.relative
		_prof_window.position = Vector2(
			clampf(new_pos.x, 0.0, vp.x - _prof_window.size.x),
			clampf(new_pos.y, 0.0, vp.y - _prof_window.size.y)
		)

func _refresh_profession_window() -> void:
	if _prof_content == null:
		return
	for c in _prof_content.get_children():
		c.queue_free()

	var base_id := "streetfighter" if character_class == "melee" else "marksman"
	var prof := ProfessionData.get_profession(base_id)
	if prof.is_empty():
		return

	# Collect all boxes in order: novice, tiers 1-4, master (bottom to top in display)
	var all_boxes : Array = []
	all_boxes.append(prof.novice)
	for disc in prof.disciplines:
		for box in disc.boxes:
			all_boxes.append(box)
	all_boxes.append(prof.master)

	var box_w := 190.0
	var box_h := 55.0
	var box_gap := 8.0
	var total := all_boxes.size()

	# Draw boxes bottom-to-top (novice at bottom, master at top)
	for i in range(total):
		var box : Dictionary = all_boxes[i]
		var tier_num := i + 1  # 1=novice, 2=SF I, ..., 6=master
		# Y position: bottom-to-top
		var y_pos := (total - 1 - i) * (box_h + box_gap)

		var learned : bool = box.id in _learned_boxes
		var can_learn_result := ProfessionData.can_learn_box(box, _learned_boxes, _xp_pools, _skill_points_available, _credits)
		var can_learn : bool = can_learn_result.can_learn

		# Box panel
		var slot := Panel.new()
		slot.position = Vector2(0, y_pos)
		slot.size = Vector2(box_w, box_h)
		var ssty := StyleBoxFlat.new()
		if learned:
			ssty.bg_color = Color(0.04, 0.14, 0.18, 0.96)
			ssty.border_color = Color(0.15, 0.65, 0.55, 1.0)
		elif can_learn:
			ssty.bg_color = Color(0.04, 0.10, 0.16, 0.96)
			ssty.border_color = Color(0.20, 0.60, 0.75, 1.0)
		else:
			ssty.bg_color = Color(0.05, 0.06, 0.10, 0.90)
			ssty.border_color = Color(0.18, 0.22, 0.30, 0.70)
		ssty.set_border_width_all(1)
		ssty.set_corner_radius_all(2)
		slot.add_theme_stylebox_override("panel", ssty)

		# Box name (line 1)
		var name_lbl := Label.new()
		name_lbl.text = box.name
		name_lbl.add_theme_font_size_override("font_size", 11)
		if learned:
			name_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.85))
		elif can_learn:
			name_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.45, 0.50, 0.55))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(box_w, 16)
		name_lbl.position = Vector2(0, 8)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_lbl)

		# Subtitle (line 2)
		var subtitle : String = box.get("subtitle", "")
		if subtitle != "":
			var sub_lbl := Label.new()
			sub_lbl.text = subtitle
			sub_lbl.add_theme_font_size_override("font_size", 9)
			sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65, 0.7))
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub_lbl.size = Vector2(box_w, 14)
			sub_lbl.position = Vector2(0, 26)
			sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(sub_lbl)

		# Tier number (bottom-right, SWG style)
		var tier_lbl := Label.new()
		tier_lbl.text = str(tier_num)
		tier_lbl.add_theme_font_size_override("font_size", 10)
		tier_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 0.7))
		tier_lbl.position = Vector2(box_w - 16, box_h - 16)
		tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tier_lbl)

		# Clickable — learn on click
		if not learned and can_learn:
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			var box_id : String = box.id
			slot.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_learn_skill_box(box_id)
			)
		else:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_prof_content.add_child(slot)

		# Connecting line to next box (except last)
		if i < total - 1:
			var line := ColorRect.new()
			line.size = Vector2(2, box_gap)
			line.position = Vector2(box_w * 0.5 - 1, y_pos + box_h)
			line.color = Color(0.2, 0.5, 0.6, 0.5)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_prof_content.add_child(line)

func _learn_skill_box(box_id : String) -> void:
	var box := ProfessionData.find_box(box_id)
	if box.is_empty():
		return
	var check := ProfessionData.can_learn_box(box, _learned_boxes, _xp_pools, _skill_points_available, _credits)
	if not check.can_learn:
		_log_combat("[color=red]Cannot learn: " + check.reason + "[/color]")
		return
	_learned_boxes.append(box_id)
	_skill_points_available -= box.cost_sp
	var xp_type : String = box.xp_type
	_xp_pools[xp_type] = _xp_pools.get(xp_type, 0) - box.xp_cost
	_credits -= box.credit_cost
	_log_combat("[color=green]Learned: " + box.name + "[/color]")
	# Apply modifiers
	var mods : Dictionary = box.get("modifiers", {})
	for key in mods:
		if key == "max_health_bonus":
			max_health += mods[key]
		elif key == "max_action_bonus":
			max_action_stat += mods[key]
		elif key == "max_mind_bonus":
			max_mind += mods[key]
	# Refresh window
	_refresh_profession_window()
	if _stats_visible:
		_refresh_stats_window()

# ════════════════════════════════════════════════════════════
#  MINIMAP
# ════════════════════════════════════════════════════════════
func _build_minimap() -> void:
	var vp := get_viewport().get_visible_rect().size
	_minimap_panel = Panel.new()
	_minimap_panel.position = Vector2(vp.x - MMAP_SIZE - 15, 10)
	_minimap_panel.size = Vector2(MMAP_SIZE, MMAP_SIZE)
	var mm_style := StyleBoxFlat.new()
	mm_style.bg_color = Color(0.05, 0.08, 0.05, 0.85)
	mm_style.border_color = Color(0.3, 0.35, 0.3)
	mm_style.set_border_width_all(2)
	mm_style.set_corner_radius_all(4)
	_minimap_panel.add_theme_stylebox_override("panel", mm_style)
	_make_draggable(_minimap_panel)
	_hud.add_child(_minimap_panel)

	# Location label
	var loc_lbl := Label.new()
	loc_lbl.text = "CORONET"
	loc_lbl.position = Vector2(8, 2)
	loc_lbl.add_theme_font_size_override("font_size", 10)
	loc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	_minimap_panel.add_child(loc_lbl)

	# Draw area — create with script pre-loaded
	var mm_script = load("res://Scripts/Client/UI/CoronetMinimap.gd") if ResourceLoader.exists("res://Scripts/Client/UI/CoronetMinimap.gd") else null
	_minimap_draw = Control.new()
	if mm_script:
		_minimap_draw.set_script(mm_script)
	_minimap_draw.position = Vector2(4, 18)
	_minimap_draw.size = Vector2(MMAP_SIZE - 8, MMAP_SIZE - 22)
	_minimap_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_panel.add_child(_minimap_draw)
	if _minimap_draw.get_script() != null:
		_minimap_draw.scene_ref = self

	# Coordinate display anchored below minimap
	_coord_label = Label.new()
	_coord_label.text = "X: 0  Y: 0  Z: 0"
	_coord_label.add_theme_font_size_override("font_size", 10)
	_coord_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	_coord_label.position = Vector2(_minimap_panel.position.x, _minimap_panel.position.y + MMAP_SIZE + 4)
	_coord_label.size = Vector2(MMAP_SIZE, 16)
	_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var coord_bg := StyleBoxFlat.new()
	coord_bg.bg_color = Color(0.05, 0.08, 0.05, 0.85)
	coord_bg.border_color = Color(0.3, 0.35, 0.3)
	coord_bg.set_border_width_all(1)
	coord_bg.set_corner_radius_all(3)
	_coord_label.add_theme_stylebox_override("normal", coord_bg)
	_hud.add_child(_coord_label)

	# Cogwheel options button — below coordinates
	_options_btn = Button.new()
	_options_btn.text = "⚙"
	_options_btn.position = Vector2(_minimap_panel.position.x + MMAP_SIZE - 28, _minimap_panel.position.y + MMAP_SIZE + 24)
	_options_btn.size = Vector2(28, 28)
	_options_btn.add_theme_font_size_override("font_size", 16)
	var gear_s := StyleBoxFlat.new()
	gear_s.bg_color = Color(0.08, 0.10, 0.16, 0.90)
	gear_s.border_color = Color(0.30, 0.45, 0.65, 0.60)
	gear_s.set_border_width_all(1); gear_s.set_corner_radius_all(4)
	var gear_h := gear_s.duplicate() as StyleBoxFlat
	gear_h.bg_color = Color(0.14, 0.18, 0.28, 0.95)
	_options_btn.add_theme_stylebox_override("normal", gear_s)
	_options_btn.add_theme_stylebox_override("hover", gear_h)
	_options_btn.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
	_options_btn.pressed.connect(_toggle_options)
	_hud.add_child(_options_btn)

func _toggle_options() -> void:
	_options_visible = not _options_visible
	if _options_visible:
		_show_options()
	elif _options_panel:
		_options_panel.queue_free()
		_options_panel = null

func _show_options() -> void:
	if _options_panel:
		_options_panel.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var pw := 420.0
	var ph := 520.0

	_options_panel = Panel.new()
	_options_panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	_options_panel.size = Vector2(pw, ph)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.04, 0.05, 0.12, 0.96)
	psb.border_color = Color(0.25, 0.45, 0.80, 0.70)
	psb.set_border_width_all(2); psb.set_corner_radius_all(8)
	_options_panel.add_theme_stylebox_override("panel", psb)
	_hud.add_child(_options_panel)

	var font = load("res://Assets/Fonts/Bebas_Neue/BebasNeue-Regular.ttf")
	var roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

	# Title
	var title := Label.new()
	title.add_theme_font_override("font", font)
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.00))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(pw, 40)
	_options_panel.add_child(title)

	# Close X button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(pw - 36, 8)
	close_btn.size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.80, 0.35, 0.30))
	var xbs := StyleBoxFlat.new()
	xbs.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	close_btn.add_theme_stylebox_override("normal", xbs)
	close_btn.pressed.connect(_toggle_options)
	_options_panel.add_child(close_btn)

	# Divider
	var div := ColorRect.new()
	div.position = Vector2(15, 52)
	div.size = Vector2(pw - 30, 1)
	div.color = Color(0.25, 0.35, 0.55, 0.50)
	_options_panel.add_child(div)

	# Hotkeys section
	var hotkey_header := Label.new()
	hotkey_header.add_theme_font_override("font", font)
	hotkey_header.text = "HOTKEYS"
	hotkey_header.add_theme_font_size_override("font_size", 20)
	hotkey_header.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))
	hotkey_header.position = Vector2(20, 62)
	hotkey_header.size = Vector2(pw - 40, 26)
	_options_panel.add_child(hotkey_header)

	var hotkeys := [
		["W A S D / Arrows", "Move"],
		["Shift", "Sprint"],
		["Alt", "Toggle Walk / Run"],
		["Tab", "Cycle Targets"],
		["1 - 8", "Hotbar Abilities"],
		["Space", "Stand Up (when knocked down)"],
		["R", "Toggle Rain"],
		["C", "Character Stats"],
		["I", "Inventory"],
		["P", "Skills Window"],
		["K", "Profession Window"],
		["Enter", "Chat"],
		["Escape", "Clear Target / Close Menus"],
		["Middle Mouse", "Auto-Run"],
		["Right Click", "Camera / Radial Menu"],
		["Scroll Wheel", "Zoom In / Out"],
	]

	var y_off := 90.0
	for hk in hotkeys:
		var key_lbl := Label.new()
		key_lbl.add_theme_font_override("font", roboto)
		key_lbl.text = hk[0]
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.00))
		key_lbl.position = Vector2(25, y_off)
		key_lbl.size = Vector2(160, 18)
		_options_panel.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.add_theme_font_override("font", roboto)
		desc_lbl.text = hk[1]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.80))
		desc_lbl.position = Vector2(190, y_off)
		desc_lbl.size = Vector2(pw - 210, 18)
		_options_panel.add_child(desc_lbl)
		y_off += 20.0

	# Divider before buttons
	var div2 := ColorRect.new()
	div2.position = Vector2(15, ph - 90)
	div2.size = Vector2(pw - 30, 1)
	div2.color = Color(0.25, 0.35, 0.55, 0.50)
	_options_panel.add_child(div2)

	# Character Select button
	var charsel_btn := Button.new()
	charsel_btn.text = "CHARACTER SELECT"
	charsel_btn.position = Vector2(20, ph - 78)
	charsel_btn.size = Vector2(pw - 40, 32)
	charsel_btn.add_theme_font_size_override("font_size", 14)
	charsel_btn.add_theme_font_override("font", font)
	var cs_s := StyleBoxFlat.new()
	cs_s.bg_color = Color(0.08, 0.12, 0.25, 0.90)
	cs_s.border_color = Color(0.30, 0.55, 0.90, 0.70)
	cs_s.set_border_width_all(1); cs_s.set_corner_radius_all(4)
	var cs_h := cs_s.duplicate() as StyleBoxFlat
	cs_h.bg_color = Color(0.12, 0.18, 0.35, 0.95)
	charsel_btn.add_theme_stylebox_override("normal", cs_s)
	charsel_btn.add_theme_stylebox_override("hover", cs_h)
	charsel_btn.add_theme_color_override("font_color", Color(0.55, 0.75, 1.00))
	charsel_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/character_list.tscn"))
	_options_panel.add_child(charsel_btn)

	# Quit button
	var quit_btn := Button.new()
	quit_btn.text = "QUIT GAME"
	quit_btn.position = Vector2(20, ph - 40)
	quit_btn.size = Vector2(pw - 40, 32)
	quit_btn.add_theme_font_size_override("font_size", 14)
	quit_btn.add_theme_font_override("font", font)
	var q_s := StyleBoxFlat.new()
	q_s.bg_color = Color(0.20, 0.06, 0.06, 0.90)
	q_s.border_color = Color(0.75, 0.25, 0.20, 0.70)
	q_s.set_border_width_all(1); q_s.set_corner_radius_all(4)
	var q_h := q_s.duplicate() as StyleBoxFlat
	q_h.bg_color = Color(0.30, 0.10, 0.10, 0.95)
	quit_btn.add_theme_stylebox_override("normal", q_s)
	quit_btn.add_theme_stylebox_override("hover", q_h)
	quit_btn.add_theme_color_override("font_color", Color(0.90, 0.40, 0.35))
	quit_btn.pressed.connect(func(): get_tree().quit())
	_options_panel.add_child(quit_btn)

func _update_minimap() -> void:
	if _minimap_draw == null or _active == null:
		return
	_minimap_draw.queue_redraw()
	# Update coordinate display
	if _coord_label and _active:
		var p := _active.global_position
		_coord_label.text = "X: %d  Y: %d  Z: %d" % [int(p.x), int(p.y), int(p.z)]
		# Keep anchored below minimap (in case minimap was dragged)
		_coord_label.position = Vector2(_minimap_panel.position.x, _minimap_panel.position.y + MMAP_SIZE + 4)

# ════════════════════════════════════════════════════════════
#  CHAT
# ════════════════════════════════════════════════════════════
var _chat_general_log : RichTextLabel
var _chat_tab_active : String = "general"
var _chat_tab_btns := {}
var _chat_dragging := false
var _chat_drag_offset := Vector2.ZERO

func _build_chat() -> void:
	var vp := get_viewport().get_visible_rect().size
	_chat_panel = Panel.new()
	_chat_panel.position = Vector2(10, vp.y - 240)
	_chat_panel.size = Vector2(420, 220)
	var ch_style := StyleBoxFlat.new()
	ch_style.bg_color = Color(0.04, 0.04, 0.04, 0.75)
	ch_style.border_color = Color(0.25, 0.25, 0.3)
	ch_style.set_border_width_all(1)
	ch_style.set_corner_radius_all(4)
	_chat_panel.add_theme_stylebox_override("panel", ch_style)
	_chat_panel.gui_input.connect(_on_chat_panel_drag)
	_hud.add_child(_chat_panel)

	# Tab buttons
	var tab_y := 4.0
	var tabs := ["General", "Combat"]
	var tx := 8.0
	for tab_name in tabs:
		var btn := Button.new()
		btn.text = tab_name
		btn.position = Vector2(tx, tab_y)
		btn.size = Vector2(70, 22)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_switch_chat_tab.bind(tab_name.to_lower()))
		_chat_panel.add_child(btn)
		_chat_tab_btns[tab_name.to_lower()] = btn
		tx += 74.0

	# General chat log
	_chat_general_log = RichTextLabel.new()
	_chat_general_log.position = Vector2(8, 30)
	_chat_general_log.size = Vector2(404, 152)
	_chat_general_log.bbcode_enabled = true
	_chat_general_log.scroll_following = true
	_chat_general_log.add_theme_font_size_override("normal_font_size", 12)
	_chat_general_log.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_chat_panel.add_child(_chat_general_log)

	# Combat log (hidden by default)
	_combat_log = RichTextLabel.new()
	_combat_log.position = Vector2(8, 30)
	_combat_log.size = Vector2(404, 152)
	_combat_log.bbcode_enabled = true
	_combat_log.scroll_following = true
	_combat_log.add_theme_font_size_override("normal_font_size", 12)
	_combat_log.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_combat_log.visible = false
	_chat_panel.add_child(_combat_log)

	# Keep _chat_log pointing to general for backwards compat (general chat display)
	_chat_log = _chat_general_log

	# Chat input
	_chat_input = LineEdit.new()
	_chat_input.position = Vector2(8, 190)
	_chat_input.size = Vector2(404, 22)
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.add_theme_font_size_override("font_size", 11)
	var ci_style := StyleBoxFlat.new()
	ci_style.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	ci_style.border_color = Color(0.3, 0.3, 0.35)
	ci_style.set_border_width_all(1)
	_chat_input.add_theme_stylebox_override("normal", ci_style)
	_chat_input.text_submitted.connect(_on_chat_submit)
	_chat_panel.add_child(_chat_input)

	_chat_general_log.append_text("[color=gray]Welcome to Coronet. Press Enter to chat.[/color]\n")
	_switch_chat_tab("general")

func _switch_chat_tab(tab_id : String) -> void:
	_chat_tab_active = tab_id
	_chat_general_log.visible = (tab_id == "general")
	_combat_log.visible = (tab_id == "combat")
	# Highlight active tab
	for tid in _chat_tab_btns:
		var btn : Button = _chat_tab_btns[tid]
		if tid == tab_id:
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		else:
			btn.remove_theme_color_override("font_color")

func _on_chat_panel_drag(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y < 28:  # Only drag from tab bar area
			_chat_dragging = true
			_chat_drag_offset = event.position
		elif not event.pressed:
			_chat_dragging = false
	if event is InputEventMouseMotion and _chat_dragging:
		_chat_panel.position += event.relative

func _on_chat_submit(text : String) -> void:
	if text.strip_edges().is_empty():
		_chat_input.clear()
		_chat_input.release_focus()
		return
	# Display locally in general chat
	var nick : String = PlayerData.nickname if PlayerData.nickname != "" else CHAR_DISPLAY_NAMES.get(_selected_char_id, "Player")
	_chat_general_log.append_text("[color=cyan]" + nick + ":[/color] " + text + "\n")
	# Send via Relay
	if Relay and Relay.has_method("send_game_data"):
		Relay.send_game_data({"cmd": "chat", "nick": nick, "msg": text})
	# Show bubble above player in 3D
	_show_chat_bubble(_active, nick, text)
	_chat_input.clear()
	_chat_input.release_focus()

func _show_chat_bubble(target : Node3D, nick : String, msg : String) -> void:
	if not is_instance_valid(target):
		return
	# Remove old bubble
	var old := target.get_node_or_null("ChatBubble3D")
	if old:
		old.queue_free()
	# 3D billboard label
	var bubble := Label3D.new()
	bubble.name = "ChatBubble3D"
	bubble.text = nick + ": " + msg
	bubble.font_size = 24
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.modulate = Color(1, 1, 1, 1)
	bubble.outline_modulate = Color(0, 0, 0, 1)
	bubble.outline_size = 4
	bubble.position = Vector3(0, 3.0, 0)
	target.add_child(bubble)
	# Fade after 5s
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(bubble, "modulate:a", 0.0, 1.0)
	tw.tween_callback(bubble.queue_free)

# ════════════════════════════════════════════════════════════
#  MULTIPLAYER RELAY
# ════════════════════════════════════════════════════════════
func _connect_relay() -> void:
	if Relay and Relay.has_signal("game_data_received"):
		if not Relay.game_data_received.is_connected(_on_relay_data):
			Relay.game_data_received.connect(_on_relay_data)

func _on_relay_data(from_peer : int, data : Dictionary) -> void:
	var cmd : String = str(data.get("cmd", ""))
	match cmd:
		"chat":
			var nick := str(data.get("nick", "Player_%d" % from_peer))
			var msg := str(data.get("msg", ""))
			if msg.length() > 0:
				_chat_log.append_text("[color=cyan]" + nick + ":[/color] " + msg + "\n")
				var rp = _remote_players.get(from_peer)
				if is_instance_valid(rp):
					_show_chat_bubble(rp, nick, msg)
		"pos":
			# Remote player position update
			var px : float = data.get("x", 0.0)
			var py : float = data.get("y", 0.0)
			var pz : float = data.get("z", 0.0)
			var rp = _remote_players.get(from_peer)
			if is_instance_valid(rp):
				rp.global_position = Vector3(px, py, pz)

# ════════════════════════════════════════════════════════════
#  DIZZY EFFECT
# ════════════════════════════════════════════════════════════
func _spawn_dizzy_effect(target : Node3D) -> void:
	# Spinning cartoon stars above the target's head
	var stars_parent := Node3D.new()
	stars_parent.name = "DizzyEffect"
	target.add_child(stars_parent)
	stars_parent.position = Vector3(0, 2.5, 0)
	# Create 5 star-shaped meshes using PrismMesh (closest to star shape)
	for i in range(5):
		var star := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.15, 0.15, 0.04)
		var star_mat := StandardMaterial3D.new()
		# Alternate gold and white stars
		var col := Color(1, 0.9, 0.15) if i % 2 == 0 else Color(1, 1, 0.7)
		star_mat.albedo_color = col
		star_mat.emission_enabled = true
		star_mat.emission = col
		star_mat.emission_energy_multiplier = 4.0
		star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		prism.material = star_mat
		star.mesh = prism
		stars_parent.add_child(star)
	# Animate — smooth continuous spin like cartoon dizzy
	var tw := create_tween()
	tw.set_loops(750)  # 15s at 0.02s per loop
	tw.tween_callback(func():
		if is_instance_valid(stars_parent):
			stars_parent.rotation.y += 0.12
			for j in range(stars_parent.get_child_count()):
				var angle := stars_parent.rotation.y + j * (TAU / 5.0)
				var bob := sin(stars_parent.rotation.y * 3.0 + j * 1.5) * 0.08
				stars_parent.get_child(j).position = Vector3(cos(angle) * 0.5, bob, sin(angle) * 0.5)
				# Each star spins on its own axis too
				stars_parent.get_child(j).rotation.z += 0.2
	).set_delay(0.02)
	# Remove after 15s
	get_tree().create_timer(15.0).timeout.connect(func():
		if is_instance_valid(stars_parent):
			stars_parent.queue_free()
	)

func _tgt_stat(node : Node3D, stat : String, fallback = null):
	# Check property first (CoronetMob), then metadata (player character nodes)
	var val = node.get(stat)
	if val != null:
		return val
	if node.has_meta(stat):
		return node.get_meta(stat)
	return fallback

func _tgt_display_name(node : Node3D) -> String:
	if node.has_method("get_display_name"):
		return node.get_display_name()
	if node.has_meta("display_name"):
		return node.get_meta("display_name")
	return str(node.name)

func _tgt_take_damage(node : Node3D, amount : float, pool : String = "health") -> void:
	if node.has_method("take_damage"):
		node.take_damage(amount, pool)
	elif node.has_meta("ham_health"):
		# Player character node — update metadata
		var key := "ham_" + pool if pool != "health" else "ham_health"
		var cur : float = node.get_meta(key, 0.0)
		var new_val := maxf(0.0, cur - amount)
		node.set_meta(key, new_val)
		# Sync class vars if this is the player
		if node == _active:
			match pool:
				"health": ham_health = new_val
				"action": ham_action = new_val
				"mind": ham_mind = new_val
		# Check death
		if node.get_meta("ham_health", 0.0) <= 0.0:
			node.set_meta("is_dead", true)
			# Player death
			if node == _active:
				_auto_attacking = false
				_current_target = null
				_in_combat = false
				_attack_anim_timer = 999.0  # lock anim
				_play_anim("dead")
				_anim_state = "dead"
				_log_combat("[color=red]You have been defeated![/color]")

func _tgt_apply_state(node : Node3D, state_name : String, duration : float) -> void:
	if node.has_method("apply_combat_state"):
		node.apply_combat_state(state_name, duration)
	elif node.has_meta("ham_health"):
		node.set_meta("state_" + state_name, duration)

func _update_hud() -> void:
	# Posture icon — follow player frame position
	if _posture_label:
		_posture_label.text = _KNOCKDOWN_ICON if state_knockdown > 0.0 else _STANDING_ICON
	if _posture_box and _player_frame:
		_posture_box.position = Vector2(_player_frame.position.x - 28, _player_frame.position.y + 2)
	# Player bars — use effective max (wounds reduce max)
	if _hp_bar:
		_hp_bar.max_value = get_effective_max_health()
		_hp_bar.value = ham_health
	if _action_bar:
		_action_bar.max_value = get_effective_max_action()
		_action_bar.value = ham_action
	if _mind_bar:
		_mind_bar.max_value = get_effective_max_mind()
		_mind_bar.value = ham_mind
	# Wound overlays
	if _hp_wound_ov:
		_apply_wound_overlay(_hp_wound_ov, wound_health, max_health, 6.0, 208.0)
	if _action_wound_ov:
		_apply_wound_overlay(_action_wound_ov, wound_action, max_action_stat, 6.0, 208.0)
	if _mind_wound_ov:
		_apply_wound_overlay(_mind_wound_ov, wound_mind, max_mind, 6.0, 208.0)
	# XP bar
	if _xp_bar:
		_xp_bar.max_value = exp_needed
		_xp_bar.value = exp_points
	if _xp_bar_lbl:
		_xp_bar_lbl.text = "Lv%d  XP %d / %d" % [level, int(exp_points), int(exp_needed)]

	# Target frame
	var tgt_dead = _tgt_stat(_current_target, "is_dead", false) if _current_target and is_instance_valid(_current_target) else true
	if _current_target and is_instance_valid(_current_target) and not tgt_dead:
		_tgt_panel.visible = true
		_tgt_name_lbl.text = _tgt_display_name(_current_target)
		_tgt_hp_bar.max_value = _tgt_stat(_current_target, "max_hp", 100.0)
		_tgt_hp_bar.value = _tgt_stat(_current_target, "ham_health", 0.0)
		_tgt_action_bar.max_value = _tgt_stat(_current_target, "max_action", 100.0)
		_tgt_action_bar.value = _tgt_stat(_current_target, "ham_action", 0.0)
		_tgt_mind_bar.max_value = _tgt_stat(_current_target, "max_mind", 100.0)
		_tgt_mind_bar.value = _tgt_stat(_current_target, "ham_mind", 0.0)
		# Target debuff icons — track target frame position
		if _tgt_debuff_row:
			_tgt_debuff_row.position = Vector2(_tgt_panel.position.x, _tgt_panel.position.y + 54)
		_update_status_row(_tgt_debuff_row, _current_target, false)
	else:
		_tgt_panel.visible = false
		_clear_status_row(_tgt_debuff_row)
		if _current_target and (not is_instance_valid(_current_target) or tgt_dead):
			_current_target = null
			_auto_attacking = false

	# Combat queue HUD
	_update_combat_queue_hud()
	# Player buff icons — track player frame position
	if _player_buff_row and _player_frame:
		_player_buff_row.position = Vector2(_player_frame.position.x, _player_frame.position.y + 54)
	_update_status_row(_player_buff_row, null, true)

func _update_status_row(row : HBoxContainer, target : Node3D, is_player : bool) -> void:
	if row == null:
		return
	# Clear existing icons
	for child in row.get_children():
		child.queue_free()

	var icons_to_show : Array = []

	if is_player:
		# Buffs on player
		if _sprint_active:
			icons_to_show.append({"label": "SPR", "color": Color(0.3, 0.8, 1.0), "time": _sprint_timer})
		if _sensu_active:
			icons_to_show.append({"label": "HEAL", "color": Color(0.2, 0.9, 0.3), "time": _sensu_timer})
		# Debuffs on player
		if state_dizzy > 0.0:
			icons_to_show.append({"label": "DIZ", "color": Color(0.9, 0.8, 0.2), "time": state_dizzy})
		if state_knockdown > 0.0:
			icons_to_show.append({"label": "KD", "color": Color(0.9, 0.3, 0.2), "time": state_knockdown})
		if state_stun > 0.0:
			icons_to_show.append({"label": "STN", "color": Color(0.8, 0.5, 0.9), "time": state_stun})
		if state_blind > 0.0:
			icons_to_show.append({"label": "BLN", "color": Color(0.5, 0.5, 0.5), "time": state_blind})
	else:
		# Debuffs on target
		if target and is_instance_valid(target):
			var diz : float = _tgt_stat(target, "state_dizzy", 0.0)
			var kd : float = _tgt_stat(target, "state_knockdown", 0.0)
			if diz > 0.0:
				icons_to_show.append({"label": "DIZ", "color": Color(0.9, 0.8, 0.2), "time": diz})
			if kd > 0.0:
				icons_to_show.append({"label": "KD", "color": Color(0.9, 0.3, 0.2), "time": kd})

	for icon_data in icons_to_show:
		var icon_panel := Panel.new()
		icon_panel.custom_minimum_size = Vector2(36, 36)
		var ic_style := StyleBoxFlat.new()
		ic_style.bg_color = Color(0.06, 0.06, 0.06, 0.9)
		ic_style.border_color = icon_data["color"]
		ic_style.set_border_width_all(2)
		ic_style.set_corner_radius_all(3)
		icon_panel.add_theme_stylebox_override("panel", ic_style)
		row.add_child(icon_panel)

		var lbl := Label.new()
		lbl.text = icon_data["label"]
		lbl.position = Vector2(2, 1)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", icon_data["color"])
		icon_panel.add_child(lbl)

		var time_lbl := Label.new()
		time_lbl.text = str(int(ceilf(icon_data["time"])))
		time_lbl.position = Vector2(2, 18)
		time_lbl.add_theme_font_size_override("font_size", 10)
		time_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		icon_panel.add_child(time_lbl)

func _clear_status_row(row : HBoxContainer) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()

# ════════════════════════════════════════════════════════════
#  TARGETING
# ════════════════════════════════════════════════════════════
func _get_all_targetables() -> Array:
	var targets := []
	for child in get_children():
		if child is CoronetMob and not child.is_dead:
			targets.append(child)
		elif child is MachineWalker and not child.is_dead:
			targets.append(child)
	# Include the inactive player character as targetable
	var inactive : Node3D = _red if _active == _silver else _silver
	if inactive and is_instance_valid(inactive):
		targets.append(inactive)
	return targets

func _cycle_target() -> void:
	var mobs := _get_all_targetables()
	if mobs.is_empty():
		_current_target = null
		_auto_attacking = false
		return
	# Sort by distance
	mobs.sort_custom(func(a, b): return _active.global_position.distance_to(a.global_position) < _active.global_position.distance_to(b.global_position))
	# Filter by range
	var in_range := mobs.filter(func(m): return _active.global_position.distance_to(m.global_position) < TARGET_CYCLE_RANGE)
	if in_range.is_empty():
		_current_target = null
		_auto_attacking = false
		return
	# Cycle to next
	if _current_target == null or _current_target not in in_range:
		_current_target = in_range[0]
	else:
		var idx := in_range.find(_current_target)
		_current_target = in_range[(idx + 1) % in_range.size()]
	# Tab only targets — does NOT start auto-attack (use RMB → Attack)
	_auto_attacking = false
	_log_combat("[color=yellow]Target: " + _tgt_display_name(_current_target) + "[/color]")

func _update_target_indicator() -> void:
	# Remove old indicator
	if _target_indicator and is_instance_valid(_target_indicator):
		_target_indicator.queue_free()
		_target_indicator = null
	if _current_target == null or not is_instance_valid(_current_target):
		return
	# Create a ring under the target
	var torus := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.6
	mesh.outer_radius = 0.8
	mesh.rings = 16
	mesh.ring_segments = 16
	torus.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.3, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2, 1.0)
	mat.emission_energy_multiplier = 2.0
	torus.material_override = mat
	torus.position = Vector3(0, 0.05, 0)
	_current_target.add_child(torus)
	_target_indicator = torus

# ════════════════════════════════════════════════════════════
#  COMBAT
# ════════════════════════════════════════════════════════════
func _tick_combat(delta : float) -> void:
	if not _auto_attacking:
		return
	if _current_target == null or not is_instance_valid(_current_target) or _tgt_stat(_current_target, "is_dead", false):
		_auto_attacking = false
		_current_target = null
		return

	var dist : float = _active.global_position.distance_to(_current_target.global_position)
	var atk_range : float = ATTACK_RANGE_MELEE if character_class == "melee" else ATTACK_RANGE_RANGED

	# Out of range — don't attack but keep target
	if dist > atk_range:
		return

	# Face the target — only when NOT moving (movement direction trumps target facing)
	var is_moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
	if not is_moving:
		var dir : Vector3 = (_current_target.global_position - _active.global_position).normalized()
		var target_angle := atan2(dir.x, dir.z)
		# RedArmor attack anim shoots left — rotate 90 degrees clockwise to face target
		# RedSoldier faces target directly (no offset needed)
		if _selected_char_id == "RedArmor" and _attack_anim_timer > 0.0:
			target_angle -= PI * 0.5
		_active.rotation.y = lerp_angle(_active.rotation.y, target_angle, ROTATION_SPEED * delta)

	# Attack timer
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_do_attack()
		_attack_timer = ATTACK_COOLDOWN

func _do_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return

	# Auto-attack: always plays "attack" (profession determines the actual anim loaded)
	_play_anim("attack")
	_anim_state = "attack"
	var ap := _get_active_anim()

	var is_moving := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or _auto_run

	if character_class == "ranged" and is_moving:
		# Gunslinger moving: run_attack loops, no timer needed (movement code handles anim)
		_anim_state = "run_attack"
	elif not is_moving:
		if character_class == "ranged":
			# Gunslinger idle: trimmed attack (frames 120-180 = 1.0s)
			_attack_anim_timer = 1.0
		elif ap and ap.has_animation("attack"):
			_attack_anim_timer = ap.get_animation("attack").length
		else:
			_attack_anim_timer = 2.0

	# Roll to hit using CombatEngine
	var attack_data := {"is_ranged": character_class != "melee"}
	var result := CombatEngine.roll_to_hit(self, _current_target, attack_data)

	# Spawn attack effect based on class — bullet timing
	if character_class == "ranged":
		var bullet_delay : float
		if is_moving:
			bullet_delay = 0.3  # run_attack fires early in the anim
		else:
			bullet_delay = 0.5  # trimmed attack (1s total), shot midway
		# RedSoldier fires 2.3s earlier total
		if _selected_char_id == "RedSoldier":
			bullet_delay = maxf(0.1, bullet_delay - 2.3)
		_spawn_laser_effect(_active, _current_target, bullet_delay)
	else:
		# Delay melee hit to match swing
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_inside_tree() and is_instance_valid(_current_target):
				_spawn_melee_hit_effect(_current_target)
		)

	var tgt_name := _tgt_display_name(_current_target)
	match result.get("result", "miss"):
		"miss", "dodge":
			_log_combat("[color=cyan]" + tgt_name + " dodges![/color]")
			_spawn_damage_text(_current_target, "DODGE", Color(0.3, 0.8, 1.0))
			pass
		"block":
			var reduction : float = result.get("reduction", 0.75)
			var dmg := BASE_DAMAGE * (1.0 - reduction)
			_tgt_take_damage(_current_target, dmg, "health")
			_log_combat("[color=orange]" + tgt_name + " blocks! (" + str(int(dmg)) + " dmg)[/color]")
			_spawn_damage_text(_current_target, str(int(dmg)), Color(1.0, 0.6, 0.2))
		_:  # hit
			var dmg := BASE_DAMAGE + randf_range(-5.0, 10.0)
			# 2x damage if target is knocked down
			var tgt_kd : float = _tgt_stat(_current_target, "state_knockdown", 0.0)
			if tgt_kd > 0.0:
				dmg *= 2.0
			_tgt_take_damage(_current_target, dmg, "health")
			var dmg_text := str(int(dmg)) + (" (KD 2x!)" if tgt_kd > 0.0 else "")
			_log_combat("[color=red]You hit " + tgt_name + " for " + dmg_text + " damage[/color]")
			_spawn_damage_text(_current_target, str(int(dmg)), Color(1.0, 1.0, 0.2))

func _spawn_damage_text(target : Node3D, text : String, color : Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 48
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color
	lbl.position = target.global_position + Vector3(randf_range(-0.5, 0.5), 2.5, 0)
	add_child(lbl)
	# Float up and fade
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 2.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

# ════════════════════════════════════════════════════════════
#  ATTACK EFFECTS
# ════════════════════════════════════════════════════════════
func _spawn_laser_effect(from_node : Node3D, target : Node3D, delay : float = 0.6) -> void:
	# Delay to match shoot anim (default 0.6s, or 80% of anim length)
	get_tree().create_timer(delay).timeout.connect(func():
		if not is_inside_tree():
			return
		if not is_instance_valid(from_node) or not is_instance_valid(target):
			return
		# Spawn a traveling bullet from shooter to target
		var start_pos : Vector3 = from_node.global_position + Vector3(0, 1.2, 0)
		var end_pos : Vector3 = target.global_position + Vector3(0, 1.0, 0)
		var bullet := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.3, 0.1, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.2, 0.05)
		mat.emission_energy_multiplier = 15.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material = mat
		bullet.mesh = sphere
		bullet.global_position = start_pos
		add_child(bullet)
		# Travel to target
		var travel_time := clampf(start_pos.distance_to(end_pos) / 30.0, 0.1, 0.5)
		var tw := create_tween()
		tw.tween_property(bullet, "global_position", end_pos, travel_time)
		tw.tween_callback(func():
			if is_instance_valid(bullet) and bullet.is_inside_tree():
				_spawn_impact_effect(end_pos)
				bullet.queue_free()
		)
	)

func _spawn_heal_effect(target : Node3D) -> void:
	if not is_instance_valid(target):
		return
	for i in range(8):
		var particle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.4, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.9, 0.3)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere.material = mat
		particle.mesh = sphere
		add_child(particle)
		var start_pos := target.global_position + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5))
		particle.global_position = start_pos
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(particle, "position:y", start_pos.y + 2.5, 1.0 + randf_range(0, 0.5))
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)
		tw.chain().tween_callback(particle.queue_free)

func _spawn_melee_hit_effect(target : Node3D) -> void:
	if not is_instance_valid(target):
		return
	var hit_pos : Vector3 = target.global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
	_spawn_impact_effect(hit_pos)

func _spawn_impact_effect(pos : Vector3) -> void:
	# White semi-transparent star burst
	var flash := MeshInstance3D.new()
	var star := PrismMesh.new()
	star.size = Vector3(0.5, 0.5, 0.1)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 1, 1, 0.5)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 1, 1)
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.material = flash_mat
	flash.mesh = star
	add_child(flash)
	flash.global_position = pos
	# Expand then remove
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(3.0, 3.0, 3.0), 0.2)
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(flash.queue_free)

# ════════════════════════════════════════════════════════════
#  INPUT
# ════════════════════════════════════════════════════════════
func _input(event : InputEvent) -> void:
	# Enter — focus/unfocus chat
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if _chat_input and not _chat_input.has_focus():
			_chat_input.grab_focus()
			get_viewport().set_input_as_handled()
			return
	# Block game input when chat is focused
	if _chat_input and _chat_input.has_focus():
		# ESC unfocuses chat
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_chat_input.clear()
			_chat_input.release_focus()
			get_viewport().set_input_as_handled()
		return

	# TAB — cycle targets
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_target()
		_update_target_indicator()

	# F1/F2 — switch active character
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and _silver:
			_active = _silver
			character_class = "melee"
			_player_name_lbl.text = "Silver Sentinel"
			_play_anim("idle")
		elif event.keycode == KEY_F2 and _red:
			_active = _red
			character_class = "ranged"
			_player_name_lbl.text = "Ember Guard"
			_play_anim("idle")
		elif event.keycode == KEY_ESCAPE:
			if _options_visible:
				_toggle_options()
			elif _radial_menu_visible:
				_close_radial_menu()
			else:
				_current_target = null
				_auto_attacking = false
				_update_target_indicator()
		elif event.keycode == KEY_R:
			_toggle_rain()
		elif event.keycode == KEY_ALT:
			if _can_walk:
				_uses_walk = not _uses_walk
				_log_combat("[color=gray]" + ("Walking" if _uses_walk else "Running") + "[/color]")
		elif event.keycode == KEY_P:
			_toggle_skills_window()
		elif event.keycode == KEY_C:
			_toggle_stats_window()
		elif event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_K:
			_toggle_profession_window()
		# Hotbar keys 1-8
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			_activate_hotbar_slot(event.keycode - KEY_1)
		# Spacebar — stand up from knockdown (only when not mounted)
		elif event.keycode == KEY_F5:
			_spawn_machine_walker()
		elif event.keycode == KEY_F6:
			_spawn_test_dummy()
		elif event.keycode == KEY_SPACE and state_knockdown > 0.0 and not _mounted:
			state_knockdown = 0.0
			_attack_anim_timer = 0.0
			_play_anim("idle")
			_anim_state = "idle"
			_log_combat("[color=green]You stand up![/color]")
	# RMB — short click = radial menu, hold+drag = orbit camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_rmb_held = true
				_rmb_press_pos = event.position
				_rmb_press_time = Time.get_ticks_msec()
				_rmb_dragged = false
			else:
				_rmb_held = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# If released quickly without dragging, open radial menu
				var elapsed := Time.get_ticks_msec() - _rmb_press_time
				if not _rmb_dragged and elapsed < 300:
					_open_radial_menu(_rmb_press_pos)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_auto_run = not _auto_run
			if _auto_run:
				_log_combat("[color=gray]Auto-run ON[/color]")
			else:
				_log_combat("[color=gray]Auto-run OFF[/color]")
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Block camera zoom if hovering minimap
			if _minimap_panel:
				var mp := get_viewport().get_mouse_position()
				if Rect2(_minimap_panel.global_position, _minimap_panel.size).has_point(mp):
					return
			# Zoom in
			if _first_person:
				pass  # Already in first person, can't zoom further
			elif _cam_zoom <= 0.25:
				# At or near minimum — next scroll enters first person
				_first_person = true
				_cam_pitch = 0.0  # Look straight ahead
				# Don't hide character — other players need to see us in multiplayer
				_camera.near = 0.5  # Clip through own model
				_log_combat("[color=gray]First Person Mode[/color]")
			else:
				_cam_zoom = clampf(_cam_zoom - 0.05, 0.2, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _minimap_panel:
				var mp := get_viewport().get_mouse_position()
				if Rect2(_minimap_panel.global_position, _minimap_panel.size).has_point(mp):
					return
			if _first_person:
				# Exit first person back to closest 3rd person
				_first_person = false
				_cam_zoom = 0.25
				_cam_pitch = 0.6  # Reset to default 3rd person pitch
				_camera.near = 0.05  # Restore normal near clip
				_log_combat("[color=gray]Third Person Mode[/color]")
			else:
				_cam_zoom = clampf(_cam_zoom + 0.05, 0.2, 3.0)

	# RMB drag — orbit camera (only after drag threshold)
	if event is InputEventMouseMotion and _rmb_held:
		if not _rmb_dragged and event.relative.length() > 3.0:
			_rmb_dragged = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _rmb_dragged:
			_cam_yaw -= event.relative.x * CAM_MOUSE_SENSITIVITY
			var pitch_dir := -1.0 if _first_person else 1.0
			var pitch_min := -1.2 if _first_person else 0.1
			_cam_pitch = clampf(_cam_pitch + event.relative.y * CAM_MOUSE_SENSITIVITY * pitch_dir, pitch_min, 1.4)

	# LMB — click to target mob (raycast), also close radial menu if clicking outside
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _radial_menu_visible:
			# Check if click is on a radial button — if so, let the button handle it
			var on_button := false
			if _radial_menu and is_instance_valid(_radial_menu):
				for child in _radial_menu.get_children():
					if child is Button:
						var r := Rect2(child.global_position, child.size)
						if r.has_point(event.position):
							on_button = true
							break
			if not on_button:
				_close_radial_menu()
		else:
			_try_click_target(event.position)

# ════════════════════════════════════════════════════════════
#  CLICK TARGETING (raycast from mouse)
# ════════════════════════════════════════════════════════════
func _raycast_from_mouse(screen_pos : Vector2) -> Dictionary:
	# Returns {"node": Node3D or null, "position": Vector3, "type": String}
	if _camera == null:
		return {"node": null, "position": Vector3.ZERO, "type": "none"}
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return {"node": null, "position": Vector3.ZERO, "type": "none"}
	var hit_pos : Vector3 = result.get("position", Vector3.ZERO)
	var collider : Node = result.get("collider")
	# Walk up the tree to find a meaningful parent
	var node : Node = collider
	while node and node != self:
		if node is CoronetMob or node is MachineWalker:
			return {"node": node, "position": hit_pos, "type": "mob"}
		if node.has_method("take_damage") and node.get("mob_name") != null:
			return {"node": node, "position": hit_pos, "type": "mob"}
		# Check if it's any vehicle/mount
		var vname := node.name.to_lower()
		if "vehicle" in vname or "landspeeder" in vname or "speeder" in vname or "mount" in vname or "voyager" in vname or "shuttle" in vname:
			return {"node": node, "position": hit_pos, "type": "vehicle"}
		if _vehicle_mount and (node == _vehicle_mount or node.get_parent() == _vehicle_mount):
			return {"node": _vehicle_mount, "position": hit_pos, "type": "vehicle"}
		if node.has_meta("interactable"):
			return {"node": node, "position": hit_pos, "type": node.get_meta("interactable")}
		node = node.get_parent()
	# Hit ground or unrecognized object — ignore for targeting
	return {"node": null, "position": hit_pos, "type": "ground"}

func _try_click_target(screen_pos : Vector2) -> void:
	var hit := _raycast_from_mouse(screen_pos)
	if hit.type == "mob":
		var mob : Node3D = hit.node
		if not mob.get("is_dead"):
			var was_attacking := _auto_attacking and _current_target != null
			_current_target = mob
			_update_target_indicator()
			_log_combat("[color=yellow]Target: " + _tgt_display_name(_current_target) + "[/color]")
			# Only auto-attack if already in combat, otherwise just target
			if was_attacking:
				_auto_attacking = true
				_attack_timer = 0.0
	# Don't detarget on ground click — only ESC or new target detargets

# ════════════════════════════════════════════════════════════
#  PROCESS
# ════════════════════════════════════════════════════════════
# Store original armature rotations (FBX import applies axis conversion)
var _silver_armature_rot := Vector3.ZERO
var _red_armature_rot := Vector3.ZERO

func _lock_armatures() -> void:
	if _silver_armature:
		_silver_armature.position = Vector3.ZERO
	if _red_armature:
		_red_armature.position = Vector3.ZERO
		_red_armature.rotation = _red_armature_rot

func _process(delta : float) -> void:
	if _active == null:
		return

	# Lock armatures to prevent root motion (both now and after anim applies)
	_lock_armatures()
	_lock_armatures.call_deferred()

	# Tick combat states
	if state_knockdown > 0.0:
		state_knockdown -= delta
		# Lower character during KD so they lie on the ground
		_active.position.y = lerp(_active.position.y, -0.2, 8.0 * delta)
		_update_camera(delta)
		_update_hud()
		return  # KD blocks all
	else:
		# Raise back up after KD
		if _active.position.y < -0.01:
			_active.position.y = lerp(_active.position.y, 0.0, 8.0 * delta)

	if state_dizzy > 0.0: state_dizzy -= delta
	if state_stun > 0.0: state_stun -= delta
	if state_blind > 0.0: state_blind -= delta
	if state_intimidate > 0.0: state_intimidate -= delta

	# Sensu Bean heal over time
	if _sensu_active:
		_sensu_timer -= delta
		var heal_rate_h := max_health / SENSU_DURATION * delta
		var heal_rate_a := max_action_stat / SENSU_DURATION * delta
		var heal_rate_m := max_mind / SENSU_DURATION * delta
		ham_health = minf(ham_health + heal_rate_h, max_health)
		ham_action = minf(ham_action + heal_rate_a, max_action_stat)
		ham_mind = minf(ham_mind + heal_rate_m, max_mind)
		if _sensu_timer <= 0.0:
			_sensu_active = false
			_log_combat("[color=green]Sensu Bean effect ended.[/color]")

	# Sprint tick
	if _sprint_active:
		_sprint_timer -= delta
		if _sprint_timer <= 0.0:
			_sprint_active = false
			_log_combat("[color=aqua]Sprint ended.[/color]")
	if _sprint_cooldown_timer > 0.0:
		_sprint_cooldown_timer -= delta

	# Tick attack anim timer
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta

	# ── VEHICLE PROMPT (when near vehicle and not mounted) ──
	if not _mounted and _vehicle_mount and is_instance_valid(_vehicle_mount) and _active:
		var vdist := _active.global_position.distance_to(_vehicle_mount.global_position)
		if vdist <= VEHICLE_MOUNT_RANGE:
			if _vehicle_prompt == null:
				_vehicle_prompt = Label3D.new()
				_vehicle_prompt.text = "[F] Enter Vehicle"
				_vehicle_prompt.font_size = 28
				_vehicle_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				_vehicle_prompt.modulate = Color(1, 0.9, 0.3, 1)
				_vehicle_prompt.outline_modulate = Color(0, 0, 0, 1)
				_vehicle_prompt.outline_size = 4
				_vehicle_mount.add_child(_vehicle_prompt)
				_vehicle_prompt.position = Vector3(0, 2.5, 0)
		else:
			if _vehicle_prompt and is_instance_valid(_vehicle_prompt):
				_vehicle_prompt.queue_free()
				_vehicle_prompt = null

	# ── VEHICLE CONTROLS (when mounted) ──
	if _mounted and _vehicle_mount and is_instance_valid(_vehicle_mount):
		var v_input := Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v_input.z -= 1.0
			_auto_run = false
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v_input.z += 1.0
			_auto_run = false
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v_input.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v_input.x += 1.0
		# Auto-run for vehicle
		if _auto_run and v_input.length_squared() < 0.01:
			v_input.z = -1.0
		# Fly up/down
		if Input.is_key_pressed(KEY_SPACE):
			v_input.y += 1.0
		if Input.is_key_pressed(KEY_CTRL):
			v_input.y -= 1.0
		# Shift boost
		_vehicle_boosting = Input.is_key_pressed(KEY_SHIFT)
		var target_speed := VEHICLE_BOOST_SPEED if _vehicle_boosting else VEHICLE_SPEED
		var accel := VEHICLE_BOOST_ACCEL if _vehicle_boosting else VEHICLE_ACCEL

		var has_horizontal := (v_input.x != 0 or v_input.z != 0)
		var is_moving := v_input.length_squared() > 0.01

		# Accelerate / decelerate
		if has_horizontal:
			_vehicle_cur_speed = move_toward(_vehicle_cur_speed, target_speed, accel * delta)
			var flat_input := Vector3(v_input.x, 0, v_input.z).normalized()
			_vehicle_last_dir = flat_input.rotated(Vector3.UP, _cam_yaw)
		else:
			# Slow deceleration — coast to a stop
			_vehicle_cur_speed = move_toward(_vehicle_cur_speed, 0.0, accel * 1.0 * delta)

		# Move in current direction (coasting when no input)
		if _vehicle_cur_speed > 0.1 and _vehicle_last_dir.length() > 0.01:
			_vehicle_mount.position += _vehicle_last_dir * _vehicle_cur_speed * delta

		# Vertical movement — only for flying vehicles
		if _vehicle_can_fly and v_input.y != 0:
			_vehicle_mount.position.y += v_input.y * VEHICLE_FLY_SPEED * delta
		_vehicle_mount.position.y = maxf(0.5, _vehicle_mount.position.y)

		# Turning — only when actively steering
		if has_horizontal:
			var target_angle := atan2(_vehicle_last_dir.x, _vehicle_last_dir.z)
			var speed_ratio := clampf(_vehicle_cur_speed / VEHICLE_BOOST_SPEED, 0.0, 1.0)
			var turn_rate := lerpf(VEHICLE_TURN_SPEED, VEHICLE_TURN_SPEED * 0.2, speed_ratio)
			_vehicle_mount.rotation.y = lerp_angle(_vehicle_mount.rotation.y, target_angle + PI * 0.5, turn_rate * delta)

		# Speed lines effect when boosting and moving fast
		_tick_speed_lines(delta, _vehicle_boosting and _vehicle_cur_speed > VEHICLE_SPEED * 0.8)

		# Ion glow — always animate while mounted (scales with speed)
		_tick_ion_glow()

		# Hover bob continues always (even when idle)
		_vehicle_hover_time += delta
		var hover_bob := sin(_vehicle_hover_time * 1.5) * 0.2
		if not is_moving and v_input.y == 0:
			_vehicle_mount.position.y += hover_bob * delta * 2.0  # gentle drift

		# Camera follows vehicle
		_active.position = _vehicle_mount.position
		_active.position.y = 0.0
		_tick_rain()
		_tick_hotbar(delta)
		if _kd_immunity_timer > 0.0:
			_kd_immunity_timer -= delta
		_update_camera(delta)
		_update_hud()
		_update_minimap()
		return  # Skip normal character movement

	# ── NORMAL CHARACTER MOVEMENT ──
	# Block movement while chat is focused
	var chat_focused := _chat_input != null and _chat_input.has_focus()
	var input := Vector3.ZERO
	if not chat_focused:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input.z -= 1.0
			_auto_run = false
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input.z += 1.0
			_auto_run = false
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input.x += 1.0
	# Auto-run — keep moving forward based on camera direction
	if _auto_run and not chat_focused and input.length_squared() < 0.01:
		input.z = -1.0

	var base_speed := WALK_SPEED if _uses_walk else MOVE_SPEED
	var speed := SPRINT_SPEED if _sprint_active else base_speed
	var moving := input.length_squared() > 0.01
	# Footstep audio
	if moving and not _footstep_playing and _footstep_player and is_instance_valid(_footstep_player):
		_footstep_player.play()
		_footstep_playing = true
	elif not moving and _footstep_playing and _footstep_player and is_instance_valid(_footstep_player):
		_footstep_player.stop()
		_footstep_playing = false
	if moving:
		input = input.normalized()
		var rotated := input.rotated(Vector3.UP, _cam_yaw)
		_active.position += rotated * speed * delta
		var target_angle := atan2(rotated.x, rotated.z)
		_active.rotation.y = lerp_angle(_active.rotation.y, target_angle, ROTATION_SPEED * delta)
		# Set move animation
		var move_anim : String = "walk" if _uses_walk and not _sprint_active else "run"
		if _anim_state != move_anim:
			if _anim_state == "run_attack" and _attack_anim_timer <= 0.0:
				# Gunslinger run_attack expired — return to normal run
				var ap2 := _get_active_anim()
				if ap2 and ap2.has_animation(move_anim):
					ap2.stop()
					ap2.play(move_anim)
				_anim_state = move_anim
			elif _attack_anim_timer <= 0.0:
				var ap2 := _get_active_anim()
				if ap2 and ap2.has_animation(move_anim):
					ap2.stop()
					ap2.play(move_anim)
				_anim_state = move_anim
			elif _get_anim_priority(_anim_state) <= _get_anim_priority(move_anim):
				_play_anim(move_anim)
				_anim_state = move_anim
	else:
		# Not moving: let higher priority anims finish, then return to idle
		if _anim_state == "run_attack":
			# Stopped moving while gunslinger was run-attacking — go to idle
			_play_anim("idle")
			_anim_state = "idle"
		elif _attack_anim_timer > 0.0:
			pass  # let attack/dodge/hit anim finish
		elif _anim_state != "idle":
			_play_anim("idle")
			_anim_state = "idle"

	# Run/walk sit slightly low — nudge up (lerp to avoid jarring jumps on anim transitions)
	var target_y := 0.08 if _anim_state in ["run", "walk", "run_attack"] else 0.0
	_active.position.y = lerp(_active.position.y, target_y, 10.0 * delta)
	# Pin armature Y
	var _arm_node : Node3D = _active.get_node_or_null("Armature") if _active else null
	if _arm_node and state_knockdown <= 0.0:
		_arm_node.position.y = 0.0

	# Update combat state
	_in_combat = _auto_attacking and _current_target != null and is_instance_valid(_current_target)

	# Combat
	_tick_combat(delta)
	_tick_combat_queue(delta)
	_tick_wound_regen(delta)
	_tick_vehicle_hover(delta)
	_tick_rain()
	_tick_hotbar(delta)
	if _kd_immunity_timer > 0.0:
		_kd_immunity_timer -= delta
	_update_camera(delta)
	_update_hud()
	_update_minimap()

# ════════════════════════════════════════════════════════════
#  CAMERA
# ════════════════════════════════════════════════════════════
func _update_camera(delta : float) -> void:
	if _active == null or _camera == null:
		return

	var look_target : Vector3
	if _mounted and _vehicle_mount and is_instance_valid(_vehicle_mount):
		look_target = _vehicle_mount.position
	else:
		look_target = _active.position

	if _first_person:
		# First person — camera at character head height, looking forward
		var forward := Vector3(
			-sin(_cam_yaw) * cos(_cam_pitch),
			sin(_cam_pitch),
			-cos(_cam_yaw) * cos(_cam_pitch)
		).normalized()
		# Place camera slightly in front of head to avoid seeing own model
		var head_pos := look_target + Vector3(0, 1.8, 0) + forward * 0.3
		var fp_target := head_pos + forward * 5.0
		# Snap instantly — no lerp lag in first person
		_camera.position = head_pos
		_camera.look_at(fp_target)
		# Rotate character to face camera direction
		_active.rotation.y = _cam_yaw
	else:
		# Third person orbit camera
		var base_dist := VEHICLE_CAM_DISTANCE if _mounted else CAM_DISTANCE
		var dist : float = base_dist * _cam_zoom
		var offset := Vector3(
			dist * sin(_cam_yaw) * cos(_cam_pitch),
			dist * sin(_cam_pitch),
			dist * cos(_cam_yaw) * cos(_cam_pitch)
		)
		var target_pos : Vector3 = look_target + offset
		if delta > 0.0:
			_camera.position = _camera.position.lerp(target_pos, 8.0 * delta)
		else:
			_camera.position = target_pos
		_camera.look_at(look_target + CAM_LOOK_OFFSET)
