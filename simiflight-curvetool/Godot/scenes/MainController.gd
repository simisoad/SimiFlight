extends Control

@onready var generator_view = %LutGeneratorView
@onready var visualizer_view = %LutVisualizer
@onready var tabs = %TabContainer

func _ready():
	# Verbinde das Signal vom Generator mit dem Visualizer
	generator_view.lut_generated.connect(_on_new_lut_generated)

func _on_new_lut_generated(path: String):
	# 1. Wechsle zum Visualizer Tab
	tabs.current_tab = 1

	# 2. Aktualisiere die Dateiliste im Visualizer
	visualizer_view._refresh_file_list()

	# 3. Wähle die neu erstellte Datei aus (optional, Logik müsste in Visualizer ergänzt werden)
	print("New LUT generated, switching to visualizer.")
