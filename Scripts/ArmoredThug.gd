extends CharacterBody2D

# ============================================================
#  ArmoredThug.gd — Low-level mob (half vampire difficulty)
#  Spawned by TheedScene on F10 or via spawner.
# ============================================================

const SPEED             = 50.0
const MAX_HP            = 325.0
const ATTACK_RANGE      = 160.0
const REPOSITION_RANGE  = 140.0
const REPOSITION_DELAY  = 1.0
const ATTACK_INTERVAL   = 2.4
const ATTACK_DAMAGE_MIN = 15.0
const ATTACK_DAMAGE_MAX = 28.0
const DEATH_DURATION    = 2.0

const BAR_W   = 150.0
const BAR_H   = 9.0
const BAR_Y   = -120.0
const ARROW_Y = -100.0

enum State { CHASE, ATTACK, REPOSITION }
var _state            : State = State.CHASE
var _reposition_timer : float = 0.0

var character_name : String = "Armored Thug"
var hp         : float = MAX_HP
var max_hp     : float = MAX_HP
var ham_action : float = MAX_HP
var max_action : float = MAX_HP
var ham_mind   : float = MAX_HP
var max_mind   : float = MAX_HP

var _facing       : String = "s"
var _is_attacking : bool   = false
var _attack_anim_timer : float = 0.0
var _attack_timer : float  = 1.0
var _special_timer : float = randf_range(10.0, 16.0)  # Dizzy punch cooldown
var _target       : Node   = null
var _spawn_pos    : Vector2 = Vector2.ZERO  # Where this mob was spawned
const LEASH_RANGE : float = 500.0  # Max distance from spawn before resetting

var _dying       : bool  = false
var _death_timer : float = 0.0

var _pulse_t     : float = 0.0

func _ready() -> void:
	add_to_group("targetable")
	add_to_group("mob")
	add_to_group("armored_thug")
	_spawn_pos = global_position

func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return
	_pulse_t += delta
	_tick_mob_states(delta)
	if state_knockdown > 0.0 or state_stun > 0.0:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	_find_target()
	_attack_timer -= delta
	_special_timer -= delta
	# Safety: clear stuck attack state
	if _is_attacking:
		_attack_anim_timer -= delta
		if _attack_anim_timer <= 0.0:
			_is_attacking = false
	_update_animation()
	queue_redraw()

func _tick_death(delta: float) -> void:
	_death_timer += delta
	var blink  = absf(sin(_death_timer * 14.0))
	var fade   = 1.0 - clampf((_death_timer - 1.4) / 0.6, 0.0, 1.0)
	modulate.a = blink * fade
	queue_redraw()
	if _death_timer >= DEATH_DURATION:
		queue_free()

func _physics_process(delta: float) -> void:
	if _dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _target == null or not is_instance_valid(_target):
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

const AGGRO_RANGE : float = 300.0
var _returning : bool = false  # Walking back to spawn

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var best : Node = null
	var best_dist : float = INF
	for p in players:
		if not is_instance_valid(p): continue
		# Skip incapped players
		if p.get("_incapped") == true: continue
		var d = global_position.distance_to(p.global_position)
		if d < best_dist and d <= AGGRO_RANGE:
			best_dist = d
			best = p

	# Leash check — if too far from spawn, drop target and return
	if best != null and global_position.distance_to(_spawn_pos) > LEASH_RANGE:
		best = null

	if best == null and _target != null:
		# Lost target — start returning to spawn
		_returning = true
		_state = State.CHASE
	_target = best

	# Return to spawn when no target
	if _target == null and _returning:
		var to_spawn = _spawn_pos - global_position
		if to_spawn.length() < 10.0:
			_returning = false
			velocity = Vector2.ZERO
			hp = max_hp  # Full heal on reset
		else:
			velocity = to_spawn.normalized() * SPEED
			_update_facing(to_spawn)
			move_and_slide()

func _update_facing(to_target: Vector2) -> void:
	var angle = to_target.angle()
	var deg = fmod(rad_to_deg(angle) + 360.0 + 22.5, 360.0)
	var sector = int(deg / 45.0)
	match sector:
		0: _facing = "e"
		1: _facing = "se"
		2: _facing = "s"
		3: _facing = "sw"
		4: _facing = "w"
		5: _facing = "nw"
		6: _facing = "n"
		7: _facing = "ne"

func _do_attack() -> void:
	_attack_timer = ATTACK_INTERVAL
	_is_attacking = true
	_attack_anim_timer = 2.0
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var anim = "attack_" + _facing
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			if not sprite.animation_finished.is_connected(_on_attack_done):
				sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)
	if _target != null and is_instance_valid(_target):
		var dmg = randf_range(ATTACK_DAMAGE_MIN, ATTACK_DAMAGE_MAX)
		# Special: dizzy punch on cooldown
		var is_special = _special_timer <= 0.0
		if is_special:
			_special_timer = randf_range(12.0, 18.0)
			dmg *= 1.3  # Bonus damage on special
		if _target.has_method("take_damage"):
			_target.take_damage(dmg)
		var arena = get_tree().get_first_node_in_group("boss_arena_scene")
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_target.global_position, dmg, Color(1.0, 0.6, 0.15))
		if is_special:
			if _target.has_method("apply_combat_state"):
				_target.apply_combat_state("dizzy", 2.5)
			if arena and arena.has_method("spawn_damage_number"):
				arena.spawn_damage_number(_target.global_position + Vector2(0, -20), 0, Color(1.0, 0.85, 0.1), "DIZZY!")

