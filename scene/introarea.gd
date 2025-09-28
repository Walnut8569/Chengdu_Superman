extends Area3D

@onready var introTriggered := false

signal loadIntro
@onready var anim_player: AnimationPlayer = $".."/Boss/Pivot/Boss/boss_V2/AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 綁定動畫結束訊號
	anim_player.animation_finished.connect(_on_animation_finished)


signal intro_finished   # Intro動畫結束的訊號

@onready var ani_player: AnimationPlayer = $Pivot/Boss/boss_V2/AnimationPlayer
	

		
func _on_body_entered(body):
	if body.is_in_group("player") and not introTriggered:
		print("玩家進入範圍")
		loadIntro.emit();
		introTriggered = true
		anim_player.play("start_fight")
		
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "start_fight":  # 這裡填你 FBX 動畫的名字
		print("Boss 開場動畫播放完畢！")
		intro_finished.emit()

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("玩家離開範圍")
