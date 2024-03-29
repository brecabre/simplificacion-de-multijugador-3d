extends Node

# Puerto de juego predeterminado
const DEFAULT_PORT = 10567

# numero max de jugadores
const MAX_PEERS = 12

# Nombre para mi player
var player_name = "The Bravo"

# Nombres para jugadores remotos en id: formato de nombre
var players = {}

# Señales para que el GUI del lobby sepa lo que está pasando
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

# Devolución de llamada de SceneTree
func _player_connected(_id):
	
	# Esto no se usa en esta demostración, porque se llama a _connected_ok para clientes
	# en el éxito y hará el trabajo.
	pass

# Devolución de llamada de SceneTree
func _player_disconnected(id):
	if get_tree().is_network_server():
		if has_node("/root/world"): # El juego está en progreso
			emit_signal("game_error", "Player " + players[id] + " disconnected")
			end_game()
		else: # # El juego no está en progreso
				# Si somos el servidor, envíe al nuevo amigo todos los jugadores ya registrados.
			unregister_player(id)
			for p_id in players:
				# borrar en el servidor
				rpc_id(p_id, "unregister_player", id)

# Devolución de llamada de SceneTree, solo para clientes (no servidor)
func _connected_ok():
	
# Registro de un cliente aquí, dile a todos que estamos aquí.
	rpc("register_player", get_tree().get_network_unique_id(), player_name)
	emit_signal("connection_succeeded")

# Devolución de llamada de SceneTree, solo para clientes (no servidor)
func _server_disconnected():
	emit_signal("game_error", "Server disconnected")
	end_game()

# Devolución de llamada de SceneTree, solo para clientes (no servidor)
func _connected_fail():
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")

# Funciones de gestión del lobby.
remote func register_player(id, new_player_name):
	if get_tree().is_network_server():
		
# Si somos el servidor, díganles a todos acerca del nuevo jugador.
		rpc_id(id, "register_player", 1, player_name) # Envíame a un nuevo amigo

		for p_id in players: # Luego, para cada jugador remoto
			rpc_id(id, "register_player", p_id, players[p_id]) # Send player to new dude
			rpc_id(p_id, "register_player", id, new_player_name) # Send new dude to player

	players[id] = new_player_name
	emit_signal("player_list_changed")

remote func unregister_player(id):
	players.erase(id)
	emit_signal("player_list_changed")

remote func pre_start_game(spawn_points):
	# Cambiar escena
	var world = load("res://world.tscn").instance()
	get_tree().get_root().add_child(world)

	get_tree().get_root().get_node("lobby").hide()

	var player_scene = load("res://player.tscn")

	for p_id in spawn_points:
		var spawn_pos = world.get_node("spawn_points/" + str(spawn_points[p_id])).global_transform
		
		var player = player_scene.instance()

		player.set_name(str(p_id)) # Usar ID única como nombre de nodo
		player.global_transform=spawn_pos
		player.set_network_master(p_id) #set id único como maestro

		if p_id == get_tree().get_network_unique_id():
			# Si el nodo para este ID de par, establecer nombre
			player.set_player_name(player_name)
		else:
			# De lo contrario, establecer el nombre de igual
			player.set_player_name(players[p_id])

		world.get_node("players").add_child(player)

	# Configurar puntuación
#	world.get_node("score").add_player(get_tree().get_network_unique_id(), player_name)
#	for pn in players:
#		world.get_node("score").add_player(pn, players[pn])

	if not get_tree().is_network_server():
		# Dile al servidor que estamos listos para comenzar
		rpc_id(1, "ready_to_start", get_tree().get_network_unique_id())
	elif players.size() == 0:
		post_start_game()

remote func post_start_game():
	get_tree().set_pause(false) # Despausa y comienza el juego!

var players_ready = []

remote func ready_to_start(id):
	assert(get_tree().is_network_server())

	if not id in players_ready:
		players_ready.append(id)

	if players_ready.size() == players.size():
		for p in players:
			rpc_id(p, "post_start_game")
		post_start_game()

func host_game(new_player_name):
	player_name = new_player_name
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(host)

func join_game(ip, new_player_name):
	player_name = new_player_name
	var host = NetworkedMultiplayerENet.new()
	host.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(host)

func get_player_list():
	return players.values()

func get_player_name():
	return player_name

func begin_game():
	assert(get_tree().is_network_server())

	# Crear un diccionario con ID de compañero y puntos de generación respectivos, podría mejorarse aleatoriamente
	var spawn_points = {}
	spawn_points[1] = 0 # Servidor en punto de generación 0
	var spawn_point_idx = 1
	for p in players:
		spawn_points[p] = spawn_point_idx
		spawn_point_idx += 1
	# Llamar para iniciar el juego con los puntos de generación.
	for p in players:
		rpc_id(p, "pre_start_game", spawn_points)

	pre_start_game(spawn_points)

func end_game():
	if has_node("/root/world"): # El juego está en progreso
		# se acaba
		get_node("/root/world").queue_free()

	emit_signal("game_ended")
	players.clear()
	get_tree().set_network_peer(null) # End networking

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
