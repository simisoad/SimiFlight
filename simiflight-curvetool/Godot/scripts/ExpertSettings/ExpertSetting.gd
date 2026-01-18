@tool
class_name ExpertSetting extends VBoxContainer

@export_tool_button("SetNamesAndValues") var set_names_and_values_btn = _set_names_and_values

func _set_names_and_values() -> void:
	setup_panel(AeroPhysicsConfig.new())

func setup_panel(physics_cfg: AeroPhysicsConfig) -> void:
	push_error("setup_panel() must be implemented!")
