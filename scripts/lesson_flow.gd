class_name LessonFlow
extends Node

enum Mode { INTRO, DEMO, PRACTICE, CORRECT, COMPLETE, FREE_PLAY }

var mode := Mode.INTRO
var stage_index := 0
var exercise_index := 0
var _attempts := 0
var _hint_used := false
var _results: Array[String] = []
var _demo: Tween
var _title_tween: Tween
var _buttons: Array[LessonButton] = []

@onready var lab := get_parent() as ChordLab
@onready var panel: Node3D = lab.get_node("Station/Panel")
@onready var eyebrow: Label3D = panel.get_node("Eyebrow")
@onready var title: Label3D = panel.get_node("Title")
@onready var body: Label3D = panel.get_node("Explanation")


func _ready() -> void:
	for index in range(3):
		var button := LessonButton.new()
		button.position = Vector3((index - 1) * 0.31, -0.177, 0.028)
		panel.add_child(button)
		button.pressed.connect(_on_button)
		_buttons.append(button)


func restart() -> void:
	_results.clear()
	stage_index = 0
	exercise_index = 0
	_show_exercise()


func enter_free_play() -> void:
	mode = Mode.FREE_PLAY
	_reset_keyboard()
	_render("CHORD LAB  /  FREE PLAY", "Play any chord",
		"Explore the keyboard and hear your notes together.\nTry making a major chord into a minor chord.")
	_set_buttons([], [], ["Restart lessons", &"restart"])
	lab.status.text = "Choose a note to hear it."


func clear() -> void:
	if mode == Mode.DEMO:
		_show_intro()
		lab.status.text = "Demo cleared. Play it again when ready."
		return
	_reset_keyboard()
	if mode == Mode.PRACTICE:
		lab.set_lesson_keyboard(true, _stage().get("guide", []))
	if mode in [Mode.PRACTICE, Mode.FREE_PLAY]:
		lab.status.text = "Selection cleared."


func _show_exercise() -> void:
	_attempts = 0
	_hint_used = false
	if _stage().has("demo"):
		_show_intro()
	else:
		_show_practice()


func _show_intro() -> void:
	mode = Mode.INTRO
	_reset_keyboard()
	var stage := _stage()
	_render(_stage_label(), stage.title, stage.intro)
	_set_buttons([], [], ["Play demo", &"demo"])
	lab.status.text = "Watch the gold keys and listen."


func _play_demo() -> void:
	mode = Mode.DEMO
	_reset_keyboard()
	var stage := _stage()
	_render(_stage_label(), stage.title, stage.intro)
	_set_buttons([], [], ["Replay demo", &"demo"])
	_demo = create_tween()
	for step: Dictionary in stage.demo:
		_demo.tween_callback(_demo_step.bind(step))
		_demo.tween_interval(step.seconds)
	_demo.tween_callback(_finish_demo)


func _finish_demo() -> void:
	_demo = null
	_show_practice()


func _demo_step(step: Dictionary) -> void:
	var notes: Array[int] = []
	notes.assign(step.notes)
	lab.set_lesson_keyboard(false, [], notes)
	lab.audio.play_notes(notes)
	lab.status.text = step.caption


func _show_practice() -> void:
	mode = Mode.PRACTICE
	_reset_keyboard()
	var stage := _stage()
	var guide: Array = stage.get("guide", [])
	lab.set_lesson_keyboard(true, guide)
	var copy: String = stage.practice
	if stage.get("record_results", false):
		var exercise := _exercise()
		copy = copy % [lab.note_name_for(exercise.root), exercise.name]
	_render(_stage_label(), stage.title, copy)
	var replay := ["Replay demo", &"demo"] if stage.has("demo") else []
	_set_buttons(replay, ["Hint", &"hint"], ["Check answer", &"check"])
	lab.status.text = "Select three keys."


