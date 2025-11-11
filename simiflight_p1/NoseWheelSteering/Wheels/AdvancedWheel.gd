# AdvancedWheel.gd
class_name AdvancedWheel extends Node3D

@export var is_steerable: bool = false
@export var max_steering_angle: float = 85.0
@export var brake_component: BrakeComponent
@export var aircraft: RigidBody3D
@export var my_collision: CollisionShape3D

@export_group("High Speed (Slip Angle Model)")
@export var cornering_stiffness: float = 80000.0
@export var rolling_resistance: float = 20.0

@export_group("Low Speed (Damping Model)")
@export var low_speed_lateral_friction: float = 10000.0
@export var low_speed_longitudinal_friction: float = 300.0 # Für Bremswirkung bei Stillstand

@export_group("Transition Zone")
@export var transition_start_speed: float = 0.5 # Ab hier beginnen wir mit dem Blending
@export var transition_end_speed: float = 1.5   # Ab hier benutzen wir nur noch das High-Speed-Modell

@export_group("Suspension")
@export var spring_stiffness: float = 50000.0 # Federhärte (Hooke's Law)
@export var damping_coefficient: float = 5000.0  # Dämpfer, verhindert Oszillieren
@export var max_suspension_travel: float = 0.1

@export_group("Bounce Physics")
@export var bounce_speed_threshold: float = 5.0 # Kompressionsgeschwindigkeit (m/s), ab der ein Bounce ausgelöst wird
@export var bounce_coefficient: float = 0.4   # Wie viel Energie wird zurückgegeben? (0.0 = kein Bounce, 1.0 = perfekter Bounce)
var steering_input: float = 0.0
var last_compression: float = 0.0
var wheel_radius: float

var debug: String = ""
@onready var rec_arr: Array[RayCast3D] = [$RecoveryRay,$RecoveryRay2,$RecoveryRay3]
@onready var ray_arr: Array[RayCast3D] = [%RayCast3D,%RayCast3D2,%RayCast3D3]
@onready var ray_cast: RayCast3D = %RayCast3D
#@onready var shape_cast: ShapeCast3D = %ShapeCast3D


@onready var wheel_model: CSGMesh3D = %Wheel_Model
#@onready var shape_cast: ShapeCast3D = $ShapeCast3D
@onready var shape_cast: ShapeCast3D = %ShapeCast3D
@onready var recovery_ray: RayCast3D = $RecoveryRay


# _ready und _physics_process bleiben gleich ...
func _ready() -> void:
	#ray_cast.add_exception(aircraft)
	shape_cast.add_exception(aircraft)

	for rec_ray in rec_arr:
		rec_ray.add_exception(aircraft)
	for ray_ray in ray_arr:
		ray_ray.add_exception(aircraft)

	var wheel_mesh: CylinderMesh = wheel_model.mesh
	var shape_cast_shape: SphereShape3D = shape_cast.shape
	wheel_radius = wheel_mesh.top_radius
	#shape_cast.shape.radius = wheel_radius
	_debugDraw()

func _debugDraw() -> void:
	DebugDraw3D.scoped_config().set_thickness(0.05)
	DebugDraw3D.debug_enabled = true


