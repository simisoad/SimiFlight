extends Control

@onready var plot: Graph2D = %Plot
@onready var lift_curve_plot = LineSeries.new(Color.BLUE, 2.0)
@onready var lift_curve_plot_min_reynolds = LineSeries.new(Color.AQUA, 2.0)
@onready var drag_curve_plot = LineSeries.new(Color.RED, 2.0)
@onready var drag_curve_min_reynolds = LineSeries.new(Color.ROSY_BROWN, 2.0)
@onready var lift_curve_from_JavaFoil = LineSeries.new(Color.GREEN, 2.0)
@onready var lift_curve_from_JavaFoil2 = LineSeries.new(Color.DARK_ORANGE, 2.0)
@onready var curves: Dictionary
@onready var scatter_series = ScatterSeries.new(Color.RED, 5.0, ScatterSeries.SHAPE.CIRCLE)
@onready var upper_surface: Array
@onready var lower_surface: Array
@onready var airfoil: PackedVector2Array

@onready var final_lift_curve: LineSeries = LineSeries.new(Color.DARK_GREEN, 5.0)
@onready var final_drag_curve: LineSeries = LineSeries.new(Color.DARK_RED, 5.0)

@export var mach_number: float = 0.1
@export var min_reynolds_number: float = 100
@export var reynolds_number: float = 1000000
@export var alpha_min: float = -180.0
@export var alpha_max: float = 180.0
@export var alpha_step: float = 1.0

@onready var positive_stall_angle: float = 6.0
@onready var negative_stall_angle: float = -6.0
@onready var sharpness: float = 12.0
var NACA_632012 = preload('res://data/airfoils/naca_632012.tres')

var Naca632012LiftCurve = preload('res://data/LiftCurves/Naca632012LiftCurve.gd')
var javaFoilLift: NACA632012LiftCurve
func _ready():
	_set_line_edits()
	print("_compute_cd_max_realistic(0.3, 0.12, 1e6): Erwartet: ~1.87, ist: ", _compute_cd_max_realistic(0.3, 0.12, 1e6))  # Erwartet: ~1.87
	print("_compute_cd_max_realistic(1.0, 0.12, 1e6): Erwartet: ~2.10, ist: ",_compute_cd_max_realistic(1.0, 0.12, 1e6))  # Erwartet: ~2.35
	print("_compute_cd_max_realistic(5.0, 0.12, 1e6): Erwartet: ~1.87, ist: ",_compute_cd_max_realistic(5.0, 0.12, 1e6))  # Erwartet: ~1.92
	print("_compute_cd_max_realistic(10.0, 0.12, 1e6): Erwartet: ~2.06, ist: ",_compute_cd_max_realistic(10.0, 0.12, 1e6)) # Erwartet: ~3.0
	print("_compute_cd_max_realistic(20.0, 0.12, 1e6): Erwartet: ~2.43, ist: ",_compute_cd_max_realistic(20.0, 0.12, 1e6)) # Erwartet: ~2.2
	pass
func _show_lut()-> void:
	pass
	
	# for alt in altitude_points:
#   for mach in mach_points:
#     for alpha in alpha_points:
#       data.append(...)
func _set_line_edits() -> void:
	%LineEditPositiveStallAngle.text = str(self.positive_stall_angle)
	%LineEditMachNumber.text = str(self.mach_number)
	%LineEditReynoldsNumber.text = str(self.reynolds_number)
func _start_cd_cl_calculations() -> void:
	lift_curve_plot.clear_data()
	lift_curve_plot_min_reynolds.clear_data()
	drag_curve_plot.clear_data()
	drag_curve_min_reynolds.clear_data()
	lift_curve_from_JavaFoil.clear_data()
	lift_curve_from_JavaFoil2.clear_data()
	final_drag_curve.clear_data()
	final_lift_curve.clear_data()
	self.plot.clear_data()
	curves = {"cl_curve": lift_curve_plot, "cd_curve": drag_curve_plot, "cd_curve_minR": drag_curve_min_reynolds, "cl_curve_minR": lift_curve_plot_min_reynolds }
	javaFoilLift = Naca632012LiftCurve.new()
	
	# ohne await, werden die x und y Achse von GodPlot leit verschoben dargestellt...
	await self.get_tree().create_timer(0.01).timeout
	_perpare_airfoil()
	await self.get_tree().create_timer(0.01).timeout
	_draw_graph_aerodynamic_curves(curves)
	await self.get_tree().create_timer(0.01).timeout
	
	#_draw_graph_aerodynamic_curves(1) 
	
