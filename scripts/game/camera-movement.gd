extends Camera2D

@export var movement_speed : float = 500
var movement_directon : Vector2

func _physics_process(delta):
	movement_directon.x = Input.get_axis("move_left", "move_right")
	movement_directon.y = Input.get_axis("move_up", "move_down")
	movement_directon = movement_directon.normalized()

	
	if movement_directon:
		position += movement_directon * movement_speed * delta
