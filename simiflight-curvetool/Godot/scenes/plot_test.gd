extends Control

@onready var plot: Graph2D = %Plot
@onready var lift_curve_plot = LineSeries.new(Color.BLUE, 2.0)
@onready var drag_curve_plot = LineSeries.new(Color.RED, 2.0)
@onready var drag_curve_jf_plot = LineSeries.new(Color.ROSY_BROWN, 2.0)
@onready var lift_curve_from_JavaFoil = LineSeries.new(Color.GREEN, 2.0)
@onready var lift_curve_from_JavaFoil2 = LineSeries.new(Color.DARK_ORANGE, 2.0)
@onready var curves: Dictionary
@onready var scatter_series = ScatterSeries.new(Color.RED, 5.0, ScatterSeries.SHAPE.CIRCLE)
@onready var upper_surface: Array
@onready var lower_surface: Array

@export var mach_number: float = 0.1

var NACA_632012 = preload('res://data/airfoils/naca_632012.tres')

var Naca632012LiftCurve = preload('res://data/LiftCurves/Naca632012LiftCurve.gd')
var javaFoilLift: NACA632012LiftCurve
func _ready():
	curves = {"cl_curve": lift_curve_plot, "cd_curve": drag_curve_plot, "cd_curve_jf": drag_curve_jf_plot}
	javaFoilLift = Naca632012LiftCurve.new()
	
	# ohne await, werden die x und y Achse von GodPlot leit verschoben dargestellt...
	await self.get_tree().create_timer(0.01).timeout 
	_perpare_airfoil()
	await self.get_tree().create_timer(0.01).timeout 
	_draw_graph_aerodynamic_curves(curves, 0)
	await self.get_tree().create_timer(0.01).timeout 
	
	#_draw_graph_aerodynamic_curves(1) 
	
func _draw_graph_aerodynamic_curves(curves: Dictionary , stall_model: int) -> void:
	for i in range(javaFoilLift.NACA0012_WINDTUNNEL.size()):
		self.lift_curve_from_JavaFoil.add_point_vector(javaFoilLift.NACA0012_WINDTUNNEL[i])
	for i in range(javaFoilLift.lift_curve_with_calcfoil.size()):
		self.lift_curve_from_JavaFoil2.add_point_vector(javaFoilLift.lift_curve_with_calcfoil[i])
	#self.plot.add_series(self.lift_curve_from_JavaFoil)
	#self.plot.add_series(self.lift_curve_from_JavaFoil2)
	#self.plot.add_series(self.lift_curve_from_JavaFoil)
	await self.get_tree().create_timer(0.1).timeout
	
	var aerodynamic_curves: Dictionary = _compute_aerodynamic_curves_from_geometry(-180,180,5, stall_model)
	var cl_data: Array = aerodynamic_curves.get("cl")
	var cd_data: Array = aerodynamic_curves.get("cd")
	var cd_jf_data: Array = aerodynamic_curves.get("cd_jf")
	
	var lift_curve: LineSeries = curves.get("cl_curve")
	var drag_curve: LineSeries = curves.get("cd_curve")
	var drag_curve_jf: LineSeries = curves.get("cd_curve_jf")
	lift_curve.clear_data()
	drag_curve.clear_data()
	drag_curve_jf.clear_data()
	
	#self.scatter_series.clear_data()
	for angle in cl_data.size():
		lift_curve.add_point_vector(cl_data[angle])
	for angle in cd_data.size():
		drag_curve.add_point_vector(cd_data[angle])	
	for angle in cd_jf_data.size():
		drag_curve_jf_plot.add_point_vector(cd_jf_data[angle])
		
	self.plot.add_series(lift_curve)
	self.plot.add_series(drag_curve)
	#self.plot.add_series(drag_curve_jf)
	#self.plot.add_series(scatter_series)
	#print(cl_data)
	
	
