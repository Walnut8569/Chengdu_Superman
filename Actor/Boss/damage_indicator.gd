extends MeshInstance3D

@export var flash_speed: float = 3.0  # 閃爍速度
@export var min_alpha: float = 0.3     # 最小透明度
@export var max_alpha: float = 0.9     # 最大透明度

var material_ref: StandardMaterial3D
var base_color: Color
var flash_timer: float = 0.0

func _ready() -> void:
	# 獲取材質參考
	if material_override:
		material_ref = material_override as StandardMaterial3D
		if material_ref:
			base_color = material_ref.albedo_color

func _process(delta: float) -> void:
	if visible and material_ref:
		# 更新閃爍計時器
		flash_timer += delta * flash_speed

		# 使用sin函數創建平滑的漸變效果
		var alpha = min_alpha + (max_alpha - min_alpha) * (sin(flash_timer) * 0.5 + 0.5)

		# 更新材質的透明度
		material_ref.albedo_color = Color(base_color.r, base_color.g, base_color.b, alpha)

func reset_flash() -> void:
	# 重置閃爍計時器
	flash_timer = 0.0
	if material_ref:
		material_ref.albedo_color = Color(base_color.r, base_color.g, base_color.b, max_alpha)