func _draw_graph_aerodynamic_curves(curves: Dictionary) -> void:
	for i in range(javaFoilLift.NACA0012_WINDTUNNEL.size()):
		self.lift_curve_from_JavaFoil.add_point_vector(javaFoilLift.NACA0012_WINDTUNNEL[i])
	for i in range(javaFoilLift.lift_curve_with_calcfoil.size()):
		self.lift_curve_from_JavaFoil2.add_point_vector(javaFoilLift.lift_curve_with_calcfoil[i])
	#self.plot.add_series(self.lift_curve_from_JavaFoil)
	#self.plot.add_series(self.lift_curve_from_JavaFoil2)
	#self.plot.add_series(self.lift_curve_from_JavaFoil)
	await self.get_tree().create_timer(0.1).timeout
	
	var aerodynamic_curves: Dictionary = _compute_aerodynamic_curves_from_geometry(self.alpha_min,self.alpha_max,self.alpha_step)
	var cl_data: Array = aerodynamic_curves.get("cl")
	var cl_data_minR: Array = aerodynamic_curves.get("cl_minR")
	
	var cd_data: Array = aerodynamic_curves.get("cd")
	var cd_mR_data: Array = aerodynamic_curves.get("cd_minR")
	
	
	var final_cl_data: Array = blend_curve(cl_data, cl_data_minR)
	var final_cd_data: Array = _combine_curves(cd_data, cd_mR_data)
	#var final_cd_data: Array = _combine_curves_simple(cl_data, cl_data_minR, true)
	
	var lift_curve: LineSeries = curves.get("cl_curve")
	var drag_curve: LineSeries = curves.get("cd_curve")
	var cd_curve_minR: LineSeries = curves.get("cd_curve_minR")
	var lift_curve_minR: LineSeries = curves.get("cl_curve_minR")
	
	lift_curve.clear_data()
	drag_curve.clear_data()
	cd_curve_minR.clear_data()
	var max_drag_final: float = 0.0
	var max_drag_m1: float = 0.0
	var max_drag_m2: float = 0.0
	#self.scatter_series.clear_data()
	for angle in cl_data.size():
		lift_curve.add_point_vector(cl_data[angle])
	for angle in cd_data.size():
		drag_curve.add_point_vector(cd_data[angle])
		if cd_data[angle].y > max_drag_m1:
			max_drag_m1 = cd_data[angle].y
			
	for angle in cd_mR_data.size():
		drag_curve_min_reynolds.add_point_vector(cd_mR_data[angle])
		if cd_mR_data[angle].y > max_drag_m2:
			max_drag_m2 = cd_mR_data[angle].y
				
	for angle in cl_data_minR.size():
		lift_curve_minR.add_point_vector(cl_data_minR[angle])
	for angle in final_cl_data.size():
		self.final_lift_curve.add_point_vector(final_cl_data[angle])

	for angle in final_cd_data.size():
		self.final_drag_curve.add_point_vector(final_cd_data[angle])
		if final_cd_data[angle].y > max_drag_final:
			max_drag_final = final_cd_data[angle].y
		
	%MaxDragLabel.text = str(
	"Max Drag: C: %0.2f, m1: %0.2f, m2: %0.2f " % [max_drag_final, max_drag_m1, max_drag_m2])
	
	self.plot.add_series(lift_curve)
	self.plot.add_series(lift_curve_minR)
	#self.plot.add_series(drag_curve)
	#self.plot.add_series(drag_curve_min_reynolds)
	
	self.plot.add_series(self.final_lift_curve)
	#self.plot.add_series(self.final_drag_curve)
	#self.plot.add_series(scatter_series)
	#print(cl_data)
