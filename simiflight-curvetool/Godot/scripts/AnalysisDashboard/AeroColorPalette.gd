class_name AeroColorPalette extends Resource

@export var cl: Color = Color.CYAN
@export var cd: Color = Color.RED
@export var cm: Color = Color.GREEN
@export var sigma: Color = Color.DARK_VIOLET
@export var ref: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var polar: Color = Color.ORANGE
@export var best_glide: Color = Color.GOLD
@export var min_sink: Color = Color.DEEP_SKY_BLUE

## Updates the palette color based on a string ID (e.g., "CL", "CD")
func update_channel_color(channel_id: String, new_color: Color) -> void:
	match channel_id.to_upper():
		"CL": cl = new_color
		"CD": cd = new_color
		"CM": cm = new_color
		"SIGMA": sigma = new_color
		"POLAR": polar = new_color
