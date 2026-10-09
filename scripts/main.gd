class_name ChordLab
extends Node3D
## Milestone 1 only: tracked rig, three note targets and playback feedback.

var xr_active := false
var _needs_placement := false
var _desktop_hover: KeyboardKey
var _keys: Array[KeyboardKey] = []

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var head: XRCamera3D = $XROrigin3D/Head
@onready var desktop_camera: Camera3D = $DesktopCamera
@onready var station: Node3D = $Station
@onready var audio: AudioManager = $AudioManager
@onready var status: Label3D = $Station/Panel/Status
@onready var instructions: Label3D = $Station/Panel/Instructions
@onready var selection_label: Label3D = $Station/Selection


func _ready() -> void:
	for child in $Station/Keys.get_children():
		var key := child as KeyboardKey
		_keys.append(key)
		key.selection_changed.connect(_on_selection_changed)
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
		instructions.text = "Point + trigger: select a note\nA / X: hear selection   B / Y: clear\nGrip: place the keys in front of you"
		status.text = "Choose a note to hear it."
		print("Chord Lab: OpenXR initialized; headset interaction awaits verification.")
	else:
		desktop_camera.make_current()
		instructions.text = "Click a key, or press 1 / 2 / 3\nSpace: hear selection   C: clear\nDesktop preview"
		status.text = "Choose a note to hear it."
		print("Chord Lab: desktop preview (OpenXR unavailable or disabled).")
	_update_selection_label()


func _physics_process(_delta: float) -> void:
	if xr_active:
		if _needs_placement and head.get_has_tracking_data():
			reposition_station()
	else:
		_update_desktop_hover()


func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var key := _key_at_screen_position(event.position)
		if key:
			key.activate()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_keys[0].activate()
			KEY_2:
				_keys[1].activate()
			KEY_3:
				_keys[2].activate()
			KEY_SPACE:
				play_selection()
			KEY_C:
				clear_selection()


func selected_notes() -> Array[int]:
	var notes: Array[int] = []
	for key in _keys:
		if key.selected:
			notes.append(key.midi_note)
	notes.sort()
	return notes


func play_selection() -> void:
	var notes := selected_notes()
	if notes.is_empty():
		status.text = "Select a note first."
		return
	audio.play_notes(notes)
	status.text = "Hearing %s" % _selected_names()


func clear_selection() -> void:
	for key in _keys:
		key.set_selected(false)
	audio.stop_all()
	status.text = "Selection cleared. Choose a note."


func reposition_station() -> void:
	if not xr_active or not head.get_has_tracking_data():
		return
	var forward := -head.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return
	forward = forward.normalized()
	station.global_position = head.global_position + forward * 0.8 - Vector3(0, 0.5, 0)
	station.rotation.y = atan2(-forward.x, -forward.z)
	_needs_placement = false
	status.text = "Keys placed in front of you."


func _on_selection_changed(midi_note: int, selected: bool) -> void:
	if selected:
		audio.play_note(midi_note)
	_update_selection_label()
	status.text = "Choose more notes, then hear them together."


func _selected_names() -> String:
	var names := PackedStringArray()
	for key in _keys:
		if key.selected:
			names.append(key.note_name)
	return " + ".join(names)


func _update_selection_label() -> void:
	var names := _selected_names()
	selection_label.text = names if not names.is_empty() else "No notes selected"


func _key_at_screen_position(screen_position: Vector2) -> KeyboardKey:
	var origin := desktop_camera.project_ray_origin(screen_position)
	var direction := desktop_camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 10.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as KeyboardKey


func _update_desktop_hover() -> void:
	var key := _key_at_screen_position(get_viewport().get_mouse_position())
	if key == _desktop_hover:
		return
	if is_instance_valid(_desktop_hover):
		_desktop_hover.set_hovered(&"desktop", false)
	_desktop_hover = key
	if key:
		key.set_hovered(&"desktop", true)
