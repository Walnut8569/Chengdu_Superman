extends Area3D

@onready var introTriggered := false

signal loadIntro


# Called when the node enters the scene tree for the first time.
func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("玩家進入範圍")
		loadIntro.emit();
		introTriggered = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("玩家離開範圍")
