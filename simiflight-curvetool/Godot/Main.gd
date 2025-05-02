extends Control

@onready var angle_input = $AngleInput
@onready var result_label = $ResultLabel

func _on_calculate_button_pressed():
	var angle = angle_input.text
	var output = []

	var exit_code = OS.execute("python3", ["res://lift_calc.py", angle], output)
	
	if exit_code == 0:
		var cl = output[0].strip()
		result_label.text = "Cl = " + cl
	else:
		result_label.text = "Fehler bei Berechnung"
