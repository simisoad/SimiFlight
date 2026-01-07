extends Control

@onready var generator_view = %LutGeneratorView
@onready var visualizer_view = %LutVisualizer
@onready var creator_view = %AirfoilCreatorView # Removed type hint for safety if node missing
@onready var tabs = %TabContainer
@onready var snap_preview: Window = %SnapPreview

# UI References
@onready var resize_handles_container = %ResizeHandles # The parent of all handle nodes
@onready var maximize_btn = %MaximizeButton
@onready var title_bar = %TitleBar

const MIN_WINDOW_SIZE = Vector2i(800, 600)

# State variables
var _resizing = false
var _resize_node_name = ""
var _initial_window_rect: Rect2i
var _drag_start_mouse_global: Vector2i
var _dragging_title = false
var _drag_offset_from_top_left = Vector2()
var _is_toggling_maximize = false
# 0=Left, 1=Right, 2=Top (Max)
# 3=TopLeft, 4=TopRight, 5=BotLeft, 6=BotRight
var _current_snap_state = null
var _preview_rect: Rect2i = Rect2i()

# Sensitivity
const SNAP_THRESHOLD = 20

func _ready():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true, 0)
	generator_view.lut_generated.connect(_on_new_lut_generated)
	if creator_view:
		creator_view.airfoil_saved.connect(_on_airfoil_created)

	# Window Buttons
	%MinimizeButton.pressed.connect(_on_minimize_pressed)
	maximize_btn.pressed.connect(_on_maximize_pressed)
	%CloseButton.pressed.connect(_on_close_pressed)

	# Title Bar
	title_bar.gui_input.connect(_on_title_bar_gui_input)

	# Resize Handles
	await get_tree().process_frame
	var handles = [
		%ResizeTopLeft, %ResizeTop, %ResizeTopRight,
		%ResizeLeft, %ResizeRight,
		%ResizeBottomRight, %ResizeBottom, %ResizeBottomLeft
	]
	for handle in handles:
		handle.gui_input.connect(_on_resize_handle_gui_input.bind(handle.name))

	# Run once to ensure correct state on boot
	_update_window_state()

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
# AUTO-DETECT WINDOW STATE CHANGES
# ---------------------------------------------------------
func _notification(what):
	# This detects if the window size/mode changes (e.g. via Win+UpArrow or Restore)
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_window_state()

func _update_window_state():
	var mode = DisplayServer.window_get_mode()
	var is_maximized = mode == DisplayServer.WINDOW_MODE_MAXIMIZED

	# 1. Hide resize handles when maximized
	resize_handles_container.visible = not is_maximized

	# 2. Update Icons (Windows 10/11 style symbols)
	if is_maximized:
		maximize_btn.text = "❐" # Restore symbol
		maximize_btn.tooltip_text = "Restore Down"
	else:
		maximize_btn.text = "☐" # Maximize symbol
		maximize_btn.tooltip_text = "Maximize"

# ---------------------------------------------------------
# DRAGGING & SNAP LOGIC
# ---------------------------------------------------------
func _on_title_bar_gui_input(event):
	# 1. SAFETY BLOCK
	# If we are in the middle of a toggle (waiting for the timer),
	# ignore ALL inputs. This "eats" the triple-click.
	if _is_toggling_maximize:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 2. DOUBLE CLICK HANDLING
				if event.double_click:
					_smart_toggle_maximize()
				else:
					# Standard Drag Logic
					_dragging_title = true
					_drag_offset_from_top_left = get_global_mouse_position()
			else:
				# Mouse Released
				if _dragging_title:
					_finalize_drag_snap()
				_dragging_title = false
				snap_preview.hide()
				_current_snap_state = null

	if event is InputEventMouseMotion and _dragging_title:
		_handle_drag_move()

func _smart_toggle_maximize():
	var current_mode = DisplayServer.window_get_mode()

	# CASE A: We are Windowed -> Going to Maximized
	# This is safe to do instantly because the window gets BIGGER (can't miss click)
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_on_maximize_pressed()

	# CASE B: We are Maximized -> Going to Windowed
	# This is the dangerous one! The window shrinks.
	elif current_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		_is_toggling_maximize = true

		# We wait 0.2 seconds (200ms).
		# This keeps the window maximized long enough to catch a potential 3rd click.
		await get_tree().create_timer(0.2).timeout

		# Now we shrink
		_on_maximize_pressed()

		# Unlock input again
		_is_toggling_maximize = false

func _handle_drag_move():
	# 1. Standard Move Logic
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		_restore_and_attach_to_mouse()

	var global_mouse = DisplayServer.mouse_get_position()
	get_window().position = global_mouse - Vector2i(_drag_offset_from_top_left)

	# 2. CALCULATE SNAP PREVIEW
	_update_snap_preview(global_mouse)

