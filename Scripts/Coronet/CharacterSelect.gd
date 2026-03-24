extends Node2D

## Character Select Screen for Coronet 3D scene.
## Shows 4 character choices. Selected character is stored in a global
## so CoronetPlayer.gd knows which one to spawn.

# Character definitions
const CHARACTERS := {
	"RedArmor": {
		"display_name": "Red Armor",
		"description": "Heavy ranged specialist.\nEquipped with a sci-fi pistol.\nShoots from range with devastating firepower.",
		"class": "ranged",
		"color": Color(0.85, 0.25, 0.15),
		"idle_fbx": "res://Coronet/Redarmor/idle/Meshy_AI_Ember_Guard_biped/Meshy_AI_Ember_Guard_biped_Animation_Idle_11_withSkin.fbx",
	},
	"SilverArmor": {
		"display_name": "Silver Armor",
		"description": "Melee tank with stun baton.\nCloses distance and strikes hard.\nHigh defense, devastating combos.",
		"class": "melee",
		"color": Color(0.75, 0.78, 0.82),
		"idle_fbx": "res://Coronet/silverarmor/idle/Meshy_AI_Iron_Sentinel_biped_Animation_Idle_frame_rate_60.fbx",
	},
	"RedSoldier": {
		"display_name": "Red Soldier",
		"description": "Quick-draw ranged gunslinger.\nWalks into position, sprints to safety.\nFast shooting, cowboy style.",
		"class": "ranged",
		"color": Color(0.9, 0.3, 0.2),
		"idle_fbx": "res://Coronet/redsoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Idle_11_frame_rate_60.fbx",
	},
	"WhiteSoldier": {
		"display_name": "White Soldier",
		"description": "Sword-wielding melee fighter.\nWalks with purpose, sprints to engage.\nPrecise slashes and weapon combos.",
		"class": "melee",
		"color": Color(0.9, 0.92, 0.95),
		"idle_fbx": "res://Coronet/whitesoldier/Meshy_AI_Azure_Sentinel_biped_Animation_Idle_11_frame_rate_60.fbx",
	},
}

var _canvas : CanvasLayer
var _selected : String = ""
var _char_buttons := {}
var _desc_label : RichTextLabel
var _play_btn : Button
var _title_lbl : Label
var _preview_3d : SubViewport
var _preview_container : SubViewportContainer

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)
	var vp := get_viewport().get_visible_rect().size

	# Dark background
	var bg := ColorRect.new()
	bg.size = vp
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	_canvas.add_child(bg)

	# Title
	_title_lbl = Label.new()
	_title_lbl.text = "SELECT YOUR CHARACTER"
	_title_lbl.add_theme_font_size_override("font_size", 32)
	_title_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.position = Vector2(0, 40)
	_title_lbl.size = Vector2(vp.x, 50)
	_canvas.add_child(_title_lbl)

	# Subtitle
	var sub := Label.new()
	sub.text = "Coronet City — Terminus Station"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 80)
	sub.size = Vector2(vp.x, 30)
	_canvas.add_child(sub)

	# Character cards — 4 across
	var card_w := 200.0
	var card_h := 260.0
	var gap := 30.0
	var total_w := card_w * 4.0 + gap * 3.0
	var start_x := (vp.x - total_w) * 0.5
	var card_y := 130.0

	var idx := 0
	for char_id in CHARACTERS:
		var char_data : Dictionary = CHARACTERS[char_id]
		var card := _make_card(char_id, char_data, Vector2(start_x + idx * (card_w + gap), card_y), Vector2(card_w, card_h))
		_canvas.add_child(card)
		idx += 1

	# Description panel
	var desc_panel := Panel.new()
	desc_panel.position = Vector2(start_x, card_y + card_h + 20)
	desc_panel.size = Vector2(total_w, 120)
	var desc_sb := StyleBoxFlat.new()
	desc_sb.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	desc_sb.border_color = Color(0.3, 0.3, 0.35)
	desc_sb.set_border_width_all(1)
	desc_sb.set_corner_radius_all(4)
	desc_panel.add_theme_stylebox_override("panel", desc_sb)
	_canvas.add_child(desc_panel)

	_desc_label = RichTextLabel.new()
	_desc_label.position = Vector2(15, 10)
	_desc_label.size = Vector2(total_w - 30, 100)
	_desc_label.bbcode_enabled = true
	_desc_label.add_theme_font_size_override("normal_font_size", 14)
	_desc_label.add_theme_color_override("default_color", Color(0.7, 0.72, 0.75))
	_desc_label.text = "[center]Choose a character to begin your journey.[/center]"
	desc_panel.add_child(_desc_label)

	# Play button
	_play_btn = Button.new()
	_play_btn.text = "ENTER CORONET"
	_play_btn.position = Vector2((vp.x - 220) * 0.5, card_y + card_h + 160)
	_play_btn.size = Vector2(220, 50)
	_play_btn.add_theme_font_size_override("font_size", 18)
	_play_btn.disabled = true
	_play_btn.pressed.connect(_on_play)
	_canvas.add_child(_play_btn)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(20, vp.y - 60)
	back_btn.size = Vector2(100, 40)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/start_screen.tscn"))
	_canvas.add_child(back_btn)

