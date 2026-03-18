class_name ProfessionData

# ============================================================
#  ProfessionData.gd — SWG Pre-CU Profession Tree Definitions
#  Static data: professions, disciplines, skillboxes, modifiers.
#  Each profession: Novice + 4 disciplines × 4 tiers + Master = 18 boxes
#  250 skill points total per character.
# ============================================================

# ── SKILLBOX STRUCTURE ───────────────────────────────────────
# Each box: {
#   "id": unique string,
#   "name": display name,
#   "cost_sp": skill points required,
#   "xp_type": which XP pool is spent,
#   "xp_cost": how much XP to spend,
#   "credit_cost": credits to pay trainer,
#   "requires": array of box IDs that must be learned first,
#   "modifiers": dict of stat bonuses granted,
#   "abilities": array of ability IDs unlocked (empty for most boxes),
# }

static func get_all_professions() -> Array:
	return [
		_brawler(),
		_marksman(),
		_medic(),
		_forcesensitive(),
	]

static func get_profession(prof_id: String) -> Dictionary:
	for p in get_all_professions():
		if p.id == prof_id:
			return p
	return {}

# ── BRAWLER ──────────────────────────────────────────────────
static func _brawler() -> Dictionary:
	return {
		"id": "scrapper",
		"name": "Scrapper",
		"desc": "Close-quarters combat specialist. Masters unarmed, one-handed, two-handed, and polearm weapons.",
		"novice": {
			"id": "brawler_novice", "name": "Novice Scrapper",
			"cost_sp": 15, "xp_type": "unarmed", "xp_cost": 0, "credit_cost": 0,
			"requires": [],
			"modifiers": {"accuracy": 5, "defense": 5, "unarmed_damage": 3},
			"abilities": [],
		},
		"disciplines": [
			{ "name": "Unarmed", "boxes": [
				{"id": "brawler_unarmed_01", "name": "Unarmed I", "cost_sp": 2, "xp_type": "unarmed", "xp_cost": 800, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 8, "unarmed_damage": 5}, "abilities": []},
				{"id": "brawler_unarmed_02", "name": "Unarmed II", "cost_sp": 3, "xp_type": "unarmed", "xp_cost": 2000, "credit_cost": 250, "requires": ["brawler_unarmed_01"],
				 "modifiers": {"accuracy": 10, "unarmed_damage": 8}, "abilities": ["dizzy_punch"]},
				{"id": "brawler_unarmed_03", "name": "Unarmed III", "cost_sp": 4, "xp_type": "unarmed", "xp_cost": 5000, "credit_cost": 500, "requires": ["brawler_unarmed_02"],
				 "modifiers": {"accuracy": 12, "unarmed_damage": 10}, "abilities": []},
				{"id": "brawler_unarmed_04", "name": "Unarmed IV", "cost_sp": 5, "xp_type": "unarmed", "xp_cost": 10000, "credit_cost": 1000, "requires": ["brawler_unarmed_03"],
				 "modifiers": {"accuracy": 15, "unarmed_damage": 12}, "abilities": ["knockout_blow"]},
			]},
			{ "name": "One Hand", "boxes": [
				{"id": "brawler_onehand_01", "name": "One Hand I", "cost_sp": 2, "xp_type": "onehand", "xp_cost": 800, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 8, "onehand_damage": 5}, "abilities": []},
				{"id": "brawler_onehand_02", "name": "One Hand II", "cost_sp": 3, "xp_type": "onehand", "xp_cost": 2000, "credit_cost": 250, "requires": ["brawler_onehand_01"],
				 "modifiers": {"accuracy": 10, "onehand_damage": 8, "dodge": 3}, "abilities": ["riposte"]},
				{"id": "brawler_onehand_03", "name": "One Hand III", "cost_sp": 4, "xp_type": "onehand", "xp_cost": 5000, "credit_cost": 500, "requires": ["brawler_onehand_02"],
				 "modifiers": {"accuracy": 12, "onehand_damage": 10, "dodge": 5}, "abilities": []},
				{"id": "brawler_onehand_04", "name": "One Hand IV", "cost_sp": 5, "xp_type": "onehand", "xp_cost": 10000, "credit_cost": 1000, "requires": ["brawler_onehand_03"],
				 "modifiers": {"accuracy": 15, "onehand_damage": 14, "dodge": 8}, "abilities": ["blade_flurry"]},
			]},
			{ "name": "Two Hand", "boxes": [
				{"id": "brawler_twohand_01", "name": "Two Hand I", "cost_sp": 2, "xp_type": "twohand", "xp_cost": 800, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 6, "twohand_damage": 8, "defense": 3}, "abilities": []},
				{"id": "brawler_twohand_02", "name": "Two Hand II", "cost_sp": 3, "xp_type": "twohand", "xp_cost": 2000, "credit_cost": 250, "requires": ["brawler_twohand_01"],
				 "modifiers": {"accuracy": 8, "twohand_damage": 12, "defense": 5}, "abilities": ["power_attack"]},
				{"id": "brawler_twohand_03", "name": "Two Hand III", "cost_sp": 4, "xp_type": "twohand", "xp_cost": 5000, "credit_cost": 500, "requires": ["brawler_twohand_02"],
				 "modifiers": {"accuracy": 10, "twohand_damage": 15, "defense": 8}, "abilities": []},
				{"id": "brawler_twohand_04", "name": "Two Hand IV", "cost_sp": 5, "xp_type": "twohand", "xp_cost": 10000, "credit_cost": 1000, "requires": ["brawler_twohand_03"],
				 "modifiers": {"accuracy": 12, "twohand_damage": 20, "defense": 10, "block": 5}, "abilities": ["cleave"]},
			]},
			{ "name": "Pikeman", "boxes": [
				{"id": "brawler_pike_01", "name": "Pikeman I", "cost_sp": 2, "xp_type": "twohand", "xp_cost": 800, "credit_cost": 100, "requires": ["brawler_novice"],
				 "modifiers": {"accuracy": 8, "polearm_damage": 6, "defense_vs_knockdown": 3}, "abilities": []},
				{"id": "brawler_pike_02", "name": "Pikeman II", "cost_sp": 3, "xp_type": "twohand", "xp_cost": 2000, "credit_cost": 250, "requires": ["brawler_pike_01"],
				 "modifiers": {"accuracy": 10, "polearm_damage": 10, "defense_vs_knockdown": 5}, "abilities": ["leg_sweep"]},
				{"id": "brawler_pike_03", "name": "Pikeman III", "cost_sp": 4, "xp_type": "twohand", "xp_cost": 5000, "credit_cost": 500, "requires": ["brawler_pike_02"],
				 "modifiers": {"accuracy": 12, "polearm_damage": 14, "defense_vs_knockdown": 8, "defense_vs_dizzy": 5}, "abilities": []},
				{"id": "brawler_pike_04", "name": "Pikeman IV", "cost_sp": 5, "xp_type": "twohand", "xp_cost": 10000, "credit_cost": 1000, "requires": ["brawler_pike_03"],
				 "modifiers": {"accuracy": 15, "polearm_damage": 18, "defense_vs_knockdown": 12, "defense_vs_dizzy": 8}, "abilities": ["impale"]},
			]},
		],
		"master": {
			"id": "brawler_master", "name": "Master Scrapper",
			"cost_sp": 6, "xp_type": "unarmed", "xp_cost": 20000, "credit_cost": 5000,
			"requires": ["brawler_unarmed_04", "brawler_onehand_04", "brawler_twohand_04", "brawler_pike_04"],
			"modifiers": {"accuracy": 20, "defense": 20, "unarmed_damage": 15, "dodge": 10, "block": 8},
			"abilities": ["berserk"],
			"grants_title": "Master Scrapper",
		},
	}

