class_name CombatEngine

# ============================================================
#  CombatEngine.gd — SWG Pre-CU style combat resolution
#  Static utility class — no state, pure functions.
#  All attack logic routes through here.
# ============================================================

# ── POSTURES ─────────────────────────────────────────────────
enum Posture { STANDING, KNEELING, PRONE }

# ── DAMAGE TYPES ─────────────────────────────────────────────
# Primary: kinetic (melee), energy (ranged/lightsaber)
# Elemental: heat, cold, acid, electricity
# Special: blast, stun (stun bypasses most armor)
const DAMAGE_TYPES = ["kinetic", "energy", "heat", "cold", "acid", "electricity", "blast", "stun"]

# ── COMBAT STATES ────────────────────────────────────────────
const STATE_DIZZY      = "dizzy"
const STATE_KNOCKDOWN  = "knockdown"
const STATE_STUN       = "stun"
const STATE_BLIND      = "blind"
const STATE_INTIMIDATE = "intimidate"

# ── HIT RESOLUTION ───────────────────────────────────────────
# Returns: {"result": "hit"/"miss"/"dodge"/"block"/"counterattack",
#           "reduction": 0.0-1.0 (for block)}
static func roll_to_hit(attacker: Node, defender: Node, attack_data: Dictionary = {}) -> Dictionary:
	var acc = _get_stat(attacker, "accuracy") + attack_data.get("accuracy_bonus", 0)
	var def = _get_stat(defender, "defense")

	# Posture modifiers
	var atk_posture = attacker.get("posture") if attacker.get("posture") != null else Posture.STANDING
	var def_posture = defender.get("posture") if defender.get("posture") != null else Posture.STANDING
	var is_ranged = attack_data.get("is_ranged", false)

	acc += _posture_accuracy_mod(atk_posture, is_ranged)
	def += _posture_defense_mod(def_posture, is_ranged)

	# Combat state modifiers
	if _has_state(attacker, STATE_BLIND):
		acc -= 50
	if _has_state(attacker, STATE_INTIMIDATE):
		acc -= 25
	if _has_state(defender, STATE_INTIMIDATE):
		def -= 25

	# Hit chance: base 66% + (acc - def) * 0.5%, clamped [5%, 100%]
	var hit_chance = 0.66 + (acc - def) * 0.005
	hit_chance = clampf(hit_chance, 0.05, 1.0)

	var roll = randf()
	if roll > hit_chance:
		return {"result": "miss"}

	# Knockdown = guaranteed hit, no secondary defenses
	if _has_state(defender, STATE_KNOCKDOWN):
		return {"result": "hit"}

	# Secondary defense rolls (only if not stunned/knocked)
	if not _has_state(defender, STATE_STUN):
		var dodge_chance = _get_stat(defender, "dodge") * 0.005
		if randf() < dodge_chance:
			return {"result": "dodge"}

		var block_chance = _get_stat(defender, "block") * 0.005
		if randf() < block_chance:
			return {"result": "block", "reduction": 0.75}

		var counter_chance = _get_stat(defender, "counterattack") * 0.005
		if randf() < counter_chance:
			return {"result": "counterattack"}

	return {"result": "hit"}

# ── DAMAGE CALCULATION ───────────────────────────────────────
static func calc_damage(base_damage: float, damage_type: String, defender: Node, attack_data: Dictionary = {}) -> float:
	var dmg = base_damage

	# Knockdown = 2× damage
	if _has_state(defender, STATE_KNOCKDOWN):
		dmg *= 2.0

	# Armor resistance (stun bypasses most armor)
	if damage_type != "stun":
		var resist = _get_stat(defender, "resist_" + damage_type)
		dmg *= maxf(0.05, 1.0 - resist * 0.01)  # min 5% damage through

	return maxf(1.0, dmg)

# ── COMBAT STATE APPLICATION ─────────────────────────────────
# Returns true if state was successfully applied
static func try_apply_state(attacker: Node, defender: Node, state_name: String, duration: float, attack_data: Dictionary = {}) -> bool:
	# Defense vs specific state
	var defense_stat = "defense_vs_" + state_name
	var def_chance = _get_stat(defender, defense_stat) * 0.005
	if randf() < def_chance:
		return false  # Resisted

	# Dizzy → knockdown combo: if target is dizzy and we apply knockdown, it sticks
	if state_name == STATE_KNOCKDOWN and _has_state(defender, STATE_DIZZY):
		duration *= 1.5  # Extended knockdown while dizzy

	if defender.has_method("apply_combat_state"):
		defender.call("apply_combat_state", state_name, duration)
		return true
	return false

# ── POSTURE MODIFIERS ────────────────────────────────────────
static func _posture_accuracy_mod(posture: int, is_ranged: bool) -> float:
	if is_ranged:
		match posture:
			Posture.KNEELING: return 16.0
			Posture.PRONE:    return 25.0
	return 0.0

static func _posture_defense_mod(def_posture: int, is_ranged: bool) -> float:
	if is_ranged:
		match def_posture:
			Posture.KNEELING: return 8.0   # Smaller target
			Posture.PRONE:    return 16.0  # Even smaller
	else:  # Melee attacks vs kneeling/prone = easier to hit
		match def_posture:
			Posture.KNEELING: return -10.0
			Posture.PRONE:    return -20.0
	return 0.0

# ── HELPERS ──────────────────────────────────────────────────
static func _get_stat(node: Node, stat_name: String) -> float:
	if node.has_method("get_stat"):
		return node.call("get_stat", stat_name)
	# Fallback: try reading as property
	var val = node.get(stat_name)
	if val != null:
		return float(val)
	return 0.0

static func _has_state(node: Node, state_name: String) -> bool:
	var timer_var = "state_" + state_name
	var val = node.get(timer_var)
	if val != null and val is float:
		return val > 0.0
	return false

# ── WEAPON DAMAGE TYPE MAPPING ───────────────────────────────
static func get_weapon_damage_type(character_class: String) -> String:
	match character_class:
		"scrapper", "melee", "streetfighter": return "kinetic"
		"ranged":           return "energy"
		"mage":             return "energy"
		"medic", "robo":    return "energy"
	return "kinetic"

# ── WEAPON HAM TARGET MAPPING ────────────────────────────────
# SWG: different weapons target different pools
static func get_weapon_target_pool(character_class: String) -> String:
	match character_class:
		"scrapper", "melee", "streetfighter": return "health"
		"ranged":           return "action"
		"mage":             return "mind"
		"medic", "robo":    return "health"
	return "health"