func _make_card(char_id : String, data : Dictionary, pos : Vector2, sz : Vector2) -> Panel:
	var card := Panel.new()
	card.position = pos
	card.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.14, 0.95)
	sb.border_color = Color(0.25, 0.25, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", sb)

	# Color accent bar at top
	var accent := ColorRect.new()
	accent.position = Vector2(0, 0)
	accent.size = Vector2(sz.x, 4)
	accent.color = data["color"]
	card.add_child(accent)

	# Character name
	var name_lbl := Label.new()
	name_lbl.text = data["display_name"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", data["color"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 15)
	name_lbl.size = Vector2(sz.x, 30)
	card.add_child(name_lbl)

	# Class label
	var class_lbl := Label.new()
	class_lbl.text = data["class"].to_upper()
	class_lbl.add_theme_font_size_override("font_size", 11)
	class_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.position = Vector2(0, 42)
	class_lbl.size = Vector2(sz.x, 20)
	card.add_child(class_lbl)

	# Placeholder silhouette area
	var silhouette := ColorRect.new()
	silhouette.position = Vector2(30, 70)
	silhouette.size = Vector2(sz.x - 60, 120)
	silhouette.color = Color(0.15, 0.16, 0.2, 0.5)
	card.add_child(silhouette)

	# Icon text (first letter)
	var icon := Label.new()
	icon.text = data["display_name"].substr(0, 1)
	icon.add_theme_font_size_override("font_size", 64)
	icon.add_theme_color_override("font_color", Color(data["color"].r, data["color"].g, data["color"].b, 0.3))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.position = Vector2(30, 85)
	icon.size = Vector2(sz.x - 60, 100)
	card.add_child(icon)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.position = Vector2(20, sz.y - 50)
	btn.size = Vector2(sz.x - 40, 36)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_select.bind(char_id, card))
	card.add_child(btn)

	_char_buttons[char_id] = {"card": card, "btn": btn, "sb": sb}
	return card

func _on_select(char_id : String, _card : Panel) -> void:
	_selected = char_id
	_play_btn.disabled = false
	var data : Dictionary = CHARACTERS[char_id]

	# Update description
	_desc_label.text = "[b][color=#" + data["color"].to_html(false) + "]" + data["display_name"] + "[/color][/b]\n" + data["description"]

	# Highlight selected card, dim others
	for cid in _char_buttons:
		var info : Dictionary = _char_buttons[cid]
		var sb : StyleBoxFlat = info["sb"]
		if cid == char_id:
			sb.border_color = data["color"]
			sb.set_border_width_all(3)
		else:
			sb.border_color = Color(0.25, 0.25, 0.3)
			sb.set_border_width_all(2)

func _on_play() -> void:
	if _selected.is_empty():
		return
	# Store selection globally so CoronetPlayer can read it
	# Using a meta on the tree root
	get_tree().root.set_meta("selected_character", _selected)
	get_tree().change_scene_to_file("res://Scenes/Coronet.tscn")
