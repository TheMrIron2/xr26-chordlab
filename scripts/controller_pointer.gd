class_name ControllerPointer
extends XRController3D
## Aim pose points along local -Z. Analogue hysteresis makes one squeeze one press.

signal play_requested
signal clear_requested
signal reposition_requested

const RAY_LENGTH := 3.0
const PRESS_THRESHOLD := 0.7
const RELEASE_THRESHOLD := 0.3

var enabled := false
var _trigger_held := false
var _grip_held := false
var _hovered_target: RayTarget
var _source: StringName

@onready var ray: RayCast3D = $RayCast3D
@onready var beam: MeshInstance3D = $Beam
@onready var tip: MeshInstance3D = $Tip


func _ready() -> void:
	# Assign after the hand tracker is configured so its default pose cannot replace aim.
	pose = &"aim"
	_source = StringName(name)
	button_pressed.connect(_on_button_pressed)
	_set_visuals_visible(false)


func _physics_process(_delta: float) -> void:
	if not enabled or not get_has_tracking_data():
		_set_hover(null)
		_set_visuals_visible(false)
		_trigger_held = false
		_grip_held = false
		return
	_set_visuals_visible(true)
	ray.force_raycast_update()
	var target := ray.get_collider() as RayTarget if ray.is_colliding() else null
	_set_hover(target)
	var distance := RAY_LENGTH
	if ray.is_colliding():
		distance = global_position.distance_to(ray.get_collision_point())
	beam.scale.y = distance
	beam.position.z = -distance / 2.0
	tip.position.z = -distance
	var trigger := get_float(&"select")
	if trigger >= PRESS_THRESHOLD and not _trigger_held:
		_trigger_held = true
		if _hovered_target:
			_hovered_target.activate()
	elif trigger <= RELEASE_THRESHOLD:
		_trigger_held = false
	var grip := get_float(&"reposition")
	if grip >= PRESS_THRESHOLD and not _grip_held:
		_grip_held = true
		reposition_requested.emit()
	elif grip <= RELEASE_THRESHOLD:
		_grip_held = false


func _set_hover(target: RayTarget) -> void:
	if target == _hovered_target:
		return
	if is_instance_valid(_hovered_target):
		_hovered_target.set_hovered(_source, false)
	_hovered_target = target
	if target:
		target.set_hovered(_source, true)


func _set_visuals_visible(value: bool) -> void:
	beam.visible = value
	tip.visible = value


func _on_button_pressed(action_name: String) -> void:
	if not enabled or not get_has_tracking_data():
		return
	match action_name:
		"play_chord":
			play_requested.emit()
		"clear":
			clear_requested.emit()