# ── MARKSMAN ─────────────────────────────────────────────────
static func _marksman() -> Dictionary:
	return {
		"id": "marksman",
		"name": "Marksman",
		"desc": "Ranged weapons specialist. Masters pistols, rifles, and carbines.",
		"novice": {
			"id": "marksman_novice", "name": "Novice Marksman",
			"cost_sp": 15, "xp_type": "ranged", "xp_cost": 0, "credit_cost": 0,
			"requires": [],
			"modifiers": {"accuracy": 5, "defense": 3},
			"abilities": [],
		},
		"disciplines": [
			{ "name": "Pistol", "boxes": [
				{"id": "marksman_pistol_01", "name": "Pistol I", "cost_sp": 2, "xp_type": "pistol", "xp_cost": 800, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"accuracy": 10, "pistol_damage": 5}, "abilities": []},
				{"id": "marksman_pistol_02", "name": "Pistol II", "cost_sp": 3, "xp_type": "pistol", "xp_cost": 2000, "credit_cost": 250, "requires": ["marksman_pistol_01"],
				 "modifiers": {"accuracy": 12, "pistol_damage": 8}, "abilities": ["body_shot"]},
				{"id": "marksman_pistol_03", "name": "Pistol III", "cost_sp": 4, "xp_type": "pistol", "xp_cost": 5000, "credit_cost": 500, "requires": ["marksman_pistol_02"],
				 "modifiers": {"accuracy": 15, "pistol_damage": 10}, "abilities": []},
				{"id": "marksman_pistol_04", "name": "Pistol IV", "cost_sp": 5, "xp_type": "pistol", "xp_cost": 10000, "credit_cost": 1000, "requires": ["marksman_pistol_03"],
				 "modifiers": {"accuracy": 18, "pistol_damage": 14}, "abilities": ["fan_shot"]},
			]},
			{ "name": "Rifle", "boxes": [
				{"id": "marksman_rifle_01", "name": "Rifle I", "cost_sp": 2, "xp_type": "rifle", "xp_cost": 800, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"accuracy": 10, "rifle_damage": 5}, "abilities": []},
				{"id": "marksman_rifle_02", "name": "Rifle II", "cost_sp": 3, "xp_type": "rifle", "xp_cost": 2000, "credit_cost": 250, "requires": ["marksman_rifle_01"],
				 "modifiers": {"accuracy": 12, "rifle_damage": 8}, "abilities": ["aimed_shot"]},
				{"id": "marksman_rifle_03", "name": "Rifle III", "cost_sp": 4, "xp_type": "rifle", "xp_cost": 5000, "credit_cost": 500, "requires": ["marksman_rifle_02"],
				 "modifiers": {"accuracy": 15, "rifle_damage": 12}, "abilities": []},
				{"id": "marksman_rifle_04", "name": "Rifle IV", "cost_sp": 5, "xp_type": "rifle", "xp_cost": 10000, "credit_cost": 1000, "requires": ["marksman_rifle_03"],
				 "modifiers": {"accuracy": 20, "rifle_damage": 16}, "abilities": ["headshot"]},
			]},
			{ "name": "Carbine", "boxes": [
				{"id": "marksman_carbine_01", "name": "Carbine I", "cost_sp": 2, "xp_type": "carbine", "xp_cost": 800, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"accuracy": 8, "carbine_damage": 5}, "abilities": []},
				{"id": "marksman_carbine_02", "name": "Carbine II", "cost_sp": 3, "xp_type": "carbine", "xp_cost": 2000, "credit_cost": 250, "requires": ["marksman_carbine_01"],
				 "modifiers": {"accuracy": 10, "carbine_damage": 8}, "abilities": ["scatter_shot"]},
				{"id": "marksman_carbine_03", "name": "Carbine III", "cost_sp": 4, "xp_type": "carbine", "xp_cost": 5000, "credit_cost": 500, "requires": ["marksman_carbine_02"],
				 "modifiers": {"accuracy": 12, "carbine_damage": 10}, "abilities": []},
				{"id": "marksman_carbine_04", "name": "Carbine IV", "cost_sp": 5, "xp_type": "carbine", "xp_cost": 10000, "credit_cost": 1000, "requires": ["marksman_carbine_03"],
				 "modifiers": {"accuracy": 15, "carbine_damage": 14}, "abilities": ["rapid_fire"]},
			]},
			{ "name": "Ranged Support", "boxes": [
				{"id": "marksman_support_01", "name": "Ranged Support I", "cost_sp": 2, "xp_type": "ranged", "xp_cost": 800, "credit_cost": 100, "requires": ["marksman_novice"],
				 "modifiers": {"defense": 8, "dodge": 3}, "abilities": []},
				{"id": "marksman_support_02", "name": "Ranged Support II", "cost_sp": 3, "xp_type": "ranged", "xp_cost": 2000, "credit_cost": 250, "requires": ["marksman_support_01"],
				 "modifiers": {"defense": 10, "dodge": 5}, "abilities": ["leg_shot"]},
				{"id": "marksman_support_03", "name": "Ranged Support III", "cost_sp": 4, "xp_type": "ranged", "xp_cost": 5000, "credit_cost": 500, "requires": ["marksman_support_02"],
				 "modifiers": {"defense": 12, "dodge": 8, "defense_vs_blind": 5}, "abilities": []},
				{"id": "marksman_support_04", "name": "Ranged Support IV", "cost_sp": 5, "xp_type": "ranged", "xp_cost": 10000, "credit_cost": 1000, "requires": ["marksman_support_03"],
				 "modifiers": {"defense": 15, "dodge": 12, "defense_vs_blind": 10}, "abilities": ["flash_grenade"]},
			]},
		],
		"master": {
			"id": "marksman_master", "name": "Master Marksman",
			"cost_sp": 6, "xp_type": "ranged", "xp_cost": 20000, "credit_cost": 5000,
			"requires": ["marksman_pistol_04", "marksman_rifle_04", "marksman_carbine_04", "marksman_support_04"],
			"modifiers": {"accuracy": 25, "defense": 15, "dodge": 10},
			"abilities": ["called_shot"],
			"grants_title": "Master Marksman",
		},
	}

