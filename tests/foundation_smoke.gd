extends SceneTree
## Integration checks use real scene colliders and synthetic XR tracking data.
## They do not validate an OpenXR runtime or a physical headset.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "Main scene loads")
	if not packed:
		quit(1)
		return
	var lab := packed.instantiate() as ChordLab
	root.add_child(lab)
	await physics_frame
	await physics_frame
	_check(not lab.xr_active, "XR disabled uses the desktop fallback")
	_check(lab.desktop_camera.is_current(), "Desktop fallback has an active camera")
	_check(lab.selected_notes().is_empty(), "No notes selected on startup")
	var keys: Array[KeyboardKey] = []
	for child in lab.get_node("Station/Keys").get_children():
		keys.append(child)
	_check(keys.size() == 3, "Foundation contains exactly three note targets")
	for key in keys:
		var screen_position := lab.desktop_camera.unproject_position(key.global_position)
		_check(lab._key_at_screen_position(screen_position) == key, "Desktop ray reaches " + key.note_name)
	for code in [KEY_3, KEY_1, KEY_2]:
		_press_key(code)
	_check(lab.selected_notes() == [60, 64, 67], "Keyboard input produces order-independent selection")
	_press_key(KEY_SPACE)
	_check(_playing_voices(lab.audio) >= 3, "All selected samples start together")
	for midi_note in AudioManager.SAMPLES:
		var sample := AudioManager.SAMPLES[midi_note] as AudioStreamWAV
		_check(sample != null and sample.get_length() > 1.0, "Packaged audio loads for MIDI %d" % midi_note)
	_press_key(KEY_C)
	_check(lab.selected_notes().is_empty() and _playing_voices(lab.audio) == 0, "Clear input resets selection and stops audio")
	_press_key(KEY_SPACE)
	_check(lab.status.text == "Select a note first.", "Empty playback gives useful feedback")
	await _check_controller(lab, keys[0])
	_check_action_map()
	print("Foundation smoke: %d checks, %d failures." % [_checks, _failures])
	lab.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _check_controller(lab: ChordLab, key: KeyboardKey) -> void:
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = &"right_hand"
	tracker.hand = XRPositionalTracker.TRACKER_HAND_RIGHT
	tracker.set_input(&"select", 0.0)
	tracker.set_input(&"reposition", 0.0)
	XRServer.add_tracker(tracker)
	var pointer := lab.xr_origin.get_node("RightHand") as ControllerPointer
	pointer.enabled = true
	var origin := key.global_position + Vector3(0, 0.3, 0.3)
	var transform := Transform3D(Basis.looking_at(key.global_position - origin), origin)
	tracker.set_pose(&"aim", transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await physics_frame
	await physics_frame
	_check(pointer.get_has_tracking_data(), "Synthetic controller pose reaches the XR node")
	_check(pointer.ray.get_collider() == key, "Controller aim ray reaches the note collider")
	tracker.set_input(&"select", 1.0)
	await physics_frame
	await physics_frame
	_check(key.selected, "A trigger squeeze selects the aimed note")
	await physics_frame
	await physics_frame
	_check(key.selected, "Holding the trigger does not toggle repeatedly")
	tracker.set_input(&"select", 0.5)
	await physics_frame
	tracker.set_input(&"select", 1.0)
	await physics_frame
	_check(key.selected, "Partial release does not count as another squeeze")
	tracker.set_input(&"select", 0.0)
	await physics_frame
	await physics_frame
	tracker.set_input(&"select", 1.0)
	await physics_frame
	await physics_frame
	_check(not key.selected, "Release then squeeze deselects the note")
	tracker.set_input(&"select", 0.0)
	await physics_frame
	key.activate()
	tracker.set_input(&"play_chord", true)
	_check(lab.status.text == "Hearing C4", "Controller face button requests playback")
	tracker.set_input(&"clear", true)
	_check(lab.selected_notes().is_empty(), "Controller face button clears selection")
	tracker.invalidate_pose(&"aim")
	await physics_frame
	await physics_frame
	_check(not pointer.beam.visible, "Tracking loss hides the pointer")
	tracker.set_input(&"select", 1.0)
	await physics_frame
	await physics_frame
	_check(not key.selected, "An untracked controller cannot select a note")
	pointer.enabled = false
	XRServer.remove_tracker(tracker)


func _check_action_map() -> void:
	var action_map := load("res://xr/action_map.tres") as OpenXRActionMap
	_check(action_map != null, "Committed action map loads")
	var profile := action_map.find_interaction_profile("/interaction_profiles/oculus/touch_controller")
	_check(profile != null and profile.get_binding_count() == 10, "Quest bindings survive resource serialization")
	var expected := {
		"aim": "/input/aim/pose", "select": "/input/trigger/value",
		"reposition": "/input/squeeze/value", "play_chord": "/input/a/click",
		"clear": "/input/b/click",
	}
	for action_name in expected:
		var found := false
		for binding: OpenXRIPBinding in profile.bindings:
			if binding.action.resource_name == action_name and binding.binding_path == "/user/hand/right" + expected[action_name]:
				found = true
		_check(found, "Right controller binding exists for " + action_name)


func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _playing_voices(audio: AudioManager) -> int:
	var count := 0
	for voice in audio.get_children():
		if voice.playing:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
