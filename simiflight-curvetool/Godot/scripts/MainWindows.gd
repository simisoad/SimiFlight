extends Control
@onready var dashboard: AnalysisDashboard = %"Analysis Dashboard"
@onready var creator: AirfoilCreatorView = %"Airfoil Creator"
@onready var tab_container: TabContainer = %TabContainer
@onready var quit_dialog: ConfirmationDialog = %QuitDialog

const MIN_WINDOW_SIZE: Vector2i = Vector2i(1024,600)


func _ready() -> void:
	if OS.has_feature("windows"):
		get_tree().root.sharp_corners = true
	if OS.has_feature("macos"):
		get_tree().root.extend_to_title = true
	if OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		get_tree().root.content_scale_factor = 0.75
	if !OS.has_feature("web"):
		quit_dialog.get_label().vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quit_dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		get_window().close_requested.connect(_on_close_requested)
		quit_dialog.confirmed.connect(_on_quit_confirmed)
	if OS.has_feature("debug"):
		print("")
	get_tree().root.min_size = Vector2i(MIN_WINDOW_SIZE)
	tab_container.current_tab = 0
	# Listen for the save signal from the Creator
	creator.airfoil_saved.connect(_on_airfoil_created)


func _on_airfoil_created(full_path: String):
	print("New airfoil created: ", full_path)

	# 1. Refresh the list in the dashboard settings
	dashboard.settings_panel._refresh_profile_list()

	# 2. Select the new file automatically
	var filename = full_path.get_file()
	var list = dashboard.settings_panel.opt_profile

	for i in range(list.item_count):
		if list.get_item_text(i) == filename:
			list.select(i)
			# Trigger the load logic manually
			dashboard.settings_panel.on_profile_selected(i)
			break

	# 3. (Optional) Switch tab back to Analyzer automatically?
	# $TabContainer.current_tab = 0
func _on_close_requested():
	quit_dialog.popup_centered()

func _on_quit_confirmed():
	await get_tree().process_frame
	get_tree().quit(99444)
