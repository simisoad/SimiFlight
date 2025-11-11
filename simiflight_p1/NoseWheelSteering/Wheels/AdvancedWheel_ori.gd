# AdvancedWheel.gd
class_name AdvancedWheel_ori extends Node3D

# --- Alte Variablen bleiben, wir fügen eine neue hinzu ---
@export var is_steerable: bool = false
@export var max_steering_angle: float = 85.0
@export var rolling_resistance: float = 20.0 # Für Längsreibung
@export var aircraft: RigidBody3D
# Repräsentiert die "Steifigkeit" des Reifens. Höher = mehr Grip.
@export var cornering_stiffness: float = 80000.0
@export var slip_model_threshold_speed: float = 1.0

@export var lateral_friction: float = 10000.0 ## not a real physical value!
@export var stop_threshold_speed: float = 0.5 ## is the absolut speed slower -> more friction.
@export var static_friction_damping: float = 0.01 ## fake static friction damping

var steering_input: float = 0.0
@onready var ray_cast_3d: RayCast3D = %RayCast3D

func _ready() -> void:
	DebugDraw3D.scoped_config().set_thickness(0.5)

func _physics_process(delta):
	# Annahme: RayCast trifft, wenn Bodenkontakt besteht.
	if ray_cast_3d.is_colliding():
		_update_wheel_forces(delta)

func _update_wheel_forces(delta: float) -> void:

	# --- Lenkung (bleibt gleich) ---
	var steer_angle_rad: float = 0.0
	if is_steerable:
		steer_angle_rad = deg_to_rad(steering_input * max_steering_angle)
	self.rotation.y = steer_angle_rad
	DebugDraw3D.draw_line(self.global_position, self.global_position + -self.global_transform.basis.z*10, Color.GREEN)
	# --- Geschwindigkeit berechnen (bleibt gleich) ---
	var wheel_offset_global: Vector3 = self.global_position - (aircraft.global_position + aircraft.center_of_mass) #
	var rotational_velocity_global: Vector3 = aircraft.angular_velocity.cross(wheel_offset_global)
	var wheel_velocity_global: Vector3 = aircraft.linear_velocity + rotational_velocity_global

	#print("angular_v: ", aircraft.angular_velocity, ", lin_v:", aircraft.linear_velocity)
	# === NEUE PHYSIK-BERECHNUNG STARTET HIER ===
	
	# 1. Bestimme die Längs- und Querrichtung des Rades im globalen Raum
	var lateral_dir_global: Vector3 = self.global_transform.basis.x
	var longitudinal_dir_global: Vector3 = -self.global_transform.basis.z

	# 2. Zerlege die Radgeschwindigkeit in Längs- und Querkomponenten
	var lateral_speed: float = wheel_velocity_global.dot(lateral_dir_global)
	var longitudinal_speed: float = wheel_velocity_global.dot(longitudinal_dir_global)

	
	var total_force_global: Vector3
	var lateral_force: Vector3 
	var longitudinal_force: Vector3 
	
	# Berechne den Schräglaufwinkel (Slip Angle) in Radiant
	# Wir benutzen atan2, weil es stabil ist und das korrekte Vorzeichen liefert.
	# Wichtig: Nur berechnen, wenn wir uns überhaupt bewegen, um Division durch Null zu vermeiden.
	if abs(longitudinal_speed) > slip_model_threshold_speed: # Schwellenwert
		var slip_angle_rad: float = atan2(lateral_speed, longitudinal_speed)

		
		# Berechne die Seitenführungskraft basierend auf dem Slip Angle
		# Lineares Modell: Kraft = Winkel * Steifigkeit. Das Minuszeichen ist wichtig,
		# da die Kraft dem Schräglauf entgegenwirkt.
		var lateral_force_magnitude: float = -slip_angle_rad * cornering_stiffness
		lateral_force = lateral_dir_global * lateral_force_magnitude
		
		# Longitudinale Kraft (Rollwiderstand) - können wir vorerst beim alten Modell belassen
		var longitudinal_force_magnitude: float = -longitudinal_speed * rolling_resistance
		longitudinal_force = longitudinal_dir_global * longitudinal_force_magnitude
		total_force_global = lateral_force + longitudinal_force
	else:
		lateral_force = _calculate_friction_force(lateral_dir_global, wheel_velocity_global, lateral_friction, delta)
		longitudinal_force = _calculate_friction_force(longitudinal_dir_global, wheel_velocity_global, rolling_resistance, delta)
		total_force_global = lateral_force + longitudinal_force
	# --- Gesamtkraft anwenden ---
	aircraft.apply_force(total_force_global, self.global_position - aircraft.global_position)

	# --- Debug-Visualisierung ---
	DebugDraw3D.draw_line(self.global_position, self.global_position + lateral_dir_global*10, Color.AQUA)
	DebugDraw3D.draw_line(self.global_position, self.global_position + lateral_force, Color.RED) # Seitenkraft
	DebugDraw3D.draw_line(self.global_position, self.global_position + longitudinal_force, Color.BLUE) # Rollwiderstand

func _calculate_friction_force(direction_global: Vector3, velocity_global: Vector3, coefficient: float, delta: float) -> Vector3:
	var speed_in_direction: float = velocity_global.dot(direction_global)
	
	if abs(speed_in_direction) < stop_threshold_speed:
		var force_magnitude = -speed_in_direction * (1.0 / delta) * aircraft.mass
		return direction_global * force_magnitude * static_friction_damping
	else:
		var force_magnitude = -speed_in_direction * coefficient
		return direction_global * force_magnitude
		
func set_steering_input(value: float):
	if is_steerable:
		steering_input = clamp(value, -1.0, 1.0)
