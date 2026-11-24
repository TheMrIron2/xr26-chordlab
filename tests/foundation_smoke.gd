extends SceneTree
## Integration checks use real scene colliders and synthetic XR tracking data.
## They do not validate an OpenXR runtime or a physical headset.

var _failures := 0
var _checks := 0

const MAJOR := ChordValidator.Quality.MAJOR
const MINOR := ChordValidator.Quality.MINOR
const BLACK_NOTES := [61, 63, 66, 68, 70, 73]
const Mode := LessonFlow.Mode


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
	for child in lab.keyboard.get_children():
		keys.append(child)
	_check(keys.size() == 15, "Chromatic keyboard contains 15 keys")
	if keys.size() != 15:
		quit(1)
		return
	_check(keys[0].note_name == "C4" and keys[14].note_name == "D5", "Keyboard labels show both ends of the range")
	for index in range(keys.size()):
		var key := keys[index]
		_check(key.midi_note == 60 + index, "Keyboard MIDI notes are contiguous and ordered")
		_check(key.flat_name.is_empty() != BLACK_NOTES.has(key.midi_note), "Piano layout correctly classifies " + key.note_name)
	_check(keys[3].note_label.text == "D♯4\nE♭4", "Black keys display sharp and flat names")
	_check_validator()
	lab.lesson.enter_free_play()
	_check_desktop(lab, keys)
	await _check_controller(lab, keys, &"right_hand", XRPositionalTracker.TRACKER_HAND_RIGHT, "RightHand", 0.2)
	await _check_controller(lab, keys, &"left_hand", XRPositionalTracker.TRACKER_HAND_LEFT, "LeftHand", -0.2)
	_check_action_map()
	await _check_lessons(lab, keys)
	print("Chord Lab smoke: %d checks, %d failures." % [_checks, _failures])
	lab.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _check_lessons(lab: ChordLab, keys: Array[KeyboardKey]) -> void:
	var flow := lab.lesson
	await _lesson_button(lab, &"restart")
	_check(flow.mode == Mode.INTRO and flow.stage_index == 0, "Restart opens the first lesson")
	await _capture("01-triads")
	_press_key(KEY_1)
	_check(lab.selected_notes().is_empty(), "The keyboard waits for the demonstration")
	await _controller_button(lab, &"demo", true)
	_check(flow.mode == Mode.DEMO, "Right trigger starts the lesson demo")
	await create_timer(0.20).timeout
	_check_demo_frame(lab, [60], "C is the root")
	await _lesson_button(lab, &"demo")
	await create_timer(0.20).timeout
	_check_demo_frame(lab, [60], "C is the root")
	_press_key(KEY_C)
	_check(flow.mode == Mode.INTRO and _playing_samples(lab.audio).is_empty(),
		"Clear interrupts the demo and stops all voices")
	await create_timer(0.95).timeout
	_check(flow.mode == Mode.INTRO and _playing_samples(lab.audio).is_empty(),
		"Cancelled callbacks cannot play old notes or advance the exercise")
	await _lesson_button(lab, &"demo")
	await _wait_for_caption(lab, "E is the third")
	_check_demo_frame(lab, [64], "E is the third")
	await _wait_for_caption(lab, "G is the fifth")
	_check_demo_frame(lab, [67], "G is the fifth")
	await _wait_for_caption(lab, "Together they make C major")
	_check_demo_frame(lab, [60, 64, 67], "Together they make C major")
	await _capture("01b-triads-demo")
	await _wait_for_caption(lab, "Select three keys.")
	_check(flow.mode == Mode.PRACTICE and keys[0]._guided and keys[4]._guided
		and keys[7]._guided and not keys[3]._guided, "C major practice guides exactly the chord tones")
	_check(_playing_samples(lab.audio).is_empty() and lab.selected_notes().is_empty(),
		"Demo-to-practice clears audio and the learner starts with no answer")
	await _capture("01c-triads-practice")
	await _lesson_button(lab, &"check")
	_check(flow.mode == Mode.PRACTICE and lab.status.text.contains("before checking"),
		"An empty answer cannot advance the first lesson")
	_choose_notes(lab, keys, [67, 60, 64])
	await _controller_button(lab, &"check", false)
	_check(flow.mode == Mode.CORRECT and lab.status.text.contains("C major"),
		"Left trigger checks and accepts the guided chord")
	await _lesson_button(lab, &"next")
	_check(flow.stage_index == 1 and lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty(),
		"Continuing to the second lesson resets selection and audio")
	await _lesson_button(lab, &"demo")
	await _wait_for_caption(lab, "C major  ·  C  E  G")
	_check_demo_frame(lab, [60, 64, 67], "C major  ·  C  E  G")
	await _wait_for_caption(lab, "E♭ is 3 semitones above C")
	_check_demo_frame(lab, [63], "E♭ is 3 semitones above C")
	await _wait_for_caption(lab, "C minor  ·  C  E♭  G")
	_check_demo_frame(lab, [60, 63, 67], "C minor  ·  C  E♭  G")
	await _capture("02-major-and-minor")
	await _wait_for_caption(lab, "Select three keys.")
	await _capture("02b-interval-patterns")
	_choose_notes(lab, keys, [60, 64, 67])
	await _lesson_button(lab, &"check")
	_check(flow.mode == Mode.PRACTICE and lab.status.text.contains("3 steps"),
		"C major in the minor exercise gives feedback about the third")
	await _lesson_button(lab, &"demo")
	_check(lab.selected_notes().is_empty(), "Replaying from practice clears the previous answer")
	await _wait_for_caption(lab, "Select three keys.")
	_choose_notes(lab, keys, [72, 67, 63])
	await _lesson_button(lab, &"check")
	_check(flow.mode == Mode.CORRECT, "C minor with the root an octave higher passes")
	await _lesson_button(lab, &"next")
	for key in keys:
		_check(not key._guided and not key._demonstrated, "Independent practice leaves " + key.note_name + " unmarked")
	var practice_answers := [[65, 69, 72], [67, 71, 74], [62, 65, 69]]
	for index in range(practice_answers.size()):
		_check(flow.mode == Mode.PRACTICE and flow.exercise_index == index
			and lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty(),
			"Independent exercise %d starts with a clean keyboard" % (index + 1))
		if index == 0:
			_choose_notes(lab, keys, [65, 69, 72, 74])
			await _lesson_button(lab, &"check")
			_check(flow.mode == Mode.PRACTICE and lab.status.text.contains("extras"),
				"An extra note prevents independent progression")
			_press_key(KEY_C)
			await _lesson_button(lab, &"hint")
			_check(lab.status.text.contains("4 and 7") and not keys[5]._guided,
				"Independent hint explains the intervals without highlighting the answer")
			await _capture("03-independent-practice")
		_choose_notes(lab, keys, practice_answers[index])
		await _lesson_button(lab, &"check")
		_check(flow.mode == Mode.CORRECT, "Correct practice chord passes")
		await _lesson_button(lab, &"next")
	_check(flow.mode == Mode.COMPLETE and flow.body.text.contains("F major  ·  2 tries  ·  hint used")
		and flow.body.text.contains("G major  ·  1 try") and flow.body.text.contains("D minor  ·  1 try"),
		"Completion shows attempts and hints for each independent exercise")
	_check(lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty()
		and lab.status.text.contains("4 + 7") and lab.status.text.contains("3 + 7"),
		"Completion clears the keyboard and recaps both patterns")
	_check(_find_button(lab, &"restart") != null, "The completion panel offers a restart")
	await _capture("04-completion")
	await _lesson_button(lab, &"free")
	_choose_notes(lab, keys, [60, 64, 67])
	_press_key(KEY_SPACE)
	_check(flow.mode == Mode.FREE_PLAY and _playing_samples(lab.audio).size() == 3,
		"Free play preserves polyphonic keyboard interaction")
	await _capture("05-free-play")
	await _lesson_button(lab, &"restart")
	_check(flow.mode == Mode.INTRO and flow.stage_index == 0 and flow._results.is_empty()
		and lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty(),
		"Restart clears results, notes, and voices and returns to lesson one")
	await _lesson_button(lab, &"demo")
	await create_timer(0.20).timeout
	flow.restart()
	await create_timer(0.95).timeout
	_check(flow.mode == Mode.INTRO and lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty()
		and not keys[0]._demonstrated, "Restarting during a demo clears its highlights and queued audio")


