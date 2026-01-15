class_name SpinBoxSetupUtils
extends RefCounted

## Configures a SpinBoxExtended with standard limits, default value, and tooltip.
## Returns the SpinBox for chaining if needed.
static func setup(node: SpinBoxExtended, min_v: float, max_v: float, step_v: float, default_v: float, tip: String, name_override: String = "") -> SpinBoxExtended:

	name_override = "" # TODO better like that
	node.allow_greater = true
	node.allow_lesser = true
	#node.get_line_edit().set_theme_type_variation("ExpertLineEditSpinBox")
	#node.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.min_value = min_v
	node.max_value = max_v
	node.step = step_v

	# Set the value first so the reset button captures it as default
	node.value = default_v
	node.default_val = default_v

	node.tooltip_text = tip

	if name_override != "":
		node.prefix = name_override + ":  "
	else:
		# Clean up variable names (e.g., "bluff_factor_min" -> "Bluff Factor Min:")
		var readable = node.name.replace("_", " ").capitalize()
		node.prefix = readable + ":  "

	return node