func _physics_process(delta) -> void:
	var collided: bool = false
	var is_recovery: bool = false # Der neue Schalter
	var collision_point: Vector3
	var ground_normal: Vector3


	var rec_ray_is_coll: bool = false
	var temp_recovery_ray: RayCast3D
	for rec_ray in rec_arr:
		rec_ray.force_raycast_update()
		if rec_ray.is_colliding():
			rec_ray_is_coll = true
			temp_recovery_ray = rec_ray
			break

	var ray_ray_is_coll: bool = false
	var temp_ray_ray: RayCast3D
	for ray_ray in ray_arr:
		ray_ray.force_raycast_update()
		if ray_ray.is_colliding():
			ray_ray_is_coll = true
			temp_ray_ray = ray_ray
			break

	if rec_ray_is_coll:
		collided = true
		is_recovery = true # Wir sind im Recovery-Modus
		collision_point = temp_recovery_ray.get_collision_point()
		ground_normal = -temp_recovery_ray.get_collision_normal()
		debug = "recovery_ray"

	elif ray_ray_is_coll:
		collided = true
		is_recovery = false # Normaler Modus
		collision_point = temp_ray_ray.get_collision_point()
		ground_normal = temp_ray_ray.get_collision_normal()
		debug = "ray_cast"
	else:
		last_compression = 0.0
		wheel_model.position = Vector3(0, -max_suspension_travel, 0)

	if collided:
		_update_suspension_and_forces(delta, collision_point, ground_normal, is_recovery)
		#_update_suspension_and_forces_old(delta, collision_point, ground_normal)

	#_update_suspension_and_forces_ray_cast(delta)

func _update_suspension_and_forces_ray_cast(delta: float) -> void:
	if shape_cast.is_colliding():
		# 1. Berechne die aktuelle Länge der Federung
		var coll_point: Vector3 = shape_cast.get_collision_point(0)
		var current_length = coll_point.distance_to(self.global_position) - wheel_radius
		#if is_steerable:
			#print("current_length: ", current_length)
		# 2. Berechne die Kompression, aber NUR wenn das Rad in Reichweite ist
		#current_length = abs(current_length)
		#current_length = clamp(current_length, current_length, max_suspension_travel)
		if current_length <= max_suspension_travel:
			#my_collision.disabled = true
			# Hier ist die korrekte Berechnung!
			var compression = max_suspension_travel - current_length

			# Ab hier bleibt deine Feder- und Dämpferkraftberechnung gleich...
			var spring_force_mag = compression * spring_stiffness
			var compression_speed = (compression - last_compression) / delta
			var damper_force_mag = compression_speed * damping_coefficient
			var ground_normal = shape_cast.get_collision_normal(0)
			var suspension_force = ground_normal * (spring_force_mag + damper_force_mag)


			#print(suspension_force.length(), ", gf: ", aircraft.mass * 9.81)
			aircraft.apply_force(abs(suspension_force), self.global_position - aircraft.global_position)
			DebugDraw3D.draw_line(self.global_position, self.global_position + suspension_force, Color.PINK)
			# Rad-Positionierung etc.
			wheel_model.global_position.y = shape_cast.get_collision_point(0).y + wheel_radius
			my_collision.global_position = wheel_model.global_position
			last_compression = compression
			_update_wheel_forces(delta)
		else:
			#my_collision.disabled = false
			# Das Rad ist ausgefedert, aber der Ray trifft trotzdem etwas (z.B. weil er sehr lang ist)
			# -> Keine Kraft anwenden
			last_compression = 0.0
			# Positioniere das Rad am Ende des Federwegs
			wheel_model.position = Vector3(0, -max_suspension_travel, 0)
	else:
		pass
		#my_collision.disabled = false
