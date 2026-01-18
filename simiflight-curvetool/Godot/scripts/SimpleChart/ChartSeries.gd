class_name ChartSeries extends Resource

@export var name: String
@export var points: Array[Vector2] = []
@export var color: Color = Color.WHITE
@export var width: float = 2.0
@export var visible: bool = true
@export var markers: Array[AeroMarker] = []

# Metadata for Legend Organization
var category: String = "General"
var subcategory: String = ""
var channel_id: String = ""

# Metadata for Chart Routing (NEW: Moved to base class)
var type: String = "" # "ALPHA" or "POLAR"

func add_marker(m_name: String, x: float, y: float, m_color: Color, m_fill: bool = true) -> AeroMarker:
	var m = AeroMarker.new()
	m.name = m_name
	m.x_val = x
	m.y_val = y
	m.color = m_color
	m.fill = m_fill
	markers.append(m)
	return m

func clear_markers() -> void:
	markers.clear()

func copy() -> ChartSeries:
	var new_series = ChartSeries.new()
	new_series.name = name
	new_series.points = points.duplicate()
	new_series.color = color
	new_series.width = width
	new_series.visible = visible
	new_series.type = type # PRESERVE TYPE
	# Deep copy markers
	for m in markers:
		var nm = AeroMarker.new()
		nm.name = m.name; nm.x_val = m.x_val; nm.y_val = m.y_val
		nm.color = m.color; nm.fill = m.fill; nm.visible = m.visible
		new_series.markers.append(nm)
	return new_series
