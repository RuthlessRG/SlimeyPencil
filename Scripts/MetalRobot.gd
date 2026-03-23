extends CharacterBody2D

# ============================================================
#  MetalRobot.gd — Heavy melee mob, android war machine
#  5-dir sprites (e/n/ne/s/se); w/nw/sw handled via flip_h.
#  Based on RoboWalker template.
# ============================================================

const SPEED             = 55.0
const MAX_HP            = 350.0
const AGGRO_RANGE       = 280.0
const PACK_AGGRO_RANGE  = 0.0     # solo mob — no pack pull
const ATTACK_RANGE      = 45.0
const LEASH_RANGE       = 900.0
const REPOSITION_RANGE  = 130.0
const REPOSITION_DELAY  = 1.0
const ATTACK_INTERVAL   = 2.8
const ATTACK_DAMAGE_MIN = 22.0
const ATTACK_DAMAGE_MAX = 40.0
const DEATH_DURATION    = 1.5

const BAR_W   = 90.0
const BAR_H   = 7.0
const BAR_Y   = -145.0
const ARROW_Y = -35.0

enum State { IDLE, CHASE, ATTACK, REPOSITION, KNOCKDOWN }
var _state            : State = State.IDLE
var _reposition_timer : float = 0.0
var _kd_done          : bool  = false   # true = kd anim finished, hold last frame
var _kd_standup_timer : float = 0.0    # auto stand up after KD duration
var _kd_immunity      : float = 0.0    # 30s immunity after standing up

# Combat states (so CombatEngine can apply states to this mob)
var state_dizzy      : float = 0.0
var state_knockdown  : float = 0.0
var state_stun       : float = 0.0
var state_blind      : float = 0.0
var state_intimidate : float = 0.0

var character_name : String = "Metal Robot"
var hp         : float = MAX_HP
var max_hp     : float = MAX_HP
var ham_action : float = MAX_HP
var max_action : float = MAX_HP
var ham_mind   : float = MAX_HP
var max_mind   : float = MAX_HP

var _facing       : String = "s"
var _is_attacking : bool   = false
var _attack_timer : float  = 1.0
var _target       : Node   = null

var _dying       : bool  = false
var _death_timer : float = 0.0
var _pulse_t     : float = 0.0

var _snd_attack : AudioStreamPlayer = null

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("targetable")
	add_to_group("mob")

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return
	# Tick immunity
	if _kd_immunity > 0.0:
		_kd_immunity -= delta
	# Tick combat states
	for sname in ["dizzy", "stun", "blind", "intimidate"]:
		var val = get("state_" + sname) as float
		if val > 0.0:
			set("state_" + sname, maxf(0.0, val - delta))
	if _state == State.KNOCKDOWN:
		_pulse_t += delta
		_kd_standup_timer -= delta
		if _kd_standup_timer <= 0.0:
			stand_up()
		queue_redraw()
		return
	_pulse_t      += delta
	_attack_timer -= delta
	_tick_aggro()
	_update_animation()
	queue_redraw()

func _tick_aggro() -> void:
	if _state == State.IDLE:
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and global_position.distance_to(p.global_position) <= AGGRO_RANGE:
				_target = p
				_state  = State.CHASE
				return
		_target = null
		return

	if _target == null or not is_instance_valid(_target):
		_state  = State.IDLE
		_target = null
		return
	if global_position.distance_to(_target.global_position) > LEASH_RANGE:
		_state  = State.IDLE
		_target = null

func _tick_death(delta: float) -> void:
	_death_timer += delta
	var blink  = absf(sin(_death_timer * 14.0))
	var fade   = 1.0 - clampf((_death_timer - 1.0) / 0.5, 0.0, 1.0)
	modulate.a = blink * fade
	queue_redraw()
	if _death_timer >= DEATH_DURATION:
		queue_free()

func _physics_process(delta: float) -> void:
	if _dying or _state == State.KNOCKDOWN or _state == State.IDLE or _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target = _target.global_position - global_position
	var dist      = to_target.length()
	_update_facing(to_target)

	match _state:
		State.CHASE:
			velocity = to_target.normalized() * SPEED
			if dist <= ATTACK_RANGE:
				_state   = State.ATTACK
				velocity = Vector2.ZERO

		State.ATTACK:
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_do_attack()
			if dist > REPOSITION_RANGE:
				_state            = State.REPOSITION
				_reposition_timer = REPOSITION_DELAY

		State.REPOSITION:
			velocity           = Vector2.ZERO
			_reposition_timer -= delta
			if _reposition_timer <= 0.0:
				_state = State.CHASE

	move_and_slide()

func force_aggro(new_target: Node) -> void:
	if _dying or _state == State.KNOCKDOWN or not is_instance_valid(new_target): return
	_target = new_target
	_state  = State.CHASE

# ── KNOCKDOWN ────────────────────────────────────────────────
func knockdown() -> void:
	if _dying or _state == State.KNOCKDOWN: return
	_state = State.KNOCKDOWN
	_kd_done = false
	_is_attacking = false
	velocity = Vector2.ZERO
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var anim = "kd_" + _facing
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			sprite.flip_h = _facing in _FLIP_DIRS
			if not sprite.animation_finished.is_connected(_on_kd_anim_done):
				sprite.animation_finished.connect(_on_kd_anim_done, CONNECT_ONE_SHOT)

func _on_kd_anim_done() -> void:
	_kd_done = true
	# Hold last frame — sprite stays paused on final frame automatically (loop=false)

func stand_up() -> void:
	if _state != State.KNOCKDOWN: return
	_kd_done = false
	_kd_immunity = 30.0
	state_knockdown = 0.0
	_state = State.IDLE
	_attack_timer = 1.0

