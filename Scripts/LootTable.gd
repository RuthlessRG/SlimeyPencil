class_name LootTable
extends Node

# ============================================================
#  LootTable.gd — Static item database + mob drop tables
#  Usage: LootTable.roll_drop("armored_thug")
#         returns an item dict or {} if no drop
# ============================================================

# ── ITEM DATABASE ────────────────────────────────────────────
const ITEMS : Dictionary = {
	# ── ARMOR ─────────────────────────────────────────────────
	"armor_tattered_vest": {
		"id": "armor_tattered_vest", "name": "Tattered Vest", "rarity": "white",
		"type": "armor", "cost": 60,
		"attr_str": 1, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 3,
		"resist_kinetic": 8, "resist_energy": 0,
		"desc": "Worn chest armour.\n+3 Defense  +8 Kinetic resist",
	},
	"armor_composite": {
		"id": "armor_composite", "name": "Composite Armor", "rarity": "blue",
		"type": "armor", "cost": 450,
		"attr_str": 3, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 12,
		"resist_kinetic": 22, "resist_energy": 15,
		"desc": "Solid composite plating.\n+12 Defense  +22 Kinetic  +15 Energy",
	},
	"armor_battle_plate": {
		"id": "armor_battle_plate", "name": "Battle Plate", "rarity": "gold",
		"type": "armor", "cost": 1400,
		"attr_str": 6, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 22,
		"resist_kinetic": 38, "resist_energy": 28,
		"desc": "Heavy battle-forged plate.\n+22 Defense  +38 Kinetic  +28 Energy",
	},
	# ── MELEE WEAPONS ──────────────────────────────────────────
	"weapon_vibroknife": {
		"id": "weapon_vibroknife", "name": "Vibroknife", "rarity": "white",
		"type": "weapon", "cost": 160,
		"attr_str": 1, "attr_agi": 1, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 6, "defense": 0,
		"resist_kinetic": 0, "resist_energy": 0,
		"desc": "High-frequency blade.\n+6 Damage  +1 STR  +1 AGI",
	},
	"weapon_vibrolance": {
		"id": "weapon_vibrolance", "name": "Vibrolance", "rarity": "blue",
		"type": "weapon", "cost": 650,
		"attr_str": 4, "attr_agi": 1, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 16, "defense": 0,
		"resist_kinetic": 0, "resist_energy": 0,
		"desc": "Powered shock lance.\n+16 Damage  +4 STR  +1 AGI",
	},
	"weapon_plasma_lance": {
		"id": "weapon_plasma_lance", "name": "Plasma Lance", "rarity": "gold",
		"type": "weapon", "cost": 2200,
		"attr_str": 5, "attr_agi": 2, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 30, "defense": 0,
		"resist_kinetic": 0, "resist_energy": 0,
		"desc": "Plasma-core lance.\n+30 Damage  +5 STR  +2 AGI",
	},
	# ── RANGED WEAPONS ─────────────────────────────────────────
	"weapon_scatter_pistol": {
		"id": "weapon_scatter_pistol", "name": "Scatter Pistol", "rarity": "white",
		"type": "weapon", "cost": 200,
		"attr_str": 0, "attr_agi": 2, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 5, "defense": 0,
		"resist_kinetic": 0, "resist_energy": 0,
		"desc": "Wide-spread pistol.\n+5 Damage  +2 AGI",
	},
	"weapon_precision_rifle": {
		"id": "weapon_precision_rifle", "name": "Precision Rifle", "rarity": "blue",
		"type": "weapon", "cost": 720,
		"attr_str": 0, "attr_agi": 4, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 18, "defense": 0,
		"resist_kinetic": 0, "resist_energy": 0,
		"desc": "High-accuracy rifle.\n+18 Damage  +4 AGI",
	},
	"weapon_void_carbine": {
		"id": "weapon_void_carbine", "name": "Void Carbine", "rarity": "gold",
		"type": "weapon", "cost": 2500,
		"attr_str": 1, "attr_agi": 6, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 32, "defense": 0,
		"resist_kinetic": 0, "resist_energy": 0,
		"desc": "Void-infused energy carbine.\n+32 Damage  +6 AGI  +1 STR",
	},
}

# ── DROP TABLES ─────────────────────────────────────────────
# Each table entry: { "id": item_id, "weight": int }
# Higher weight = more common

const DROP_TABLES : Dictionary = {
	"zergling": [
		{"id": "weapon_vibroknife",    "weight": 3},
		{"id": "armor_tattered_vest",  "weight": 4},
	],
	"mob": [
		{"id": "armor_tattered_vest",  "weight": 6},
		{"id": "weapon_vibroknife",    "weight": 5},
		{"id": "weapon_scatter_pistol","weight": 4},
	],
	"armored_thug": [
		{"id": "armor_tattered_vest",  "weight": 8},
		{"id": "weapon_vibroknife",    "weight": 7},
		{"id": "weapon_scatter_pistol","weight": 6},
		{"id": "armor_composite",      "weight": 2},
	],
	"boss_weak": [
		{"id": "armor_composite",       "weight": 9},
		{"id": "weapon_vibrolance",     "weight": 8},
		{"id": "weapon_precision_rifle","weight": 7},
		{"id": "armor_battle_plate",    "weight": 2},
		{"id": "weapon_plasma_lance",   "weight": 1},
		{"id": "weapon_void_carbine",   "weight": 1},
	],
	"boss_mid": [
		{"id": "armor_composite",       "weight": 6},
		{"id": "weapon_vibrolance",     "weight": 6},
		{"id": "weapon_precision_rifle","weight": 6},
		{"id": "armor_battle_plate",    "weight": 4},
		{"id": "weapon_plasma_lance",   "weight": 3},
		{"id": "weapon_void_carbine",   "weight": 3},
	],
	"boss_strong": [
		{"id": "armor_composite",       "weight": 4},
		{"id": "weapon_vibrolance",     "weight": 3},
		{"id": "armor_battle_plate",    "weight": 6},
		{"id": "weapon_plasma_lance",   "weight": 5},
		{"id": "weapon_void_carbine",   "weight": 5},
		{"id": "weapon_precision_rifle","weight": 4},
	],
}

# Drop chance per mob type (0.0 – 1.0)
const DROP_CHANCE : Dictionary = {
	"zergling":     0.05,
	"mob":          0.10,
	"armored_thug": 0.22,
	"boss_weak":    0.45,
	"boss_mid":     0.55,
	"boss_strong":  0.65,
}

# ── PUBLIC API ───────────────────────────────────────────────
# Returns a copy of an item dict, or {} if no drop this kill.
static func roll_drop(mob_type: String) -> Dictionary:
	var chance = DROP_CHANCE.get(mob_type, 0.0)
	if randf() > chance:
		return {}
	var table : Array = DROP_TABLES.get(mob_type, [])
	if table.is_empty():
		return {}
	# Weighted pick
	var total = 0
	for entry in table:
		total += entry.get("weight", 1)
	var roll = randi_range(1, total)
	var accum = 0
	for entry in table:
		accum += entry.get("weight", 1)
		if roll <= accum:
			var item_id : String = entry.get("id", "")
			if ITEMS.has(item_id):
				return ITEMS[item_id].duplicate()
			return {}
	return {}

# Returns the rarity colour for UI (white/blue/gold)
static func rarity_color(rarity: String) -> Color:
	match rarity:
		"blue": return Color(0.40, 0.72, 1.00)
		"gold": return Color(1.00, 0.82, 0.15)
	return Color(0.88, 0.88, 0.88)  # white