func _update_snap_preview(mouse_pos: Vector2i):
	var screen_id = DisplayServer.get_screen_from_rect(Rect2(mouse_pos, Vector2(1, 1)))
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)

	var new_state = null
	var target_rect = Rect2i()

	# Thresholds
	# Corners need a larger hit area to feel comfortable
	var corner_size = 50
	var edge_threshold = 20

	var is_top = mouse_pos.y < screen_rect.position.y + corner_size
	var is_bot = mouse_pos.y > screen_rect.end.y - corner_size
	var is_left_corner = mouse_pos.x < screen_rect.position.x + corner_size
	var is_right_corner = mouse_pos.x > screen_rect.end.x - corner_size

	# Standard dimensions
	var half_w = screen_rect.size.x / 2
	var half_h = screen_rect.size.y
	var full_h = screen_rect.size.y

	# --- 1. CHECK CORNERS FIRST (Priority) ---

	# Top-Left (State 3)
	if is_top and is_left_corner:
		new_state = 3
		target_rect = Rect2i(screen_rect.position.x, screen_rect.position.y, half_w, half_h / 2)

	# Top-Right (State 4)
	elif is_top and is_right_corner:
		new_state = 4
		target_rect = Rect2i(screen_rect.position.x + half_w, screen_rect.position.y, half_w, half_h / 2)

	# Bottom-Left (State 5)
	elif is_bot and is_left_corner:
		new_state = 5
		target_rect = Rect2i(screen_rect.position.x, screen_rect.position.y + (half_h), half_w, half_h) # Logic fix: half_h is actually full height / 2? Windows splits 50/50 vertically usually
		# Actually Windows usually does 4 quadrants. Let's do 50% height.
		target_rect = Rect2i(screen_rect.position.x, screen_rect.position.y + (screen_rect.size.y / 2), half_w, screen_rect.size.y / 2)

	# Bottom-Right (State 6)
	elif is_bot and is_right_corner:
		new_state = 6
		target_rect = Rect2i(screen_rect.position.x + half_w, screen_rect.position.y + (screen_rect.size.y / 2), half_w, screen_rect.size.y / 2)

	# --- 2. CHECK EDGES (If not a corner) ---

	if new_state == null:
		# Top Edge (Maximize)
		if mouse_pos.y < screen_rect.position.y + edge_threshold:
			new_state = 2
			target_rect = screen_rect

		# Left Edge (Half)
		elif mouse_pos.x < screen_rect.position.x + edge_threshold:
			new_state = 0
			target_rect = Rect2i(screen_rect.position.x, screen_rect.position.y, half_w, full_h)

		# Right Edge (Half)
		elif mouse_pos.x > screen_rect.end.x - edge_threshold:
			new_state = 1
			target_rect = Rect2i(screen_rect.position.x + half_w, screen_rect.position.y, half_w, full_h)

	# --- APPLY ---
	if new_state != null:
		if _current_snap_state != new_state:
			_current_snap_state = new_state
			# Margin for the "Windows 11 Look"
			var margin = 10
			var visual_rect = target_rect.grow(-margin)

			snap_preview.position = visual_rect.position
			snap_preview.size = visual_rect.size
			snap_preview.show()
	else:
		if _current_snap_state != null:
			snap_preview.hide()
			_current_snap_state = null

	_preview_rect = target_rect

func _restore_and_attach_to_mouse():
	# 1. Calculate relative X position (percentage) before restoring
	var mouse_x_ratio = get_global_mouse_position().x / get_window().size.x

	# 2. Restore window
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# 3. Recalculate offset so window centers on mouse horizontally (optional style)
	# or keeps the ratio. Let's keep ratio:
	var new_width = get_window().size.x
	_drag_offset_from_top_left = Vector2(new_width * mouse_x_ratio, _drag_offset_from_top_left.y)

func _finalize_drag_snap():
	if _current_snap_state != null:

		# Maximize (Top)
		if _current_snap_state == 2:
			_on_maximize_pressed()

		# All other states (Left, Right, Corners) -> Set Rect
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			get_window().position = _preview_rect.position
			get_window().size = _preview_rect.size
			_update_window_state()

func _snap_window_half(screen_rect: Rect2i, side: String):
	# Ensure we are in Windowed mode so we can move/resize freely
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var new_w = screen_rect.size.x / 2.0
	var new_h = screen_rect.size.y
	var new_x = screen_rect.position.x
	var new_y = screen_rect.position.y

	if side == "right":
		new_x += new_w # Shift start position to the middle of the screen

	# Apply the rect
	get_window().position = Vector2i(new_x, new_y)
	get_window().size = Vector2i(int(new_w), int(new_h))

	# Update state (handles should be visible since it's technically windowed)
	_update_window_state()

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

	# Force update state immediately
	_update_window_state()

func _on_close_pressed():
	get_tree().quit()

# ---------------------------------------------------------
# RESIZING LOGIC (Global Coordinates)
# ---------------------------------------------------------
func _on_resize_handle_gui_input(event, handle_name):
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		return # Should be redundant if visible=false, but good safety

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_resizing = true
				_resize_node_name = handle_name
				_initial_window_rect = Rect2i(get_window().position, get_window().size)
				_drag_start_mouse_global = DisplayServer.mouse_get_position()
			else:
				_resizing = false

func _input(event):
	if _resizing and event is InputEventMouseMotion:
		_handle_resize_global()

func _handle_resize_global():
	var current_mouse_global = DisplayServer.mouse_get_position()
	var diff = current_mouse_global - _drag_start_mouse_global

	var new_rect = _initial_window_rect
	var min_w = MIN_WINDOW_SIZE.x
	var min_h = MIN_WINDOW_SIZE.y

	# Apply differences
	if "Left" in _resize_node_name:
		var proposed_width = _initial_window_rect.size.x - diff.x
		if proposed_width > min_w:
			new_rect.position.x += diff.x
			new_rect.size.x = proposed_width
	elif "Right" in _resize_node_name:
		var proposed_width = _initial_window_rect.size.x + diff.x
		if proposed_width > min_w:
			new_rect.size.x = proposed_width

	if "Top" in _resize_node_name:
		var proposed_height = _initial_window_rect.size.y - diff.y
		if proposed_height > min_h:
			new_rect.position.y += diff.y
			new_rect.size.y = proposed_height
	elif "Bottom" in _resize_node_name:
		var proposed_height = _initial_window_rect.size.y + diff.y
		if proposed_height > min_h:
			new_rect.size.y = proposed_height

	get_window().position = new_rect.position
	get_window().size = new_rect.size
