@tool
class_name SquareButton extends Button

@export_tool_button("squarify") var squarify = _squarify_btn
@export var theme_variation: = &"SquareButton"
func _ready() -> void:
	_squarify_btn()
	self.theme_type_variation = theme_variation

func _notification(what):
	# This detects if the window size/mode changes (e.g. via Win+UpArrow or Restore)
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_squarify_btn()
func _squarify_btn() -> void:
	var size_x: float = self.size.x
	var size_y: float = self.size.y

	var square_size: float = size_x
	if size_y > size_x:
		square_size = size_y
	self.custom_minimum_size = Vector2(square_size, square_size)
