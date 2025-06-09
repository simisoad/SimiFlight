# res://scenes/plot_test.gd
extends Control

# --- UI-Referenzen ---
@onready var plot: Graph2D = %Plot
@onready var mach_selector: OptionButton = %MachSelector
@onready var altitude_selector: OptionButton = %AltitudeSelector

# --- Plot-Serien ---
@onready var lift_curve_plot = LineSeries.new(Color.BLUE, 2.0)
@onready var drag_curve_plot = LineSeries.new(Color.RED, 2.0)

# --- Daten ---
var airfoil_lut: AirfoilLut # Hier speichern wir unsere geladene LUT

func _ready():
	# Lade die generierte LUT-Ressource
	airfoil_lut = preload("res://data/luts/naca_632012_lut.tres")
	if airfoil_lut == null:
		push_error("LUT-Datei nicht gefunden oder konnte nicht geladen werden!")
		return

	# Füge die Linien zum Plot hinzu (einmalig)
	plot.add_series(lift_curve_plot)
	plot.add_series(drag_curve_plot)
	
	# Fülle die UI-Selektoren mit den Daten aus der LUT
	_populate_selectors()

	# Zeichne die initiale Kurve (für die erste Auswahl)
	await self.get_tree().create_timer(0.01).timeout # Warte auf UI-Initialisierung
	_update_plot_from_lut()

# Füllt die OptionButtons mit den Achsen-Werten aus der LUT
func _populate_selectors():
	for i in range(airfoil_lut.mach_points.size()):
		mach_selector.add_item("Mach " + str(airfoil_lut.mach_points[i]), i)
	
	for i in range(airfoil_lut.altitude_points.size()):
		altitude_selector.add_item(str(airfoil_lut.altitude_points[i]) + " m", i)

# Diese Funktion wird aufgerufen, wenn der Benutzer einen neuen Wert auswählt
func _on_selection_changed(index: int):
	_update_plot_from_lut()

# Das neue Herzstück: Liest die UI, holt die Daten aus der LUT und zeichnet den Graphen
func _update_plot_from_lut():
	if airfoil_lut == null: return

	# 1. Aktuelle Auswahl aus der UI holen
	var selected_mach_idx = mach_selector.selected
	var selected_alt_idx = altitude_selector.selected

	# Leere die alten Daten der Kurven
	lift_curve_plot.clear_data()
	drag_curve_plot.clear_data()

	# 2. Die richtige 2D-"Scheibe" aus den flachen 1D-Arrays extrahieren
	var num_alphas = airfoil_lut.alpha_points.size()
	var num_machs = airfoil_lut.mach_points.size()

	for i in range(num_alphas):
		var alpha_deg = airfoil_lut.alpha_points[i]
		
		# Dies ist die entscheidende Index-Berechnung, um den flachen Array zu lesen
		var data_index = (selected_alt_idx * num_machs * num_alphas) + (selected_mach_idx * num_alphas) + i
		
		if data_index >= airfoil_lut.cl_data.size():
			push_error("Index out of bounds!")
			continue

		var cl = airfoil_lut.cl_data[data_index]
		var cd = airfoil_lut.cd_data[data_index]
		
		lift_curve_plot.add_point(alpha_deg, cl)
		drag_curve_plot.add_point(alpha_deg, cd)
	
	# Aktualisiere den Titel des Plots, um die aktuelle Auswahl anzuzeigen
	var mach_str = str(airfoil_lut.mach_points[selected_mach_idx])
	var alt_str = str(airfoil_lut.altitude_points[selected_alt_idx])
	plot.title = "NACA 63-2012 (Mach: %s, Alt: %s m)" % [mach_str, alt_str]