func apply_combat_state(state_name: String, duration: float) -> void:
	if _dying: return
	match state_name:
		"knockdown":
			if _kd_immunity > 0.0: return
			state_knockdown = duration
			_kd_standup_timer = duration
			knockdown()
		"dizzy":
			state_dizzy = maxf(state_dizzy, duration)
		"stun":
			state_stun = maxf(state_stun, duration)
		"blind":
			state_blind = maxf(state_blind, duration)
		"intimidate":
			state_intimidate = maxf(state_intimidate, duration)

func _update_facing(to_target: Vector2) -> void:
	if absf(to_target.x) >= absf(to_target.y):
		_facing = "e" if to_target.x > 0.0 else "w"
	else:
		_facing = "s" if to_target.y > 0.0 else "n"

func _do_attack() -> void:
	_attack_timer = ATTACK_INTERVAL
	_is_attacking = true

	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var anim = "attack_" + _facing
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			if not sprite.animation_finished.is_connected(_on_attack_done):
				sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)

	if _target != null and is_instance_valid(_target):
		var dmg = randf_range(ATTACK_DAMAGE_MIN, ATTACK_DAMAGE_MAX)
		if _target.has_method("take_damage"):
			_target.take_damage(dmg)
		var arena = get_tree().get_first_node_in_group("boss_arena_scene")
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_target.global_position, dmg, Color(0.40, 0.90, 1.00))

func _on_attack_done() -> void:
	_is_attacking = false

# ── ANIMATION ─────────────────────────────────────────────────
# 5-dir sprites: e/n/ne/s/se; w/nw/sw mirror via flip_h
const _FLIP_DIRS = ["w", "nw", "sw"]

func _update_animation() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if _state == State.KNOCKDOWN:
		return  # kd anim managed by knockdown(), hold last frame

	var anim : String
	if _is_attacking:
		anim = "attack_" + _facing
	elif velocity != Vector2.ZERO:
		anim = "run_" + _facing
	else:
		anim = "idle_" + _facing

	sprite.flip_h = _facing in _FLIP_DIRS

	if sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
	else:
		if sprite.sprite_frames.has_animation("idle_s") and sprite.animation != "idle_s":
			sprite.play("idle_s")

func get_target_position() -> Vector2:
	return global_position + Vector2(0.0, -50.0)

# ── DAMAGE ────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if _dying: return
	hp = maxf(0.0, hp - amount)
	if _state == State.IDLE:
		var attacker = _nearest_player()
		if attacker:
			force_aggro(attacker)
	if hp <= 0.0:
		_die()

func _nearest_player() -> Node:
	var best : Node = null; var best_dist : float = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var d = global_position.distance_to(p.global_position)
		if d < best_dist: best_dist = d; best = p
	return best

func _award_kill_reward() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var killer : Node = null
	for p in players:
		if not is_instance_valid(p): continue
		if p.get("_current_target") == self: killer = p; break
		if killer == null or global_position.distance_to(p.global_position) < global_position.distance_to(killer.global_position):
			killer = p
	if killer != null and killer.has_method("add_exp"):
		killer.call("add_exp", 35.0)
	var cred = randi_range(16, 35)
	var loot_script = load("res://Scripts/GroundLoot.gd")
	if loot_script:
		var loot = Node2D.new(); loot.set_script(loot_script)
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position
		loot.call("init", cred, 0.0)
	var item_script = load("res://Scripts/LootTable.gd")
	if item_script and killer != null and killer.has_method("add_item_to_inventory"):
		var item = item_script.roll_drop("mob")
		if not item.is_empty():
			killer.call("add_item_to_inventory", item)

func _die() -> void:
	_award_kill_reward()
	_dying = true
	remove_from_group("targetable")
	remove_from_group("mob")
	remove_from_group("mission_mob")
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("on_mob_died"):
		arena.call("on_mob_died", global_position)
	if randf() < 0.10 and arena and arena.has_method("on_mob_dropped_loot"):
		arena.call("on_mob_dropped_loot", global_position)

# ── DRAW ──────────────────────────────────────────────────────
func _draw_shadow() -> void:
	var sprite : AnimatedSprite2D = get_node_or_null("Sprite")
	if sprite == null or sprite.sprite_frames == null: return
	var anim = sprite.animation
	if not sprite.sprite_frames.has_animation(anim): return
	var tex = sprite.sprite_frames.get_frame_texture(anim, sprite.frame)
	if tex == null: return
	var ts = tex.get_size()
	var sc = sprite.scale
	var shadow_scale_x = sc.x * 1.0
	var shadow_scale_y = sc.y * 0.25
	var off = sprite.offset * Vector2(sc.x, shadow_scale_y)
	var shadow_pos = Vector2(6, -1) + off
	draw_set_transform(shadow_pos, 0.0, Vector2(shadow_scale_x, shadow_scale_y))
	draw_texture(tex, -ts * 0.5, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if _dying: return
	_draw_shadow()
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena != null and arena.has_method("is_targeted") and arena.call("is_targeted", self):
		var ay = ARROW_Y + sin(_pulse_t * 4.5) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8.0, ay), Vector2(8.0, ay), Vector2(0.0, ay + 11.0),
		]), Color(1.0, 0.15, 0.15, 0.92))
		draw_polyline(PackedVector2Array([
			Vector2(-8.0, ay), Vector2(8.0, ay), Vector2(0.0, ay + 11.0), Vector2(-8.0, ay),
		]), Color(1.0, 0.75, 0.75, 0.70), 1.2)
