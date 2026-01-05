extends Node2D

@onready var line_2d: Line2D = %Line2D

func _ready() -> void:
	var mid_x = line_2d.global_position.x
	var mid_y = line_2d.global_position.y
	var points: = line_2d.points
	print("[")
	for point in points:
		print("Vector2(",(point.x+mid_x)*0.6113455545838180228, ",", -(point.y+mid_y)*0.0123022036322, ")," )
	print("]")
