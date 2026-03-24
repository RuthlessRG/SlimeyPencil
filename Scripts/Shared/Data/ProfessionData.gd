class_name ProfessionData

# ============================================================
#  ProfessionData.gd — Galactic War Profession System
#  8 professions total: 2 base → 4 advanced (2 per base)
#  Base: Brawler, Marksman
#  Advanced Melee: MMA (TKM), Fencing (Fencer)
#  Advanced Ranged: Gunslinger (Pistoleer), Sniper (Rifleman)
#  Each profession: Novice + 4 disciplines × 4 tiers + Master = 18 boxes
#  250 skill points total per character.
# ============================================================

# ── COMBAT STATS ─────────────────────────────────────────────
# These are the SWG-style stats that professions modify:
# accuracy, melee_defense, ranged_defense,
# defense_vs_dizzy, defense_vs_knockdown, defense_vs_stun, defense_vs_blind,
# dodge, block, counterattack,
# melee_damage, ranged_damage, heal_potency,
# max_health_bonus, max_action_bonus, max_mind_bonus

static func get_base_stats() -> Dictionary:
	return {
		"accuracy": 0, "melee_defense": 0, "ranged_defense": 0,
		"defense_vs_dizzy": 0, "defense_vs_knockdown": 0,
		"defense_vs_stun": 0, "defense_vs_blind": 0,
		"dodge": 0, "block": 0, "counterattack": 0,
		"melee_damage": 0, "ranged_damage": 0, "heal_potency": 0,
		"max_health_bonus": 0, "max_action_bonus": 0, "max_mind_bonus": 0,
	}

static func get_all_professions() -> Array:
	return [
		_brawler(),
		_marksman(),
		_mma(),
		_fencing(),
		_gunslinger(),
		_sniper(),
	]

static func get_base_professions() -> Array:
	return [_brawler(), _marksman()]

static func get_advanced_professions(base_id: String) -> Array:
	match base_id:
		"brawler":
			return [_mma(), _fencing()]
		"marksman":
			return [_gunslinger(), _sniper()]
	return []

static func get_profession(prof_id: String) -> Dictionary:
	for p in get_all_professions():
		if p.id == prof_id:
			return p
	return {}

