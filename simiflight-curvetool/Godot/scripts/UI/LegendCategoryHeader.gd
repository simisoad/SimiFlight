# Helper UI for Categories
class_name LegendCategoryHeader extends PanelContainer

func _init(title: String, col: Color = Color(0.2, 0.2, 0.2)):
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	var lbl = Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.8, 0.8, 0.8)
	add_child(margin)
	margin.add_child(lbl)
	var style = StyleBoxFlat.new()
	style.bg_color = col
	add_theme_stylebox_override("panel", style)
