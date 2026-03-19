extends CharacterBody2D

# ============================================================
#  ZergMob.gd — small mob version of ZergBoss
#  Idles in place until aggroed. Aggro triggers:
#    1. Player enters AGGRO_RANGE
#    2. take_damage() is called (also alerts pack nearby)
#    3. force_aggro(target) called externally (lair hit, pack alert)
# ============================================================

const SPEED             = 75.0
const MAX_HP            = 100.0
const AGGRO_RANGE       = 220.0   # proximity aggro radius
const PACK_AGGRO_RANGE  = 180.0   # radius to pull in pack-mates on hit
const ATTACK_RANGE      = 30.0
const LEASH_RANGE       = 900.0   # de-aggro if player escapes this far
const REPOSITION_RANGE  = 120.0
const REPOSITION_DELAY  = 0.9
const ATTACK_INTERVAL   = 2.2
const ATTACK_DAMAGE_MIN = 8.0
const ATTACK_DAMAGE_MAX = 15.0
const DEATH_DURATION    = 1.5

const BAR_W   = 80.0
const BAR_H   = 7.0
const BAR_Y   = -120.0
const ARROW_Y = -28.0

# ── STATE MACHINE ─────────────────────────────────────────────
enum State { IDLE, CHASE, ATTACK, REPOSITION }
var _state            : State = State.IDLE
var _reposition_timer : float = 0.0

var character_name : String = "Zerg Mob"
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

# ── DEATH ─────────────────────────────────────────────────────
var _dying       : bool  = false
var _death_timer : float = 0.0

# ── TARGET INDICATOR ──────────────────────────────────────────
var _pulse_t : float = 0.0

# ── SOUNDS ─────────────────────────────────────────────────────
var _snd_attack : AudioStreamPlayer = null

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("targetable")
	add_to_group("mob")
	var stream = load("res://Sounds/zerg_attack.mp3") as AudioStream
	if stream:
		_snd_attack = AudioStreamPlayer.new()
		_snd_attack.stream    = stream
		_snd_attack.volume_db = -6.0
		_snd_attack.bus       = "Master"
		add_child(_snd_attack)

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return

	_pulse_t      += delta
	_attack_timer -= delta
	_tick_aggro()
	_update_animation()
	queue_redraw()

func _tick_aggro() -> void:
	if _state == State.IDLE:
		# Check for player walking into range
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and global_position.distance_to(p.global_position) <= AGGRO_RANGE:
				_target = p
				_state  = State.CHASE
				return
		_target = null
		return

	# Validate existing target; leash if player runs too far
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
	if _dying or _state == State.IDLE or _target == null or not is_instance_valid(_target):
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

# ── PUBLIC: force aggro from lair hit or pack pull ─────────────
func force_aggro(new_target: Node) -> void:
	if _dying or not is_instance_valid(new_target): return
	_target = new_target
	_state  = State.CHASE

# ── AI ────────────────────────────────────────────────────────
func _update_facing(to_target: Vector2) -> void:
	if absf(to_target.x) >= absf(to_target.y):
		_facing = "e" if to_target.x > 0.0 else "w"
	else:
		_facing = "s" if to_target.y > 0.0 else "n"

# ── ATTACK ────────────────────────────────────────────────────
func _do_attack() -> void:
	_attack_timer = ATTACK_INTERVAL
	_is_attacking = true
	if _snd_attack != null: _snd_attack.play()

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
			arena.spawn_damage_number(_target.global_position, dmg, Color(1.0, 0.2, 0.15))

func _on_attack_done() -> void:
	_is_attacking = false

# ── ANIMATION ─────────────────────────────────────────────────
func _update_animation() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return

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

# ── TARGET POSITION ───────────────────────────────────────────
func get_target_position() -> Vector2:
	return global_position + Vector2(0.0, -40.0)

# ── DAMAGE INTERFACE ──────────────────────────────────────────
func take_damage(amount: float) -> void:
	if _dying: return
	hp = maxf(0.0, hp - amount)

	# On first hit while idle: aggro attacker and alert nearby pack
	if _state == State.IDLE:
		var attacker = _nearest_player()
		if attacker:
			force_aggro(attacker)
		# Pull pack members within PACK_AGGRO_RANGE
		for mob in get_tree().get_nodes_in_group("mob"):
			if mob == self or not is_instance_valid(mob): continue
			if global_position.distance_to(mob.global_position) <= PACK_AGGRO_RANGE:
				if mob.has_method("force_aggro") and _target != null:
					mob.call("force_aggro", _target)

	if hp <= 0.0:
		_die()

func _nearest_player() -> Node:
	var best      : Node  = null
	var best_dist : float = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var d = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best      = p
	return best

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
		killer.call("add_exp", 12.0)
	var cred = randi_range(5, 12)
	var loot_script = load("res://Scripts/GroundLoot.gd")
	if loot_script:
		var loot = Node2D.new(); loot.set_script(loot_script)
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position
		loot.call("init", cred, 0.0)
	# Gear drop
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
	# 10% loot drop
	if randf() < 0.10 and arena and arena.has_method("on_mob_dropped_loot"):
		arena.call("on_mob_dropped_loot", global_position)

# ── DRAW ──────────────────────────────────────────────────────
func _draw() -> void:
	if _dying:
		return

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena != null and arena.has_method("is_targeted") and arena.call("is_targeted", self):
		var ay = ARROW_Y + sin(_pulse_t * 4.5) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8.0, ay),
			Vector2( 8.0, ay),
			Vector2( 0.0, ay + 11.0),
		]), Color(1.0, 0.15, 0.15, 0.92))
		draw_polyline(PackedVector2Array([
			Vector2(-8.0, ay),
			Vector2( 8.0, ay),
			Vector2( 0.0, ay + 11.0),
			Vector2(-8.0, ay),
		]), Color(1.0, 0.75, 0.75, 0.70), 1.2)
