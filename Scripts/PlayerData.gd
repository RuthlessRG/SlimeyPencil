extends Node

# ═══════════════════════════════════════════════════════════════════════
#  PlayerData.gd — Autoload Singleton
#  Authentication and character persistence via Nakama + PostgreSQL.
#  Replaces the local JSON file approach.
#
#  Flow:
#    1. StartScreen awaits login() or register()
#    2. On success → Relay.init_socket() is called automatically
#    3. Character data is stored in Nakama Storage Engine (PostgreSQL)
#    4. On scene exit / mission complete → save_character(player)
# ═══════════════════════════════════════════════════════════════════════

const STORAGE_COLLECTION : String = "player"
const STORAGE_KEY        : String = "character"
# Nakama email auth requires email format; we append this fake domain
# so players still only ever type a plain username in the UI.
const EMAIL_DOMAIN       : String = "@miniswg.game"

var username     : String = ""
var nickname     : String = ""
var char_class   : String = ""
var credits      : int    = 0
var level        : int    = 1
var exp_points   : float  = 0.0
var is_logged_in : bool   = false

# ── Auth ──────────────────────────────────────────────────────────────

## Returns true on success, false on wrong credentials or server error.
func login(uname: String, password: String) -> bool:
	var email   = uname.to_lower().strip_edges() + EMAIL_DOMAIN
	var client  : NakamaClient = Relay.get_client()
	var session : NakamaSession = await client.authenticate_email_async(
		email, password, uname, false
	)
	if session.is_exception():
		return false
	await _apply_session(uname, session)
	return true

## Returns true if account created, false if username already taken.
func register(uname: String, password: String) -> bool:
	var email   = uname.to_lower().strip_edges() + EMAIL_DOMAIN
	var client  : NakamaClient = Relay.get_client()
	# create=true → register new account; fails if email already exists
	var session : NakamaSession = await client.authenticate_email_async(
		email, password, uname, true
	)
	if session.is_exception():
		return false
	await _apply_session(uname, session)
	return true

## Kept for API compatibility; Nakama doesn't expose a lookup without auth.
func account_exists(_uname: String) -> bool:
	return false

func _apply_session(uname: String, session: NakamaSession) -> void:
	username     = uname.strip_edges()
	nickname     = username
	is_logged_in = true
	Relay.nickname = nickname
	# Open the multiplayer socket now that we have a valid session
	await Relay.init_socket(session)
	# Load stored character data (level, credits, class, xp)
	await _load_character(session)

# ── Storage ───────────────────────────────────────────────────────────

func _load_character(session: NakamaSession) -> void:
	var client : NakamaClient = Relay.get_client()
	var result = await client.read_storage_objects_async(session, [
		NakamaStorageObjectId.new(STORAGE_COLLECTION, STORAGE_KEY, session.user_id)
	])
	if result.is_exception() or result.objects.is_empty():
		return  # new account — defaults are fine
	var cd = JSON.parse_string(result.objects[0].value)
	if not cd is Dictionary:
		return
	char_class = str(cd.get("char_class",  ""))
	credits    = int(cd.get("credits",     0))
	level      = int(cd.get("level",       1))
	exp_points = float(cd.get("exp_points", 0.0))

## Call this when a player's stats change (scene exit, mission complete, etc.)
func save_character(player: Node) -> void:
	if not is_logged_in:
		return
	var session : NakamaSession = Relay.get_session()
	if session == null:
		return
	var cls_val = player.get("character_class")
	var cr_val  = player.get("credits")
	var lv_val  = player.get("level")
	var xp_val  = player.get("exp_points")
	var cd = {
		"char_class":  cls_val  if cls_val  != null else char_class,
		"credits":     cr_val   if cr_val   != null else credits,
		"level":       lv_val   if lv_val   != null else level,
		"exp_points":  xp_val   if xp_val   != null else exp_points,
	}
	var client : NakamaClient = Relay.get_client()
	await client.write_storage_objects_async(session, [
		NakamaWriteStorageObject.new(
			STORAGE_COLLECTION,
			STORAGE_KEY,
			2,   # read:  public (other players can't read your stats, server can)
			1,   # write: owner only
			JSON.stringify(cd),
			""   # version: empty = unconditional write
		)
	])
