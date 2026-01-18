class_name SeriesLegendItem extends HBoxContainer

signal series_changed()
signal delete_requested()
signal snap_shot_taken(series: ChartSeries)

var target_series: ChartSeries

@onready var check_vis: CheckBox = CheckBox.new()
@onready var btn_copy: Button = Button.new()
@onready var edit_name: LineEdit = LineEdit.new()
@onready var picker: ColorPickerButton = ColorPickerButton.new()
@onready var marker_container: HBoxContainer = HBoxContainer.new()
@onready var btn_delete: Button = Button.new()

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)

	# Name
	edit_name.custom_minimum_size.x = 200
	add_child(edit_name)

	# Visibility
	check_vis.text = "Visible"
	add_child(check_vis)

	# Copy/Snapshot
	btn_copy.text = "Copy"
	add_child(btn_copy)

	# Color
	picker.custom_minimum_size.x = 40
	picker.get_picker().deferred_mode = true
	add_child(picker)

	# Markers Label
	var m_lbl = Label.new()
	m_lbl.text = "Markers:"
	m_lbl.modulate = Color(0.7, 0.7, 0.7)
	add_child(m_lbl)
	add_child(marker_container)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10.0
	add_child(spacer)

	# Delete
	btn_delete.text = "Delete"
	add_child(btn_delete)

func setup(series: ChartSeries, can_delete: bool = false) -> void:
	target_series = series

	# Sync UI
	edit_name.text = series.name
	check_vis.button_pressed = series.visible
	picker.color = series.color
	btn_delete.visible = can_delete

	# Snapshots/Reference usually don't need a "Copy" button to avoid recursion
	btn_copy.visible = !can_delete and series.name != "Reference"

	# Build Markers
	for child in marker_container.get_children(): child.queue_free()
	for marker in series.markers:
		var m_check = CheckBox.new()
		m_check.text = marker.name
		m_check.button_pressed = marker.visible
		m_check.toggled.connect(func(v):
			marker.visible = v
			series_changed.emit()
		)
		marker_container.add_child(m_check)

	# Connections
	if not check_vis.toggled.is_connected(_on_vis_toggled):
		check_vis.toggled.connect(_on_vis_toggled)
		picker.color_changed.connect(_on_color_changed)
		edit_name.text_submitted.connect(_on_name_changed)
		btn_copy.pressed.connect(func(): snap_shot_taken.emit(target_series))
		btn_delete.pressed.connect(func(): delete_requested.emit())

func _on_vis_toggled(v: bool) -> void:
	target_series.visible = v
	series_changed.emit()

func _on_color_changed(c: Color) -> void:
	target_series.color = c
	series_changed.emit()

func _on_name_changed(new_text: String) -> void:
	target_series.name = new_text
	series_changed.emit()
