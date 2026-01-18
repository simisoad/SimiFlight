class_name AeroRayScanner extends RefCounted

## Analyzes a polygon using ray-casting to find aerodynamic "crimes".
static func scan_airfoil(points: Array[Vector2], alpha_deg: float) -> Dictionary:
	var alpha_rad = deg_to_rad(alpha_deg)
	var rotated_poly = _get_rotated_poly(points, alpha_rad)

	var num_rays = 21
	var ray_y_range = 1.0 # From -0.5 to 0.5
	var intersections: Array[Array] = []

	var projected_height = 0.0
	var min_y = 999.0
	var max_y = -999.0

	# 1. Cast Rays parallel to the wind (X-axis)
	for i in range(num_rays):
		var y = lerp(-ray_y_range, ray_y_range, float(i) / (num_rays - 1))
		var ray_start = Vector2(-2.0, y)
		var ray_end = Vector2(2.0, y)

		var hits = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([ray_start, ray_end]), rotated_poly)

		# Analyze hits for this specific Y-level
		if hits.size() > 0:
			min_y = min(min_y, y)
			max_y = max(max_y, y)
			intersections.append(hits)

	projected_height = max_y - min_y if max_y > -900 else 0.0

	# 2. Analyze geometric "Crimes"
	var concavity_penalty = 0.0
	var roughness_penalty = 0.0

	for hit_group in intersections:
		# If a single ray enters and exits the body more than once, it's a "Trapped Air" zone (Concave)
		if hit_group.size() > 1:
			concavity_penalty += 0.1

	return {
		"projected_area": projected_height,
		"concavity": clamp(concavity_penalty, 0.0, 1.0),
		"is_bluff": projected_height > 0.5 # Geometric definition of a bluff body
	}

static func _get_rotated_poly(points: Array[Vector2], angle: float) -> PackedVector2Array:
	var out = PackedVector2Array()
	var center = Vector2(0.5, 0.0)
	for p in points:
		out.append((p - center).rotated(angle) + center)
	return out