# ── BRAWLER (Base Melee) ─────────────────────────────────────
static func _brawler() -> Dictionary:
	return {
		"id": "brawler", "name": "Brawler", "is_base": true,
		"desc": "Close-quarters combat specialist. Foundation for all melee professions.",
		"advances_to": ["mma", "fencing"],
		"novice": {
			"id": "brawler_novice", "name": "Novice Brawler",
			"cost_sp": 15, "xp_type": "melee", "xp_cost": 0, "credit_cost": 0,
			"requires": [],
			"modifiers": {"accuracy": 5, "melee_defense": 5, "melee_damage": 3},
			"abilities": [],
		},
		"disciplines": [
			{ "name": "Unarmed", "boxes": [
				{"id": "brawler_unarmed_01", "name": "Unarmed I", "cost_sp": 2, "xp_type": "melee", "xp_cost": 500, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 5, "melee_damage": 3}, "abilities": []},
				{"id": "brawler_unarmed_02", "name": "Unarmed II", "cost_sp": 3, "xp_type": "melee", "xp_cost": 1500, "credit_cost": 250, "requires": ["brawler_unarmed_01"],
				 "modifiers": {"accuracy": 8, "melee_damage": 5}, "abilities": ["dizzy_punch"]},
				{"id": "brawler_unarmed_03", "name": "Unarmed III", "cost_sp": 4, "xp_type": "melee", "xp_cost": 4000, "credit_cost": 500, "requires": ["brawler_unarmed_02"],
				 "modifiers": {"accuracy": 10, "melee_damage": 8}, "abilities": []},
				{"id": "brawler_unarmed_04", "name": "Unarmed IV", "cost_sp": 5, "xp_type": "melee", "xp_cost": 8000, "credit_cost": 1000, "requires": ["brawler_unarmed_03"],
				 "modifiers": {"accuracy": 12, "melee_damage": 10, "defense_vs_knockdown": 5}, "abilities": ["knockdown_blow"]},
			]},
			{ "name": "One Hand", "boxes": [
				{"id": "brawler_onehand_01", "name": "One Hand I", "cost_sp": 2, "xp_type": "melee", "xp_cost": 500, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 5, "melee_damage": 4, "dodge": 2}, "abilities": []},
				{"id": "brawler_onehand_02", "name": "One Hand II", "cost_sp": 3, "xp_type": "melee", "xp_cost": 1500, "credit_cost": 250, "requires": ["brawler_onehand_01"],
				 "modifiers": {"accuracy": 8, "melee_damage": 6, "dodge": 4}, "abilities": ["riposte"]},
				{"id": "brawler_onehand_03", "name": "One Hand III", "cost_sp": 4, "xp_type": "melee", "xp_cost": 4000, "credit_cost": 500, "requires": ["brawler_onehand_02"],
				 "modifiers": {"accuracy": 10, "melee_damage": 8, "dodge": 6}, "abilities": []},
				{"id": "brawler_onehand_04", "name": "One Hand IV", "cost_sp": 5, "xp_type": "melee", "xp_cost": 8000, "credit_cost": 1000, "requires": ["brawler_onehand_03"],
				 "modifiers": {"accuracy": 12, "melee_damage": 10, "dodge": 8, "block": 3}, "abilities": ["blade_flurry"]},
			]},
			{ "name": "Two Hand", "boxes": [
				{"id": "brawler_twohand_01", "name": "Two Hand I", "cost_sp": 2, "xp_type": "melee", "xp_cost": 500, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 4, "melee_damage": 6, "melee_defense": 3}, "abilities": []},
				{"id": "brawler_twohand_02", "name": "Two Hand II", "cost_sp": 3, "xp_type": "melee", "xp_cost": 1500, "credit_cost": 250, "requires": ["brawler_twohand_01"],
				 "modifiers": {"accuracy": 6, "melee_damage": 10, "melee_defense": 5}, "abilities": ["power_attack"]},
				{"id": "brawler_twohand_03", "name": "Two Hand III", "cost_sp": 4, "xp_type": "melee", "xp_cost": 4000, "credit_cost": 500, "requires": ["brawler_twohand_02"],
				 "modifiers": {"accuracy": 8, "melee_damage": 14, "melee_defense": 8}, "abilities": []},
				{"id": "brawler_twohand_04", "name": "Two Hand IV", "cost_sp": 5, "xp_type": "melee", "xp_cost": 8000, "credit_cost": 1000, "requires": ["brawler_twohand_03"],
				 "modifiers": {"accuracy": 10, "melee_damage": 18, "melee_defense": 10, "block": 5}, "abilities": ["cleave"]},
			]},
			{ "name": "Toughness", "boxes": [
				{"id": "brawler_tough_01", "name": "Toughness I", "cost_sp": 2, "xp_type": "melee", "xp_cost": 500, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"melee_defense": 5, "defense_vs_knockdown": 3, "max_health_bonus": 50}, "abilities": []},
				{"id": "brawler_tough_02", "name": "Toughness II", "cost_sp": 3, "xp_type": "melee", "xp_cost": 1500, "credit_cost": 250, "requires": ["brawler_tough_01"],
				 "modifiers": {"melee_defense": 8, "defense_vs_knockdown": 5, "max_health_bonus": 100}, "abilities": []},
				{"id": "brawler_tough_03", "name": "Toughness III", "cost_sp": 4, "xp_type": "melee", "xp_cost": 4000, "credit_cost": 500, "requires": ["brawler_tough_02"],
				 "modifiers": {"melee_defense": 10, "defense_vs_knockdown": 8, "max_health_bonus": 150}, "abilities": []},
				{"id": "brawler_tough_04", "name": "Toughness IV", "cost_sp": 5, "xp_type": "melee", "xp_cost": 8000, "credit_cost": 1000, "requires": ["brawler_tough_03"],
				 "modifiers": {"melee_defense": 12, "defense_vs_knockdown": 12, "defense_vs_dizzy": 5, "max_health_bonus": 200}, "abilities": []},
			]},
		],
		"master": {
			"id": "brawler_master", "name": "Master Brawler",
			"cost_sp": 6, "xp_type": "melee", "xp_cost": 15000, "credit_cost": 5000,
			"requires": ["brawler_unarmed_04", "brawler_onehand_04", "brawler_twohand_04", "brawler_tough_04"],
			"modifiers": {"accuracy": 15, "melee_defense": 15, "melee_damage": 12, "dodge": 8, "block": 5},
			"abilities": ["berserk"],
			"grants_title": "Master Brawler",
		},
	}

