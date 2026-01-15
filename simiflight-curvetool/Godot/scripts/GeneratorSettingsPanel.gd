class_name GeneratorSettingsPanel extends PanelContainer

# --- Signals ---
signal profile_loaded(profile: AirfoilProfile)
signal config_updated(config: LutGenerator.GeneratorConfig)

# --- Constants & State ---
var _profile_paths: Dictionary = {}
var custom_json_dir: String = ""
var current_profile: AirfoilProfile

# --- UI References ---
@onready var opt_profile: OptionButton = %ProfileSelector
@onready var input_output_name: LineEdit = %OutputName
@onready var btn_generate: Button = %GenerateFullLUT
@onready var lbl_state: Label = %StateLabelInfo

@onready var check_export_json: CheckBox = %CheckExportJson
@onready var check_export_tres: CheckBox = %CheckExportTres

@onready var line_json_path: LineEdit = %JsonPathDisplay
@onready var btn_select_path: SquareButton = %BtnSelectPath
@onready var folder_dialog: FileDialog = %FolderDialog

# --- Configuration Inputs ---
@onready var input_stall_fwd: SpinBox = %StallAngleFwd
@onready var input_stall_bwd: SpinBox = %StallAngleBwd
@onready var input_sharpness: SpinBoxExtended = %Sharpness
@onready var enable_vortex_lift_check_box: CheckBox = %EnableVortexLiftCheckBox
@onready var enable_vortex_lift_check_box2: CheckBox = %EnableVortexLiftCheckBox2
@onready var vortex_intensity: SpinBox = %VortexIntensity
@onready var input_sweep: SpinBox = %InputSweep
@onready var input_ar: SpinBox = %InputAR
@onready var input_eff: SpinBox = %InputEff

func _ready() -> void:
	_refresh_profile_list()

	# 1. Connect Inputs
	input_stall_fwd.value_changed.connect(func(_v): _emit_config_update())
	input_stall_bwd.value_changed.connect(func(_v): _emit_config_update())
	input_sharpness.value_changed.connect(func(_v): _emit_config_update())
	input_sweep.value_changed.connect(func(_v): _emit_config_update())
	input_ar.value_changed.connect(func(_v): _emit_config_update())



	enable_vortex_lift_check_box.toggled.connect(func(_v): _emit_config_update(); _vertex_lift_methods())
	enable_vortex_lift_check_box2.toggled.connect(func(_v): _emit_config_update(); _vertex_lift_methods())
	vortex_intensity.value_changed.connect(func(_v): _emit_config_update())
	# 2. Connect Main Actions
	opt_profile.item_selected.connect(on_profile_selected)
	btn_generate.pressed.connect(_on_generate_full_lut_pressed)

	# 3. Connect EventBus (Expert Settings)
	EventBus.reanalyze_requested.connect(_emit_config_update)

	# 4. Connect Stall Limit Signals
	EventBus.stall_limits_fwd_changed.connect(_on_stall_limits_fwd_changed)
	EventBus.stall_limits_bwd_changed.connect(_on_stall_limits_bwd_changed)

	# 5. Connect Path Selection
	btn_select_path.pressed.connect(func(): folder_dialog.popup_centered_ratio(0.6))
	folder_dialog.dir_selected.connect(_on_dir_selected)

	# Toggle Path UI availability based on JSON checkbox
	check_export_json.toggled.connect(func(active):
		line_json_path.editable = active
		btn_select_path.disabled = !active
	)
	check_export_tres.toggled.connect(func(active):
		line_json_path.editable = active
		btn_select_path.disabled = !active
	)
	# Initialize UI State
	_init_default_values()

	btn_select_path.disabled = !check_export_json.button_pressed

	# --- Setup Default Paths via FileSystemHandler ---
	var default_path = FileSystemHandler.get_user_data_root()
	folder_dialog.current_dir = default_path
	line_json_path.placeholder_text = "Default: " + default_path
	line_json_path.tooltip_text = line_json_path.placeholder_text

	# Load first profile
	if opt_profile.item_count > 0:
		on_profile_selected(0)

	if OS.has_feature("web"):
		_setup_web_limitations()
