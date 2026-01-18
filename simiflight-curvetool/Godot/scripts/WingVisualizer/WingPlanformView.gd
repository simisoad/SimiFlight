class_name WingPlanformView extends Control

# --- Configuration ---
@export var background_color: Color = Color(0.12, 0.12, 0.14, 1.0)
@export var wing_color: Color = Color(0.7, 0.7, 0.7, 0.9)
@export var line_color: Color = Color.CYAN # Farbe für die gewählte Sweep-Linie
@onready var reset_view_wing_visu: SquareButton = %ResetViewWingVisu

# --- Wing Geometry ---
var aspect_ratio: float = 6.0
var taper: float = 0.5
var sweep_deg: float = 0.0
var sweep_loc: float = 0.25 # 0=LE, 0.25=c/4, 1=TE

# Viewport
var view_zoom: float = 50.0
var default_zoom: float
var pan_offset: Vector2 = Vector2(-25.0, 0.0)
var default_pan_offset: Vector2
var _is_dragging: bool = false
var _last_mouse_pos: Vector2

func _ready() -> void:
	clip_contents = true
	default_zoom = view_zoom
	default_pan_offset = pan_offset
	reset_view_wing_visu.pressed.connect(_reset_zoom)

func update_geometry(ar: float, t: float, s: float, loc: float):
	aspect_ratio = ar
	taper = t
	sweep_deg = s
	sweep_loc = loc
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true, -1.0, true)

	var center = (size / 2.0) + pan_offset
	_draw_grid(center)

	# --- Flügel-Koordinaten berechnen ---
	# Wir nehmen eine mittlere Tiefe (c_avg) als Referenz für die Zeichnung
	var c_root = 1.0
	var c_tip = c_root * taper

	# Spannweite b berechnen aus AR = b^2 / S -> b = AR * c_avg
	# S = b * (c_root + c_tip) / 2
	var span = aspect_ratio * ((c_root + c_tip) / 2.0)
	var half_span = span / 2.0

	# Sweep-Versatz berechnen
	# x_loc_tip = x_loc_root + half_span * tan(sweep)
	var sweep_rad = deg_to_rad(sweep_deg)
	var x_loc_root = sweep_loc * c_root
	var x_loc_tip = x_loc_root + (half_span * tan(sweep_rad))

	# Eckpunkte (Relativ zur Wurzel-Vorderkante bei 0,0)
	var root_le = Vector2(0, 0)
	var root_te = Vector2(c_root, 0)

	var tip_le_y = -half_span # Godot Y ist nach unten, Flügelspitze nach "oben" zeichnen
	var tip_le_x = x_loc_tip - (sweep_loc * c_tip)
	var tip_te_x = tip_le_x + c_tip

	var tip_le = Vector2(tip_le_x, tip_le_y)
	var tip_te = Vector2(tip_te_x, tip_le_y)

	# --- Zeichnen ---
	var scale_zoom = view_zoom
	# Wir spiegeln die Punkte für die rechte Hälfte
	var pts_left = PackedVector2Array([
		center + root_le * scale_zoom,
		center + tip_le * scale_zoom,
		center + tip_te * scale_zoom,
		center + root_te * scale_zoom
	])

	var pts_right = PackedVector2Array([
		center + root_le * scale_zoom,
		center + Vector2(tip_le.x, -tip_le.y) * scale_zoom,
		center + Vector2(tip_te.x, -tip_te.y) * scale_zoom,
		center + root_te * scale_zoom
	])

	draw_colored_polygon(pts_left, wing_color)
	draw_colored_polygon(pts_right, wing_color)
	draw_polyline(pts_left, Color.WHITE, 2.0, true)
	draw_polyline(pts_right, Color.WHITE, 2.0, true)

	# Hilfslinie: Die definierte Sweep-Linie zeichnen
	var sweep_line_pts = PackedVector2Array([
		center + Vector2(x_loc_tip, -half_span) * scale_zoom,
		center + Vector2(x_loc_root, 0) * scale_zoom,
		center + Vector2(x_loc_tip, half_span) * scale_zoom
	])
	draw_polyline(sweep_line_pts, line_color, 1.5, true)

func _draw_grid(center_ref: Vector2):
	var grid_step = 50.0
	var col = Color(1, 1, 1, 0.05)
	for x in range(fmod(center_ref.x, grid_step), size.x, grid_step):
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0, true)
	for y in range(fmod(center_ref.y, grid_step), size.y, grid_step):
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0, true)

# --- Input-Handling (Pan & Zoom wie in WindTunnelView) ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_action_pressed(&"pan_chart"):
			_is_dragging = true
			_last_mouse_pos = event.position
		elif event.is_action_released(&"pan_chart"):
			_is_dragging = false
		if event.is_action_pressed(&"reset_zoom_chart") and event.double_click:
			_reset_zoom()

		if event.button_index == MOUSE_BUTTON_WHEEL_UP: view_zoom *= 1.1; queue_redraw()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: view_zoom *= 0.9; queue_redraw()
	if event is InputEventMouseMotion and _is_dragging:
		pan_offset += event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		queue_redraw()
func _reset_zoom() -> void:
	view_zoom = default_zoom; pan_offset = default_pan_offset
	queue_redraw()