func _lesson_button(lab: ChordLab, action: StringName) -> void:
	await physics_frame
	var button := _find_button(lab, action)
	if button:
		var screen := lab.desktop_camera.unproject_position(button.global_position)
		_check(lab._target_at_screen_position(screen) == button, "Desktop ray hits the " + action + " button")
		_click(screen)


func _find_button(lab: ChordLab, action: StringName) -> LessonButton:
	for button in lab.lesson._buttons:
		if button.visible and button.action == action:
			return button
	_check(false, "Visible lesson button exists for " + action)
	return null


func _controller_button(lab: ChordLab, action: StringName, right: bool) -> void:
	var button := _find_button(lab, action)
	if not button:
		return
	var pointer := lab.xr_origin.get_node("RightHand" if right else "LeftHand") as ControllerPointer
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = &"right_hand" if right else &"left_hand"
	tracker.hand = XRPositionalTracker.TRACKER_HAND_RIGHT if right else XRPositionalTracker.TRACKER_HAND_LEFT
	tracker.set_input(&"select", 0.0)
	XRServer.add_tracker(tracker)
	pointer.enabled = true
	_aim_controller(tracker, lab.station.to_global(Vector3(0.16 if right else -0.16, 0.25, 0.50)),
		button.global_position)
	await physics_frame
	await physics_frame
	_check(pointer.ray.get_collider() == button, "Synthetic controller ray hits the " + action + " button")
	tracker.set_input(&"select", 1.0)
	await physics_frame
	await physics_frame
	pointer.enabled = false
	XRServer.remove_tracker(tracker)