# ── MARKSMAN (Base Ranged) ───────────────────────────────────
static func _marksman() -> Dictionary:
	return {
		"id": "marksman", "name": "Marksman", "is_base": true,
		"desc": "Ranged weapons specialist. Foundation for all ranged professions.",
		"advances_to": ["gunslinger", "sniper"],
		"novice": {
			"id": "marksman_novice", "name": "Novice Marksman",
			"cost_sp": 15, "xp_type": "ranged", "xp_cost": 0, "credit_cost": 0,
			"requires": [],
			"modifiers": {"accuracy": 5, "ranged_defense": 3, "ranged_damage": 3},
			"abilities": [],
		},
		"disciplines": [
			{ "name": "Pistol", "boxes": [
				{"id": "marksman_pistol_01", "name": "Pistol I", "cost_sp": 2, "xp_type": "ranged", "xp_cost": 500, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"accuracy": 8, "ranged_damage": 4}, "abilities": []},
				{"id": "marksman_pistol_02", "name": "Pistol II", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 1500, "credit_cost": 250, "requires": ["marksman_pistol_01"],
				 "modifiers": {"accuracy": 10, "ranged_damage": 6}, "abilities": ["body_shot"]},
				{"id": "marksman_pistol_03", "name": "Pistol III", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 4000, "credit_cost": 500, "requires": ["marksman_pistol_02"],
				 "modifiers": {"accuracy": 12, "ranged_damage": 8}, "abilities": []},
				{"id": "marksman_pistol_04", "name": "Pistol IV", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 8000, "credit_cost": 1000, "requires": ["marksman_pistol_03"],
				 "modifiers": {"accuracy": 15, "ranged_damage": 12}, "abilities": ["fan_shot"]},
			]},
			{ "name": "Rifle", "boxes": [
				{"id": "marksman_rifle_01", "name": "Rifle I", "cost_sp": 2, "xp_type": "ranged", "xp_cost": 500, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"accuracy": 8, "ranged_damage": 5}, "abilities": []},
				{"id": "marksman_rifle_02", "name": "Rifle II", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 1500, "credit_cost": 250, "requires": ["marksman_rifle_01"],
				 "modifiers": {"accuracy": 10, "ranged_damage": 8}, "abilities": ["aimed_shot"]},
				{"id": "marksman_rifle_03", "name": "Rifle III", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 4000, "credit_cost": 500, "requires": ["marksman_rifle_02"],
				 "modifiers": {"accuracy": 12, "ranged_damage": 12}, "abilities": []},
				{"id": "marksman_rifle_04", "name": "Rifle IV", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 8000, "credit_cost": 1000, "requires": ["marksman_rifle_03"],
				 "modifiers": {"accuracy": 18, "ranged_damage": 16}, "abilities": ["headshot"]},
			]},
			{ "name": "Ranged Speed", "boxes": [
				{"id": "marksman_speed_01", "name": "Ranged Speed I", "cost_sp": 2, "xp_type": "ranged", "xp_cost": 500, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"accuracy": 5, "dodge": 3}, "abilities": []},
				{"id": "marksman_speed_02", "name": "Ranged Speed II", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 1500, "credit_cost": 250, "requires": ["marksman_speed_01"],
				 "modifiers": {"accuracy": 8, "dodge": 5}, "abilities": ["quick_draw"]},
				{"id": "marksman_speed_03", "name": "Ranged Speed III", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 4000, "credit_cost": 500, "requires": ["marksman_speed_02"],
				 "modifiers": {"accuracy": 10, "dodge": 8}, "abilities": []},
				{"id": "marksman_speed_04", "name": "Ranged Speed IV", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 8000, "credit_cost": 1000, "requires": ["marksman_speed_03"],
				 "modifiers": {"accuracy": 12, "dodge": 12, "defense_vs_blind": 5}, "abilities": ["evasive_fire"]},
			]},
			{ "name": "Ranged Support", "boxes": [
				{"id": "marksman_support_01", "name": "Ranged Support I", "cost_sp": 2, "xp_type": "ranged", "xp_cost": 500, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"ranged_defense": 5, "defense_vs_dizzy": 3}, "abilities": []},
				{"id": "marksman_support_02", "name": "Ranged Support II", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 1500, "credit_cost": 250, "requires": ["marksman_support_01"],
				 "modifiers": {"ranged_defense": 8, "defense_vs_dizzy": 5}, "abilities": ["leg_shot"]},
				{"id": "marksman_support_03", "name": "Ranged Support III", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 4000, "credit_cost": 500, "requires": ["marksman_support_02"],
				 "modifiers": {"ranged_defense": 10, "defense_vs_dizzy": 8, "defense_vs_blind": 5}, "abilities": []},
				{"id": "marksman_support_04", "name": "Ranged Support IV", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 8000, "credit_cost": 1000, "requires": ["marksman_support_03"],
				 "modifiers": {"ranged_defense": 12, "defense_vs_dizzy": 12, "defense_vs_blind": 8}, "abilities": ["flash_grenade"]},
			]},
		],
		"master": {
			"id": "marksman_master", "name": "Master Marksman",
			"cost_sp": 6, "xp_type": "ranged", "xp_cost": 15000, "credit_cost": 5000,
			"requires": ["marksman_pistol_04", "marksman_rifle_04", "marksman_speed_04", "marksman_support_04"],
			"modifiers": {"accuracy": 20, "ranged_defense": 12, "ranged_damage": 10, "dodge": 8},
			"abilities": ["called_shot"],
			"grants_title": "Master Marksman",
		},
	}

