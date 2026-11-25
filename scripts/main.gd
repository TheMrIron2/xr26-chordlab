class_name ChordLab
extends Node3D

const KEY_SCENE := preload("res://scenes/keyboard_key.tscn")
const FIRST_NOTE := 60
const LAST_NOTE := 74
const NOTE_NAMES := ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
const FLAT_NAMES := {1: "D♭", 3: "E♭", 6: "G♭", 8: "A♭", 10: "B♭"}
const WHITE_KEY_STEP := 0.11
const DESKTOP_SHORTCUTS := {KEY_1: 60, KEY_2: 64, KEY_3: 67}

var xr_active := false
var _needs_placement := false
var _desktop_hover: RayTarget
var _keys: Array[KeyboardKey] = []

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var head: XRCamera3D = $XROrigin3D/Head
@onready var desktop_camera: Camera3D = $DesktopCamera
@onready var station: Node3D = $Station
@onready var keyboard: Node3D = $Station/Keys
@onready var audio: AudioManager = $AudioManager
@onready var lesson: LessonFlow = $LessonFlow
@onready var status: Label3D = $Station/Panel/Status
@onready var instructions: Label3D = $Station/Panel/Instructions
@onready var selection_label: Label3D = $Station/Selection


func _ready() -> void:
	_build_keyboard()
	for pointer: ControllerPointer in [xr_origin.get_node("LeftHand"), xr_origin.get_node("RightHand")]:
		pointer.play_requested.connect(play_selection)
		pointer.clear_requested.connect(clear_selection)
		pointer.reposition_requested.connect(reposition_station)
	var xr_interface := XRServer.find_interface("OpenXR")
	xr_active = xr_interface != null and xr_interface.is_initialized()
	get_viewport().use_xr = xr_active
	for pointer: ControllerPointer in [xr_origin.get_node("LeftHand"), xr_origin.get_node("RightHand")]:
		pointer.enabled = xr_active
	if xr_active:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		head.make_current()
		_needs_placement = true
		instructions.text = "Point + trigger to use  ·  A / X to hear  ·  B / Y to clear\nSqueeze either grip to reposition"
		print("Chord Lab: OpenXR initialized; headset interaction awaits verification.")
	else:
		desktop_camera.make_current()
		instructions.text = "Click to use keys and buttons  ·  Space to hear  ·  C to clear"
		print("Chord Lab: desktop preview (OpenXR unavailable or disabled).")
	_update_selection_label()
	lesson.restart()


func _build_keyboard() -> void:
	var white_count := 0
	for midi_note in range(FIRST_NOTE, LAST_NOTE + 1):
		var pitch_class := midi_note % 12
		var key := KEY_SCENE.instantiate() as KeyboardKey
		key.midi_note = midi_note
		key.note_name = note_name_for(midi_note)
		key.name = key.note_name
		if FLAT_NAMES.has(pitch_class):
			key.flat_name = "%s%d" % [FLAT_NAMES[pitch_class], floori(midi_note / 12.0) - 1]
			# Leave the fronts of both neighbouring white keys open to rays.
			key.position = Vector3((white_count - 0.5) * WHITE_KEY_STEP, 0.0475, -0.075)
		else:
			key.position.x = white_count * WHITE_KEY_STEP
			white_count += 1
		keyboard.add_child(key)
		_keys.append(key)
		key.selection_changed.connect(_on_selection_changed)
	keyboard.position.x = -(white_count - 1) * WHITE_KEY_STEP / 2.0


func _physics_process(_delta: float) -> void:
	if xr_active:
		if _needs_placement and _head_has_tracking_data():
			reposition_station()
	else:
		_update_desktop_hover()


func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target := _target_at_screen_position(event.position)
		if target:
			target.activate()
	elif event is InputEventKey and event.pressed and not event.echo:
		var shortcut_note: int = DESKTOP_SHORTCUTS.get(event.physical_keycode, -1)
		if shortcut_note >= FIRST_NOTE:
			_keys[shortcut_note - FIRST_NOTE].activate()
			return
		match event.physical_keycode:
			KEY_SPACE:
				play_selection()
			KEY_C:
				clear_selection()


