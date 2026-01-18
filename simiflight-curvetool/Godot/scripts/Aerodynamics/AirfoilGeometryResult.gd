class_name AirfoilGeometryResult
extends Resource

# Basic Geometry
@export var thickness: float = 0.0
@export var pos_max_thick_x: float = 0.3
@export var camber: float = 0.0
@export var fullness_factor: float = 0.5
@export var rectangularity: float = 0.0
@export var fore_aft_symmetry: float = 0.0
@export var centroid_x: float = 0.25

# Leading Edge
@export var le_radius: float = 0.0
@export var le_radius_norm: float = 0.0
@export var le_tip_thickness: float = 0.0
@export var le_bluntness: float = 0.0

# Trailing Edge
@export var te_radius_norm: float = 0.0
@export var te_openness: float = 0.0
@export var te_bluntness: float = 0.0

# Aero Integrals
@export var alpha_0: float = 0.0
@export var cm_0: float = 0.0

# Physics Modifiers
@export var stall_angle_fwd: float = 15.0
@export var stall_angle_back: float = 8.0
@export var camber_efficiency: float = 1.0
@export var vortex_potential: float = 0.0