func _choose_notes(lab: ChordLab, keys: Array[KeyboardKey], notes: Array) -> void:
	for note: int in notes:
		_click(lab.desktop_camera.unproject_position(_aim_point(keys[note - 60])))


func _wait_for_caption(lab: ChordLab, caption: String) -> void:
	for index in range(110):
		if lab.status.text == caption:
			return
		await create_timer(0.05).timeout
	_check(false, "Reached lesson caption " + caption)


func _check_demo_frame(lab: ChordLab, notes: Array, caption: String) -> void:
	var playing := _playing_samples(lab.audio)
	var highlighted: Array[int] = []
	for key: KeyboardKey in lab.keyboard.get_children():
		if key._demonstrated:
			highlighted.append(key.midi_note)
	var expected_samples: Array[AudioStream] = []
	for note: int in notes:
		expected_samples.append(AudioManager.SAMPLES[note])
	_check(lab.status.text == caption and lab.selected_notes().is_empty() and highlighted == notes
		and playing.size() == notes.size() and expected_samples.all(playing.has),
		"Demo highlights and plays the expected pitches without selecting them")


func _capture(filename: String) -> void:
	if "--capture-lessons" not in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "Lesson screenshots require a rendered desktop run")
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var folder := "res://builds/lesson-review"
	DirAccess.make_dir_recursive_absolute(folder)
	if not FileAccess.file_exists(folder.path_join(".gdignore")):
		var ignore := FileAccess.open(folder.path_join(".gdignore"), FileAccess.WRITE)
		if ignore:
			ignore.close()
	var image := root.get_texture().get_image()
	_check(image.save_png("%s/%s.png" % [folder, filename]) == OK, "Saved screenshot " + filename)


