extends Node

const SFX_POOL_SIZE: int = 12
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_player: int = 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)


func play_sfx(sfx_name: String) -> void:
	var path := "res://Assets/Audio/SFX/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		path = "res://Assets/Audio/SFX/%s.ogg" % sfx_name
		if not ResourceLoader.exists(path):
			return

	var stream := load(path) as AudioStream
	if stream == null:
		return

	var player := _sfx_players[_current_player]
	player.stream = stream
	player.play()
	_current_player = (_current_player + 1) % SFX_POOL_SIZE


func play_music(track_name: String) -> void:
	var path := "res://Assets/Audio/Music/%s.ogg" % track_name
	if not ResourceLoader.exists(path):
		return

	_music_player.stream = load(path) as AudioStream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