func _perpare_airfoil() -> void:
	self.NACA_632012.airfoil_path = 'res://data/airfoils/Naca0015.txt'
	self.NACA_632012.load_from_dat(NACA_632012.airfoil_path)
	self.upper_surface = NACA_632012.upper_surface
	self.lower_surface = NACA_632012.lower_surface
	print("Upper_Surface: ", self.upper_surface)
	print("Lower_Surface: ", self.lower_surface)

func _get_camber_line() -> Array:
	var camber = []
	var count = min(upper_surface.size(), lower_surface.size())
	for i in range(count):
		var upper = upper_surface[i]
		var lower = lower_surface[i]
		var mid = (upper + lower) / 2.0
		camber.append(mid)
	return camber
# Gibt die maximale Dicke und Wölbung des Profils zurück.
# Benötigt, dass upper_surface und lower_surface von x=0 bis x=1 sortiert sind.
func _get_max_thickness_and_camber() -> Dictionary:
	var max_thickness = 0.0
	var max_camber = 0.0
	
	var count = min(upper_surface.size(), lower_surface.size())
	if count == 0:
		return {"thickness": 0.0, "camber": 0.0}

	# Wir nehmen an, dass upper_surface[i] und lower_surface[i] 
	# eine ähnliche x-Koordinate haben.
	for i in range(count):
		var y_upper = upper_surface[i].y
		var y_lower = lower_surface[i].y
		
		var thickness = y_upper - y_lower
		if thickness > max_thickness:
			max_thickness = thickness
			
		var camber_y = (y_upper + y_lower) / 2.0
		if abs(camber_y) > abs(max_camber):
			max_camber = camber_y
			
	return {"thickness": max_thickness, "camber": max_camber}	

func _compute_aerodynamic_curves_from_geometry(alpha_min := -180, alpha_max := 180, step := 1, stall_model: int = 1) -> Dictionary:
	var camber_line = _get_camber_line()
	var x = []
	var z = []
	for p in camber_line:
		x.append(p.x)
		z.append(p.y)

	# Numerische Ableitung dz/dx (zentral)
	var dzdx = []
	for i in range(x.size()):
		if i == 0:
			dzdx.append((z[1] - z[0]) / (x[1] - x[0]))
		elif i == x.size() - 1:
			dzdx.append((z[-1] - z[-2]) / (x[-1] - x[-2]))
		else:
			dzdx.append((z[i+1] - z[i-1]) / (x[i+1] - x[i-1]))

	# Annäherung von alpha_0 mit numerischer Integration
	var alpha_0 := 0.0
	var N := dzdx.size()
	if N > 1:
		for i in range(N):
			var theta := PI * float(i) / float(N - 1)
			# Die korrekte Formel beinhaltet (cos(theta) - 1)
			alpha_0 += dzdx[i] * (cos(theta) - 1.0)
		# Das Integral wird mit der Schrittweite multipliziert und normalisiert
		alpha_0 *= PI / float(N - 1) # Schrittweite d(theta)
		alpha_0 *= -1.0 / PI          # Faktor -1/PI
		
	print("Korrigierter alpha_0 (rad): ", alpha_0, " (deg): ", rad_to_deg(alpha_0))
	#print("alpha_0: ", alpha_0)
	# Holen wir uns die Geometrie-Daten einmal am Anfang
	var geometry = _get_max_thickness_and_camber()
	print("Geometrie-Analyse: ", geometry)
	
	# Berechne Lift-Kurve (CL über Alpha)
	var cl_data := []
	var cd_data := [] 
	var cd_data_from_JavaFoilLift: Array = []
	for alpha_deg in range(alpha_min, alpha_max + 1, step):
		var alpha_rad = deg_to_rad(alpha_deg)

	#return {"cl": cl_data, "cd": cd_data, "cd_jf": cd_data_from_JavaFoilLift}
		var aero_coeffs = _compute_final_aero_curves(alpha_rad, alpha_0, geometry, self.mach_number)
		cl_data.append(Vector2(alpha_deg, aero_coeffs.cl))
		cd_data.append(Vector2(alpha_deg, aero_coeffs.cd))
	return {"cl": cl_data, "cd": cd_data, "cd_jf": cd_data_from_JavaFoilLift}
	



