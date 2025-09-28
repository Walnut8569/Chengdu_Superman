extends RigidBody3D

@export var damage: float = 5.0
@export var speed: float = 20.0
@export var lifetime: float = 5.0

var direction: Vector3
var lifetime_timer: float = 0.0

func _ready() -> void:
	# 設定子彈的物理屬性
	gravity_scale = 0  # 不受重力影響
	add_to_group("bullets")

func _physics_process(delta: float) -> void:
	# 更新生存時間
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		queue_free()
		return

	# 移動子彈
	if direction != Vector3.ZERO:
		linear_velocity = direction * speed

func setup(start_position: Vector3, target_direction: Vector3, bullet_damage: float, bullet_speed: float) -> void:
	global_position = start_position
	direction = target_direction.normalized()
	damage = bullet_damage
	speed = bullet_speed
	linear_velocity = direction * speed

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(damage)
		print("子彈擊中玩家，造成", damage, "點傷害")
		queue_free()
	elif not body.is_in_group("boss"):  # 不與Boss本身碰撞
		queue_free()  # 擊中其他物體時銷毀
