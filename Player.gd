extends KinematicBody2D

export var debug_mode = false
export var speed_target: = 300.0
export var gravity: = 1000.0
export var acceleration: = 250.0
export var min_acceleration: = 100.0
export var air_acceleration_modifier: = 0.25
export var jump_force: = 400.0
export var slide_speed_boost: = 150.0
export var wallrun_gravity_modifier: = 0.1
export var wallrun_jump_force: = 200.0
export var wallrun_speed_boost: = 150.0
export var wallrun_delay: = 0.5
export var wallrun_acceleration_modifier: = 0.1
export var wallrun_stopping_speed: = 1000.0
export var snap_distance: = 0
export var max_consecutive_slides: = 1
export var wallrun_coyote_time: = 0.1

var _font: = preload("res://fonts/montreal/Montreal.tres") # DEBUG
var _velocity: = Vector2()
var _current_speed_target: = speed_target
var _current_acceleration: = acceleration
var _current_gravity: = gravity
var _wallrunning: = false
var _slide_count: = 0
var _finished_wallrun_slide = false
onready var _sprite: Sprite = $Sprite
onready var _timer: Timer = $Timer
onready var _coyote_timer: Timer = $CoyoteTimer
onready var _tilemap: = $"../TileMap"
onready var _rayshape: = $RayShape
onready var _capsule_shape: = $MainShape
onready var node = get_parent().get_node("UILayer/UI")

func _ready():
	node.connect("draw", self, "_draw_UI", [node])

func _physics_process(delta):
	var is_jump_interrupted = Input.is_action_just_released("jump") and _velocity.y < 0.0
	var direction: = get_direction()
	_velocity = calculate_jump(_velocity, direction, false)
	
	_velocity = calculate_slide(_velocity, delta)
	_velocity = calculate_move_velocity(_velocity, delta)
	_velocity = calculate_wallrun(_velocity)
	
	if _velocity.y >= 0 and test_move(transform, _velocity): 
		_rayshape.disabled = false
		_capsule_shape.position = Vector2(0, -25)
		_capsule_shape.shape.set_extents(Vector2(10, 15))
	
	_velocity = move_and_slide(_velocity, Vector2.UP) if snap_distance <= 0 or _velocity.y < 0 else move_and_slide_with_snap(_velocity, Vector2.DOWN * snap_distance, Vector2.UP)
		
	
	if debug_mode:
		update()
		node.update()

func get_direction() -> Vector2:
	return Vector2(
		1.0, 
		-1.0 if Input.is_action_just_pressed("jump") else 0.0
	)

func calculate_move_velocity(linear_velocity: Vector2, delta: float):
	var out: = linear_velocity
	out.x = move_toward(out.x, _current_speed_target, max(_current_acceleration, min_acceleration) * delta)
	
	if _wallrunning and wallrun_stopping_speed > 0:
		if out.y == 0:
			_finished_wallrun_slide = true
		if not _finished_wallrun_slide:
			out.y = move_toward(out.y, 0, wallrun_stopping_speed * delta)
		else:
			out.y += _current_gravity * delta
	else:
		out.y += _current_gravity * delta
	
	return out

func calculate_jump(linear_velocity: Vector2, direction: Vector2, is_jump_interrupted: bool):
	if not is_on_floor() and not _wallrunning and _coyote_timer.is_stopped(): return linear_velocity
	
	var out: = linear_velocity
	
	if direction.y == -1.0:
		var _jump_force = jump_force
		_rayshape.disabled = true
		_capsule_shape.position = Vector2(0, -20)
		_capsule_shape.shape.set_extents(Vector2(10, 20))
		if _wallrunning or not _coyote_timer.is_stopped():
			_jump_force = wallrun_jump_force 
			out.x += wallrun_speed_boost
		out.y = _jump_force * direction.y
		_coyote_timer.stop()
		_timer.stop()
	if is_jump_interrupted:
		out.y = 0.0
			
	return out

func calculate_slide(linear_velocity: Vector2, delta: float):
	var out: = linear_velocity
	
	if is_on_floor() and _timer.is_stopped():
		if Input.is_action_pressed("slide") and _slide_count < max_consecutive_slides:
			_slide_count += 1
			out.x += slide_speed_boost
			_current_speed_target = 0
			_sprite.centered = false
			_sprite.rotation_degrees = -90.0
			_timer.start(0.0035 * slide_speed_boost)
		if not Input.is_action_pressed("slide"):
			_current_speed_target = speed_target
	
	
	if Input.is_action_just_released("slide"):
		_slide_count = 0
	
	var temp_acceleration = acceleration
	
	if !is_on_floor():
		_current_speed_target = speed_target
		temp_acceleration *= wallrun_acceleration_modifier if is_on_background() and _wallrunning else air_acceleration_modifier
	
	
	_current_acceleration = temp_acceleration * (_velocity.x / 400)
	
	if _current_speed_target != 0:
		_sprite.centered = true
		_sprite.rotation_degrees = 0.0
	
	return out

func calculate_wallrun(linear_velocity: Vector2):
	if is_on_floor(): return linear_velocity
	
	var out = linear_velocity
	if Input.is_action_just_pressed("wallrun") and is_on_background():
		_current_gravity = 0
		if wallrun_stopping_speed <= 0:
			out.y = 0
		if wallrun_delay > 0:
			_timer.start(wallrun_delay)
		_wallrunning = true
	if _wallrunning and (not Input.is_action_pressed("wallrun") or not is_on_background() or Input.is_action_just_pressed("jump")):
		if not Input.is_action_just_pressed("jump"):
			_coyote_timer.start(wallrun_coyote_time)
		_timer.stop()
		_current_gravity = gravity
		_wallrunning = false
		_finished_wallrun_slide = false
	
	return out

func _wallrun_delay_end():
	if _wallrunning: _current_gravity = gravity * wallrun_gravity_modifier

func is_on_background():
	var cell_pos = _tilemap.world_to_map(position)
	return not _tilemap.get_cell(cell_pos.x, cell_pos.y) == -1

func _draw():
	if debug_mode:
		var real_acceleration = acceleration * (_velocity.x / 400)
		draw_line(Vector2(), _velocity * 0.25 + Vector2(1, 0), Color.black, 7.0)
		
		draw_line(Vector2(), _velocity * 0.25, Color.red, 3.0)
		if snap_distance > 0:
			draw_line(Vector2.ZERO, Vector2.DOWN * snap_distance, Color.green, 2.0)


func _draw_UI(node):
	if debug_mode:
		node.draw_string(_font, Vector2(10, 60), "Speed: %d" % [_velocity.x], Color.red)
		node.draw_string(_font, Vector2(10, 80), "Gravity*: %d" % [_velocity.y], Color.red)
		node.draw_string(_font, Vector2(10, 100), "Acc Modifier: %s" % ["None" if is_on_floor() else (wallrun_acceleration_modifier if is_on_background() and _wallrunning else air_acceleration_modifier)], Color.yellow)
		node.draw_string(_font, Vector2(10, 120), "Acceleration: %d" % [max(_current_acceleration, min_acceleration)], Color.cyan)
		if snap_distance > 0:
			node.draw_string(_font, Vector2(10, 140), "Snap Distance: %d" % [snap_distance], Color.green)

