class_name LutJSONExporter extends RefCounted

static func save_lut_as_json(lut: AirfoilLut, path: String) -> void:
	# 1. Construct a Dictionary representing the data
	var data = {
		"meta": {
			"name": lut.airfoil.name,
			"generated_by": "SimiFlight Curve Tool",
			"version": "1.0"
		},
		"axes": {
			"alpha_deg": lut.alpha_points,
			"mach": lut.mach_points,
			"reynolds": lut.reynolds_points
		},
		# We flatten the arrays or keep them as nested lists?
		# Flat arrays are usually easier for compute shaders/textures.
		"data": {
			"cl": lut.cl_data,
			"cd": lut.cd_data,
			"cm": lut.cm_data,
			"stall_fraction": lut.stall_data
		},
		"dimensions": {
			"alpha_count": lut.alpha_points.size(),
			"mach_count": lut.mach_points.size(),
			"re_count": lut.reynolds_points.size()
		}
	}

	# 2. Serialize to JSON text
	var json_string = JSON.stringify(data, "\t") # "\t" makes it pretty-printed (readable)

	# 3. Save
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("JSON LUT saved to: " + path)
	else:
		push_error("Failed to save JSON to: " + path)
