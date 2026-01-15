class_name SpinBoxExtended extends SpinBox

@export var default_val: float = INF
@export var size_flags_horizontal_spinbox: SizeFlags = Control.SIZE_EXPAND_FILL
@export var size_flags_horizontal_reset_btn: SizeFlags = Control.SIZE_SHRINK_END
@export var size_flags_horizontal_hbox: SizeFlags = Control.SIZE_EXPAND_FILL
var button: SquareButton = SquareButton.new()

func _ready() -> void:
	if default_val == INF:
		default_val = value
	await self.get_tree().process_frame
	_setup_default_button()



func _setup_default_button() -> void:
	var parent: Control = self.get_parent_control()
	var tree_pos_index: int = self.get_index()
	parent.remove_child(self)
	var hbox_container: HBoxContainer = HBoxContainer.new()
	parent.add_child(hbox_container)
	hbox_container.add_child(self)
	hbox_container.size_flags_horizontal = size_flags_horizontal_hbox
	parent.move_child(hbox_container, tree_pos_index)
	self.size_flags_horizontal = size_flags_horizontal_spinbox
	hbox_container.add_child(button)
	button._squarify_btn()
	self.size_flags_stretch_ratio = 1000
	button.size_flags_horizontal = size_flags_horizontal_reset_btn
	button.text = "D"
	button.pressed.connect(func(): self.value = default_val)
	button.tooltip_text = "Reset value to default"