# Helper-Funktion, die unser bestes Modell für den primären Bereich [-90°, +90°] enthält.
func _calculate_cl_primary(angle_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float) -> float:
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (angle_rad - alpha_0)
	var cd_max = 1.9
	var cl_post_stall = cd_max * sin(angle_rad - alpha_0) * cos(angle_rad)
	
	var alpha_stall_pos = deg_to_rad(9.0 + 50.0 * geometry.thickness) # 12.0 + 50.0 *
	var alpha_stall_neg = deg_to_rad(-7.0 - 50.0 * geometry.thickness)
	var sharpness_pos = 15.0
	var sharpness_neg = 8.0
	
	var sigma_pos = 1.0 / (1.0 + exp(sharpness_pos * (angle_rad - alpha_stall_pos)))
	var sigma_neg = 1.0 / (1.0 + exp(-sharpness_neg * (angle_rad - alpha_stall_neg)))
	var sigma = min(sigma_pos, sigma_neg)
	
	return sigma * cl_linear + (1.0 - sigma) * cl_post_stall	
# DIE FINALE MASTER-FUNKTION
# Ersetzt alle vorherigen _compute... Funktionen.
func _compute_final_aero_curves(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float = 0.1) -> Dictionary:

	# Hauptlogik für glatte 360° CL-Kurve
	var cl_primary = _calculate_cl_primary(alpha_rad, alpha_0, geometry, mach_number)
	
	var mirrored_alpha: float = alpha_rad - PI if alpha_rad > 0 else alpha_rad + PI
	# HIER WAR DER BUG: Verwende mirrored_alpha!
	var cl_mirrored = _calculate_cl_primary(mirrored_alpha, alpha_0, geometry, mach_number)
	
	var blend_sharpness_90 = 8.0
	var sigma_90 = 1.0 / (1.0 + exp(blend_sharpness_90 * (abs(alpha_rad) - deg_to_rad(90.0))))
	
	var final_cl = sigma_90 * cl_primary + (1.0 - sigma_90) * cl_mirrored
	
	# --- TEIL 2: HOCHPRÄZISE CD-BERECHNUNG ---
	
	# Wir verwenden das Modell, das du validiert hast, aber mit unserem finalen CL-Wert.
	var thickness = geometry.thickness
	var cd_min = 0.004 + 0.01 * thickness + 0.1 * pow(thickness, 4)
	
	var oswald_eff = 0.95
	var ar_eff = 50.0
	var cd_i = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall = cd_min + cd_i
	
	var cd_max_drag = 1.9
	# Wichtige Korrektur für CD: Asymmetrie durch alpha_0 berücksichtigen!
	# Das stellt sicher, dass der minimale Widerstand bei alpha=alpha_0 liegt, nicht bei alpha=0.
	var cd_post_stall = cd_max_drag * pow(sin(alpha_rad - alpha_0), 2)
	
	# Blending mit dem gleichen Sigma wie bei der CL-Berechnung
	var alpha_stall_pos = deg_to_rad(12.0 + 50.0 * geometry.thickness)
	var alpha_stall_neg = deg_to_rad(-8.0 - 50.0 * geometry.thickness)
	var sharpness_pos = 10.0
	var sharpness_neg = 5.0
	var sigma_pos_cd = 1.0 / (1.0 + exp(sharpness_pos * (alpha_rad - alpha_stall_pos)))
	var sigma_neg_cd = 1.0 / (1.0 + exp(-sharpness_neg * (alpha_rad - alpha_stall_neg)))
	var sigma_cd = min(sigma_pos_cd, sigma_neg_cd)
	var cd_wave = 0.0
	if mach_number > 0.75:
		cd_wave = 20 * pow(mach_number - 0.75, 4)
	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall
	final_cd = final_cd + cd_wave
	return {"cl": final_cl, "cd": final_cd}
