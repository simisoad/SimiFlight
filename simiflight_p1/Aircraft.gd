class_name Aircraft extends PhysicsBody3D


func _init() -> void:
	pass
		
func _ready() -> void:
	PhysicsServer3D.body_apply_force(self.get_rid(), Vector3(0,100,0))
	