func _update_suspension_and_forces(delta: float, collision_point: Vector3, ground_normal: Vector3, is_recovery: bool):
	# Deine funktionierende Längen-Berechnung
	var current_length: float = collision_point.distance_to(self.global_position) - wheel_radius

	if current_length <= max_suspension_travel:
		var compression: float = max_suspension_travel - current_length
		var compression_speed: float = (compression - last_compression) / delta
		# --- bounce logic ---
		if compression >= max_suspension_travel * 0.99 and compression_speed >= bounce_speed_threshold:
			print("bounce!")
			var bounce_impulse_magnitude: float = compression_speed * aircraft.mass * bounce_coefficient
			var impulse_vector: Vector3 = ground_normal * bounce_impulse_magnitude
			aircraft.apply_impulse(impulse_vector, self.global_position - aircraft.global_position)
			last_compression = compression
			return
		# --- end bounce logic ---
		var damper_force_mag: float = 0.0
		# recovery when wheel sinks in ground and rigidbody ccd would fail
		if is_recovery:
			damper_force_mag = 0.0
		else:
			damper_force_mag = compression_speed * damping_coefficient

		var spring_force_mag: float = compression * spring_stiffness
		var suspension_force: Vector3 = ground_normal * (spring_force_mag + damper_force_mag)

		aircraft.apply_force(suspension_force, self.global_position - aircraft.global_position)

		last_compression = compression

		# Der Rest bleibt gleich...
		var wheel_center_at_impact: Vector3 = collision_point + ground_normal * wheel_radius
		wheel_center_at_impact = wheel_center_at_impact.min(self.global_position)
		wheel_model.global_position = wheel_center_at_impact

		# Seiten- und Längskräfte nur im Normal-Modus anwenden,
		# um zusätzliche Instabilität zu vermeiden.
		if not is_recovery:
			_update_wheel_forces(delta)
	else:
		last_compression = 0.0
		var wheel_model_y: float = lerp(wheel_model.position.y, -max_suspension_travel, delta*7)
		wheel_model.position = Vector3(0, wheel_model_y, 0)

func _update_suspension_and_forces_old(delta: float, collision_point: Vector3, ground_normal: Vector3):
	# 1. BERECHNE DIE ZENTRUMSPOSITION DES RADS BEI DER KOLLISION (jetzt korrekt)

	var wheel_center_at_impact: Vector3 = collision_point + ground_normal * wheel_radius
	#var wheel_center_at_impact = collision_point + ground_normal * wheel_radius

	# 2. BERECHNE DIE AKTUELLE FEDERLÄNGE (jetzt korrekt)
	#var current_length = wheel_center_at_impact.distance_to(self.global_position)

	var current_length = collision_point.distance_to(self.global_position) - wheel_radius


	 #3. PRÜFE, OB DIE FEDERUNG WIRKT
	if current_length <= max_suspension_travel:
		var compression = max_suspension_travel - current_length
		#ground_normal = self.global_basis.y#Vector3(0,self.basis.y.y, 0).normalized()
		# Ab hier ist alles wie gehabt...
		var spring_force_mag = compression * spring_stiffness
		var compression_speed = (compression - last_compression) / delta
		var damper_force_mag = compression_speed * damping_coefficient
		var suspension_force = ground_normal * (spring_force_mag + damper_force_mag)
		#suspension_force = abs(suspension_force)

		if is_steerable:
			print("gn: ", ground_normal, ", cl: ", current_length, ", sf: ", suspension_force, ", from: ", debug)
		aircraft.apply_force(suspension_force, self.global_position - aircraft.global_position)
		DebugDraw3D.draw_line(self.global_position, self.global_position + suspension_force, Color.PINK)
		wheel_model.global_position = wheel_center_at_impact
		last_compression = compression

		_update_wheel_forces(delta) # Seiten- und Längskräfte
	else:
		# Ausgefedert
		last_compression = 0.0
		wheel_model.position = Vector3(0, -max_suspension_travel, 0)

