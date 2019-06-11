extends KinematicBody

const MOTION_SPEED = 90.0

puppet var puppet_pos = Vector3()
puppet var puppet_motion = Vector3()

func _physics_process(_delta):
	var motion = Vector3()

	if is_network_master():
		if Input.is_action_pressed("ui_left"):
			motion += Vector3(-0.01, 0, 0)
		if Input.is_action_pressed("ui_right"):
			motion += Vector3(0.01, 0, 0)
		if Input.is_action_pressed("ui_up"):
			motion += Vector3(0, 0.01, 0)
		if Input.is_action_pressed("ui_down"):
			motion += Vector3(0, -0.01, 0)



		rset("puppet_motion", motion)
		rset("puppet_pos", translation)
	else:
		translation = puppet_pos
		motion = puppet_motion



	move_and_collide(motion)
	if not is_network_master():
		puppet_pos = translation # Para evitar el jitter



func set_player_name(new_name):
	get_node("label").set_text(new_name)

func _ready():
	puppet_pos = translation
	
	