# --- Initialization Logic ---d

func _init_default_values() -> void:
	var config = LutGenerator.GeneratorConfig.new()
	enable_vortex_lift_check_box.button_pressed = config.enable_vortex_lift_m1
	enable_vortex_lift_check_box2.button_pressed = config.enable_vortex_lift_m2
	vortex_intensity.value = config.vortex_intensity
	input_sweep.value = config.sweep_deg
	input_ar.value = config.aspect_ratio
	input_eff.value = config.oswald_efficiency
	input_stall_fwd.value = config.stall_angle_deg_fwd
	input_stall_bwd.value = config.stall_angle_deg_bwd
	input_sharpness.value = config.sharpness
	input_sharpness.default_val = input_sharpness.value
	input_stall_fwd.min_value = AeroPhysicsModel.stall_min_deg_fwd
	input_stall_fwd.max_value = AeroPhysicsModel.stall_max_cap_deg_fwd
	input_stall_bwd.min_value = AeroPhysicsModel.stall_min_deg_bwd
	input_stall_bwd.max_value = AeroPhysicsModel.stall_max_cap_deg_bwd

func _refresh_profile_list():
	var old_selection = ""
	if opt_profile.selected >= 0:
		old_selection = opt_profile.get_item_text(opt_profile.selected)

	opt_profile.clear()
	_profile_paths.clear()

	var id_counter = 0

	# 1. Scan Built-in (Read Only)
	_scan_directory("res://data/airfoils/", "[Built-in] ", id_counter)

	# 2. Scan User Folder (Read/Write)
	# Delegated to FileSystemHandler to get the correct path
	var user_path = FileSystemHandler.get_user_airfoil_dir()
	id_counter = opt_profile.item_count
	_scan_directory(user_path, "", id_counter)

	# Restore selection
	for i in range(opt_profile.item_count):
		if opt_profile.get_item_text(i) == old_selection:
			opt_profile.select(i)
			break

func _scan_directory(path: String, prefix: String, start_id: int):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var current_id = start_id

		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".dat") or file_name.ends_with(".txt"):
					opt_profile.add_item(prefix + file_name, current_id)
					_profile_paths[current_id] = path.path_join(file_name)
					current_id += 1
			file_name = dir.get_next()

# --- Public API ---

func get_current_config() -> LutGenerator.GeneratorConfig:
	var config = LutGenerator.GeneratorConfig.new()
	config.stall_angle_deg_fwd = input_stall_fwd.value
	config.stall_angle_deg_bwd = input_stall_bwd.value
	config.sharpness = input_sharpness.value
	config.enable_vortex_lift_m1 = enable_vortex_lift_check_box.button_pressed
	config.enable_vortex_lift_m2 = enable_vortex_lift_check_box2.button_pressed
	config.vortex_intensity = vortex_intensity.value
	config.sweep_deg = input_sweep.value
	config.aspect_ratio = input_ar.value
	config.oswald_efficiency = input_eff.value
	return config

# --- Signal Handlers ---

func _emit_config_update() -> void:
	var config = get_current_config()
	config_updated.emit(config)

func on_profile_selected(index: int):
	var file_name = opt_profile.get_item_text(index)
	var id = opt_profile.get_item_id(index)

	if not _profile_paths.has(id): return
	opt_profile.tooltip_text = file_name
	var full_path = _profile_paths[id]
	var profile = AirfoilProfile.new()

	if profile.load_from_dat(full_path):
		current_profile = profile
		lbl_state.text = "Loaded: " + profile.name
		lbl_state.tooltip_text = "Loaded: " + profile.name

		# Auto-name the output file based on the profile name
		# Strip the [Built-in] prefix if present for cleaner filenames
		var clean_name = file_name.replace("[Built-in] ", "")
		input_output_name.text = clean_name.get_basename() + "_lut"
		input_output_name.tooltip_text = input_output_name.text
		# Run Analyzer for parameter estimation
		var geo_data = AirfoilGeometryAnalyzer.analyze(profile)
		input_stall_fwd.value = geo_data.stall_angle_fwd
		input_stall_bwd.value = geo_data.stall_angle_back

		profile_loaded.emit(profile)
	else:
		lbl_state.text = "Error parsing profile."
		lbl_state.tooltip_text = "Error parsing profile."