# ── MMA (Advanced Melee — TKM equivalent) ────────────────────
static func _mma() -> Dictionary:
	return {
		"id": "mma", "name": "MMA Fighter", "is_base": false,
		"desc": "Master of mixed martial arts. Devastating unarmed strikes and grapples.",
		"requires_base": "brawler",
		"novice": {
			"id": "mma_novice", "name": "Novice MMA Fighter",
			"cost_sp": 15, "xp_type": "melee", "xp_cost": 12000, "credit_cost": 2000,
			"requires": ["brawler_master"],
			"modifiers": {"accuracy": 10, "melee_damage": 8, "melee_defense": 8, "defense_vs_knockdown": 5},
			"abilities": ["spinning_kick"],
		},
		"disciplines": [
			{ "name": "Striking", "boxes": [
				{"id": "mma_striking_01", "name": "Striking I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["mma_novice"],
				 "modifiers": {"accuracy": 12, "melee_damage": 10}, "abilities": []},
				{"id": "mma_striking_02", "name": "Striking II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["mma_striking_01"],
				 "modifiers": {"accuracy": 15, "melee_damage": 14}, "abilities": ["haymaker"]},
				{"id": "mma_striking_03", "name": "Striking III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["mma_striking_02"],
				 "modifiers": {"accuracy": 18, "melee_damage": 18}, "abilities": []},
				{"id": "mma_striking_04", "name": "Striking IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["mma_striking_03"],
				 "modifiers": {"accuracy": 22, "melee_damage": 24}, "abilities": ["knockout_combo"]},
			]},
			{ "name": "Grappling", "boxes": [
				{"id": "mma_grapple_01", "name": "Grappling I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["mma_novice"],
				 "modifiers": {"melee_defense": 10, "defense_vs_knockdown": 8}, "abilities": []},
				{"id": "mma_grapple_02", "name": "Grappling II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["mma_grapple_01"],
				 "modifiers": {"melee_defense": 14, "defense_vs_knockdown": 12}, "abilities": ["takedown"]},
				{"id": "mma_grapple_03", "name": "Grappling III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["mma_grapple_02"],
				 "modifiers": {"melee_defense": 18, "defense_vs_knockdown": 16, "defense_vs_stun": 8}, "abilities": []},
				{"id": "mma_grapple_04", "name": "Grappling IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["mma_grapple_03"],
				 "modifiers": {"melee_defense": 22, "defense_vs_knockdown": 20, "defense_vs_stun": 14}, "abilities": ["chokehold"]},
			]},
			{ "name": "Conditioning", "boxes": [
				{"id": "mma_cond_01", "name": "Conditioning I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["mma_novice"],
				 "modifiers": {"max_health_bonus": 100, "max_action_bonus": 50, "dodge": 5}, "abilities": []},
				{"id": "mma_cond_02", "name": "Conditioning II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["mma_cond_01"],
				 "modifiers": {"max_health_bonus": 200, "max_action_bonus": 100, "dodge": 8}, "abilities": []},
				{"id": "mma_cond_03", "name": "Conditioning III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["mma_cond_02"],
				 "modifiers": {"max_health_bonus": 300, "max_action_bonus": 150, "dodge": 12}, "abilities": ["iron_body"]},
				{"id": "mma_cond_04", "name": "Conditioning IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["mma_cond_03"],
				 "modifiers": {"max_health_bonus": 400, "max_action_bonus": 200, "dodge": 16}, "abilities": []},
			]},
			{ "name": "Focus", "boxes": [
				{"id": "mma_focus_01", "name": "Focus I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["mma_novice"],
				 "modifiers": {"defense_vs_dizzy": 8, "defense_vs_blind": 5, "counterattack": 3}, "abilities": []},
				{"id": "mma_focus_02", "name": "Focus II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["mma_focus_01"],
				 "modifiers": {"defense_vs_dizzy": 12, "defense_vs_blind": 8, "counterattack": 6}, "abilities": ["counter_strike"]},
				{"id": "mma_focus_03", "name": "Focus III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["mma_focus_02"],
				 "modifiers": {"defense_vs_dizzy": 16, "defense_vs_blind": 12, "counterattack": 10}, "abilities": []},
				{"id": "mma_focus_04", "name": "Focus IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["mma_focus_03"],
				 "modifiers": {"defense_vs_dizzy": 20, "defense_vs_blind": 16, "counterattack": 15}, "abilities": ["meditative_focus"]},
			]},
		],
		"master": {
			"id": "mma_master", "name": "MMA Champion",
			"cost_sp": 8, "xp_type": "melee", "xp_cost": 80000, "credit_cost": 10000,
			"requires": ["mma_striking_04", "mma_grapple_04", "mma_cond_04", "mma_focus_04"],
			"modifiers": {"accuracy": 25, "melee_defense": 25, "melee_damage": 20, "dodge": 15, "counterattack": 10},
			"abilities": ["finishing_move"],
			"grants_title": "MMA Champion",
		},
	}