func _combine_curves(curve1: Array, curve2: Array, is_lift: bool = false) -> Array:
	var combined: Array = []
	if curve1.size() != curve2.size():
		push_error("Kurven haben unterschiedliche Größen – Kombination nicht möglich!")
		return combined
	
	# Übergangsgewicht basierend auf Reynolds-Zahl
	var log_min_R = log(self.min_reynolds_number)
	var log_max_R = log(1e7)
	var log_current_R = log(clamp(self.reynolds_number, self.min_reynolds_number, 1e7))
	var t = (log_current_R - log_min_R) / (log_max_R - log_min_R)  # ergibt Wert von 0.0 bis 1.0
	t = pow(t, 0.7)  # Beschleunigt den Übergang
	# oder sigmoid:
	#t = 1.0 / (1.0 + exp(-10.0 * (t - 0.5)))  # weicher Übergang in der Mitte

	for i in range(curve1.size()):
		var alpha = curve1[i].x  # beide Kurven haben gleiche x-Werte
		var y1 = curve1[i].y
		var y2 = curve2[i].y
		
		# Interpolation mit Gewichtung t
		var y_combined = lerp(y2, y1, t)  # Wichtig: y2 = minRe, y1 = maxRe
		combined.append(Vector2(alpha, y_combined))
	
	return combined
	
func weight(alpha: float) -> float:
	# Gewichtung: 1.0 bei alpha = 0°, 0.0 bei alpha <= -45° oder >= +45°
	var alpha_deg = rad_to_deg(alpha)
	var abs_alpha = abs(alpha_deg)
	var full_merge_alpha: float = 30.0
	var middle_merge_alpha: float = 45.0
	var none_merge_alpha: float = 90.0
	if abs_alpha >= none_merge_alpha:
		return 0.0
	elif abs_alpha <= full_merge_alpha:
		return 1.0
	elif abs_alpha <= middle_merge_alpha:
		return (1.0 - (abs_alpha - middle_merge_alpha) / (none_merge_alpha - middle_merge_alpha))/2
	else:
		return 1.0 - (abs_alpha - full_merge_alpha) / (none_merge_alpha - full_merge_alpha)
