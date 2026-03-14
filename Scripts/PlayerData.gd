extends Node

# ============================================================
#  PlayerData.gd — Autoload Singleton
#  Username / password authentication + character persistence.
#  Saves to user://miniswg_accounts.json (local, per-machine).
#
#  Flow:
#    1. StartScreen calls login() or register()
#    2. SpaceportScene reads PlayerData.nickname, .char_class, etc.
#    3. On scene exit / mission complete → save_character(player)
# ============================================================

const SAVE_PATH : String = "user://miniswg_accounts.json"

var username     : String = ""
var nickname     : String = ""   # same as username (display name)
var char_class   : String = ""
var credits      : int    = 0
var level        : int    = 1
var exp_points   : float  = 0.0
var is_logged_in : bool   = false

var _accounts    : Dictionary = {}   # key=username.to_lower() → {password_hash, char_data}

func _ready() -> void:
	_load_accounts()

# ── Persistence ───────────────────────────────────────────────
func _load_accounts() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		_accounts = data

func _save_accounts() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f: return
	f.store_string(JSON.stringify(_accounts, "\t"))
	f.close()

# ── Auth ──────────────────────────────────────────────────────
## Returns true on success, false if wrong password.
func login(uname: String, password: String) -> bool:
	var key = uname.to_lower().strip_edges()
	if not _accounts.has(key):
		return false
	var acc = _accounts[key]
	if acc.get("password_hash", "") != password.sha256_text():
		return false
	_apply_account(uname, acc)
	return true

## Returns true if created, false if username already taken.
func register(uname: String, password: String) -> bool:
	var key = uname.to_lower().strip_edges()
	if _accounts.has(key):
		return false
	_accounts[key] = {
		"password_hash": password.sha256_text(),
		"char_data": {
			"char_class":  "",
			"credits":     0,
			"level":       1,
			"exp_points":  0.0,
		}
	}
	_save_accounts()
	_apply_account(uname, _accounts[key])
	return true

func account_exists(uname: String) -> bool:
	return _accounts.has(uname.to_lower().strip_edges())

func _apply_account(uname: String, acc: Dictionary) -> void:
	username     = uname.strip_edges()
	nickname     = username
	Relay.nickname = username
	var cd       = acc.get("char_data", {})
	char_class   = cd.get("char_class",  "")
	credits      = cd.get("credits",     0)
	level        = cd.get("level",       1)
	exp_points   = cd.get("exp_points",  0.0)
	is_logged_in = true

# ── Character save ────────────────────────────────────────────
func save_character(player: Node) -> void:
	if not is_logged_in: return
	var key = username.to_lower()
	if not _accounts.has(key): return
	var cls_val = player.get("character_class")
	var cr_val  = player.get("credits")
	var lv_val  = player.get("level")
	var xp_val  = player.get("exp_points")
	_accounts[key]["char_data"] = {
		"char_class":  cls_val  if cls_val  != null else char_class,
		"credits":     cr_val   if cr_val   != null else credits,
		"level":       lv_val   if lv_val   != null else level,
		"exp_points":  xp_val   if xp_val   != null else exp_points,
	}
	_save_accounts()