# ── FENCING (Advanced Melee — Fencer equivalent) ─────────────
static func _fencing() -> Dictionary:
	return {
		"id": "fencing", "name": "Fencer", "is_base": false,
		"desc": "Precision swordsman. Lightning fast parries and lethal ripostes.",
		"requires_base": "brawler",
		"novice": {
			"id": "fencing_novice", "name": "Novice Fencer",
			"cost_sp": 15, "xp_type": "melee", "xp_cost": 12000, "credit_cost": 2000,
			"requires": ["brawler_master"],
			"modifiers": {"accuracy": 10, "melee_damage": 6, "dodge": 8, "block": 5},
			"abilities": ["lunge"],
		},
		"disciplines": [
			{ "name": "Blade Mastery", "boxes": [
				{"id": "fencing_blade_01", "name": "Blade Mastery I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["fencing_novice"],
				 "modifiers": {"accuracy": 12, "melee_damage": 8, "block": 5}, "abilities": []},
				{"id": "fencing_blade_02", "name": "Blade Mastery II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["fencing_blade_01"],
				 "modifiers": {"accuracy": 15, "melee_damage": 12, "block": 8}, "abilities": ["precise_strike"]},
				{"id": "fencing_blade_03", "name": "Blade Mastery III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["fencing_blade_02"],
				 "modifiers": {"accuracy": 18, "melee_damage": 16, "block": 12}, "abilities": []},
				{"id": "fencing_blade_04", "name": "Blade Mastery IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["fencing_blade_03"],
				 "modifiers": {"accuracy": 22, "melee_damage": 20, "block": 16}, "abilities": ["death_blow"]},
			]},
			{ "name": "Parry", "boxes": [
				{"id": "fencing_parry_01", "name": "Parry I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["fencing_novice"],
				 "modifiers": {"melee_defense": 10, "dodge": 8, "counterattack": 5}, "abilities": []},
				{"id": "fencing_parry_02", "name": "Parry II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["fencing_parry_01"],
				 "modifiers": {"melee_defense": 14, "dodge": 12, "counterattack": 8}, "abilities": ["riposte_counter"]},
				{"id": "fencing_parry_03", "name": "Parry III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["fencing_parry_02"],
				 "modifiers": {"melee_defense": 18, "dodge": 16, "counterattack": 12}, "abilities": []},
				{"id": "fencing_parry_04", "name": "Parry IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["fencing_parry_03"],
				 "modifiers": {"melee_defense": 22, "dodge": 20, "counterattack": 18}, "abilities": ["perfect_parry"]},
			]},
			{ "name": "Footwork", "boxes": [
				{"id": "fencing_foot_01", "name": "Footwork I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["fencing_novice"],
				 "modifiers": {"dodge": 8, "defense_vs_knockdown": 8}, "abilities": []},
				{"id": "fencing_foot_02", "name": "Footwork II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["fencing_foot_01"],
				 "modifiers": {"dodge": 12, "defense_vs_knockdown": 12}, "abilities": ["sidestep"]},
				{"id": "fencing_foot_03", "name": "Footwork III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["fencing_foot_02"],
				 "modifiers": {"dodge": 16, "defense_vs_knockdown": 16, "defense_vs_dizzy": 8}, "abilities": []},
				{"id": "fencing_foot_04", "name": "Footwork IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["fencing_foot_03"],
				 "modifiers": {"dodge": 22, "defense_vs_knockdown": 20, "defense_vs_dizzy": 14}, "abilities": ["untouchable"]},
			]},
			{ "name": "Dueling", "boxes": [
				{"id": "fencing_duel_01", "name": "Dueling I", "cost_sp": 3, "xp_type": "melee", "xp_cost": 10000, "credit_cost": 500, "requires": ["fencing_novice"],
				 "modifiers": {"accuracy": 8, "melee_damage": 5, "max_action_bonus": 50}, "abilities": []},
				{"id": "fencing_duel_02", "name": "Dueling II", "cost_sp": 4, "xp_type": "melee", "xp_cost": 20000, "credit_cost": 1000, "requires": ["fencing_duel_01"],
				 "modifiers": {"accuracy": 12, "melee_damage": 8, "max_action_bonus": 100}, "abilities": ["feint"]},
				{"id": "fencing_duel_03", "name": "Dueling III", "cost_sp": 5, "xp_type": "melee", "xp_cost": 35000, "credit_cost": 2000, "requires": ["fencing_duel_02"],
				 "modifiers": {"accuracy": 16, "melee_damage": 12, "max_action_bonus": 150}, "abilities": []},
				{"id": "fencing_duel_04", "name": "Dueling IV", "cost_sp": 6, "xp_type": "melee", "xp_cost": 50000, "credit_cost": 4000, "requires": ["fencing_duel_03"],
				 "modifiers": {"accuracy": 20, "melee_damage": 16, "max_action_bonus": 200}, "abilities": ["fatal_thrust"]},
			]},
		],
		"master": {
			"id": "fencing_master", "name": "Master Fencer",
			"cost_sp": 8, "xp_type": "melee", "xp_cost": 80000, "credit_cost": 10000,
			"requires": ["fencing_blade_04", "fencing_parry_04", "fencing_foot_04", "fencing_duel_04"],
			"modifiers": {"accuracy": 25, "melee_defense": 20, "melee_damage": 18, "dodge": 20, "block": 15, "counterattack": 15},
			"abilities": ["blade_dance"],
			"grants_title": "Master Fencer",
		},
	}