# ── MEDIC ────────────────────────────────────────────────────
static func _medic() -> Dictionary:
	return {
		"id": "medic",
		"name": "Medic",
		"desc": "Battlefield healer and pharmaceutical expert. Heals wounds and crafts stimpaks.",
		"novice": {
			"id": "medic_novice", "name": "Novice Medic",
			"cost_sp": 15, "xp_type": "medical", "xp_cost": 0, "credit_cost": 0,
			"requires": [],
			"modifiers": {"accuracy": 3, "defense": 5, "heal_potency": 5},
			"abilities": [],
		},
		"disciplines": [
			{ "name": "First Aid", "boxes": [
				{"id": "medic_firstaid_01", "name": "First Aid I", "cost_sp": 2, "xp_type": "medical", "xp_cost": 800, "credit_cost": 100, "requires": ["medic_novice"],
				 "modifiers": {"heal_potency": 8}, "abilities": ["stim_health"]},
				{"id": "medic_firstaid_02", "name": "First Aid II", "cost_sp": 3, "xp_type": "medical", "xp_cost": 2000, "credit_cost": 250, "requires": ["medic_firstaid_01"],
				 "modifiers": {"heal_potency": 12}, "abilities": ["stim_action"]},
				{"id": "medic_firstaid_03", "name": "First Aid III", "cost_sp": 4, "xp_type": "medical", "xp_cost": 5000, "credit_cost": 500, "requires": ["medic_firstaid_02"],
				 "modifiers": {"heal_potency": 16}, "abilities": ["stim_mind"]},
				{"id": "medic_firstaid_04", "name": "First Aid IV", "cost_sp": 5, "xp_type": "medical", "xp_cost": 10000, "credit_cost": 1000, "requires": ["medic_firstaid_03"],
				 "modifiers": {"heal_potency": 20}, "abilities": ["bacta_infusion"]},
			]},
			{ "name": "Pharmacology", "boxes": [
				{"id": "medic_pharma_01", "name": "Pharmacology I", "cost_sp": 2, "xp_type": "medical", "xp_cost": 800, "credit_cost": 100, "requires": ["medic_novice"],
				 "modifiers": {"defense": 5, "resist_acid": 5}, "abilities": []},
				{"id": "medic_pharma_02", "name": "Pharmacology II", "cost_sp": 3, "xp_type": "medical", "xp_cost": 2000, "credit_cost": 250, "requires": ["medic_pharma_01"],
				 "modifiers": {"defense": 8, "resist_acid": 8}, "abilities": ["poison_dart"]},
				{"id": "medic_pharma_03", "name": "Pharmacology III", "cost_sp": 4, "xp_type": "medical", "xp_cost": 5000, "credit_cost": 500, "requires": ["medic_pharma_02"],
				 "modifiers": {"defense": 10, "resist_acid": 10}, "abilities": []},
				{"id": "medic_pharma_04", "name": "Pharmacology IV", "cost_sp": 5, "xp_type": "medical", "xp_cost": 10000, "credit_cost": 1000, "requires": ["medic_pharma_03"],
				 "modifiers": {"defense": 12, "resist_acid": 15}, "abilities": ["neurotoxin"]},
			]},
			{ "name": "Organic Chemistry", "boxes": [
				{"id": "medic_orgchem_01", "name": "Organic Chemistry I", "cost_sp": 2, "xp_type": "medical", "xp_cost": 800, "credit_cost": 100, "requires": ["medic_novice"],
				 "modifiers": {"heal_potency": 5, "defense_vs_dizzy": 5}, "abilities": []},
				{"id": "medic_orgchem_02", "name": "Organic Chemistry II", "cost_sp": 3, "xp_type": "medical", "xp_cost": 2000, "credit_cost": 250, "requires": ["medic_orgchem_01"],
				 "modifiers": {"heal_potency": 8, "defense_vs_dizzy": 8}, "abilities": []},
				{"id": "medic_orgchem_03", "name": "Organic Chemistry III", "cost_sp": 4, "xp_type": "medical", "xp_cost": 5000, "credit_cost": 500, "requires": ["medic_orgchem_02"],
				 "modifiers": {"heal_potency": 12, "defense_vs_dizzy": 10}, "abilities": ["cure_state"]},
				{"id": "medic_orgchem_04", "name": "Organic Chemistry IV", "cost_sp": 5, "xp_type": "medical", "xp_cost": 10000, "credit_cost": 1000, "requires": ["medic_orgchem_03"],
				 "modifiers": {"heal_potency": 15, "defense_vs_dizzy": 15}, "abilities": []},
			]},
			{ "name": "Diagnose", "boxes": [
				{"id": "medic_diagnose_01", "name": "Diagnose I", "cost_sp": 2, "xp_type": "medical", "xp_cost": 800, "credit_cost": 100, "requires": ["medic_novice"],
				 "modifiers": {"defense": 8, "defense_vs_stun": 5}, "abilities": []},
				{"id": "medic_diagnose_02", "name": "Diagnose II", "cost_sp": 3, "xp_type": "medical", "xp_cost": 2000, "credit_cost": 250, "requires": ["medic_diagnose_01"],
				 "modifiers": {"defense": 10, "defense_vs_stun": 8}, "abilities": []},
				{"id": "medic_diagnose_03", "name": "Diagnose III", "cost_sp": 4, "xp_type": "medical", "xp_cost": 5000, "credit_cost": 500, "requires": ["medic_diagnose_02"],
				 "modifiers": {"defense": 12, "defense_vs_stun": 12}, "abilities": ["revive"]},
				{"id": "medic_diagnose_04", "name": "Diagnose IV", "cost_sp": 5, "xp_type": "medical", "xp_cost": 10000, "credit_cost": 1000, "requires": ["medic_diagnose_03"],
				 "modifiers": {"defense": 15, "defense_vs_stun": 15}, "abilities": []},
			]},
		],
		"master": {
			"id": "medic_master", "name": "Master Medic",
			"cost_sp": 6, "xp_type": "medical", "xp_cost": 20000, "credit_cost": 5000,
			"requires": ["medic_firstaid_04", "medic_pharma_04", "medic_orgchem_04", "medic_diagnose_04"],
			"modifiers": {"defense": 20, "heal_potency": 25, "defense_vs_stun": 10, "defense_vs_dizzy": 10},
			"abilities": ["full_heal"],
			"grants_title": "Master Medic",
		},
	}