func _on_dir_selected(dir: String) -> void:
	custom_json_dir = dir
	line_json_path.text = dir
	line_json_path.tooltip_text = dir

func _on_stall_limits_fwd_changed(min_v: float, max_v: float) -> void:
	input_stall_fwd.min_value = min_v
	input_stall_fwd.max_value = max_v
	input_stall_fwd.value = clamp(input_stall_fwd.value, min_v, max_v)
	_emit_config_update()

func _on_stall_limits_bwd_changed(min_v: float, max_v: float) -> void:
	input_stall_bwd.min_value = min_v
	input_stall_bwd.max_value = max_v
	input_stall_bwd.value = clamp(input_stall_bwd.value, min_v, max_v)
	_emit_config_update()

# --- Main Action ---

func _on_generate_full_lut_pressed():
	if not current_profile:
		lbl_state.text = "No Proile found to calculate LUTs!"
		lbl_state.tooltip_text = "No Proile found to calculate LUTs!"
		return
	if (check_export_json.button_pressed == false and check_export_tres.button_pressed == false):
		lbl_state.text = "Select JSON or .tres or both to export LUTs"
		lbl_state.tooltip_text = "Select JSON or .tres or both to export LUTs"
		return
	btn_generate.disabled = true
	lbl_state.text = "Generating..."
	lbl_state.tooltip_text = "Generating..."
	await get_tree().process_frame
	await get_tree().process_frame

	var config = get_current_config()
	var lut = LutGenerator.generate_lut(current_profile, config)

	# Prepare Filename (Strip extensions if user typed them)
	var fname = input_output_name.text
	if fname.ends_with(".tres"): fname = fname.replace(".tres", "")
	if fname.ends_with(".json"): fname = fname.replace(".json", "")

	var status_msg = ""

	# Determine Export Folder
	# If no custom folder selected, use Default (Documents/SimiFlightCurveTool_Data)
	var target_dir = custom_json_dir
	if target_dir.is_empty():
		target_dir = FileSystemHandler.get_user_data_root()

	# 1. JSON EXPORT
	if check_export_json.button_pressed:
		var json_path = target_dir.path_join(fname + ".json")
		LutJSONExporter.save_lut_as_json(lut, json_path)
		status_msg += "JSON "

	# 2. TRES EXPORT
	if check_export_tres.button_pressed:
		# .tres can be saved to user documents too (as a text file)
		var tres_path = target_dir.path_join(fname + ".tres")
		LutGenerator.save_lut(lut, tres_path)
		status_msg += "& TRES "

	lbl_state.text = "Saved to " + target_dir + " as" + status_msg
	lbl_state.tooltip_text = "Saved to " + target_dir + " as" + status_msg
	btn_generate.disabled = false

func _setup_web_limitations() -> void:
	# 1. Disable Export Button
	btn_generate.disabled = true
	btn_generate.text = "Export (Desktop Only)"
	btn_generate.tooltip_text = "Downloading LUTs is available in the Desktop version."

	# 2. Disable Checkboxes
	check_export_json.disabled = true
	check_export_tres.disabled = true
	check_export_json.button_pressed = false
	check_export_tres.button_pressed = false

	# 3. Disable Path Selection
	btn_select_path.visible = false
	line_json_path.visible = false

func _vertex_lift_methods() -> void:
	if enable_vortex_lift_check_box.button_pressed:
		enable_vortex_lift_check_box2.disabled = true
	else:
		enable_vortex_lift_check_box2.disabled = false

	if enable_vortex_lift_check_box2.button_pressed:
		enable_vortex_lift_check_box.disabled = true
	else:
		enable_vortex_lift_check_box.disabled = false