# Passt die Kurve so an, dass sie in einem bestimmten Bereich auf Kurve B überblendet.
# Der Übergang an den Rändern des Bereichs ist weich.
#
# @param curve_a: Die Basiskurve (Array von Vector2)
# @param curve_b: Die Kurve, auf die überblendet werden soll (Array von Vector2)
# @param blend_start_deg: Startwinkel des Bereichs in Grad (z.B. -45.0)
# @param blend_end_deg: Endwinkel des Bereichs in Grad (z.B. 0.0)
# @param transition_width_deg: Die Breite des weichen Übergangs in Grad (z.B. 10.0)
# @return: Die neue, überblendete Kurve (Array von Vector2)
func blend_curve(
	curve_a: Array, 
	curve_b: Array, 
	blend_start_deg: float = -45.0, 
	blend_end_deg: float = 0.0, 
	transition_width_deg: float = 10.0
) -> Array:
	
	var blended := []
	
	# Definiere die Ränder für die Übergänge in Radiant
	# Übergang IN Kurve B hinein
	var transition_in_start: float = blend_start_deg - transition_width_deg
	var transition_in_end: float = blend_start_deg
	
	# Übergang AUS Kurve B heraus
	var transition_out_start: float = (blend_end_deg)
	var transition_out_end: float = (blend_end_deg + transition_width_deg)

	for i in range(min(curve_a.size(), curve_b.size())):
		var point_a: Vector2 = curve_a[i]
		var point_b: Vector2 = curve_b[i]
		var alpha: float = point_a.x
		
		# Berechnung der Gewichtung für Kurve B.
		# Wir nutzen zwei smoothstep-Funktionen, um die Gewichtung zu formen.
		
		# 1. Anstieg der Gewichtung (von 0 auf 1) vor dem Startpunkt
		var weight_increase: float = smoothstep(transition_in_start, transition_in_end, alpha)
		
		# 2. Abfall der Gewichtung (von 0 auf 1), den wir später subtrahieren
		var weight_decrease: float = smoothstep(transition_out_start, transition_out_end, alpha)
		
		# Die endgültige Gewichtung für Kurve B ist der Anstieg minus der Abfall.
		# - Unterhalb von `transition_in_start`: weight_b = 0 - 0 = 0 -> 100% Kurve A
		# - Zwischen `transition_in_end` und `transition_out_start`: weight_b = 1 - 0 = 1 -> 100% Kurve B
		# - Oberhalb von `transition_out_end`: weight_b = 1 - 1 = 0 -> 100% Kurve A
		var weight_b: float = weight_increase - weight_decrease
		
		# Die Gewichtung für Kurve A ist einfach der Rest zu 1.0
		var weight_a: float = 1.0 - weight_b
		print("alpha: ", alpha, "weight_a: ", weight_a, ", weight_b: ", weight_b)
		# Den neuen Y-Wert durch lineare Interpolation (lerp) der beiden Kurvenpunkte bestimmen
		var blended_y: float = weight_a * point_a.y + weight_b * point_b.y
		
		# Den neuen Punkt zur Ergebnisliste hinzufügen
		blended.append(Vector2(alpha, blended_y))
	
	return blended

func blend_curves(curve_a: Array, curve_b: Array) -> Array:
	var mixed_curve = []

	for i in range(min(curve_a.size(), curve_b.size())):
		var pt_a = curve_a[i]
		var pt_b = curve_b[i]

		var alpha_a = pt_a.x
		var alpha_b = pt_b.x

		if abs(alpha_a - alpha_b) > 0.001:
			push_error("Alpha mismatch at index %d: %f vs %f" % [i, alpha_a, alpha_b])
			continue

		var t = weight(alpha_a)
		var y_mixed = (1.0 - t) * pt_a.y + t * pt_b.y

		mixed_curve.append(Vector2(alpha_a, y_mixed))

	return mixed_curve
	


func _combine_curves_simple(p_curve_01: Array, p_curve_02: Array, p_is_lift_curve: bool = false) -> Array:
	var new_y: float = 0.0
	var new_curve: Array[Vector2] = []
	var factor_c_01: float = 1.0
	var factor_c_02: float = 1.0
	for i in p_curve_01.size():
		if p_is_lift_curve:
			if i < 90:
				factor_c_01 = 20.0
				factor_c_02 = 1.0
			elif i < 180:
				factor_c_01 = 1.0
				factor_c_02 = 8.0
			elif i < 270:
				factor_c_01 = 1.0
				factor_c_02 = 8.0
			else:
				factor_c_01 = 20.0
				factor_c_02 = 1.0
		new_y = p_curve_01[i].y*factor_c_01 + p_curve_02[i].y*factor_c_02
		new_y /= (factor_c_01+factor_c_02)
		new_curve.append(Vector2(p_curve_01[i].x, new_y))
	return new_curve
	
