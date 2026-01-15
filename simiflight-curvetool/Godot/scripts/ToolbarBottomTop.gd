class_name ToolbarBottomTop extends PanelContainer
@export var sizing_active: bool = false

func _ready() -> void:
	if sizing_active:
		if self.get_child_count() == 0:
			return
		await self.get_tree().process_frame
		set_custom_minimum_size_tb()

func set_custom_minimum_size_tb() -> void:
	var child: Container = self.get_child(0)
	if child is HBoxContainer:
		var max_size_x: float = 0.0
		for child_vbox in child.get_children():
			if max_size_x < child_vbox.size.x:
				max_size_x = child_vbox.size.x
		for child_vbox: Control in child.get_children():
			var new_styles: Dictionary[String,StyleBox]
			var style_strings: Array[String] = [
				"disabled","focus","hover",
				"hover_pressed","normal","pressed"
				]
			for style_string in style_strings:
				new_styles.assign({style_string: get_theme_stylebox("style_string").duplicate()})

			var side_margin: float = (max_size_x - child_vbox.size.x) /2
			const CHECKBOX_SIZE: float = 16.0
			var left_margin: float = side_margin - CHECKBOX_SIZE
			var right_margin: float = side_margin + CHECKBOX_SIZE
			print("child_vbox: ", child_vbox.name, ": side_margin: ", side_margin, ", CHECKBOX_SIZE: ", CHECKBOX_SIZE, ", left_margin: ", left_margin, ", right_margin: ", right_margin)
			for new_style: String in new_styles:
				new_styles.get(new_style).content_margin_left = left_margin
				new_styles.get(new_style).content_margin_right = right_margin
				child_vbox.add_theme_stylebox_override(new_style,new_styles.get(new_style))
			child_vbox.custom_minimum_size.x = max_size_x
	else:
		push_error("ToolbarBottomTop must have only one Child of type HBoxContainer!\n
					Child %s is %s" % [child.name, child.get_class()])
