extends Resource
class_name AirfoilProfile

@export var airfoil_path: String
@export var upper_surface: Array[Vector2] = []
@export var lower_surface: Array[Vector2] = []
@export var name: String = "Unnamed"
@export var metadata: Dictionary = {} # Stores design intent

# Load profile data from a text file in Selig format.
func load_from_dat(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not FileAccess.file_exists(path) or file == null:
		push_error("Could not open airfoil file: %s" % path)
		return false
	var internal_created: bool = false
	var upper_found: bool = false
	var lower_found: bool = false
	if file.get_as_text().contains("upper"):
		internal_created = true
		print("internal created!")
	var lines: PackedStringArray = file.get_as_text().split("\n", false)
	file.close()

	if lines.size() < 3: # Needs Name + at least 2 points
		push_error("Invalid airfoil file: too short. Path: %s" % path)
		return false
	metadata.clear() # Reset for new load

	for line_str in lines.slice(1):
			var line = line_str.strip_edges()
			if line.is_empty(): continue

			# Look for Metadata line
			if line.begins_with("#META:"):
				var json_str = line.replace("#META:", "").strip_edges()
				var json = JSON.new()
				if json.parse(json_str) == OK:
					metadata = json.get_data()
				continue

	name = lines[0].strip_edges()
	upper_surface.clear()
	lower_surface.clear()

	var min_x_found = false
	var last_x = 1.1 # Start slightly above 1.0 to ensure the first point is smaller

	for line_str in lines.slice(1): # Skip the name line
		var line = line_str.strip_edges()
		if line.is_empty():
			continue
		if line.contains("upper"):
			upper_found = true
			continue
		if line.contains("lower"):
			lower_found = true
			continue

		# Robust split that handles multiple spaces/tabs
		var parts: Array = line.split_floats("\t", false)
		if parts.size() == 1:
			parts = line.split_floats(" ", false)
		elif parts.size() < 2:
			# Ignore lines that don't look like coordinates (e.g., lines starting with "x")
			continue

		var x = parts[0]
		var y = parts[1]
		var point = Vector2(x, y)

		# The logic:
		# 1. We are on the upper surface as long as x decreases.
		# 2. The point with the smallest x is the Leading Edge (nose point).
		# 3. Once x starts increasing again, we are on the lower surface.
		if not internal_created:
			if not min_x_found:
				if x < last_x:
					upper_surface.append(point)
				else:
					min_x_found = true
					# The last point on 'upper_surface' was the Leading Edge.
					# The current point is the first on the lower surface.
					lower_surface.append(point)
			else:
				lower_surface.append(point)

			last_x = x
		else:
			if upper_found and not lower_found:
				upper_surface.append(point)
			if lower_found and upper_found:
				lower_surface.append(point)

	# The points on the upper surface are ordered from x=1.0 to x=0.0.
	# For many algorithms, it is useful to have them from 0.0 to 1.0.

	upper_surface.reverse()
	# lower_surface.reverse()
	# The points on the lower surface are already ordered from x=0.0 to x=1.0.
	#print("upper:")
	#for vec in upper_surface:
		#print(vec)
	#for vec in lower_surface:
		#print(vec)
	if upper_surface.is_empty() or lower_surface.is_empty():
		push_error("Failed to parse upper or lower surface correctly. Path: %s" % path)
		return false

	print("Successfully loaded airfoil '%s' with %d upper and %d lower points." % [name, upper_surface.size(), lower_surface.size()])
	return true