func _perpare_airfoil() -> void:
	
	self.NACA_632012.airfoil_path = 'res://data/airfoils/NACA0006_Supersonic.txt'
	self.NACA_632012.airfoil_path = 'res://data/airfoils/Naca0015.txt'
	self.NACA_632012.airfoil_path = 'res://data/airfoils/naca_632012_leerz.txt'
	self.NACA_632012.airfoil_path = 'res://data/airfoils/Bikonvexprofil8%.txt'
	
	self.NACA_632012.load_from_dat(NACA_632012.airfoil_path)
	self.upper_surface = NACA_632012.upper_surface
	self.lower_surface = NACA_632012.lower_surface
	print("Upper_Surface: ", self.upper_surface)
	print("Lower_Surface: ", self.lower_surface)
	#self.upper_surface.reverse()

	var airfoil_vis_upper: LineSeries = LineSeries.new(Color.DARK_GREEN,3.0)
	var airfoil_vis_lower: LineSeries = LineSeries.new(Color.DARK_GREEN,3.0)
	for i in self.upper_surface.size():
		airfoil_vis_upper.add_point_vector(self.upper_surface[i])
	for i in self.lower_surface.size():
		airfoil_vis_lower.add_point_vector(self.lower_surface[i])
	var ratio = (%Airfoil_Panel.size.x / %Airfoil_Panel.size.y)
	%Airfoil_Panel.y_max = .1 * ratio/2
	%Airfoil_Panel.y_min = -0.1 * ratio/2
	%Airfoil_Panel.x_max = 1.0
	
	%Airfoil_Panel.add_series(airfoil_vis_upper)
	%Airfoil_Panel.add_series(airfoil_vis_lower)
	self.plot.title = String(
		"Mach-Number: " + str(mach_number)+
		" Reynolds-Number: " + str(reynolds_number))
	self.plot.title_size = 1.4
	#%Plot.vertical_title = "[color=blue]blue[/color] CL [color=blue]white[/color] / [color=blue]red[/color] CD"
	%TitleLabel.text = NACA_632012.name

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

func _compute_aerodynamic_curves_from_geometry(p_alpha_min: float = -180.0, p_alpha_max: float = 180.0, p_step: float = 1.0) -> Dictionary:
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
	var cl_data: Array = []
	var cd_data: Array = []
	var cd_min_reynolds: Array = []
	var cl_min_reynolds: Array = []
	#var alpha_deg: float = p_alpha_min
	
	#while alpha_deg <= p_alpha_max:
		#var alpha_rad = deg_to_rad(alpha_deg)
		#print("alpha_deg: ", alpha_deg)
	for alpha_deg in range(p_alpha_min, alpha_max + 1, p_step):
		var alpha_rad = deg_to_rad(alpha_deg)

	#return {"cl": cl_data, "cd": cd_data, "cd_minR": cd_min_reynolds}
		var aero_coeffs: Dictionary = _compute_final_aero_curves(alpha_rad, alpha_0, geometry, self.mach_number, self.reynolds_number)
		cl_data.append(Vector2(alpha_deg, aero_coeffs.cl))
		cd_data.append(Vector2(alpha_deg, aero_coeffs.cd))
		aero_coeffs = _compute_final_aero_curves2(alpha_rad, alpha_0, geometry, self.mach_number, self.reynolds_number)
		cd_min_reynolds.append(Vector2(alpha_deg, aero_coeffs.cd))
		cl_min_reynolds.append(Vector2(alpha_deg, aero_coeffs.cl))
		alpha_deg += p_step
	return {"cl": cl_data, "cd": cd_data, "cd_minR": cd_min_reynolds, "cl_minR": cl_min_reynolds}
func _compute_cd_max_realistic(mach: float, thickness: float, reynolds: float) -> float:
	# Basis-CD für inkompressible Strömung (validiert mit NASA-Daten)
	#var cd_base = 1.25 + 0.5 * thickness  # Korrigierte Basisformel
	#var cd_base = 1.8 + 0.6 * thickness
	var cd_base = (2.0 + 0.6 * thickness) * (1.1 - 0.1 * clamp(mach, 0.0, 1.0))
	# Reynolds-Einfluss (physikalisch korrekte Skalierung)
	var re_exponent = clamp(log(reynolds) / log(1e6), 0.7, 1.3)
	var re_factor = 0.8 + 0.2 * re_exponent  # Bei Re=1e6 → 1.0
	
	# Hyperschall-Korrektur (max +50% bei Mach 20)
	var hypersonic_factor = 1.0
	if mach > 5.0:
		hypersonic_factor = min(1.0 + 0.025 * (mach - 5.0), 1.5)
	
	# Transsonischer Peak (max +20%)
	var transonic_peak_factor = 1.0
	if mach > 0.8 && mach < 1.2:
		transonic_peak_factor = 1.0 + 0.2 * exp(-25 * pow(mach - 1.0, 2))
	
	# Finale Berechnung (physikalisch konsistent)
	return cd_base * re_factor * hypersonic_factor * transonic_peak_factor

