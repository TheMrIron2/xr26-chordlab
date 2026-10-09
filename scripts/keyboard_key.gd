class_name KeyboardKey
extends StaticBody3D
## A large note target, shared by controller rays and desktop input.

signal selection_changed(midi_note: int, selected: bool)

@export var midi_note: int = 60
@export var note_name: String = "C4"
@export var role_name: String = "ROOT"
@export var accent_color := Color("69dec0")

var selected := false
var _hover_sources: Dictionary[StringName, bool] = {}
var _material: StandardMaterial3D
var _press_tween: Tween

@onready var visual: MeshInstance3D = $Visual


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.6
	visual.material_override = _material
	$NoteLabel.text = note_name
	$RoleLabel.text = role_name
	_refresh_color()


func activate() -> void:
	set_selected(not selected)
	if _press_tween and _press_tween.is_running():
		_press_tween.kill()
	visual.position.y = -0.008
	_press_tween = create_tween()
	_press_tween.tween_property(visual, "position:y", 0.0, 0.12)


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
	_material.albedo_color = accent_color if selected else Color("e7edf0")
	if not _hover_sources.is_empty():
		_material.albedo_color = _material.albedo_color.lerp(Color.WHITE, 0.35)
	_material.emission_enabled = selected or not _hover_sources.is_empty()
	_material.emission = accent_color * (0.3 if selected else 0.12)
