class_name LessonButton
extends RayTarget

signal pressed(action: StringName)

const SIZE := Vector3(0.285, 0.075, 0.025)
const TEAL := Color("69dec0")
const NAVY := Color("20334a")

var action: StringName
var _primary := false
var _last_press_frame := -1
var _hover_sources: Dictionary[StringName, bool] = {}
var _material := StandardMaterial3D.new()
var _label := Label3D.new()


func _ready() -> void:
	collision_mask = 0
	var hitbox := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = SIZE
	hitbox.shape = shape
	add_child(hitbox)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	visual.mesh = box
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = _material
	add_child(visual)
	_label.position.z = 0.015
	_label.pixel_size = 0.0008
	_label.font_size = 34
	_label.outline_size = 0
	add_child(_label)
	configure()


func configure(caption: String = "", next_action: StringName = &"", primary: bool = false) -> void:
	action = next_action
	_primary = primary
	_label.text = caption
	visible = action != &""
	set_collision_layer_value(1, visible)
	_refresh()


func activate() -> void:
	var frame := Engine.get_physics_frames()
	if not visible or _last_press_frame == frame:
		return
	# Two rays can squeeze in the same tick while the button changes action.
	_last_press_frame = frame
	pressed.emit(action)


func set_hovered(source: StringName, value: bool) -> void:
	if value:
		_hover_sources[source] = true
	else:
		_hover_sources.erase(source)
	_refresh()


func _refresh() -> void:
	var base := TEAL if _primary else NAVY
	_material.albedo_color = base.lerp(Color.WHITE, 0.19) if not _hover_sources.is_empty() else base
	_label.modulate = Color("0e1721") if _primary else Color("e7edf0")
