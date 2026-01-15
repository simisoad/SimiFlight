@tool
class_name UIRow
extends PanelContainer

@export_range(16, 128, 1)
var row_height := 32:
	set(value):
		row_height = value
		_update_height()
@export_tool_button("Set Row Height") var set_row_height = _update_height
@export var horizontal_fill: SizeFlags = Control.SIZE_EXPAND_FILL
func _ready():
	_update_height()

func _update_height():

	custom_minimum_size.y = row_height
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = horizontal_fill
