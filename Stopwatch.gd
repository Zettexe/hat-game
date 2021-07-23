extends KinematicBody2D

var font = preload("res://fonts/montreal/Montreal.tres") # DEBUG
var timer = 1.0
var timeout = false
onready var lag_compensation = OS.get_ticks_msec()

onready var node = get_parent().get_node("UILayer/UI")
onready var player = get_parent().get_node("Player")

func _ready():
	node.connect("draw", self, "_draw_UI", [node])

func _process(delta):
	if(player.position.x < position.x):
		timer = OS.get_ticks_msec() - lag_compensation

func _draw_UI(node):
	node.draw_string(font, Vector2(10, 20), "%s" % [Engine.get_frames_per_second()])
	node.draw_string(font, Vector2(10, 40), "%s:%s" % [timer / 1000, fmod(timer / 1000.0, 1) * 1000.0])
