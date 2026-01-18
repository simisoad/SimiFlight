class_name AeroExporter
extends RefCounted

static func export_xfoil(path: String, series: AeroSeries, profile: AirfoilProfile, mach: float, re: float) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file: return

	var version: String = ProjectSettings.get_setting("application/config/version", "1.0")
	file.store_line("SimiFoil v" + version)
	file.store_line("")
	file.store_line(" Calculated polar for: %s" % profile.name)
	file.store_line("")
	file.store_line(" 1 1 Reynolds number fixed Mach number fixed")
	file.store_line("")
	file.store_line(" xtrf =   1.000 (top)        1.000 (bottom)")

	var re_millions = re / 1000000.0
	file.store_line(" Mach =   %.3f     Re =     %.3f e 6     Ncrit =   15.850" % [mach, re_millions])
	file.store_line("")
	file.store_line("  alpha    CL        CD       CDp       CM      Top_Xtr  Bot_Xtr")
	file.store_line(" ------ -------- --------- --------- -------- -------- --------")

	for res in series.results:
		var line = "%7.3f  %8.4f  %9.5f  %9.5f  %8.4f  %7.4f  %7.4f" % [
			res.alpha, res.cl, res.cd, 0.0, res.cm, 1.0, 1.0
		]
		file.store_line(line)
	file.close()

static func export_csv(path: String, series: AeroSeries, profile: AirfoilProfile, mach: float, re: float) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file: return

	file.store_line("# Airfoil: %s" % profile.name)
	file.store_line("# Environment: Mach=%.2f Re=%.0f" % [mach, re])
	file.store_line("")
	file.store_line("Alpha (deg), Cl, Cd, Cm, L/D, Stall_Sigma")

	for res in series.results:
		var ld = res.cl / res.cd if abs(res.cd) > 0.00001 else 0.0
		var line = "%.2f, %.6f, %.6f, %.6f, %.2f, %.2f" % [
			res.alpha, res.cl, res.cd, res.cm, ld, res.sigma
		]
		file.store_line(line)
	file.close()