func _check_desktop(lab: ChordLab, keys: Array[KeyboardKey]) -> void:
	for key in keys:
		var screen_position := lab.desktop_camera.unproject_position(_aim_point(key))
		_check(lab._target_at_screen_position(screen_position) == key, "Desktop ray reaches " + key.note_name)
		var material := key.visual.material_override as StandardMaterial3D
		var initial_color := material.albedo_color
		_click(screen_position)
		_check(key.selected and material.albedo_color != initial_color, "Click selects and highlights " + key.note_name)
		_check(_playing_samples(lab.audio).has(AudioManager.SAMPLES.get(key.midi_note)), "Click starts the sample for " + key.note_name)
		_click(screen_position)
		_check(not key.selected and material.albedo_color == initial_color, "Second click deselects " + key.note_name)
	for code in [KEY_3, KEY_1, KEY_2]:
		_press_key(code)
	_check(lab.selected_notes() == [60, 64, 67], "Keyboard input produces order-independent selection")
	_press_key(KEY_SPACE)
	var playing := _playing_samples(lab.audio)
	_check(playing.size() == 3 and playing.has(AudioManager.SAMPLES[60])
		and playing.has(AudioManager.SAMPLES[64]) and playing.has(AudioManager.SAMPLES[67]),
		"Playback starts exactly the selected triad samples together")
	_check(lab.status.text == "Hearing C major", "Playing the selection identifies the major triad")
	_press_key(KEY_2)
	_press_key(KEY_SPACE)
	_check(lab.status.text == "Select three notes to make a triad.", "Playing a partial triad asks for the missing note")
	_click(lab.desktop_camera.unproject_position(_aim_point(keys[1])))
	_press_key(KEY_SPACE)
	_check(lab.status.text == "Try changing a note to make a major or minor triad.",
		"A three-note selection with the wrong intervals receives a retry prompt")
	_click(lab.desktop_camera.unproject_position(_aim_point(keys[1])))
	_click(lab.desktop_camera.unproject_position(_aim_point(keys[3])))
	_press_key(KEY_SPACE)
	_check(lab.status.text == "Hearing C minor", "Replacing E with E flat identifies the minor triad")
	for key in keys:
		if not key.selected:
			_click(lab.desktop_camera.unproject_position(_aim_point(key)))
	_press_key(KEY_SPACE)
	playing = _playing_samples(lab.audio)
	_check(playing.size() == 15, "All 15 pitches can play at the same time")
	for key in keys:
		var sample := AudioManager.SAMPLES.get(key.midi_note) as AudioStreamWAV
		_check(sample != null and sample.get_length() > 1.0 and playing.has(sample),
			"Full keyboard playback includes the packaged sample for " + key.note_name)
	_check(lab.status.text == "A triad has three notes. Deselect the extras.", "Playing an oversized selection asks the learner to remove extra notes")
	_press_key(KEY_C)
	_check(lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty(), "Clear input resets selection and stops audio")
	_check(lab.selection_label.text == "No notes selected", "Clear restores the selection label")
	_press_key(KEY_SPACE)
	_check(lab.status.text == "Select a note first.", "Empty playback gives useful feedback")


func _check_validator() -> void:
	for root_note in range(60, 72):
		_check(ChordValidator.matches([root_note + 7, root_note, root_note + 4], root_note, MAJOR),
			"Major intervals transpose and accept any order")
		_check(ChordValidator.matches([root_note + 3, root_note + 7, root_note], root_note, MINOR),
			"Minor intervals transpose and accept any order")
	_check(ChordValidator.matches([64, 67, 72], 60, MAJOR), "Pitch classes accept an inversion and octave displacement")
	_check(ChordValidator.matches([65, 69, 74], 62, MINOR), "D minor can use D5 as its root")
	_check(not ChordValidator.matches([60, 63, 67], 60, MAJOR), "A minor third fails major validation")
	_check(not ChordValidator.matches([60, 64, 67], 60, MINOR), "A major third fails minor validation")
	_check(not ChordValidator.matches([60, 64], 60, MAJOR), "Missing fifth fails validation")
	_check(not ChordValidator.matches([60, 64, 67, 70], 60, MAJOR), "A seventh counts as an extra note")
	_check(not ChordValidator.matches([60, 64, 67, 72], 60, MAJOR), "An octave doubling counts as an extra selected key")
	_check(not ChordValidator.matches([60, 64, 72], 60, MAJOR), "A duplicate pitch class cannot replace the fifth")
	_check(not ChordValidator.matches([60, 64, 66], 60, MAJOR), "A wrong fifth fails validation")
	_check(not ChordValidator.matches([60, -8, 67], 60, MAJOR), "Invalid MIDI pitches fail validation")