func _calculate_cl_primary(
	angle_rad: float,
	current_alpha_0: float,
	sharpness_pos: float,
	alpha_stall_pos_re: float,
	sharpness_neg: float,
	alpha_stall_neg_re: float,
	cd_max: float ) -> float:
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (angle_rad - current_alpha_0)
	#var cd_max = 2.1 # An Windtunnel-Daten angepasst
	var cl_post_stall = cd_max * sin(angle_rad - current_alpha_0) * cos(angle_rad)
	
	var sigma_pos = 1.0 / (1.0 + exp(sharpness_pos * (angle_rad - alpha_stall_pos_re)))
	var sigma_neg = 1.0 / (1.0 + exp(-sharpness_neg * (angle_rad - alpha_stall_neg_re)))
	#print("sigma_pos: ",sigma_pos,", sigma_neg: ", sigma_neg)
	var sigma = min(sigma_pos, sigma_neg)
	
	return sigma * cl_linear + (1.0 - sigma) * cl_post_stall
# DIE FINALE, PRODUKTIONSREIFE MASTER-FUNKTION
func _compute_final_aero_curves(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float, reynolds_number: float) -> Dictionary:
	
	var thickness = geometry.thickness
	var re_exponent: float = clamp(log(reynolds_number) / log(1e6), 0.7, 1.3)
	var alpha_stall_base: float = deg_to_rad(self.positive_stall_angle + 50.0 * thickness)
	var alpha_stall_base_ng: float = deg_to_rad(self.negative_stall_angle - 50.0 * thickness)
	var alpha_stall_pos_re: float = alpha_stall_base * re_exponent
	var alpha_stall_neg_re: float = alpha_stall_base_ng * re_exponent
		
	var sharpness_pos: float = 15.0
	var sharpness_neg: float = 8.0
	var use_compute_cd_max_realistic: bool = false
		# 1. Basis-CD_max abhängig von Profildicke (dickere Profile > CD_max)
	
	var cd_max_base: float = 1.8 + 0.6 * thickness

	var cl_primary: float = _calculate_cl_primary(alpha_rad, alpha_0,sharpness_pos,alpha_stall_pos_re, sharpness_neg,alpha_stall_neg_re, cd_max_base)
	var mirrored_alpha: float = alpha_rad - PI if alpha_rad > 0 else alpha_rad + PI
	var cl_mirrored: float = _calculate_cl_primary(mirrored_alpha, -alpha_0,sharpness_pos,alpha_stall_pos_re, sharpness_neg,alpha_stall_neg_re, cd_max_base)
	var blend_sharpness_90: float = 8.0
	var sigma_90: float = 1.0 / (1.0 + exp(blend_sharpness_90 * (abs(alpha_rad) - deg_to_rad(90.0))))
	var final_cl: float = sigma_90 * cl_primary + (1.0 - sigma_90) * cl_mirrored
	
	# --- TEIL 2: CD-BERECHNUNG (mit finalem Feinschliff) ---
	var cf: float = 0.074 / pow(reynolds_number, 0.2)
	var cd_min: float = 2.0 * cf * (1.0 + 2.0 * thickness)
	var oswald_eff: float = 0.95
	var ar_eff: float = 50.0
	var cd_i: float = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall: float = cd_min + cd_i
	

	
	# 2. Reynolds-Korrektur (niedriges Re -> höherer CD_max)
	var re_factor_drag = clamp(1.0 + 2.5e5 / max(reynolds_number, 1e4), 1.0, 3.0)
	var cd_max_drag_re = cd_max_base * re_factor_drag
	# 3. Mach-Korrektur (Überschall-Erhöhung)
	if mach_number > 0.9:
		cd_max_drag_re *= 1.0 + 0.3 * (mach_number - 0.9) # +30% bei Mach 1.0
	# 4. Sicherheitsbegrenzung (niemals über 3.0!)
	cd_max_drag_re = clamp(cd_max_drag_re, 1.5, 100.0)
	
	var cd_post_stall = cd_max_drag_re * pow(sin(alpha_rad), 2)
	
	# Blending
	var sigma_pos_cd = 1.0 / (1.0 + exp(sharpness_pos * (alpha_rad - alpha_stall_pos_re)))
	var sigma_neg_cd = 1.0 / (1.0 + exp(-sharpness_neg * (alpha_rad - alpha_stall_neg_re)))
	var sigma_cd = min(sigma_pos_cd, sigma_neg_cd)
	var mach_effect_methode = 1
	var cd_wave = 0.0
	if mach_effect_methode == 0:
		cd_wave = _mach_effects_method0()
	else:
		cd_wave = _mach_effects_method1(thickness)
		#print("cd_wave: ", cd_wave)
	

	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall + cd_wave
	
	return {"cl": final_cl, "cd": final_cd}

