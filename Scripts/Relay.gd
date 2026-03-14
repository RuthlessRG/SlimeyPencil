extends Node

# ═══════════════════════════════════════════════════════════
#  Relay.gd — Autoload Singleton — Beyond the Veil
#  SETUP: Project > Project Settings > Autoload
#         Add this file as "Relay"
#
#  Architecture: same WebSocket relay server as MechaArena.
#  server.js + package.json (included) deploy to Render.com.
#  Update SERVER_URL below once you deploy your relay server.
#
#  In offline/solo mode this autoload is simply unused —
#  no connection is attempted until host_game() or join_room()
#  is called, so single-player gameplay is unaffected.
# ═══════════════════════════════════════════════════════════

# ── Update this URL once you deploy your relay server ───────
const SERVER_URL = "wss://newgamewhodis.onrender.com"

signal connected_to_relay
signal relay_error(msg: String)
signal server_list_received(rooms: Array)
signal room_hosted(room_id: String)
signal room_joined(room_id: String, my_peer_id: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal game_data_received(from_peer: int, data: Dictionary)
signal host_left

var socket        : WebSocketPeer = null
var my_peer_id    : int    = -1
var my_room_id    : String = ""
var is_host       : bool   = false
var connected     : bool   = false
var nickname      : String = "Adventurer"
var intended_host : bool   = false

# ── Player info broadcast with each message ─────────────────
# Populate before hosting/joining for multiplayer name display
var player_class  : String = "Street Fighter"
var player_level  : int    = 1

func connect_to_relay() -> void:
	if socket != null:
		var state = socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			connected = true
			emit_signal("connected_to_relay")
			return
		elif state == WebSocketPeer.STATE_CONNECTING:
			return
	connected = false
	socket    = WebSocketPeer.new()
	var err   = socket.connect_to_url(SERVER_URL)
	if err != OK:
		push_error("Relay: failed to connect: " + str(err))
		return
	set_process(true)
	print("Relay: connecting to ", SERVER_URL)

func reset_room() -> void:
	my_peer_id = -1
	my_room_id = ""
	is_host    = false

func leave_room() -> void:
	reset_room()
	if socket != null:
		socket.close()
		socket = null
	connected = false
	print("Relay: left room")

func _process(_delta: float) -> void:
	if socket == null:
		return
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			print("Relay: connected!")
			emit_signal("connected_to_relay")
		while socket.get_available_packet_count() > 0:
			var raw = socket.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(raw)
			if msg:
				_handle_message(msg)
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			connected = false
			print("Relay: disconnected")

func _handle_message(msg: Dictionary) -> void:
	match msg.get("type", ""):
		"hosted":
			my_peer_id = int(msg.get("peerId", -1))
			my_room_id = str(msg.get("roomId", ""))
			is_host    = true
			print("Relay: hosted room ", my_room_id, " as peer ", my_peer_id)
			emit_signal("room_hosted", my_room_id)
		"joined":
			my_peer_id = int(msg.get("peerId", -1))
			my_room_id = str(msg.get("roomId", ""))
			is_host    = false
			print("Relay: joined room ", my_room_id, " as peer ", my_peer_id)
			emit_signal("room_joined", my_room_id, my_peer_id)
		"list":
			emit_signal("server_list_received", msg.get("rooms", []))
		"peer_joined":
			emit_signal("peer_joined", int(msg.get("peerId", -1)))
		"peer_left":
			emit_signal("peer_left", int(msg.get("peerId", -1)))
		"host_left":
			emit_signal("host_left")
		"relay":
			emit_signal("game_data_received", msg.get("from", -1), msg.get("data", {}))
		"error":
			var emsg = msg.get("msg", "unknown")
			var expected = ["Room not found", "Room full"]
			if not expected.has(emsg):
				push_error("Relay error: " + emsg)
			emit_signal("relay_error", emsg)

func host_game(game_name: String, max_players: int = 8) -> void:
	_send({"type": "host", "name": game_name, "maxPlayers": max_players})

func fetch_server_list() -> void:
	_send({"type": "list"})

func join_room(room_id: String) -> void:
	if room_id == "":
		push_warning("Relay: tried to join room with empty ID")
		return
	_send({"type": "join", "roomId": room_id})

func send_game_data(data: Dictionary, to_peer: int = -1) -> void:
	var msg := {"type": "relay", "to": "all", "data": data}
	if to_peer != -1:
		msg["to"] = to_peer
	_send(msg)

func _send(obj: Dictionary) -> void:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_warning("Relay: tried to send while not connected")
		return
	socket.send_text(JSON.stringify(obj))
