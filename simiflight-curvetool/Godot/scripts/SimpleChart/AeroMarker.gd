class_name AeroMarker
extends Resource

@export var name: String
@export var x_val: float
@export var y_val: float
@export var color: Color = Color.WHITE
@export var radius: float = 5.0
@export var fill: bool = true
@export var visible: bool = true

# Helper to get the position as a Vector2
func get_pos() -> Vector2:
	return Vector2(x_val, y_val)