# ── FORCE SENSITIVE (Mage equivalent) ────────────────────────
static func _forcesensitive() -> Dictionary:
	return {
		"id": "forcesensitive",
		"name": "Force Sensitive",
		"desc": "Attuned to the Force. Wields devastating mental attacks and defensive barriers.",
		"novice": {
			"id": "force_novice", "name": "Force Initiate",
			"cost_sp": 15, "xp_type": "force", "xp_cost": 0, "credit_cost": 0,
			"requires": [],
			"modifiers": {"accuracy": 5, "defense": 3, "force_damage": 3},
			"abilities": [],
		},
		"disciplines": [
			{ "name": "Force Powers", "boxes": [
				{"id": "force_powers_01", "name": "Force Powers I", "cost_sp": 2, "xp_type": "force", "xp_cost": 800, "credit_cost": 100, "requires": ["force_novice"],
				 "modifiers": {"accuracy": 8, "force_damage": 5}, "abilities": []},
				{"id": "force_powers_02", "name": "Force Powers II", "cost_sp": 3, "xp_type": "force", "xp_cost": 2000, "credit_cost": 250, "requires": ["force_powers_01"],
				 "modifiers": {"accuracy": 12, "force_damage": 10}, "abilities": ["force_lightning"]},
				{"id": "force_powers_03", "name": "Force Powers III", "cost_sp": 4, "xp_type": "force", "xp_cost": 5000, "credit_cost": 500, "requires": ["force_powers_02"],
				 "modifiers": {"accuracy": 15, "force_damage": 14}, "abilities": []},
				{"id": "force_powers_04", "name": "Force Powers IV", "cost_sp": 5, "xp_type": "force", "xp_cost": 10000, "credit_cost": 1000, "requires": ["force_powers_03"],
				 "modifiers": {"accuracy": 20, "force_damage": 18}, "abilities": ["force_choke"]},
			]},
			{ "name": "Force Defense", "boxes": [
				{"id": "force_defense_01", "name": "Force Defense I", "cost_sp": 2, "xp_type": "force", "xp_cost": 800, "credit_cost": 100, "requires": ["force_novice"],
				 "modifiers": {"defense": 8, "resist_energy": 5}, "abilities": []},
				{"id": "force_defense_02", "name": "Force Defense II", "cost_sp": 3, "xp_type": "force", "xp_cost": 2000, "credit_cost": 250, "requires": ["force_defense_01"],
				 "modifiers": {"defense": 12, "resist_energy": 8}, "abilities": ["force_shield"]},
				{"id": "force_defense_03", "name": "Force Defense III", "cost_sp": 4, "xp_type": "force", "xp_cost": 5000, "credit_cost": 500, "requires": ["force_defense_02"],
				 "modifiers": {"defense": 15, "resist_energy": 12, "resist_kinetic": 5}, "abilities": []},
				{"id": "force_defense_04", "name": "Force Defense IV", "cost_sp": 5, "xp_type": "force", "xp_cost": 10000, "credit_cost": 1000, "requires": ["force_defense_03"],
				 "modifiers": {"defense": 20, "resist_energy": 16, "resist_kinetic": 10}, "abilities": ["force_absorb"]},
			]},
			{ "name": "Force Healing", "boxes": [
				{"id": "force_healing_01", "name": "Force Healing I", "cost_sp": 2, "xp_type": "force", "xp_cost": 800, "credit_cost": 100, "requires": ["force_novice"],
				 "modifiers": {"heal_potency": 5, "defense_vs_blind": 5}, "abilities": []},
				{"id": "force_healing_02", "name": "Force Healing II", "cost_sp": 3, "xp_type": "force", "xp_cost": 2000, "credit_cost": 250, "requires": ["force_healing_01"],
				 "modifiers": {"heal_potency": 10, "defense_vs_blind": 8}, "abilities": ["force_heal"]},
				{"id": "force_healing_03", "name": "Force Healing III", "cost_sp": 4, "xp_type": "force", "xp_cost": 5000, "credit_cost": 500, "requires": ["force_healing_02"],
				 "modifiers": {"heal_potency": 14, "defense_vs_blind": 12}, "abilities": []},
				{"id": "force_healing_04", "name": "Force Healing IV", "cost_sp": 5, "xp_type": "force", "xp_cost": 10000, "credit_cost": 1000, "requires": ["force_healing_03"],
				 "modifiers": {"heal_potency": 18, "defense_vs_blind": 15}, "abilities": ["force_revive"]},
			]},
			{ "name": "Lightsaber", "boxes": [
				{"id": "force_saber_01", "name": "Lightsaber I", "cost_sp": 2, "xp_type": "force", "xp_cost": 800, "credit_cost": 100, "requires": ["force_novice"],
				 "modifiers": {"accuracy": 8, "block": 5}, "abilities": []},
				{"id": "force_saber_02", "name": "Lightsaber II", "cost_sp": 3, "xp_type": "force", "xp_cost": 2000, "credit_cost": 250, "requires": ["force_saber_01"],
				 "modifiers": {"accuracy": 12, "block": 8}, "abilities": ["saber_throw"]},
				{"id": "force_saber_03", "name": "Lightsaber III", "cost_sp": 4, "xp_type": "force", "xp_cost": 5000, "credit_cost": 500, "requires": ["force_saber_02"],
				 "modifiers": {"accuracy": 15, "block": 12, "counterattack": 5}, "abilities": []},
				{"id": "force_saber_04", "name": "Lightsaber IV", "cost_sp": 5, "xp_type": "force", "xp_cost": 10000, "credit_cost": 1000, "requires": ["force_saber_03"],
				 "modifiers": {"accuracy": 20, "block": 16, "counterattack": 10}, "abilities": ["saber_flurry"]},
			]},
		],
		"master": {
			"id": "force_master", "name": "Force Adept",
			"cost_sp": 6, "xp_type": "force", "xp_cost": 20000, "credit_cost": 5000,
			"requires": ["force_powers_04", "force_defense_04", "force_healing_04", "force_saber_04"],
			"modifiers": {"accuracy": 25, "defense": 25, "force_damage": 20, "block": 10},
			"abilities": ["mind_trick"],
			"grants_title": "Force Adept",
		},
	}

# ── UTILITY: Get all boxes from a profession ─────────────────
static func get_all_boxes(prof: Dictionary) -> Array:
	var boxes = [prof.novice]
	for disc in prof.disciplines:
		for box in disc.boxes:
			boxes.append(box)
	boxes.append(prof.master)
	return boxes

# ── UTILITY: Find a box by ID across all professions ─────────
static func find_box(box_id: String) -> Dictionary:
	for prof in get_all_professions():
		for box in get_all_boxes(prof):
			if box.id == box_id:
				return box
	return {}

# ── UTILITY: Check if a box can be learned ───────────────────
static func can_learn_box(box: Dictionary, learned_boxes: Array, xp_pools: Dictionary, skill_points_available: int, player_credits: int) -> Dictionary:
	# Returns {"can_learn": bool, "reason": String}
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
