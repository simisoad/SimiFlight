class_name SpinBoxExtended extends SpinBox

@export var default_val: float
var button: Button = Button.new()

func _ready() -> void:
	await self.get_tree().process_frame
	_setup_default_button()

func _setup_default_button() -> void:
	var parent: Control = self.get_parent_control()
	var tree_pos_index: int = self.get_index()
	parent.remove_child(self)
	var hbox_container: HBoxContainer = HBoxContainer.new()
	parent.add_child(hbox_container)
	hbox_container.add_child(self)
	parent.move_child(hbox_container, tree_pos_index)
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_container.add_child(button)
	button.text = "D"
	button.pressed.connect(func(): self.value = default_val)
	button.tooltip_text = "Reset value to default"
