class_name AeroPostProcessor
extends RefCounted

static func calculate_3d_series(source: AeroSeries, config: LutGenerator.GeneratorConfig) -> AeroSeries:
	var res_3d = AeroSeries.new()
	res_3d.name = source.name + " (3D)"
	for r in source.results:
		var out = AeroPhysicsModel.calculate_finite_wing(
			r.cl, r.cd, config.aspect_ratio, config.oswald_efficiency,
			config.sweep_deg, config.taper, config.sweep_location
		)
		var nr = AeroResult.new()
		nr.alpha = r.alpha; nr.cl = out.cl; nr.cd = out.cd; nr.cm = r.cm; nr.sigma = r.sigma
		res_3d.results.append(nr)
	return res_3d

static func find_efficiency_markers(series: AeroSeries) -> Dictionary:
	var best_glide: AeroResult = null
	var min_sink: AeroResult = null
	var max_ld = -1.0
	var max_endurance = -1.0

	for r in series.results:
		if r.cl > 0.1 and r.cd > 0.0001:
			var ld = r.cl / r.cd
			if ld > max_ld:
				max_ld = ld; best_glide = r

			var endurance = pow(r.cl, 1.5) / r.cd
			if endurance > max_endurance:
				max_endurance = endurance; min_sink = r

	return {"best_glide": best_glide, "min_sink": min_sink, "max_ld": max_ld}