# ── GUNSLINGER (Advanced Ranged — Pistoleer equivalent) ──────
static func _gunslinger() -> Dictionary:
	return {
		"id": "gunslinger", "name": "Gunslinger", "is_base": false,
		"desc": "Dual-pistol specialist. Fast draws, trick shots, and close-range devastation.",
		"requires_base": "marksman",
		"novice": {
			"id": "gunslinger_novice", "name": "Novice Gunslinger",
			"cost_sp": 15, "xp_type": "ranged", "xp_cost": 12000, "credit_cost": 2000,
			"requires": ["marksman_master"],
			"modifiers": {"accuracy": 10, "ranged_damage": 8, "dodge": 8},
			"abilities": ["quick_draw_shot"],
		},
		"disciplines": [
			{ "name": "Dual Wield", "boxes": [
				{"id": "gun_dual_01", "name": "Dual Wield I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["gunslinger_novice"],
				 "modifiers": {"accuracy": 10, "ranged_damage": 10}, "abilities": []},
				{"id": "gun_dual_02", "name": "Dual Wield II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["gun_dual_01"],
				 "modifiers": {"accuracy": 14, "ranged_damage": 14}, "abilities": ["double_tap"]},
				{"id": "gun_dual_03", "name": "Dual Wield III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["gun_dual_02"],
				 "modifiers": {"accuracy": 18, "ranged_damage": 18}, "abilities": []},
				{"id": "gun_dual_04", "name": "Dual Wield IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["gun_dual_03"],
				 "modifiers": {"accuracy": 22, "ranged_damage": 24}, "abilities": ["bullet_storm"]},
			]},
			{ "name": "Trick Shots", "boxes": [
				{"id": "gun_trick_01", "name": "Trick Shots I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["gunslinger_novice"],
				 "modifiers": {"accuracy": 12, "defense_vs_dizzy": 5}, "abilities": []},
				{"id": "gun_trick_02", "name": "Trick Shots II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["gun_trick_01"],
				 "modifiers": {"accuracy": 16, "defense_vs_dizzy": 8}, "abilities": ["ricochet_shot"]},
				{"id": "gun_trick_03", "name": "Trick Shots III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["gun_trick_02"],
				 "modifiers": {"accuracy": 20, "defense_vs_dizzy": 12}, "abilities": []},
				{"id": "gun_trick_04", "name": "Trick Shots IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["gun_trick_03"],
				 "modifiers": {"accuracy": 25, "defense_vs_dizzy": 16}, "abilities": ["disarm_shot"]},
			]},
			{ "name": "Gunslinger Speed", "boxes": [
				{"id": "gun_speed_01", "name": "Gunslinger Speed I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["gunslinger_novice"],
				 "modifiers": {"dodge": 10, "ranged_defense": 5}, "abilities": []},
				{"id": "gun_speed_02", "name": "Gunslinger Speed II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["gun_speed_01"],
				 "modifiers": {"dodge": 14, "ranged_defense": 8}, "abilities": ["pistol_whip"]},
				{"id": "gun_speed_03", "name": "Gunslinger Speed III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["gun_speed_02"],
				 "modifiers": {"dodge": 18, "ranged_defense": 12}, "abilities": []},
				{"id": "gun_speed_04", "name": "Gunslinger Speed IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["gun_speed_03"],
				 "modifiers": {"dodge": 22, "ranged_defense": 16}, "abilities": ["gunslinger_stance"]},
			]},
			{ "name": "Intimidation", "boxes": [
				{"id": "gun_intim_01", "name": "Intimidation I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["gunslinger_novice"],
				 "modifiers": {"ranged_damage": 5, "defense_vs_blind": 5, "defense_vs_stun": 3}, "abilities": []},
				{"id": "gun_intim_02", "name": "Intimidation II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["gun_intim_01"],
				 "modifiers": {"ranged_damage": 8, "defense_vs_blind": 8, "defense_vs_stun": 6}, "abilities": ["warning_shot"]},
				{"id": "gun_intim_03", "name": "Intimidation III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["gun_intim_02"],
				 "modifiers": {"ranged_damage": 12, "defense_vs_blind": 12, "defense_vs_stun": 10}, "abilities": []},
				{"id": "gun_intim_04", "name": "Intimidation IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["gun_intim_03"],
				 "modifiers": {"ranged_damage": 16, "defense_vs_blind": 16, "defense_vs_stun": 14}, "abilities": ["last_stand"]},
			]},
		],
		"master": {
			"id": "gunslinger_master", "name": "Master Gunslinger",
			"cost_sp": 8, "xp_type": "ranged", "xp_cost": 80000, "credit_cost": 10000,
			"requires": ["gun_dual_04", "gun_trick_04", "gun_speed_04", "gun_intim_04"],
			"modifiers": {"accuracy": 25, "ranged_defense": 20, "ranged_damage": 20, "dodge": 18},
			"abilities": ["dead_eye"],
			"grants_title": "Master Gunslinger",
		},
	}