func _check_controller(lab: ChordLab, keys: Array[KeyboardKey], tracker_name: StringName,
		hand: XRPositionalTracker.TrackerHand, pointer_name: String, x_offset: float) -> void:
	var tracker := XRControllerTracker.new()
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.name = tracker_name
	tracker.hand = hand
	tracker.set_input(&"select", 0.0)
	tracker.set_input(&"reposition", 0.0)
	XRServer.add_tracker(tracker)
	var pointer := lab.xr_origin.get_node(pointer_name) as ControllerPointer
	pointer.enabled = true
	var origin := lab.station.to_global(Vector3(x_offset, 0.24, 0.48))
	for target_key in keys:
		_aim_controller(tracker, origin, _aim_point(target_key))
		await physics_frame
		await physics_frame
		_check(pointer.ray.get_collider() == target_key, "%s ray reaches %s" % [pointer_name, target_key.note_name])
	var key := keys[3]
	_aim_controller(tracker, origin, _aim_point(key))
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
	keys[0].activate()
	keys[7].activate()
	key.activate()
	tracker.set_input(&"play_chord", true)
	_check(lab.status.text == "Hearing C minor" and _playing_samples(lab.audio).size() == 3,
		"Controller face button plays and identifies the same triad as desktop")
	tracker.set_input(&"clear", true)
	_check(lab.selected_notes().is_empty() and _playing_samples(lab.audio).is_empty(),
		"Controller face button clears selection and stops playback")
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


func _aim_point(key: KeyboardKey) -> Vector3:
	var top := 0.025 if key.flat_name.is_empty() else 0.0225
	var front := 0.10 if key.flat_name.is_empty() else 0.0
	return key.to_global(Vector3(0, top, front))


func _aim_controller(tracker: XRControllerTracker, origin: Vector3, target: Vector3) -> void:
	var transform := Transform3D(Basis.looking_at(target - origin), origin)
	tracker.set_pose(&"aim", transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)


func _check_action_map() -> void:
	var action_map := load("res://xr/action_map.tres") as OpenXRActionMap
	_check(action_map != null, "Committed action map loads")
	if action_map == null:
		return
	var profile := action_map.find_interaction_profile("/interaction_profiles/oculus/touch_controller")
	_check(profile != null and profile.get_binding_count() == 10, "Quest bindings survive resource serialization")
	if profile == null:
		return
	for hand in ["left", "right"]:
		var expected := {
			"aim": "/input/aim/pose", "select": "/input/trigger/value",
			"reposition": "/input/squeeze/value",
			"play_chord": "/input/x/click" if hand == "left" else "/input/a/click",
			"clear": "/input/y/click" if hand == "left" else "/input/b/click",
		}
		for action_name in expected:
			var found := false
			for binding: OpenXRIPBinding in profile.bindings:
				if binding.action.resource_name == action_name and binding.binding_path == "/user/hand/" + hand + expected[action_name]:
					found = true
			_check(found, "%s controller binding exists for %s" % [hand, action_name])


func _click(screen_position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = screen_position
		event.pressed = pressed
		root.push_input(event, true)


func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _playing_samples(audio: AudioManager) -> Array[AudioStream]:
	var samples: Array[AudioStream] = []
	for voice in audio.get_children():
		if voice.playing:
			samples.append(voice.stream)
	return samples


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