func _mach_effects_method0() -> float:
	var cd_wave = 0.0
	var m_crit = 0.75 # Kritische Mach-Zahl, wo der Anstieg beginnt
	var m_peak = 1.05 # Mach-Zahl des maximalen Widerstands

	if mach_number > m_crit:
		if mach_number <= m_peak:
			# Transsonischer Anstieg: Wir verwenden eine Sinus-Funktion für einen glatten Peak
			var x = (mach_number - m_crit) / (m_peak - m_crit) # Skaliert den Bereich auf 0-1
			var peak_drag = 0.08 # Zusätzlicher Peak-Widerstand (realistischer Wert)
			cd_wave = peak_drag * sin(x * PI / 2.0)
		else:
			# Überschall-Abfall: Der Widerstand fällt mit ~1/sqrt(M^2-1) ab
			var peak_drag = 0.08 # Muss derselbe Wert sein wie oben
			var decay_factor = sqrt(pow(m_peak, 2) - 1.0) / sqrt(pow(mach_number, 2) - 1.0)
			cd_wave = peak_drag * decay_factor
	return cd_wave

func _mach_effects_method1(thickness: float) -> float:
	var m_crit = 0.7 + 0.1 * thickness  # Dickere Profile haben niedrigere M_crit!
	var cd_wave = 0.0

	if mach_number > m_crit:
		var mach_diff = mach_number - m_crit
		var relative_thickness = thickness * 100  # in Prozent
		
		# Transsonischer Bereich (M_crit < M < 1.0)
		if mach_number < 1.0:
			cd_wave = 0.002 * exp(10 * mach_diff) * relative_thickness
		elif mach_number < 1.05:
			cd_wave = 0.08 * mach_diff / 0.35
		
		# Überschall (M > 1.0)
		else:
			var beta = max(sqrt(mach_number * mach_number - 1.0), 0.01)
			cd_wave = 4 * thickness * thickness / beta  # Lineare Überschalltheorie
	return cd_wave
	
