extends Resource
class_name AirfoilProfile

@export var airfoil_path: String
@export var upper_surface: Array[Vector2] = []
@export var lower_surface: Array[Vector2] = []
@export var name: String = "Unnamed"

# Lade Profildaten aus einer Textdatei im Selig-Format.
func load_from_dat(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not FileAccess.file_exists(path) or file == null:
		push_error("Could not open airfoil file: %s" % path)
		return false

	var lines = file.get_as_text().split("\n", false)
	file.close()

	if lines.size() < 3: # Braucht Name + mindestens 2 Punkte
		push_error("Invalid airfoil file: too short. Path: %s" % path)
		return false

	name = lines[0].strip_edges()
	upper_surface.clear()
	lower_surface.clear()

	var min_x_found = false
	var last_x = 1.1 # Start slightly above 1.0 to ensure the first point is smaller

	for line_str in lines.slice(1): # Überspringe die Namenszeile
		var line = line_str.strip_edges()
		if line.is_empty():
			continue

		# Robuster Split, der mehrere Leerzeichen/Tabs handhaben kann
		var parts: Array = line.split_floats("\t", false)
		if parts.size() == 1:
			parts = line.split_floats(" ", false)
		elif parts.size() < 2:
			# Ignoriere Zeilen, die nicht wie Koordinaten aussehen (z.B. die Zeile mit "x")
			continue

		var x = parts[0]
		var y = parts[1]
		var point = Vector2(x, y)

		# Die Logik:
		# 1. Wir sind auf der Oberseite, solange x abnimmt.
		# 2. Der Punkt mit dem kleinsten x ist der Nasenpunkt (leading edge).
		# 3. Sobald x wieder zu steigen beginnt, sind wir auf der Unterseite.
		
		if not min_x_found:
			if x < last_x:
				upper_surface.append(point)
			else:
				min_x_found = true
				# Der letzte Punkt auf der 'upper_surface' war der Nasenpunkt.
				# Der aktuelle Punkt ist der erste auf der Unterseite.
				lower_surface.append(point)
		else:
			lower_surface.append(point)
		
		last_x = x
	
	# Die Punkte der Oberseite sind von x=1.0 nach x=0.0 geordnet.
	# Für viele Algorithmen ist es nützlich, sie von 0.0 nach 1.0 zu haben.
	upper_surface.reverse()
	#lower_surface.reverse()
	# Die Punkte der Unterseite sind bereits von x=0.0 nach x=1.0 geordnet.

	if upper_surface.is_empty() or lower_surface.is_empty():
		push_error("Failed to parse upper or lower surface correctly. Path: %s" % path)
		return false

	print("Successfully loaded airfoil '%s' with %d upper and %d lower points." % [name, upper_surface.size(), lower_surface.size()])
	return true