func selected_notes() -> Array[int]:
	var notes: Array[int] = []
	for key in _keys:
		if key.selected:
			notes.append(key.midi_note)
	return notes


func play_selection() -> void:
	if lesson.mode not in [LessonFlow.Mode.PRACTICE, LessonFlow.Mode.FREE_PLAY]:
		return
	var notes := selected_notes()
	if notes.is_empty():
		status.text = "Select a note first."
		return
	audio.play_notes(notes)
	if lesson.mode == LessonFlow.Mode.FREE_PLAY:
		status.text = _triad_feedback(notes)


func _triad_feedback(notes: Array[int]) -> String:
	if notes.size() < 3:
		return "Select three notes to make a triad."
	if notes.size() > 3:
		return "A triad has three notes. Deselect the extras."
	for root_note in notes:
		var root_name: String = NOTE_NAMES[root_note % 12]
		if ChordValidator.matches(notes, root_note, ChordValidator.Quality.MAJOR):
			return "Hearing %s major" % root_name
		if ChordValidator.matches(notes, root_note, ChordValidator.Quality.MINOR):
			return "Hearing %s minor" % root_name
	return "Try changing a note to make a major or minor triad."


func clear_selection() -> void:
	lesson.clear()


func reset_selection() -> void:
	for key in _keys:
		key.set_selected(false)
	audio.stop_all()


func set_lesson_keyboard(enabled: bool, guide: Array = [], demonstration: Array = []) -> void:
	for key in _keys:
		key.interaction_enabled = enabled
		key.set_lesson_highlight(guide.has(key.midi_note), demonstration.has(key.midi_note))


func note_name_for(midi_note: int) -> String:
	return "%s%d" % [pitch_name(midi_note), floori(midi_note / 12.0) - 1]


func pitch_name(midi_note: int) -> String:
	return NOTE_NAMES[midi_note % 12]


func _head_has_tracking_data() -> bool:
	var tracker := XRServer.get_tracker(&"head") as XRPositionalTracker
	if tracker == null or not tracker.has_pose(&"default"):
		return false
	var pose := tracker.get_pose(&"default")
	return pose.has_tracking_data and pose.tracking_confidence != XRPose.XR_TRACKING_CONFIDENCE_NONE


func reposition_station() -> void:
	if not xr_active or not _head_has_tracking_data():
		return
	var forward := -head.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return
	forward = forward.normalized()
	station.global_position = head.global_position + forward * 0.8 - Vector3(0, 0.5, 0)
	station.rotation.y = atan2(-forward.x, -forward.z)
	_needs_placement = false


func _on_selection_changed(midi_note: int, selected: bool) -> void:
	if selected:
		audio.play_note(midi_note)
	_update_selection_label()
	if selected and lesson.mode == LessonFlow.Mode.FREE_PLAY:
		status.text = "Play your selection to hear it together."


func _update_selection_label() -> void:
	var names := PackedStringArray()
	for key in _keys:
		if key.selected:
			names.append(key.note_name)
	if names.is_empty():
		selection_label.text = "No notes selected"
	elif names.size() <= 6:
		selection_label.text = " + ".join(names)
	else:
		selection_label.text = "%d notes selected" % names.size()


func _target_at_screen_position(screen_position: Vector2) -> RayTarget:
	var origin := desktop_camera.project_ray_origin(screen_position)
	var direction := desktop_camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 10.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as RayTarget


func _update_desktop_hover() -> void:
	var target := _target_at_screen_position(get_viewport().get_mouse_position())
	if target == _desktop_hover:
		return
	if is_instance_valid(_desktop_hover):
		_desktop_hover.set_hovered(&"desktop", false)
	_desktop_hover = target
	if target:
		target.set_hovered(&"desktop", true)
