# res://scenes/plot_test.gd
extends Control

@onready var plot: Graph2D = %Plot
@onready var mach_selector: OptionButton = %MachSelector
# ALT: @onready var altitude_selector: OptionButton = %AltitudeSelector
@onready var reynolds_selector: OptionButton = %ReynoldsSelector

@onready var lift_curve_plot = LineSeries.new(Color.BLUE, 2.0)
@onready var drag_curve_plot = LineSeries.new(Color.RED, 2.0)

var airfoil_lut: AirfoilLut

func _ready():
	airfoil_lut = preload("res://data/luts/naca_632012_lut.tres")
	if airfoil_lut == null: return

	plot.add_series(lift_curve_plot)
	plot.add_series(drag_curve_plot)
	
	_populate_selectors()

	await self.get_tree().create_timer(0.01).timeout
	_update_plot_from_lut()

func _populate_selectors():
	for i in range(airfoil_lut.mach_points.size()):
		mach_selector.add_item("Mach " + str(airfoil_lut.mach_points[i]), i)
	
	# NEU: Fülle den Reynolds-Selektor
	reynolds_selector.clear() # Sicherstellen, dass er leer ist
	for i in range(airfoil_lut.reynolds_points.size()):
		reynolds_selector.add_item("Re %.1d" % airfoil_lut.reynolds_points[i], i)

func _on_selection_changed(index: int):
	_update_plot_from_lut()

func _update_plot_from_lut():
	if airfoil_lut == null: return

	var selected_mach_idx = mach_selector.selected
	var selected_re_idx = reynolds_selector.selected

	lift_curve_plot.clear_data()
	drag_curve_plot.clear_data()

	var num_alphas = airfoil_lut.alpha_points.size()
	var num_machs = airfoil_lut.mach_points.size()

	for i in range(num_alphas):
		var alpha_deg = airfoil_lut.alpha_points[i]
		
		# Die neue Index-Berechnung für die (Re, Mach, Alpha)-Struktur
		var data_index = (selected_re_idx * num_machs * num_alphas) + (selected_mach_idx * num_alphas) + i
		
		if data_index >= airfoil_lut.cl_data.size():
			push_error("Index out of bounds!")
			continue

		var cl = airfoil_lut.cl_data[data_index]
		var cd = airfoil_lut.cd_data[data_index]
		
		lift_curve_plot.add_point(alpha_deg, cl)
		drag_curve_plot.add_point(alpha_deg, cd)
	
	var mach_str = str(airfoil_lut.mach_points[selected_mach_idx])
	var re_str = "%.1d" % airfoil_lut.reynolds_points[selected_re_idx]
	plot.title = "NACA 63-2012 (Mach: %s, Re: %s)" % [mach_str, re_str]
