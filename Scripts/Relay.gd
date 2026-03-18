extends Node

# ═══════════════════════════════════════════════════════════════════════
#  Relay.gd — Autoload Singleton
#  Drop-in replacement for the legacy WebSocket relay server.
#  Uses Nakama real-time Chat Channels for multiplayer messaging.
#  All existing signals and public API are preserved — no other
#  scripts need to change.
# ═══════════════════════════════════════════════════════════════════════

# ── Set USE_LOCAL_SERVER = true to connect to local Docker Desktop ────
const USE_LOCAL_SERVER : bool   = true

const LOCAL_HOST  : String = "localhost"
const PROD_HOST   : String = "24.199.102.143"
const NAKAMA_HOST : String = LOCAL_HOST if USE_LOCAL_SERVER else PROD_HOST
const NAKAMA_PORT   : int    = 7350
const NAKAMA_SCHEME : String = "http"
const NAKAMA_KEY    : String = "miniswg-server-key"

# ── Signals (unchanged public API) ────────────────────────────────────
signal connected_to_relay
signal relay_error(msg: String)
signal server_list_received(rooms: Array)
signal room_hosted(room_id: String)
signal room_joined(room_id: String, my_peer_id: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal game_data_received(from_peer: int, data: Dictionary)
signal host_left

# ── Public state (read by other scripts) ──────────────────────────────
var my_peer_id   : int    = -1
var my_room_id   : String = ""
var is_host      : bool   = false
var connected    : bool   = false
var nickname     : String = "Adventurer"
var player_class : String = "Street Fighter"
var player_level : int    = 1
var intended_host : bool  = false

# ── Nakama internals ──────────────────────────────────────────────────
var _client       : NakamaClient  = null
var _socket       : NakamaSocket  = null
var _session      : NakamaSession = null
var _channel_id   : String        = ""
var _socket_ready : bool          = false
var _pending_zone : String        = ""
var _pending_host : bool          = false

func _ready() -> void:
	print("[Relay] _ready — host=%s USE_LOCAL=%s" % [NAKAMA_HOST, str(USE_LOCAL_SERVER)])
	_client = Nakama.create_client(NAKAMA_KEY, NAKAMA_HOST, NAKAMA_PORT, NAKAMA_SCHEME)
	if _client == null:
		print("[Relay] ERROR: Nakama.create_client returned null — check autoload order!")
	else:
		print("[Relay] client created OK")

# ── Called by StartScreen on app start ────────────────────────────────
# We emit immediately so the login UI unlocks right away.
# The actual socket connects after the user authenticates.
func connect_to_relay() -> void:
	connected = true
	emit_signal("connected_to_relay")

# ── Called by PlayerData after successful login or register ───────────
func init_socket(session: NakamaSession) -> void:
	_session   = session
	my_peer_id = _user_id_to_peer_id(session.user_id)
	print("[Relay] init_socket — user_id=%s peer_id=%d" % [session.user_id, my_peer_id])
	if _socket != null:
		return  # already connected from a previous login
	_socket = Nakama.create_socket_from(_client)
	_socket.received_channel_message.connect(_on_channel_message)
	_socket.received_channel_presence.connect(_on_channel_presence)
	_socket.closed.connect(_on_socket_closed)
	var result = await _socket.connect_async(session)
	if result.is_exception():
		print("[Relay] socket connect FAILED: ", result.get_exception().message)
		emit_signal("relay_error", result.get_exception().message)
		_socket = null
		return
	print("[Relay] socket connected OK")
	_socket_ready = true
	if _pending_zone != "":
		_do_join_channel.call_deferred(_pending_zone, _pending_host)
		_pending_zone = ""
		_pending_host = false

# ── Zone join / host ──────────────────────────────────────────────────
func host_game(zone_name: String, _max_players: int = 64) -> void:
	is_host    = true
	my_room_id = zone_name
	_queue_or_join(zone_name, true)

# Alias used by LunarStationScene
func host_server(zone_name: String, _max_players: int = 64) -> void:
	host_game(zone_name, _max_players)

func join_room(zone_name: String) -> void:
	is_host    = false
	my_room_id = zone_name
	_queue_or_join(zone_name, false)

# Alias used by LunarStationScene
func join_server(zone_name: String) -> void:
	join_room(zone_name)

func _queue_or_join(zone: String, hosting: bool) -> void:
	if _socket_ready:
		_do_join_channel(zone, hosting)
	else:
		_pending_zone = zone
		_pending_host = hosting

func _do_join_channel(zone: String, hosting: bool) -> void:
	if _socket == null:
		return
	print("[Relay] joining channel: ", zone)
	var ch = await _socket.join_chat_async(
		zone,
		NakamaSocket.ChannelType.Room,
		false,
		false
	)
	if ch.is_exception():
		print("[Relay] join_chat FAILED: ", ch.get_exception().message)
		emit_signal("relay_error", ch.get_exception().message)
		return
	_channel_id = ch.id
	print("[Relay] joined channel OK — id=%s presences=%d" % [_channel_id, ch.presences.size()])
	# Notify about players already in the channel
	for presence in ch.presences:
		var pid = _user_id_to_peer_id(presence.user_id)
		print("[Relay] existing presence: user_id=%s peer_id=%d" % [presence.user_id, pid])
		if pid != my_peer_id:
			emit_signal("peer_joined", pid)
	if hosting:
		emit_signal("room_hosted", zone)
	else:
		emit_signal("room_joined", zone, my_peer_id)

# ── Server list (no listing needed with named channels) ───────────────
# Emit empty list so scenes fall through to the host_game() path.
func fetch_server_list() -> void:
	emit_signal("server_list_received", [])

func request_server_list() -> void:
	fetch_server_list()

# ── Sending ───────────────────────────────────────────────────────────
# to_peer == -1 means broadcast to all; otherwise only that peer reads it.
var _send_log_throttle : int = 0
func send_game_data(data: Dictionary, to_peer: int = -1) -> void:
	if _socket == null or _channel_id == "":
		return
	_send_log_throttle += 1
	if _send_log_throttle % 60 == 1:  # print once per ~3 seconds
		print("[Relay] SEND cmd=%s channel=%s" % [data.get("cmd","?"), _channel_id.left(8)])
	_socket.write_chat_message_async(_channel_id, {
		"from": my_peer_id,
		"to":   to_peer,
		"data": data,
	})

# ── Receiving ─────────────────────────────────────────────────────────
func _on_channel_message(msg) -> void:
	print("[Relay] RAW msg.content type=%s value=%s" % [typeof(msg.content), str(msg.content).left(120)])
	var parsed = JSON.parse_string(msg.content)
	if not parsed is Dictionary:
		print("[Relay] non-dict message ignored: ", msg.content)
		return
	var from_peer = int(parsed.get("from", -1))
	if from_peer == my_peer_id:
		return  # own message echoed back by server
	var to_peer = int(parsed.get("to", -1))
	if to_peer != -1 and to_peer != my_peer_id:
		return  # directed to a different peer
	var data = parsed.get("data", {})
	if data is Dictionary:
		print("[Relay] msg from peer_id=%d cmd=%s" % [from_peer, data.get("cmd", "?")])
		emit_signal("game_data_received", from_peer, data)

func _on_channel_presence(presence_event) -> void:
	for p in presence_event.joins:
		var pid = _user_id_to_peer_id(p.user_id)
		print("[Relay] peer joined channel: user_id=%s peer_id=%d" % [p.user_id, pid])
		if pid != my_peer_id:
			emit_signal("peer_joined", pid)
	for p in presence_event.leaves:
		var pid = _user_id_to_peer_id(p.user_id)
		print("[Relay] peer left channel: user_id=%s peer_id=%d" % [p.user_id, pid])
		emit_signal("peer_left", pid)

func _on_socket_closed() -> void:
	_socket_ready = false
	_socket       = null
	_channel_id   = ""
	connected     = false

# ── Cleanup ───────────────────────────────────────────────────────────
func reset_room() -> void:
	my_peer_id = _user_id_to_peer_id(_session.user_id) if _session else -1
	my_room_id = ""
	is_host    = false

func leave_room() -> void:
	if _socket != null and _channel_id != "":
		_socket.leave_chat_async(_channel_id)
	_channel_id = ""
	reset_room()

# ── Exposed for PlayerData ─────────────────────────────────────────────
func get_client() -> NakamaClient:
	return _client

func get_session() -> NakamaSession:
	return _session

# ── Helpers ───────────────────────────────────────────────────────────
# Derives a stable int peer-id from a Nakama UUID string.
# Deterministic — all clients compute the same value for the same user.
func _user_id_to_peer_id(user_id: String) -> int:
	return user_id.hash()
