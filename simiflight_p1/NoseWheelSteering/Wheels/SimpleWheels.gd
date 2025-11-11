
class_name SimpleWheels extends  Node3D
# signals
# enums
# constants
# static variables
# @export variables
#Was sind realistische Werte für lateral_friction und rolling_resistance?
#Das ist die Millionen-Dollar-Frage. Die Antwort ist: Die Werte sind nur im Kontext deines Modells und der Masse deines Objekts "realistisch".
#lateral_friction und rolling_resistance sind keine echten physikalischen Koeffizienten, sondern Tuning-Faktoren für dein spezifisches lineares Dämpfungsmodell.
#Gefühl ist König: Deine Einschätzung ist das Wichtigste. Wenn es sich richtig anfühlt, ist der Wert richtig.
#Relationen sind wichtig: Der lateral_friction sollte immer um ein Vielfaches höher sein als der rolling_resistance (z.B. Faktor 50-100), denn ein Reifen rutscht viel schwerer seitwärts, als er rollt.
#Masse beachten: Wenn du die Masse deines Flugzeugs verdoppelst, musst du wahrscheinlich auch deine Reibungswerte erhöhen, damit es sich ähnlich anfühlt.
#Beginne mit den vorgeschlagenen Werten und spiele vor allem mit stop_threshold_speed und dem Dämpfungsfaktor (0.1) in der neuen Funktion, um das "klebrige" Gefühl bei geringer Geschwindigkeit genau nach deinem Geschmack einzustellen.
@export var is_steerable: bool = false ## Normaly nose-gear
@export var max_steering_angle: float = 85.0 ## In degree
@export var lateral_friction: float = 1000.0 ## not a real physical value!
@export var rolling_resistance: float = 1.0 ## not a real physical value!
@export var stop_threshold_speed: float = 0.5 ## is the absolut speed slower -> more friction.
@export var static_friction_damping: float = 0.01 ## fake static friction damping
@export var aircraft: RigidBody3D ## the wheels aircraft

# remaining regular variables
var steering_input: float = 0.0  # -1 = left, 1 = right


# @onready variables
@onready var raycast: RayCast3D = %RayCast3D
# _static_init()
# remaining static methods
# overridden built-in virtual methods:
# _init()
# _enter_tree()
# _ready()
func _ready() -> void:
	DebugDraw3D.scoped_config().set_thickness(0.5)
# _process()
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if raycast.is_colliding(): #raycast.is_colliding() and
		_update_wheel_forces(delta)

func _update_wheel_forces(delta: float) -> void:
	if aircraft == null:
		push_error("You have to set the parent Aircraft of the wheel!")
		return

	var steer_angle_rad: float = 0.0
	if is_steerable:
		steer_angle_rad = deg_to_rad(steering_input * max_steering_angle)
	self.rotation.y = steer_angle_rad
	DebugDraw3D.draw_line(self.global_position, self.global_position + -self.global_transform.basis.z*10, Color.GREEN)

	var wheel_offset_global: Vector3 = self.global_position - aircraft.global_position
	var wheel_rotational_velocity_global: Vector3 = aircraft.angular_velocity.cross(wheel_offset_global)
	var wheel_velocity_global: Vector3 = aircraft.linear_velocity + wheel_rotational_velocity_global

	# --- Kräfte berechnen mit dem neuen Modell ---
	var lateral_dir_global: Vector3 = self.global_transform.basis.x
	var longitudinal_dir_global: Vector3 = -self.global_transform.basis.z

	var lateral_force: Vector3 = _calculate_friction_force(lateral_dir_global, wheel_velocity_global, lateral_friction, delta)
	var longitudinal_force: Vector3 = _calculate_friction_force(longitudinal_dir_global, wheel_velocity_global, rolling_resistance, delta)

	# --- Gesamtkraft anwenden ---
	var total_force_global = lateral_force + longitudinal_force
	aircraft.apply_force(total_force_global, wheel_offset_global)
	DebugDraw3D.draw_line(self.global_position, self.global_position + lateral_dir_global*10, Color.AQUA)

	DebugDraw3D.draw_line(self.global_position, self.global_position + lateral_force/100, Color.RED) # Seitenkraft
	DebugDraw3D.draw_line(self.global_position, self.global_position + longitudinal_force/100, Color.BLUE) # Rollwiderstand
func _full_stop_friction(speed: float) -> void:
	if speed < 0.01:
		aircraft.physics_material_override.friction = 0.025
	else:
		aircraft.physics_material_override.friction = 0.0


func _calculate_friction_force(direction_global: Vector3, velocity_global: Vector3, coefficient: float, delta: float) -> Vector3:
	var speed_in_direction: float = velocity_global.dot(direction_global)
	_full_stop_friction(abs(speed_in_direction))
	if abs(speed_in_direction) < stop_threshold_speed:
		var force_magnitude = -speed_in_direction * (1.0 / delta) * aircraft.mass
		return direction_global * force_magnitude * static_friction_damping
	else:
		var force_magnitude = -speed_in_direction * coefficient
		return direction_global * force_magnitude

# remaining virtual methods
# overridden custom methods
# remaining methods
func set_steering_input(value: float):
	if is_steerable:
		steering_input = clamp(value, -1.0, 1.0)
# subclasses
