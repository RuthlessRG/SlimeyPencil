extends RefCounted
class_name ItemData

# ============================================================
#  ItemData.gd — Central item definitions
#  Each item is a Dictionary with: id, name, slot, mesh_path,
#  icon_color, stats (damage_min, damage_max, attack_speed, etc.)
# ============================================================

enum Slot { NONE, RIGHT_HAND, LEFT_HAND, HEAD, CHEST, LEGS, FEET }

static var ITEMS : Dictionary = {
	"novice_baton": {
		"id":          "novice_baton",
		"name":        "Novice Baton",
		"slot":        Slot.RIGHT_HAND,
		"mesh_path":   "res://Coronet/Character/weapons/melee/baton/novicebatonsmaller.fbx",
		"icon_color":  Color(0.7, 0.7, 0.8),
		"xp_type":     "melee",
		"stats": {
			"damage_min":   10.0,
			"damage_max":   20.0,
			"attack_speed": 3.0,
		},
		"description": "A basic melee weapon for novice street fighters.",
	},
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func create_instance(item_id: String) -> Dictionary:
	var template := get_item(item_id)
	if template.is_empty():
		return {}
	var inst := template.duplicate(true)
	inst["equipped"] = false
	return inst
