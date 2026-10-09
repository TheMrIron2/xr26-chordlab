class_name AudioManager
extends Node
## Three packaged samples and a small voice pool; no runtime synthesis.

const SAMPLES := {
	60: preload("res://assets/audio/note_60.wav"),
	64: preload("res://assets/audio/note_64.wav"),
	67: preload("res://assets/audio/note_67.wav"),
}
const VOICE_COUNT := 9

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	for index in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -10.0
		add_child(voice)
		_voices.append(voice)


func play_note(midi_note: int) -> void:
	if not SAMPLES.has(midi_note):
		push_warning("No prototype sample for MIDI note %d" % midi_note)
		return
	var voice := _voices[_next_voice]
	voice.stream = SAMPLES[midi_note]
	voice.play()
	_next_voice = (_next_voice + 1) % _voices.size()


func play_notes(midi_notes: Array[int]) -> void:
	for midi_note in midi_notes:
		play_note(midi_note)


func stop_all() -> void:
	for voice in _voices:
		voice.stop()
