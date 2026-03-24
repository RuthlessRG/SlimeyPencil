extends Node

# ═══════════════════════════════════════════════════════════════════════
#  PlayerData.gd — Autoload Singleton
#  Authentication and multi-character persistence via Nakama + PostgreSQL.
#
#  Flow:
#    1. StartScreen awaits login() or register()
#    2. On success → Relay.init_socket() is called automatically
#    3. Characters stored as array in Nakama Storage (up to 3 per account)
#    4. On scene exit / mission complete → save_character(player)
# ═══════════════════════════════════════════════════════════════════════

const STORAGE_COLLECTION : String = "player"
const STORAGE_KEY_CHARS  : String = "characters"
const MAX_CHARACTERS     : int    = 3
const EMAIL_DOMAIN       : String = "@miniswg.game"

# ── Session ────────────────────────────────────────────────────────
var username     : String = ""
var is_logged_in : bool   = false
var last_error   : String = ""

# ── Character slots ────────────────────────────────────────────────
var characters       : Array = []
var active_char_index : int  = -1

# ── Active character shortcuts (gameplay code reads these) ─────────
var nickname     : String = ""
var profession   : String = ""
var skin         : String = ""
var char_class   : String = ""
var credits      : int    = 0
var level        : int    = 1
var exp_points   : float  = 0.0

# ── Auth ───────────────────────────────────────────────────────────

func login(uname: String, password: String) -> bool:
	last_error = ""
	var client : NakamaClient = Relay.get_client()
	if client == null:
		last_error = "Not connected to server."
		return false
	var email   = uname.to_lower().strip_edges() + EMAIL_DOMAIN
	var session : NakamaSession = await client.authenticate_email_async(
		email, password, uname, false
	)
	if session.is_exception():
		var msg : String = session.get_exception().message
		print("[PlayerData] login error: ", msg)
		if "credentials" in msg.to_lower() or "401" in msg:
			last_error = "Wrong username or password."
		elif "connect" in msg.to_lower() or "refused" in msg.to_lower():
			last_error = "Cannot reach server. Is it running?"
		else:
			last_error = "Login failed: " + msg
		return false
	await _apply_session(uname, session)
	return true

func register(uname: String, password: String) -> bool:
	last_error = ""
	var client : NakamaClient = Relay.get_client()
	if client == null:
		last_error = "Not connected to server."
		return false
	var email   = uname.to_lower().strip_edges() + EMAIL_DOMAIN
	var session : NakamaSession = await client.authenticate_email_async(
		email, password, uname, true
	)
	if session.is_exception():
		var msg : String = session.get_exception().message
		print("[PlayerData] register error: ", msg)
		if "username" in msg.to_lower() or "already" in msg.to_lower() or "409" in msg:
			last_error = "Username already taken."
		elif "connect" in msg.to_lower() or "refused" in msg.to_lower():
			last_error = "Cannot reach server. Is it running?"
		elif "password" in msg.to_lower():
			last_error = "Password too weak."
		else:
			last_error = "Registration failed: " + msg
		return false
	await _apply_session(uname, session)
	return true

func account_exists(_uname: String) -> bool:
	return false

func _apply_session(uname: String, session: NakamaSession) -> void:
	username     = uname.strip_edges()
	is_logged_in = true
	Relay.nickname = username
	await Relay.init_socket(session)
	await _load_characters(session)

# ── Character Management ───────────────────────────────────────────

func _load_characters(session: NakamaSession) -> void:
	var client : NakamaClient = Relay.get_client()
	# Try new multi-character key first
	var result = await client.read_storage_objects_async(session, [
		NakamaStorageObjectId.new(STORAGE_COLLECTION, STORAGE_KEY_CHARS, session.user_id)
	])
	if not result.is_exception() and not result.objects.is_empty():
		var data = JSON.parse_string(result.objects[0].value)
		if data is Array:
			characters = data
			return
	# Migration: check old single-character key
	var old_result = await client.read_storage_objects_async(session, [
		NakamaStorageObjectId.new(STORAGE_COLLECTION, "character", session.user_id)
	])
	if not old_result.is_exception() and not old_result.objects.is_empty():
		var old_data = JSON.parse_string(old_result.objects[0].value)
		if old_data is Dictionary:
			# Migrate old character to new format
			old_data["nickname"] = username
			old_data["profession"] = "streetfighter" if old_data.get("char_class", "") == "melee" else "gunslinger"
			old_data["skin"] = "Silverium"
			characters = [old_data]
			await _save_characters()
			return
	characters = []

func _save_characters() -> void:
	if not is_logged_in:
		return
	var session : NakamaSession = Relay.get_session()
	if session == null:
		return
	var client : NakamaClient = Relay.get_client()
	await client.write_storage_objects_async(session, [
		NakamaWriteStorageObject.new(
			STORAGE_COLLECTION,
			STORAGE_KEY_CHARS,
			2, 1,
			JSON.stringify(characters),
			""
		)
	])

func create_character(nick: String, prof: String, skin_id: String) -> bool:
	if characters.size() >= MAX_CHARACTERS:
		last_error = "Maximum characters reached (3)."
		return false
	for c in characters:
		if c.get("nickname", "").to_lower() == nick.to_lower():
			last_error = "You already have a character with that name."
			return false
	var cls = "melee" if prof == "streetfighter" else "ranged"
	var new_char := {
		"nickname": nick,
		"profession": prof,
		"skin": skin_id,
		"char_class": cls,
		"credits": 0,
		"level": 1,
		"exp_points": 0.0,
	}
	characters.append(new_char)
	active_char_index = characters.size() - 1
	_apply_active_character()
	await _save_characters()
	return true

func delete_character(index: int) -> void:
	if index < 0 or index >= characters.size():
		return
	characters.remove_at(index)
	if active_char_index >= characters.size():
		active_char_index = characters.size() - 1
	await _save_characters()

func select_character(index: int) -> void:
	if index < 0 or index >= characters.size():
		return
	active_char_index = index
	_apply_active_character()

func _apply_active_character() -> void:
	if active_char_index < 0 or active_char_index >= characters.size():
		return
	var c : Dictionary = characters[active_char_index]
	nickname   = c.get("nickname", "")
	profession = c.get("profession", "")
	skin       = c.get("skin", "")
	char_class = c.get("char_class", "")
	credits    = int(c.get("credits", 0))
	level      = int(c.get("level", 1))
	exp_points = float(c.get("exp_points", 0.0))
	Relay.nickname = nickname

## Call from gameplay when stats change (scene exit, mission complete, etc.)
func save_character(player: Node) -> void:
	if not is_logged_in or active_char_index < 0 or active_char_index >= characters.size():
		return
	var session : NakamaSession = Relay.get_session()
	if session == null:
		return
	var c : Dictionary = characters[active_char_index]
	var cls_val = player.get("character_class")
	var cr_val  = player.get("credits")
	var lv_val  = player.get("level")
	var xp_val  = player.get("exp_points")
	c["char_class"]  = cls_val  if cls_val  != null else char_class
	c["credits"]     = cr_val   if cr_val   != null else credits
	c["level"]       = lv_val   if lv_val   != null else level
	c["exp_points"]  = xp_val   if xp_val   != null else exp_points
	characters[active_char_index] = c
	_apply_active_character()
	await _save_characters()
