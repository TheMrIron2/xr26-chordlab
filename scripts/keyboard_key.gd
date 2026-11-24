class_name KeyboardKey
extends RayTarget
## A piano key shared by controller rays and desktop input.

signal selection_changed(midi_note: int, selected: bool)

@export var midi_note: int = 60
@export var note_name: String = "C4"
@export var flat_name: String
@export var accent_color := Color("69dec0")

const BLACK_KEY_SIZE := Vector3(0.066, 0.045, 0.165)
const LIGHT_KEY := Color("e7edf0")
const DARK_KEY := Color("223048")
const DARK_INK := Color("0e1721")

var selected := false
var interaction_enabled := true
var _guided := false
var _demonstrated := false
var _hover_sources: Dictionary[StringName, bool] = {}
var _material: StandardMaterial3D
var _press_tween: Tween

@onready var visual: MeshInstance3D = $Visual
@onready var note_label: Label3D = $Visual/NoteLabel


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.6
	visual.material_override = _material
	note_label.text = note_name
	if not flat_name.is_empty():
		var box := visual.mesh as BoxMesh
		var hitbox := $CollisionShape3D.shape as BoxShape3D
		box.size = BLACK_KEY_SIZE
		hitbox.size = BLACK_KEY_SIZE
		note_label.position = Vector3(0, BLACK_KEY_SIZE.y / 2.0 + 0.002, 0.023)
		note_label.font_size = 40
		note_label.text = "%s\n%s" % [note_name, flat_name]
	_refresh_color()


func activate() -> void:
	if not interaction_enabled:
		return
	set_selected(not selected)
	_animate_press()


func _animate_press() -> void:
	if _press_tween and _press_tween.is_running():
		_press_tween.kill()
	visual.position.y = -0.008
	_press_tween = create_tween()
	_press_tween.tween_property(visual, "position:y", 0.0, 0.12)


func set_lesson_highlight(guided: bool, demonstrated: bool) -> void:
	if demonstrated and not _demonstrated:
		_animate_press()
	_guided = guided
	_demonstrated = demonstrated
	_refresh_color()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	_refresh_color()
	selection_changed.emit(midi_note, selected)


func set_hovered(source: StringName, value: bool) -> void:
	# Each hand owns its hover state so one ray cannot clear the other ray's highlight.
	if value:
		_hover_sources[source] = true
	else:
		_hover_sources.erase(source)
	_refresh_color()


func _refresh_color() -> void:
	if not _material:
		return
	var is_black := not flat_name.is_empty()
	var hovered := interaction_enabled and not _hover_sources.is_empty()
	var base_color := DARK_KEY if is_black else LIGHT_KEY
	if _guided:
		base_color = base_color.lerp(Color("efba66"), 0.68)
	_material.albedo_color = accent_color if selected else base_color
	if _demonstrated:
		_material.albedo_color = Color("ffbf65")
	if hovered:
		var hover_color := Color.WHITE if selected else accent_color
		_material.albedo_color = _material.albedo_color.lerp(hover_color, 0.32)
	note_label.modulate = LIGHT_KEY if is_black and not (selected or _guided or _demonstrated) else DARK_INK
	_material.emission_enabled = selected or hovered or _demonstrated
	_material.emission = Color("efba66") * 0.42 if _demonstrated else accent_color * (0.3 if selected else 0.12)
