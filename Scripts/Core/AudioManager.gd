extends Node

const SFX_POOL_SIZE: int = 12
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_player: int = 0
var _music_player: AudioStreamPlayer

# Music playlist system
var _music_playlist: Array[String] = []
var _music_index: int = 0
var _music_looping: bool = true
var _sfx_enabled: bool = true


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
	_music_player.finished.connect(_on_music_finished)


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled


func play_sfx(sfx_name: String) -> void:
	if not _sfx_enabled:
		return
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
	_music_playlist = [track_name]
	_music_index = 0
	_music_looping = true
	_play_track(track_name)


## Play a sequence of tracks that loop back to the start when done.
func play_music_playlist(tracks: Array[String]) -> void:
	_music_playlist = tracks
	_music_index = 0
	_music_looping = true
	if tracks.size() > 0:
		_play_track(tracks[0])


func _play_track(track_name: String) -> void:
	var path := "res://Assets/Audio/Music/%s.ogg" % track_name
	if not ResourceLoader.exists(path):
		path = "res://Assets/Audio/Music/%s.wav" % track_name
		if not ResourceLoader.exists(path):
			return

	_music_player.stream = load(path) as AudioStream
	_music_player.play()


func _on_music_finished() -> void:
	if not _music_looping or _music_playlist.is_empty():
		return
	# Advance to next track in playlist, loop back to start
	_music_index = (_music_index + 1) % _music_playlist.size()
	_play_track(_music_playlist[_music_index])


func pause_music() -> void:
	_music_player.stream_paused = true


func resume_music() -> void:
	_music_player.stream_paused = false


func stop_music() -> void:
	_music_looping = false
	_music_player.stop()