func _update_wheel_forces(delta: float) -> void:
	# --- Lenkung und Geschwindigkeit (bleibt gleich) ---
	var steer_angle_rad: float = 0.0
	if is_steerable:
		steer_angle_rad = deg_to_rad(steering_input * max_steering_angle)
	self.rotation.y = steer_angle_rad

	var wheel_offset_global: Vector3 = wheel_model.global_position - aircraft.global_position
	var rotational_velocity_global: Vector3 = aircraft.angular_velocity.cross(wheel_offset_global)
	var wheel_velocity_global: Vector3 = aircraft.linear_velocity + rotational_velocity_global

	var lateral_dir_global: Vector3 = self.global_transform.basis.x
	var longitudinal_dir_global: Vector3 = -self.global_transform.basis.z
	var lateral_speed: float = wheel_velocity_global.dot(lateral_dir_global)
	var longitudinal_speed: float = wheel_velocity_global.dot(longitudinal_dir_global)


	# === NEUE LOGIK MIT BLENDING ===

	# 1. Berechne IMMER die Kraft für BEIDE Modelle

	# Kraft aus dem High-Speed-Modell
	var slip_angle_rad = atan2(lateral_speed, abs(longitudinal_speed)) if abs(longitudinal_speed) > 0.01 else 0.0
	var hs_lateral_force_mag = -slip_angle_rad * cornering_stiffness
	var hs_force = lateral_dir_global * hs_lateral_force_mag


	# Kraft aus dem Low-Speed-Modell
	var ls_lateral_force_mag = -lateral_speed * low_speed_lateral_friction
	var ls_force = lateral_dir_global * ls_lateral_force_mag

	# 2. Berechne den Blend-Faktor (0 = nur low-speed, 1 = nur high-speed)

	var blend_factor = inverse_lerp(transition_start_speed, transition_end_speed, abs(longitudinal_speed))
	blend_factor = clamp(blend_factor, 0.0, 1.0) # Sicherstellen, dass der Wert zwischen 0 und 1 bleibt

	# 3. Mische die beiden Kräfte mit lerp (lineare Interpolation)
	var lateral_force = lerp(ls_force, hs_force, blend_factor)

	# Für die longitudinale Kraft können wir ein ähnliches, aber einfacheres Blending machen
	var longitudinal_force_mag = lerp(low_speed_longitudinal_friction, rolling_resistance, blend_factor)
	var longitudinal_force = longitudinal_dir_global * (-longitudinal_speed * longitudinal_force_mag)

	var brake_force = Vector3.ZERO
	if brake_component != null and brake_component.brake_input > 0:
		var brake_force_magnitude = brake_component.max_brake_force * brake_component.brake_input
		brake_force = longitudinal_dir_global * -sign(longitudinal_speed) * brake_force_magnitude

	# --- Gesamtkraft anwenden ---
	var total_force_global = lateral_force + longitudinal_force + brake_force
	aircraft.apply_force(total_force_global, wheel_offset_global)

	_update_wheel_rotation(longitudinal_speed, delta)
	# Debug-Visualisierung...
	DebugDraw3D.draw_line(wheel_model.global_position, wheel_model.global_position + -self.global_transform.basis.z*10, Color.GREEN)
	DebugDraw3D.draw_line(wheel_model.global_position, wheel_model.global_position + lateral_dir_global*10, Color.AQUA)
	DebugDraw3D.draw_line(wheel_model.global_position, wheel_model.global_position + lateral_force/100, Color.RED) # Seitenkraft
	DebugDraw3D.draw_line(wheel_model.global_position, wheel_model.global_position + longitudinal_force/100, Color.BLUE) # Rollwiderstand

func _update_wheel_rotation(longitudinal_speed: float, delta: float):
	if not wheel_model.mesh is CylinderMesh:
		return # Sicherheitsabfrage

	var radius = wheel_model.mesh.top_radius
	if radius <= 0:
		return # Division durch Null verhindern

	# Berechne die Zieldrehgeschwindigkeit (Radiant pro Sekunde)
	var target_angular_velocity = longitudinal_speed / radius

	# Hier kommt die Achsenreibung/Inertia ins Spiel!
	# Wir drehen das Rad nicht sofort, sondern gleichen seine aktuelle
	# Drehgeschwindigkeit langsam an die Zielgeschwindigkeit an.
	# wheel_model.rotation.x ist hier eine schlechte Wahl, da es zu Gimbal Lock führt.
	# Besser ist es, die Rotation direkt zu steuern.
	var rotation_this_frame = target_angular_velocity * delta
	wheel_model.rotate_object_local(Vector3.DOWN, rotation_this_frame)

func set_steering_input(value: float):
	if is_steerable:
		steering_input = clamp(value, -1.0, 1.0)

func get_point_velocity (point :Vector3) -> Vector3:
	return aircraft.linear_velocity + aircraft.angular_velocity.cross(point - aircraft.global_position)