# ── SNIPER (Advanced Ranged — Rifleman equivalent) ───────────
static func _sniper() -> Dictionary:
	return {
		"id": "sniper", "name": "Sniper", "is_base": false,
		"desc": "Long-range precision specialist. One shot, one kill.",
		"requires_base": "marksman",
		"novice": {
			"id": "sniper_novice", "name": "Novice Sniper",
			"cost_sp": 15, "xp_type": "ranged", "xp_cost": 12000, "credit_cost": 2000,
			"requires": ["marksman_master"],
			"modifiers": {"accuracy": 15, "ranged_damage": 10, "ranged_defense": 5},
			"abilities": ["steady_aim"],
		},
		"disciplines": [
			{ "name": "Marksmanship", "boxes": [
				{"id": "sniper_marks_01", "name": "Marksmanship I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["sniper_novice"],
				 "modifiers": {"accuracy": 15, "ranged_damage": 8}, "abilities": []},
				{"id": "sniper_marks_02", "name": "Marksmanship II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["sniper_marks_01"],
				 "modifiers": {"accuracy": 20, "ranged_damage": 12}, "abilities": ["precision_shot"]},
				{"id": "sniper_marks_03", "name": "Marksmanship III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["sniper_marks_02"],
				 "modifiers": {"accuracy": 25, "ranged_damage": 16}, "abilities": []},
				{"id": "sniper_marks_04", "name": "Marksmanship IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["sniper_marks_03"],
				 "modifiers": {"accuracy": 30, "ranged_damage": 22}, "abilities": ["killshot"]},
			]},
			{ "name": "Concealment", "boxes": [
				{"id": "sniper_conceal_01", "name": "Concealment I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["sniper_novice"],
				 "modifiers": {"ranged_defense": 10, "dodge": 5}, "abilities": []},
				{"id": "sniper_conceal_02", "name": "Concealment II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["sniper_conceal_01"],
				 "modifiers": {"ranged_defense": 14, "dodge": 8}, "abilities": ["camouflage"]},
				{"id": "sniper_conceal_03", "name": "Concealment III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["sniper_conceal_02"],
				 "modifiers": {"ranged_defense": 18, "dodge": 12}, "abilities": []},
				{"id": "sniper_conceal_04", "name": "Concealment IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["sniper_conceal_03"],
				 "modifiers": {"ranged_defense": 22, "dodge": 16}, "abilities": ["ghost"]},
			]},
			{ "name": "Field Craft", "boxes": [
				{"id": "sniper_field_01", "name": "Field Craft I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["sniper_novice"],
				 "modifiers": {"defense_vs_knockdown": 8, "defense_vs_dizzy": 5, "max_mind_bonus": 50}, "abilities": []},
				{"id": "sniper_field_02", "name": "Field Craft II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["sniper_field_01"],
				 "modifiers": {"defense_vs_knockdown": 12, "defense_vs_dizzy": 8, "max_mind_bonus": 100}, "abilities": ["spotter"]},
				{"id": "sniper_field_03", "name": "Field Craft III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["sniper_field_02"],
				 "modifiers": {"defense_vs_knockdown": 16, "defense_vs_dizzy": 12, "max_mind_bonus": 150}, "abilities": []},
				{"id": "sniper_field_04", "name": "Field Craft IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["sniper_field_03"],
				 "modifiers": {"defense_vs_knockdown": 20, "defense_vs_dizzy": 16, "max_mind_bonus": 200}, "abilities": ["overwatch"]},
			]},
			{ "name": "Demolitions", "boxes": [
				{"id": "sniper_demo_01", "name": "Demolitions I", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 500, "requires": ["sniper_novice"],
				 "modifiers": {"ranged_damage": 8, "defense_vs_stun": 5}, "abilities": []},
				{"id": "sniper_demo_02", "name": "Demolitions II", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 1000, "requires": ["sniper_demo_01"],
				 "modifiers": {"ranged_damage": 12, "defense_vs_stun": 8}, "abilities": ["explosive_round"]},
				{"id": "sniper_demo_03", "name": "Demolitions III", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 35000, "credit_cost": 2000, "requires": ["sniper_demo_02"],
				 "modifiers": {"ranged_damage": 16, "defense_vs_stun": 12}, "abilities": []},
				{"id": "sniper_demo_04", "name": "Demolitions IV", "cost_sp": 6, "xp_type": "ranged", "xp_cost": 50000, "credit_cost": 4000, "requires": ["sniper_demo_03"],
				 "modifiers": {"ranged_damage": 22, "defense_vs_stun": 16}, "abilities": ["orbital_strike"]},
			]},
		],
		"master": {
			"id": "sniper_master", "name": "Master Sniper",
			"cost_sp": 8, "xp_type": "ranged", "xp_cost": 80000, "credit_cost": 10000,
			"requires": ["sniper_marks_04", "sniper_conceal_04", "sniper_field_04", "sniper_demo_04"],
			"modifiers": {"accuracy": 30, "ranged_defense": 20, "ranged_damage": 25, "dodge": 12},
			"abilities": ["one_shot"],
			"grants_title": "Master Sniper",
		},
	}

