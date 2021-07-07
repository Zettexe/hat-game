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

var _font: = preload("res://fonts/montreal/Montreal.tres") # DEBUG
var _velocity: = Vector2()
var _current_speed_target: = speed_target
var _current_acceleration: = acceleration
var _current_gravity: = gravity
var _wallrunning: = false
onready var _sprite: Sprite = $Sprite
onready var _timer: Timer = $Timer
onready var _tilemap: = $"../TileMap"
onready var node = get_parent().get_node("UILayer/UI")

func _ready():
	node.connect("draw", self, "_draw_UI", [node])

func _physics_process(delta):
	
	var is_jump_interrupted = Input.is_action_just_released("jump") and _velocity.y < 0.0
	var direction: = get_direction()
	_velocity = calculate_jump(_velocity, direction, false)
	
	_velocity = calculate_slide(_velocity, delta)
	_velocity = calculate_wallrun(_velocity)
	_velocity = calculate_move_velocity(_velocity, delta)
	
	_velocity = move_and_slide(_velocity, Vector2.UP)
	
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
		out.y = move_toward(out.y, 0, wallrun_stopping_speed * delta)
	else: 
		out.y += _current_gravity * delta 
	
	return out

func calculate_jump(linear_velocity: Vector2, direction: Vector2, is_jump_interrupted: bool):
	if not is_on_floor() and not _wallrunning: return linear_velocity
	
	var out: = linear_velocity
	
	if direction.y == -1.0:
		var _jump_force = jump_force
		if _wallrunning:
			_jump_force = wallrun_jump_force 
			out.x += wallrun_speed_boost
		out.y = _jump_force * direction.y
		_timer.stop()
	if is_jump_interrupted:
		out.y = 0.0
			
	return out

func calculate_slide(linear_velocity: Vector2, delta: float):
	var out: = linear_velocity
	
	if Input.is_action_just_pressed("slide") and is_on_floor() and _timer.is_stopped():
		out.x += slide_speed_boost
		_current_speed_target = 0
		_sprite.centered = false
		_sprite.rotation_degrees = -90.0
		_timer.start(0.0035 * slide_speed_boost)
	
	var temp_acceleration = acceleration
	
	if !is_on_floor():
		_current_speed_target = speed_target
		temp_acceleration *= wallrun_acceleration_modifier if is_on_background() and _wallrunning else air_acceleration_modifier
	else:
		if not Input.is_action_pressed("slide") and _timer.is_stopped():
			_current_speed_target = speed_target
			
	
	_current_acceleration = temp_acceleration * (_velocity.x / 400)
	
	if _current_speed_target != 0:
		_sprite.centered = true
		_sprite.rotation_degrees = 0.0
	
	return out

func calculate_wallrun(linear_velocity: Vector2):
	if is_on_floor(): return linear_velocity
	
	var out = linear_velocity
	if Input.is_action_just_pressed("wallrun") and is_on_background():
		if wallrun_stopping_speed <= 0:
			out.y = 0
			_current_gravity = 0
		if wallrun_delay > 0:
			_timer.start(wallrun_delay)
		_wallrunning = true
	if not Input.is_action_pressed("wallrun") or not is_on_background() or Input.is_action_just_pressed("jump"):
		_timer.stop()
		_current_gravity = gravity
		_wallrunning = false
	
	return out

func _wallrun_delay_end():
	if _current_gravity == 0 and !is_on_floor(): _current_gravity = gravity * wallrun_gravity_modifier

func is_on_background():
	var cell_pos = _tilemap.world_to_map(position)
	return not _tilemap.get_cell(cell_pos.x, cell_pos.y) == -1

func _draw():
	if debug_mode:
		var real_acceleration = acceleration * (_velocity.x / 400)
		draw_line(Vector2(0, -2), Vector2(_velocity.x * 0.25 + 2, -2), Color.black, 7)
		draw_line(Vector2.ZERO, Vector2(0, _velocity.y * 0.25 + 2), Color.black, 6)
		draw_line(Vector2(0, -10), Vector2(real_acceleration * 0.25 + 2, -10), Color.black, 6)
		draw_line(Vector2(0, -10), Vector2(max(_current_acceleration, min_acceleration) * 0.25 + 2, -10), Color.black, 6)
		
		draw_line(Vector2(0, -2), Vector2(_velocity.x * 0.25, -2), Color.red, 3.0)
		draw_line(Vector2.ZERO, Vector2(0, _velocity.y * 0.25), Color.green, 2.0)
		draw_line(Vector2(0, -10), Vector2(real_acceleration * 0.25, -10), Color.cyan, 2.0)
		draw_line(Vector2(0, -10), Vector2(max(_current_acceleration, min_acceleration) * 0.25, -10), Color.yellow, 2.0)

func _draw_UI(node):
	if debug_mode:
		node.draw_string(_font, Vector2(10, 20), "Speed: %d" % [_velocity.x], Color.red)
		node.draw_string(_font, Vector2(10, 40), "Acc Modifier: %s" % ["None" if is_on_floor() else (wallrun_acceleration_modifier if is_on_background() and _wallrunning else air_acceleration_modifier)], Color.yellow)
		node.draw_string(_font, Vector2(10, 60), "Acceleration: %d" % [max(_current_acceleration, min_acceleration)], Color.cyan)
		node.draw_string(_font, Vector2(10, 80), "Gravity*: %d" % [_velocity.y], Color.green)