func _compute_final_aero_curves2(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float, reynolds_number: float) -> Dictionary:
	var thickness = geometry.thickness
	
	# 1. REYNOLDS-EINFLUSS (logarithmisch)
	var re_exponent = clamp(log(reynolds_number) / log(1e6), 0.7, 1.3)
	var alpha_stall_base = deg_to_rad(self.positive_stall_angle + 45.0 * thickness)
	var alpha_stall_pos_re = alpha_stall_base * re_exponent
	
	# 2. CD-MAX BERECHNUNG (dickere Profile > höherer CD)
	var use_compute_cd_max_realistic = true
	var cd_max: float = 0.0
	var cd_max_for_cl: float = 1.8 + 0.6 * thickness
	if use_compute_cd_max_realistic:
		cd_max = _compute_cd_max_realistic(mach_number,thickness,reynolds_number)
	else:
		cd_max = cd_max_for_cl
	
	
	# 3. CL-BERECHNUNG
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (alpha_rad - alpha_0)
	var cl_post_stall = (cd_max_for_cl / 2) * sin(2 * alpha_rad)  # Viterna-Methode
	
	var sharpness = self.sharpness
	var sigma = 1.0 / (1.0 + exp(sharpness * (abs(alpha_rad) - alpha_stall_pos_re)))
	var final_cl = sigma * cl_linear + (1.0 - sigma) * cl_post_stall
	
	# 4. CD-BERECHNUNG (KORRIGIERT)
	# a) Reibungswiderstand (Prandtl-Schlichting)
	var cf = 0.455 / pow(log(reynolds_number)/log(10), 2.58)
	var cd_friction = 2.0 * cf * (1.0 + 2.2 * thickness + 100 * pow(thickness, 4))
	
	# b) Induzierter Widerstand
	var oswald_eff = 0.85 + 0.15 * (1 - exp(-reynolds_number/1e6)) - 0.1 * thickness
	var ar_eff = 50.0  # Effektive Streckung
	var cd_induced = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall = cd_friction + cd_induced
	
	# c) Post-Stall Widerstand
	var cd_post_stall: float = 0.0
	if use_compute_cd_max_realistic:
		if mach_number < 5.0:
			cd_post_stall = cd_max * pow(sin(alpha_rad), 2)
		else:
			# Newton'sche Theorie: CD = 2 * sin²(α) für Hyperschall
			cd_post_stall = 2.0 * pow(sin(alpha_rad), 2) * (1.0 + 0.05 * (mach_number - 5.0))
	else:
		cd_post_stall = cd_max * pow(sin(alpha_rad), 2) * (1.0 + 0.5 * (1 - re_exponent))
	# d) Mach-Effekte (KORRIGIERT)
	var m_crit = 0.7 + 0.1 * thickness
	var cd_wave = 0.0
	if mach_number > m_crit:
		if mach_number < 1.0:
			cd_wave = 0.002 * exp(10 * (mach_number - m_crit)) * thickness * 100
		elif mach_number < 1.05:  # Glättung bei Mach 1.0
			cd_wave = 0.08 * (mach_number - m_crit) / 0.35
		else:
			var beta = max(sqrt(mach_number * mach_number - 1.0), 0.01)
			cd_wave = 4 * thickness * thickness / beta
	
	# e) Finales CD mit Blending
	var sigma_cd = 1.0 / (1.0 + exp(sharpness * (abs(alpha_rad) - alpha_stall_pos_re)))
	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall + cd_wave
	
	return {"cl": final_cl, "cd": final_cd}

func _calculate_luts(combine_methos: bool = false) -> void:
	var airfoil_to_process = preload("res://data/airfoils/naca_632012.tres")
	airfoil_to_process.airfoil_path = 'res://data/airfoils/naca_632012_leerz.txt'
	airfoil_to_process.load_from_dat(airfoil_to_process.airfoil_path)
	
	var save_path = "res://data/luts/naca_632012_lut.tres"
	if combine_methos:
		LutGenerator.generate_and_save_lut_combine_m1_m2(airfoil_to_process, save_path)
	else:
		LutGenerator.generate_and_save_lut(airfoil_to_process, save_path)
			
	
func _on_calc_clcd_button_pressed() -> void:
	_start_cd_cl_calculations()



func _on_create_lu_ts_pressed() -> void:
	_calculate_luts()


func _on_create_lu_ts_combine_methods_pressed() -> void:
	_calculate_luts(true)


func _on_line_edit_positive_stall_angle_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		self.positive_stall_angle = new_text.to_float()


func _on_line_edit_mach_number_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		self.mach_number = new_text.to_float()


func _on_line_edit_reynolds_number_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		self.reynolds_number = new_text.to_float()


func _on_line_edit_sharpness_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		self.sharpness = new_text.to_float()