func _check_answer() -> void:
	var notes := lab.selected_notes()
	if notes.is_empty():
		lab.status.text = "Select three keys before checking."
		return
	_attempts += 1
	var exercise := _exercise()
	if not ChordValidator.matches(notes, exercise.root, exercise.quality):
		lab.status.text = _answer_feedback(notes, exercise)
		return
	mode = Mode.CORRECT
	lab.audio.play_notes(notes)
	lab.set_lesson_keyboard(false, [], notes)
	lab.status.text = "Correct! You made %s." % exercise.name
	if _stage().get("record_results", false):
		var attempt_text := "1 try" if _attempts == 1 else "%d tries" % _attempts
		var hint_text := "  ·  hint used" if _hint_used else ""
		_results.append("%s  ·  %s%s" % [exercise.name, attempt_text, hint_text])
	_set_buttons([], [], ["Continue", &"next"])


func _answer_feedback(notes: Array[int], exercise: Dictionary) -> String:
	if notes.size() < 3:
		return "A triad needs three notes. Add another key."
	if notes.size() > 3:
		return "A triad needs three notes. Remove the extras."
	var intervals: Array[int] = []
	for note in notes:
		intervals.append(posmod(note - int(exercise.root), 12))
	if not intervals.has(0):
		return "Include the root, %s." % lab.pitch_name(exercise.root)
	var third: int = ChordValidator.INTERVALS[exercise.quality][1]
	if not intervals.has(third):
		return "Try a third %d steps above the root." % third
	return "The fifth is 7 steps above the root."


func _show_hint() -> void:
	_hint_used = true
	var exercise := _exercise()
	var third: int = ChordValidator.INTERVALS[exercise.quality][1]
	lab.status.text = "Start at %s. Count %d and 7 steps from there." % [lab.note_name_for(exercise.root), third]


func _advance() -> void:
	exercise_index += 1
	if exercise_index >= _stage().exercises.size():
		stage_index += 1
		exercise_index = 0
	if stage_index < LessonData.STAGES.size():
		_show_exercise()
		return
	mode = Mode.COMPLETE
	_reset_keyboard()
	_render("CHORD LAB  /  COMPLETE", "You built major and minor triads",
		"\n".join(_results))
	_set_buttons(["Restart lessons", &"restart"], [], ["Free play", &"free"])
	lab.status.text = "From the root, count 4 + 7 for major or 3 + 7 for minor."


func _reset_keyboard() -> void:
	if _demo and _demo.is_running():
		_demo.kill()
	lab.reset_selection()
	lab.set_lesson_keyboard(mode in [Mode.PRACTICE, Mode.FREE_PLAY])


func _render(badge: String, heading: String, copy: String) -> void:
	eyebrow.text = badge
	var changed := title.text != heading
	title.text = heading
	body.text = copy
	if changed:
		if _title_tween and _title_tween.is_running():
			_title_tween.kill()
		title.modulate.a = 0.45
		_title_tween = create_tween()
		_title_tween.tween_property(title, "modulate:a", 1.0, 0.22)


func _set_buttons(left: Array = [], center: Array = [], right: Array = []) -> void:
	var entries := [left, center, right]
	for index in range(_buttons.size()):
		var entry: Array = entries[index]
		if entry.is_empty():
			_buttons[index].configure()
		else:
			_buttons[index].configure(entry[0], entry[1], index == 2)


func _on_button(action: StringName) -> void:
	match action:
		&"demo": _play_demo()
		&"check": _check_answer()
		&"hint": _show_hint()
		&"next": _advance()
		&"restart": restart()
		&"free": enter_free_play()


func _stage() -> Dictionary:
	return LessonData.STAGES[stage_index]


func _exercise() -> Dictionary:
	return _stage().exercises[exercise_index]


func _stage_label() -> String:
	var label := "LESSON %d / %d" % [stage_index + 1, LessonData.STAGES.size()]
	if _stage().get("record_results", false):
		label += "  ·  EXERCISE %d / %d" % [exercise_index + 1, _stage().exercises.size()]
	return label
