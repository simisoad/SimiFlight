class_name ForceVisualizer extends Control

# Only visual output now.
# Inputs come from the parent via set_simulation_state()

@onready var wind_tunnel_view: WindTunnelView = %WindTunnelView
@onready var lbl_cl: Label = %LblCl
@onready var lbl_cd: Label = %LblCd
@onready var lbl_cm: Label = %LblCm
@onready var lbl_lift: Label = %LblLift
@onready var lbl_drag: Label = %LblDrag

func set_profile_geometry(profile: AirfoilProfile) -> void:
	if not profile: return
	# Create continuous perimeter for drawing
	var geom: Array[Vector2] = []
	var upper_rev = profile.upper_surface.duplicate()
	upper_rev.reverse()
	geom.append_array(upper_rev)
	geom.append_array(profile.lower_surface)
	wind_tunnel_view.set_profile(geom)

func update_visuals(alpha: float, coeffs: Dictionary, forces: Dictionary, speed: float) -> void:

	# Update Labels
	lbl_cl.text = "Cl: %.3f" % coeffs.cl
	lbl_cd.text = "Cd: %.4f" % coeffs.cd
	lbl_cm.text = "Cm: %.3f" % coeffs.cm
	lbl_lift.text = "Lift: %.1f N" % forces.lift
	lbl_drag.text = "Drag: %.1f N" % forces.drag

	# Update View
	wind_tunnel_view.update_state(
		alpha,
		forces.lift,
		forces.drag,
		forces.moment,
		coeffs.cl,
		coeffs.cd,
		coeffs.cm,
		speed
	)

func set_auto_scale(enabled: bool):
	wind_tunnel_view.auto_scale_vectors = enabled
	wind_tunnel_view.queue_redraw()

func set_wind_animation(enabled: bool):
	wind_tunnel_view.enable_animation = enabled
	wind_tunnel_view.queue_redraw()
