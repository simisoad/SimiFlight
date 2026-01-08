extends Control

@onready var generator_view = %LutGeneratorView
@onready var visualizer_view = %LutVisualizer
@onready var creator_view = %AirfoilCreatorView # Removed type hint for safety if node missing
@onready var tabs = %TabContainer


func _ready():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true, 0)
	generator_view.lut_generated.connect(_on_new_lut_generated)
	if creator_view:
		creator_view.airfoil_saved.connect(_on_airfoil_created)

func _on_new_lut_generated(path: String):
	pass
	## 1. Switch to Visualizer Tab
	#tabs.current_tab = 1
#
	## 2. Update file list in Visualizer
	#visualizer_view._refresh_file_list()
#
	## 3. Select the newly created file (optional, logic would need to be added to Visualizer)
	#print("New LUT generated, switching to visualizer.")
func _on_airfoil_created(path: String):
	print("New airfoil created at: ", path)

	# 1. Update the list in the Generator View
	generator_view.refresh_profile_list()

	# 2. Switch to Generator Tab automatically?
	tabs.current_tab = 0 # Assuming Generator is Tab 0
