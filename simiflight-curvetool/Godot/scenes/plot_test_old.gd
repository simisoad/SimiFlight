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

@export var mach_number: float = 0.1
@export var min_reynolds_number: float = 100
@export var reynolds_number: float = 1000000
@export var alpha_min: float = -180.0
@export var alpha_max: float = 180.0
@export var alpha_step: float = 1.0

var NACA_632012 = preload('res://data/airfoils/naca_632012.tres')

var Naca632012LiftCurve = preload('res://data/LiftCurves/Naca632012LiftCurve.gd')
var javaFoilLift: NACA632012LiftCurve
func _ready():
	
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
	var cd_data: Array = aerodynamic_curves.get("cd")
	var cd_mR_data: Array = aerodynamic_curves.get("cd_minR")
	var cl_data_minR: Array = aerodynamic_curves.get("cl_minR")
	
	var lift_curve: LineSeries = curves.get("cl_curve")
	var drag_curve: LineSeries = curves.get("cd_curve")
	var cd_curve_minR: LineSeries = curves.get("cd_curve_minR")
	var lift_curve_minR: LineSeries = curves.get("cl_curve_minR")
	lift_curve.clear_data()
	drag_curve.clear_data()
	cd_curve_minR.clear_data()
	var max_drag: float = 0.0
	#self.scatter_series.clear_data()
	for angle in cl_data.size():
		lift_curve.add_point_vector(cl_data[angle])
	for angle in cd_data.size():
		drag_curve.add_point_vector(cd_data[angle])	
		if cd_data[angle].y > max_drag:
			max_drag = cd_data[angle].y
	for angle in cd_mR_data.size():
		drag_curve_min_reynolds.add_point_vector(cd_mR_data[angle])
	for angle in cl_data_minR.size():
		lift_curve_minR.add_point_vector(cl_data_minR[angle])
	%MaxDragLabel.text = ("Max Drag: " + str(max_drag))
		
	self.plot.add_series(lift_curve)
	self.plot.add_series(drag_curve)
	#self.plot.add_series(cd_curve_minR)
	#self.plot.add_series(lift_curve_minR)
	#self.plot.add_series(scatter_series)
	#print(cl_data)
	
	
func _perpare_airfoil() -> void:
	self.NACA_632012.airfoil_path = 'res://data/airfoils/NACA0006_Supersonic.txt'
	self.NACA_632012.airfoil_path = 'res://data/airfoils/Naca0015.txt'
	self.NACA_632012.airfoil_path = 'res://data/airfoils/NACA 1107-73.txt'
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
		aero_coeffs = _compute_final_aero_curves(alpha_rad, alpha_0, geometry, self.mach_number, self.min_reynolds_number)
		cd_min_reynolds.append(Vector2(alpha_deg, aero_coeffs.cd))
		cl_min_reynolds.append(Vector2(alpha_deg, aero_coeffs.cl))
		alpha_deg += p_step
	return {"cl": cl_data, "cd": cd_data, "cd_minR": cd_min_reynolds, "cl_minR": cl_min_reynolds}
	

func _calculate_cl_primary(
	angle_rad: float,
 	current_alpha_0: float, 
	sharpness_pos: float,
	alpha_stall_pos_re: float,
	sharpness_neg: float,
	alpha_stall_neg_re: float ) -> float:
	var cl_slope = (2.0 * PI) / sqrt(1.0 - pow(min(mach_number, 0.95), 2))
	var cl_linear = cl_slope * (angle_rad - current_alpha_0)
	var cd_max = 2.1 # An Windtunnel-Daten angepasst
	var cl_post_stall = cd_max * sin(angle_rad - current_alpha_0) * cos(angle_rad)
	
	var sigma_pos = 1.0 / (1.0 + exp(sharpness_pos * (angle_rad - alpha_stall_pos_re)))
	var sigma_neg = 1.0 / (1.0 + exp(-sharpness_neg * (angle_rad - alpha_stall_neg_re)))
	var sigma = min(sigma_pos, sigma_neg)
	
	return sigma * cl_linear + (1.0 - sigma) * cl_post_stall
# DIE FINALE, PRODUKTIONSREIFE MASTER-FUNKTION
func _compute_final_aero_curves(alpha_rad: float, alpha_0: float, geometry: Dictionary, mach_number: float, reynolds_number: float) -> Dictionary:
	
	var thickness = geometry.thickness

	# --- GEMEINSAME PARAMETER ---
	var re_factor = 1.0 - 0.3 / (1.0 + reynolds_number / 5.0e5)
	var alpha_stall_pos_re = deg_to_rad(11.0 + 50.0 * thickness) * re_factor
	var alpha_stall_neg_re = deg_to_rad(-7.0 - 50.0 * thickness) * re_factor
	var sharpness_pos = 15.0
	var sharpness_neg = 8.0



	var cl_primary = _calculate_cl_primary(alpha_rad, alpha_0,sharpness_pos,alpha_stall_pos_re, sharpness_neg,alpha_stall_neg_re)
	var mirrored_alpha: float = alpha_rad - PI if alpha_rad > 0 else alpha_rad + PI
	var cl_mirrored = _calculate_cl_primary(mirrored_alpha, -alpha_0,sharpness_pos,alpha_stall_pos_re, sharpness_neg,alpha_stall_neg_re)
	var blend_sharpness_90 = 8.0
	var sigma_90 = 1.0 / (1.0 + exp(blend_sharpness_90 * (abs(alpha_rad) - deg_to_rad(90.0))))
	var final_cl = sigma_90 * cl_primary + (1.0 - sigma_90) * cl_mirrored
	
	# --- TEIL 2: CD-BERECHNUNG (mit finalem Feinschliff) ---
	var cf = 0.074 / pow(reynolds_number, 0.2)
	var cd_min = 2.0 * cf * (1.0 + 2.0 * thickness)
	var oswald_eff = 0.95
	var ar_eff = 50.0
	var cd_i = pow(final_cl, 2) / (PI * ar_eff * oswald_eff)
	var cd_pre_stall = cd_min + cd_i
	
	# DER LETZTE FEINSCHLIFF: Mache CD_max selbst Re-abhängig
	var cd_max_drag_base = 2.1 # Angepasst an deine Windtunnel-Daten
	var cd_max_drag_re = cd_max_drag_base * (1.0 + 5.0 / sqrt(reynolds_number)) # Heuristik für Re-Einfluss
	var cd_post_stall = cd_max_drag_re * pow(sin(alpha_rad), 2)
	
	# Blending
	var sigma_pos_cd = 1.0 / (1.0 + exp(sharpness_pos * (alpha_rad - alpha_stall_pos_re)))
	var sigma_neg_cd = 1.0 / (1.0 + exp(-sharpness_neg * (alpha_rad - alpha_stall_neg_re)))
	var sigma_cd = min(sigma_pos_cd, sigma_neg_cd)

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

	var final_cd = sigma_cd * cd_pre_stall + (1.0 - sigma_cd) * cd_post_stall + cd_wave
	
	return {"cl": final_cl, "cd": final_cd}
