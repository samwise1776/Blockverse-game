extends Node

const PORT = 24567
const MAX_PLAYERS = 16

func host():
	var peer = NetworkedMultiplayerENet.new()

	var err = peer.create_server(PORT, MAX_PLAYERS)

	if err != OK:
		print("LAN host failed:", err)
		return

	get_tree().network_peer = peer

	print("LAN server started on port ", PORT)

func join(ip):
	var peer = NetworkedMultiplayerENet.new()

	var err = peer.create_client(ip, PORT)

	if err != OK:
		print("LAN join failed:", err)
		return

	get_tree().network_peer = peer

	print("Joining ", ip, ":", PORT)

func disconnect_network():
	get_tree().network_peer = null
