extends VBoxContainer

@onready var base_stall: SpinBoxExtended = %base_stall_deg
@onready var rad_factor: SpinBoxExtended = %stall_radius_factor
@onready var thick_factor: SpinBoxExtended = %stall_thickness_factor
@onready var shape_factor: SpinBoxExtended = %stall_shape_factor
@onready var fwd_cam_pen: SpinBoxExtended = %stall_fwd_camber_penalty
@onready var bwd_cam_pen: SpinBoxExtended = %stall_bwd_camber_penalty

func _ready() -> void:
	SpinBoxSetupUtils.setup(base_stall, 1.0, 20.0, 0.5, AirfoilGeometryAnalyzer.base_stall_deg,
		"Base stall angle for a generic airfoil before modifiers.")

	SpinBoxSetupUtils.setup(rad_factor, 1.0, 20.0, 0.5, AirfoilGeometryAnalyzer.stall_radius_factor,
		"Impact of Leading Edge Radius on stall angle (Rounder = Higher Stall).")

	SpinBoxSetupUtils.setup(thick_factor, 1.0, 20.0, 0.5, AirfoilGeometryAnalyzer.stall_thickness_factor,
		"Impact of Thickness on stall angle.")

	SpinBoxSetupUtils.setup(shape_factor, 1.0, 20.0, 0.5, AirfoilGeometryAnalyzer.stall_shape_factor,
		"Impact of 'Fullness' (Area) on stall angle.")

	SpinBoxSetupUtils.setup(fwd_cam_pen, 0.0, 50.0, 1.0, AirfoilGeometryAnalyzer.stall_fwd_camber_penalty,
		"Stall penalty for high camber in Forward flight.")

	SpinBoxSetupUtils.setup(bwd_cam_pen, 0.0, 50.0, 1.0, AirfoilGeometryAnalyzer.stall_bwd_camber_penalty,
		"Stall penalty for high camber in Backward flight (flying against the scoop).")

	# Important: Re-analyze when these change!
	base_stall.value_changed.connect(func(v):
		AirfoilGeometryAnalyzer.base_stall_deg = v
		_request_reanalysis()
	)
	rad_factor.value_changed.connect(func(v):
		AirfoilGeometryAnalyzer.stall_radius_factor = v
		_request_reanalysis()
	)
	thick_factor.value_changed.connect(func(v):
		AirfoilGeometryAnalyzer.stall_thickness_factor = v
		_request_reanalysis()
	)
	shape_factor.value_changed.connect(func(v):
		AirfoilGeometryAnalyzer.stall_shape_factor = v
		_request_reanalysis()
	)
	fwd_cam_pen.value_changed.connect(func(v):
		AirfoilGeometryAnalyzer.stall_fwd_camber_penalty = v
		_request_reanalysis()
	)
	bwd_cam_pen.value_changed.connect(func(v):
		AirfoilGeometryAnalyzer.stall_bwd_camber_penalty = v
		_request_reanalysis()
	)

func _request_reanalysis() -> void:
	EventBus.reanalyze_requested.emit()
