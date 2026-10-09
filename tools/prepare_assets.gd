extends SceneTree
## Offline setup only. Runtime audio uses the generated WAV files.


func _initialize() -> void:
	_create_action_map()
	_create_note_samples()
	quit()


func _create_action_map() -> void:
	var action_map := OpenXRActionMap.new()
	var action_set := OpenXRActionSet.new()
	action_set.resource_name = "chord_lab"
	action_set.localized_name = "Chord Lab"
	var actions: Dictionary[String, OpenXRAction] = {}
	for definition in [
		["aim", "Pointer pose", OpenXRAction.OPENXR_ACTION_POSE],
		["select", "Select a note", OpenXRAction.OPENXR_ACTION_FLOAT],
		["play_chord", "Hear selected notes", OpenXRAction.OPENXR_ACTION_BOOL],
		["clear", "Clear selection", OpenXRAction.OPENXR_ACTION_BOOL],
		["reposition", "Place keyboard in front", OpenXRAction.OPENXR_ACTION_FLOAT],
	]:
		var action := OpenXRAction.new()
		action.resource_name = definition[0]
		action.localized_name = definition[1]
		action.action_type = definition[2]
		action.toplevel_paths = PackedStringArray(["/user/hand/left", "/user/hand/right"])
		action_set.add_action(action)
		actions[definition[0]] = action
	action_map.add_action_set(action_set)
	var touch := OpenXRInteractionProfile.new()
	touch.interaction_profile_path = "/interaction_profiles/oculus/touch_controller"
	for hand in ["left", "right"]:
		var hand_path: String = "/user/hand/" + hand
		_bind(touch, actions["aim"], hand_path + "/input/aim/pose")
		_bind(touch, actions["select"], hand_path + "/input/trigger/value")
		_bind(touch, actions["reposition"], hand_path + "/input/squeeze/value")
		_bind(touch, actions["play_chord"], hand_path + ("/input/x/click" if hand == "left" else "/input/a/click"))
		_bind(touch, actions["clear"], hand_path + ("/input/y/click" if hand == "left" else "/input/b/click"))
	action_map.add_interaction_profile(touch)
	# A simple-controller profile also supports basic selection on other runtimes.
	var simple := OpenXRInteractionProfile.new()
	simple.interaction_profile_path = "/interaction_profiles/khr/simple_controller"
	for hand in ["left", "right"]:
		var hand_path: String = "/user/hand/" + hand
		_bind(simple, actions["aim"], hand_path + "/input/aim/pose")
		_bind(simple, actions["select"], hand_path + "/input/select/click")
	action_map.add_interaction_profile(simple)
	DirAccess.make_dir_recursive_absolute("res://xr")
	var save_error := ResourceSaver.save(action_map, "res://xr/action_map.tres")
	assert(save_error == OK, "Could not save the OpenXR action map")


func _bind(profile: OpenXRInteractionProfile, action: OpenXRAction, path: String) -> void:
	var binding := OpenXRIPBinding.new()
	binding.action = action
	binding.binding_path = path
	var bindings := profile.bindings.duplicate()
	bindings.append(binding)
	profile.bindings = bindings


func _create_note_samples() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for midi_note in [60, 64, 67]:
		var sample := AudioStreamWAV.new()
		sample.format = AudioStreamWAV.FORMAT_16_BITS
		sample.mix_rate = 44100
		var duration := 1.6
		var frame_count := int(duration * sample.mix_rate)
		var pcm := PackedByteArray()
		pcm.resize(frame_count * 2)
		var frequency := 440.0 * pow(2.0, (midi_note - 69) / 12.0)
		for frame in range(frame_count):
			var time := float(frame) / sample.mix_rate
			var envelope := minf(time / 0.008, 1.0) * exp(-3.5 * time)
			envelope *= minf((duration - time) / 0.05, 1.0)
			var tone := sin(TAU * frequency * time) + 0.25 * sin(TAU * frequency * 2.0 * time)
			var value := int(tone * envelope * 0.38 * 32767.0)
			pcm.encode_s16(frame * 2, value)
		sample.data = pcm
		var save_error := sample.save_to_wav("res://assets/audio/note_%d.wav" % midi_note)
		assert(save_error == OK, "Could not save note sample")
