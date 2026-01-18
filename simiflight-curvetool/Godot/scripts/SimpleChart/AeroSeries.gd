class_name AeroSeries extends ChartSeries

@export var results: Array[AeroResult] = []
@export var is_snapshot: bool = false

func get_points_for_axes(x_var: String, y_var: String) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for r in results:
		pts.append(Vector2(r.get(x_var), r.get(y_var)))
	return pts