# ── UTILITY ──────────────────────────────────────────────────
static func get_all_boxes(prof: Dictionary) -> Array:
	var boxes = [prof.novice]
	for disc in prof.disciplines:
		for box in disc.boxes:
			boxes.append(box)
	boxes.append(prof.master)
	return boxes

static func find_box(box_id: String) -> Dictionary:
	for prof in get_all_professions():
		for box in get_all_boxes(prof):
			if box.id == box_id:
				return box
	return {}

static func can_learn_box(box: Dictionary, learned_boxes: Array, xp_pools: Dictionary, skill_points_available: int, player_credits: int) -> Dictionary:
	if box.id in learned_boxes:
		return {"can_learn": false, "reason": "Already learned"}
	if box.cost_sp > skill_points_available:
		return {"can_learn": false, "reason": "Need %d skill points" % box.cost_sp}
	var xp_available = xp_pools.get(box.xp_type, 0)
	if xp_available < box.xp_cost:
		return {"can_learn": false, "reason": "Need %d %s XP" % [box.xp_cost, box.xp_type]}
	if player_credits < box.credit_cost:
		return {"can_learn": false, "reason": "Need %d credits" % box.credit_cost}
	for req_id in box.requires:
		if req_id not in learned_boxes:
			return {"can_learn": false, "reason": "Requires: " + req_id}
	return {"can_learn": true, "reason": ""}

static func compute_total_modifiers(learned_boxes: Array) -> Dictionary:
	var totals := get_base_stats()
	for box_id in learned_boxes:
		var box := find_box(box_id)
		if box.is_empty():
			continue
		var mods : Dictionary = box.get("modifiers", {})
		for key in mods:
			if key in totals:
				totals[key] += mods[key]
			else:
				totals[key] = mods[key]
	return totals
