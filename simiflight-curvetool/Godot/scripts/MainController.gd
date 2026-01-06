extends Control

@onready var generator_view = %LutGeneratorView
@onready var visualizer_view = %LutVisualizer
@onready var creator_view: AirfoilCreatorView = %AirfoilCreatorView

@onready var resize_top_left: Control = %ResizeTopLeft
@onready var resize_top: Control = %ResizeTop
@onready var resize_top_right: Control = %ResizeTopRight
@onready var resize_left: Control = %ResizeLeft
@onready var resize_right: Control = %ResizeRight
@onready var resize_bottom_right: Control = %ResizeBottomRight
@onready var resize_bottom: Control = %ResizeBottom
@onready var resize_bottom_left: Control = %ResizeBottomLeft

@onready var tabs = %TabContainer
# References to UI elements (Assign these in Inspector or via standard OnReady)
@onready var maximize_btn = %MaximizeButton # Use Unique Names in Scene %
# Define min size to prevent window breaking
const MIN_WINDOW_SIZE = Vector2i(800, 600)

# State variables
var _dragging_window = false
var _drag_start_mouse_pos = Vector2()
var _resizing = false
var _resize_node_name = ""
var _initial_window_rect: Rect2i

func _ready():
	# Connect the signal from the Generator to the Visualizer
	generator_view.lut_generated.connect(_on_new_lut_generated)
	if creator_view:
		creator_view.airfoil_saved.connect(_on_airfoil_created)
	%MinimizeButton.pressed.connect(_on_minimize_pressed)
	%MaximizeButton.pressed.connect(_on_maximize_pressed)
	%CloseButton.pressed.connect(_on_close_pressed)
	%TitleBar.gui_input.connect(_on_title_bar_gui_input)
	# Connect Resize Handles (Connect 'gui_input' signal for all 8 handles)
	# Name your nodes: ResizeLeft, ResizeRight, ResizeTop, ResizeBottom, ResizeTL, ResizeTR, ResizeBL, ResizeBR
	await self.get_tree().process_frame
	resize_top_left.gui_input.connect(_on_resize_handle_gui_input.bind(resize_top_left.name))
	resize_top.gui_input.connect(_on_resize_handle_gui_input.bind(resize_top.name))
	resize_top_right.gui_input.connect(_on_resize_handle_gui_input.bind(resize_top_right.name))
	resize_left.gui_input.connect(_on_resize_handle_gui_input.bind(resize_left.name))
	resize_right.gui_input.connect(_on_resize_handle_gui_input.bind(resize_right.name))
	resize_bottom_right.gui_input.connect(_on_resize_handle_gui_input.bind(resize_bottom_right.name))
	resize_bottom.gui_input.connect(_on_resize_handle_gui_input.bind(resize_bottom.name))
	resize_bottom_left.gui_input.connect(_on_resize_handle_gui_input.bind(resize_bottom_left.name))

func _on_new_lut_generated(path: String):
	pass
	## 1. Switch to Visualizer Tab
	#tabs.current_tab = 1
#
	## 2. Update file list in Visualizer
	#visualizer_view._refresh_file_list()
#
	## 3. Select the newly created file (optional, logic would need to be added to Visualizer)
	#print("New LUT generated, switching to visualizer.")
func _on_airfoil_created(path: String):
	print("New airfoil created at: ", path)

	# 1. Update the list in the Generator View
	generator_view.refresh_profile_list()

	# 2. Switch to Generator Tab automatically?
	tabs.current_tab = 0 # Assuming Generator is Tab 0
# ---------------------------------------------------------
# WINDOW DRAGGING (Title Bar)
# ---------------------------------------------------------
func _on_title_bar_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Double click to maximize
				if event.double_click:
					_on_maximize_pressed()
				else:
					_dragging_window = true
					_drag_start_mouse_pos = get_global_mouse_position()
			else:
				_dragging_window = false

	if event is InputEventMouseMotion and _dragging_window:
		# Check if maximized, if so, restore slightly to drag
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
			_restore_window_for_drag()

		var current_mouse_pos = get_global_mouse_position()
		var diff = Vector2i(current_mouse_pos - _drag_start_mouse_pos)
		get_window().position += diff

func _restore_window_for_drag():
	# Logic to snap window to mouse when dragging from maximized state
	var mouse_pct = get_global_mouse_position().x / get_window().size.x
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var new_width = get_window().size.x
	_drag_start_mouse_pos = Vector2(new_width * mouse_pct, _drag_start_mouse_pos.y)

# ---------------------------------------------------------
# WINDOW BUTTONS
# ---------------------------------------------------------
func _on_minimize_pressed():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

func _on_maximize_pressed():
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_close_pressed():
	get_tree().quit()

# ---------------------------------------------------------
# RESIZING LOGIC
# ---------------------------------------------------------
func _on_resize_handle_gui_input(event, handle_name):
	#print("event: ", event, ", handle_name: ", handle_name)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_resizing = true
				_resize_node_name = handle_name
				_initial_window_rect = Rect2i(get_window().position, get_window().size)
			else:
				_resizing = false

	if event is InputEventMouseMotion and _resizing:
		_handle_resize(event.relative)

func _handle_resize(relative_motion: Vector2):
	var win = get_window()
	var new_pos = win.position
	var new_size = win.size

	# Horizontal Resizing
	if "Left" in _resize_node_name:
		if new_size.x - relative_motion.x > MIN_WINDOW_SIZE.x:
			new_pos.x += relative_motion.x
			new_size.x -= relative_motion.x
	elif "Right" in _resize_node_name:
		if new_size.x + relative_motion.x > MIN_WINDOW_SIZE.x:
			new_size.x += relative_motion.x

	# Vertical Resizing
	if "Top" in _resize_node_name:
		if new_size.y - relative_motion.y > MIN_WINDOW_SIZE.y:
			new_pos.y += relative_motion.y
			new_size.y -= relative_motion.y
	elif "Bottom" in _resize_node_name:
		if new_size.y + relative_motion.y > MIN_WINDOW_SIZE.y:
			new_size.y += relative_motion.y

	win.position = new_pos
	win.size = new_size
