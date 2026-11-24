class_name AudioManager
extends Node
## Packaged samples with enough playback voices to hear the entire keyboard together.

const SAMPLES := {
	60: preload("res://assets/audio/note_60.wav"),
	61: preload("res://assets/audio/note_61.wav"),
	62: preload("res://assets/audio/note_62.wav"),
	63: preload("res://assets/audio/note_63.wav"),
	64: preload("res://assets/audio/note_64.wav"),
	65: preload("res://assets/audio/note_65.wav"),
	66: preload("res://assets/audio/note_66.wav"),
	67: preload("res://assets/audio/note_67.wav"),
	68: preload("res://assets/audio/note_68.wav"),
	69: preload("res://assets/audio/note_69.wav"),
	70: preload("res://assets/audio/note_70.wav"),
	71: preload("res://assets/audio/note_71.wav"),
	72: preload("res://assets/audio/note_72.wav"),
	73: preload("res://assets/audio/note_73.wav"),
	74: preload("res://assets/audio/note_74.wav"),
}
const NOTE_VOLUME_DB := -10.0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	for index in range(SAMPLES.size()):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


func play_note(midi_note: int, volume_db: float = NOTE_VOLUME_DB) -> void:
	if not SAMPLES.has(midi_note):
		push_warning("No sample for MIDI note %d" % midi_note)
		return
	var voice := _voices[_next_voice]
	voice.volume_db = volume_db
	voice.stream = SAMPLES[midi_note]
	voice.play()
	_next_voice = (_next_voice + 1) % _voices.size()


func play_notes(midi_notes: Array[int]) -> void:
	stop_all()
	# Scale down dense selections so the sample peaks have room to sum.
	var volume_db := NOTE_VOLUME_DB + linear_to_db(6.0 / maxf(6.0, midi_notes.size()))
	for midi_note in midi_notes:
		play_note(midi_note, volume_db)


func stop_all() -> void:
	for voice in _voices:
		voice.stop()