func _on_attack_done() -> void:
	_is_attacking = false

func _update_animation() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null: return
	var anim : String
	if _is_attacking:
		anim = "attack_" + _facing
	elif velocity != Vector2.ZERO:
		anim = "run_" + _facing
	else:
		anim = "idle_" + _facing
	if sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
	else:
		if sprite.sprite_frames.has_animation("idle_s") and sprite.animation != "idle_s":
			sprite.play("idle_s")

# ── COMBAT STATES ────────────────────────────────────────────
var state_dizzy     : float = 0.0
var state_knockdown : float = 0.0
var state_stun      : float = 0.0
var state_blind     : float = 0.0
var state_intimidate: float = 0.0

func apply_combat_state(state_name: String, duration: float) -> void:
	match state_name:
		"dizzy":      state_dizzy = maxf(state_dizzy, duration)
		"knockdown":
			state_knockdown = 999.0
			var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
			if sprite: sprite.rotation = deg_to_rad(90)
			if not is_inside_tree(): return
			get_tree().create_timer(duration).timeout.connect(func(): if is_instance_valid(self): _mob_stand_up())
		"stun":       state_stun = maxf(state_stun, duration)
		"blind":      state_blind = maxf(state_blind, duration)
		"intimidate": state_intimidate = maxf(state_intimidate, duration)

func _mob_stand_up() -> void:
	if _dying: return
	state_knockdown = 0.0
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite: sprite.rotation = 0.0

func get_stat(_stat_name: String) -> float:
	return 0.0

func _tick_mob_states(delta: float) -> void:
	if state_dizzy > 0.0: state_dizzy = maxf(0.0, state_dizzy - delta)
	if state_stun > 0.0: state_stun = maxf(0.0, state_stun - delta)
	if state_blind > 0.0: state_blind = maxf(0.0, state_blind - delta)
	if state_intimidate > 0.0: state_intimidate = maxf(0.0, state_intimidate - delta)

func get_target_position() -> Vector2:
	return global_position + Vector2(0.0, -80.0)

func take_damage(amount: float) -> void:
	if _dying: return
	if state_knockdown > 0.0:
		amount *= 2.0
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_die()

func _award_kill_reward() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var killer : Node = null
	for p in players:
		if not is_instance_valid(p): continue
		if p.get("_current_target") == self:
			killer = p; break
		if killer == null or global_position.distance_to(p.global_position) < global_position.distance_to(killer.global_position):
			killer = p
	if killer != null and killer.has_method("add_exp"):
		killer.call("add_exp", 30.0)
	var cred = randi_range(12, 28)
	var loot_script = load("res://Scripts/GroundLoot.gd")
	if loot_script:
		var loot = Node2D.new(); loot.set_script(loot_script)
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position
		loot.call("init", cred, 0.0)
	# Gear drop
	var item_script = load("res://Scripts/LootTable.gd")
	if item_script and killer != null and killer.has_method("add_item_to_inventory"):
		var item = item_script.roll_drop("armored_thug")
		if not item.is_empty():
			killer.call("add_item_to_inventory", item)

func _die() -> void:
	_award_kill_reward()
	_dying = true
	remove_from_group("targetable")
	remove_from_group("mob")
	remove_from_group("armored_thug")

func _draw() -> void:
	if _dying: return
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena != null and arena.has_method("is_targeted") and arena.call("is_targeted", self):
		var ay = ARROW_Y + sin(_pulse_t * 4.5) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11.0, ay), Vector2(11.0, ay), Vector2(0.0, ay + 15.0),
		]), Color(1.0, 0.15, 0.15, 0.92))

	# ── Dizzy stars ──────────────────────────────────────────
	if state_dizzy > 0.0:
		var t = _pulse_t
		for i in 5:
			var a = t * 3.0 + float(i) * TAU / 5.0
			var sx = cos(a) * 14.0
			var sy = sin(a) * 5.0 - 50.0
			var sa = 0.6 + sin(t * 5.0 + i * 1.5) * 0.3
			draw_circle(Vector2(sx, sy), 2.5, Color(1.0, 0.9, 0.2, sa))
			draw_circle(Vector2(sx, sy), 1.0, Color(1.0, 1.0, 1.0, sa * 0.7))

	# ── Knockdown text ───────────────────────────────────────
	if state_knockdown > 0.0:
		var ka = 0.5 + sin(_pulse_t * 3.0) * 0.3
		draw_string(ThemeDB.fallback_font, Vector2(-30, -60), "KNOCKED DOWN", HORIZONTAL_ALIGNMENT_CENTER, 70, 8, Color(1.0, 0.3, 0.2, ka))
