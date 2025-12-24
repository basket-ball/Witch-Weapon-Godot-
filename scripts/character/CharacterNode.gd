# CharacterNode.gd - 基础人物节点类
class_name CharacterNode
extends Node2D

# 人物名称输入格式：ren_battle 或 raphael
@export var character_name: String = ""

# 显示给玩家看的人物名称
@export var display_name: String = ""

# 手动输入的表情列表
@export var expression_list: Array[String] = []

# 当前表情
@export var current_expression: String = ""

# 表情字典，存储表情名称和对应的纹理
var expressions: Dictionary = {}

# 节点引用
@onready var canvas_group: CanvasGroup = $CanvasGroup
@onready var base_sprite: Sprite2D = $CanvasGroup/Base
@onready var face_sprite: Sprite2D = $CanvasGroup/Base/Face

func _ready():
	# 初始化时加载人物资源
	if character_name != "":
		load_character_resources()
		if current_expression != "":
			set_expression(current_expression)

# 根据character_name构建路径并加载资源
func load_character_resources():
	if character_name == "":
		push_error("人物名称不能为空")
		return
	
	var base_path = _build_character_path(character_name)
	if base_path == "":
		return
	
	# 加载基底图片
	var base_texture = load(base_path + "base.png")
	if base_texture:
		base_sprite.texture = base_texture
	else:
		push_error("无法加载基底图片: " + base_path + "base.png")
		return
	
	# 根据手动输入的表情列表加载表情
	_load_expressions(base_path)

# 构建人物资源路径
func _build_character_path(char_name: String) -> String:
	var base_path = "res://assets/images/role/"
	
	# 检查是否包含下划线
	if "_" in char_name:
		# 有下划线的情况：ren_battle -> res://assets/images/role/ren/battle/
		var parts = char_name.split("_")
		for part in parts:
			base_path += part + "/"
	else:
		# 没有下划线的情况：raphael -> res://assets/images/role/raphael/
		base_path += char_name + "/"
	
	# 验证路径是否存在
	if not _path_exists(base_path):
		push_error("人物资源路径不存在: " + base_path)
		return ""
	
	return base_path

# 检查路径是否存在
func _path_exists(path: String) -> bool:
	var dir = DirAccess.open(path)
	return dir != null

# 加载表情资源
func _load_expressions(base_path: String):
	expressions.clear()
	
	for expression in expression_list:
		var texture_path = base_path + expression + ".png"
		
		# 检查文件是否存在
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				expressions[expression] = texture
			else:
				push_warning("加载表情纹理失败: " + texture_path)
		else:
			push_warning("表情文件不存在: " + texture_path)

# 设置表情（无动画）
func set_expression(expression_name: String):
	if expression_name in expressions:
		face_sprite.texture = expressions[expression_name]
		current_expression = expression_name
	elif expression_name == "":
		# 空字符串表示清除表情
		face_sprite.texture = null
		current_expression = ""
	else:
		push_error("表情不存在: " + expression_name + "，请检查expression_list中是否包含该表情")

# 设置表情（带渐变动画）
func set_expression_animated(expression_name: String, duration: float = 0.2):
	# 检查新表情是否存在
	if expression_name != "" and not expression_name in expressions:
		push_error("表情不存在: " + expression_name + "，请检查expression_list中是否包含该表情")
		return

	# 如果当前表情和新表情相同，直接返回
	if current_expression == expression_name:
		return

	# 停止之前可能正在运行的表情切换动画并清理临时精灵
	if has_meta("expression_tween"):
		var old_tween = get_meta("expression_tween")
		if old_tween and is_instance_valid(old_tween):
			old_tween.kill()
		remove_meta("expression_tween")

	# 清理之前可能存在的临时精灵（修复bug关键）
	if has_meta("temp_face_sprite"):
		var old_temp_sprite = get_meta("temp_face_sprite")
		if old_temp_sprite and is_instance_valid(old_temp_sprite):
			old_temp_sprite.queue_free()
		remove_meta("temp_face_sprite")

	# 如果当前没有表情，直接设置新表情并淡入
	if face_sprite.texture == null:
		_change_expression_texture(expression_name)
		face_sprite.self_modulate.a = 0.0
		var fade_tween = create_tween()
		set_meta("expression_tween", fade_tween)
		fade_tween.tween_property(face_sprite, "self_modulate:a", 1.0, duration)
		fade_tween.set_trans(Tween.TRANS_CUBIC)
		fade_tween.set_ease(Tween.EASE_OUT)
		fade_tween.finished.connect(func(): if has_meta("expression_tween"): remove_meta("expression_tween"))
		return fade_tween

	# 创建一个临时的表情精灵来实现覆盖效果
	var new_face_sprite = Sprite2D.new()
	new_face_sprite.texture = expressions[expression_name] if expression_name in expressions else null
	new_face_sprite.position = face_sprite.position
	new_face_sprite.scale = face_sprite.scale
	new_face_sprite.self_modulate.a = 0.0
	new_face_sprite.z_index = face_sprite.z_index + 1  # 确保新表情在上层

	# 添加到同一个父节点
	face_sprite.get_parent().add_child(new_face_sprite)

	# 保存临时精灵引用（修复bug关键）
	set_meta("temp_face_sprite", new_face_sprite)

	# 创建渐变动画：新表情从透明渐变到不透明，覆盖旧表情
	var tween = create_tween()
	set_meta("expression_tween", tween)
	tween.tween_property(new_face_sprite, "self_modulate:a", 1.0, duration)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 动画完成后替换原表情并清理
	tween.finished.connect(func():
		# 更新原表情精灵
		face_sprite.texture = new_face_sprite.texture
		face_sprite.self_modulate.a = 1.0
		current_expression = expression_name

		# 清理临时精灵和meta
		new_face_sprite.queue_free()
		if has_meta("expression_tween"):
			remove_meta("expression_tween")
		if has_meta("temp_face_sprite"):
			remove_meta("temp_face_sprite")
	)

	return tween

# 内部方法：更换表情纹理
func _change_expression_texture(expression_name: String):
	if expression_name in expressions:
		face_sprite.texture = expressions[expression_name]
		current_expression = expression_name
	elif expression_name == "":
		face_sprite.texture = null
		current_expression = ""

# 获取当前表情
func get_current_expression() -> String:
	return current_expression

# 获取所有可用表情
func get_available_expressions() -> Array:
	return expressions.keys()

# 检查表情是否可用
func has_expression(expression_name: String) -> bool:
	return expression_name in expressions

# 重新加载人物资源
func reload_character(new_character_name: String = ""):
	if new_character_name != "":
		character_name = new_character_name
	
	expressions.clear()
	load_character_resources()
	
	# 如果当前表情在新人物中不存在，设置为第一个可用表情
	if current_expression != "" and not has_expression(current_expression):
		var available = get_available_expressions()
		if available.size() > 0:
			set_expression(available[0])
		else:
			set_expression("")

# ==================== CanvasGroup 控制功能 ====================

# 设置整体透明度
func set_alpha(alpha: float):
	if canvas_group:
		canvas_group.self_modulate.a = alpha

# 获取当前透明度
func get_alpha() -> float:
	if canvas_group:
		return canvas_group.self_modulate.a
	return 1.0

# 淡入效果
func fade_in(duration: float = 0.5):
	if canvas_group:
		canvas_group.self_modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(canvas_group, "self_modulate:a", 1.0, duration)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		return tween

# 淡出效果
func fade_out(duration: float = 0.5):
	if canvas_group:
		var tween = create_tween()
		tween.tween_property(canvas_group, "self_modulate:a", 0.0, duration)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		return tween

# 设置整体可见性
func set_character_visible(visibility: bool):
	if canvas_group:
		canvas_group.visible = visibility

# 获取整体可见性
func is_character_visible() -> bool:
	if canvas_group:
		return canvas_group.visible
	return false

# 设置整体颜色调制
func set_character_modulate(color: Color):
	if canvas_group:
		canvas_group.self_modulate = color

# 获取当前颜色调制
func get_character_modulate() -> Color:
	if canvas_group:
		return canvas_group.self_modulate
	return Color.WHITE

# ==================== 角色颜色变化功能 ====================

# 角色变亮（从暗色背景状态恢复到正常说话状态）
func character_light(duration: float = 0.2):
	"""角色从背景暗色状态恢复到正常说话状态，类似RenPy的left_light"""
	if not canvas_group:
		push_error("CanvasGroup节点未找到")
		return
	
	# 停止之前可能正在运行的颜色变化动画
	_stop_color_tween()
	
	# 创建从当前颜色到正常色的动画（模拟linear 0.2 matrixcolor TintMatrix("#ffffff")）
	var tween = create_tween()
	set_meta("color_tween", tween)
	
	var normal_color = Color(1.0, 1.0, 1.0, 1.0)
	
	tween.tween_property(canvas_group, "self_modulate", normal_color, duration)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func(): 
		if has_meta("color_tween"): 
			remove_meta("color_tween")
	)
	
	return tween

# 角色变暗（从正常说话状态变成背景状态）
func character_dark(duration: float = 0.2):
	"""角色从正常说话状态变成背景暗色状态，类似RenPy的left_dark"""
	if not canvas_group:
		push_error("CanvasGroup节点未找到")
		return
	
	# 停止之前可能正在运行的颜色变化动画
	_stop_color_tween()
	
	# 从当前颜色（正常状态）变暗到背景状态
	var tween = create_tween()
	set_meta("color_tween", tween)
	
	# 目标暗色（模拟TintMatrix("#000000b6")的效果）- 更深的暗色
	var dark_color = Color(0.25, 0.25, 0.25, 1.0)
	
	tween.tween_property(canvas_group, "self_modulate", dark_color, duration)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func(): 
		if has_meta("color_tween"): 
			remove_meta("color_tween")
	)
	
	return tween

# 内部方法：停止颜色变化动画
func _stop_color_tween():
	"""停止当前正在运行的颜色变化动画"""
	if has_meta("color_tween"):
		var old_tween = get_meta("color_tween")
		if old_tween and is_instance_valid(old_tween):
			old_tween.kill()
		remove_meta("color_tween")

# ==================== 角色移动功能 ====================

# 角色向左移动（模拟RenPy的move_left transform）
func move_left(to_xalign: float, duration: float = 0.3, enable_brightness_change: bool = true):
	"""角色向左移动并变暗，类似RenPy的move_left transform
	参数:
	- to_xalign: 目标X位置（百分比，0.0-1.0）
	- duration: 动画时长（默认0.3秒）
	- enable_brightness_change: 是否启用变暗动画（默认true）
	"""
	if not canvas_group:
		push_error("CanvasGroup节点未找到")
		return

	# 停止之前可能正在运行的移动和颜色动画
	_stop_move_tween()
	_stop_color_tween()

	# 获取屏幕宽度用于计算目标位置
	var screen_width = get_viewport().get_visible_rect().size.x
	var target_xpos = screen_width * to_xalign

	# 调试输出
	print("move_left 调试信息:")
	print("  屏幕宽度: ", screen_width)
	print("  当前位置: ", position.x)
	print("  目标百分比: ", to_xalign)
	print("  目标位置: ", target_xpos)
	print("  移动方向: ", "右" if target_xpos > position.x else "左")
	print("  启用变暗动画: ", enable_brightness_change)

	# 创建动画
	var tween = create_tween()
	if enable_brightness_change:
		tween.set_parallel(true)  # 如果需要颜色动画，允许并行动画
	set_meta("move_tween", tween)

	# 位置动画：linear 0.3 xalign to_xpos
	tween.tween_property(self, "position:x", target_xpos, duration)
	tween.set_trans(Tween.TRANS_LINEAR)

	# 颜色动画：仅当enable_brightness_change为true时才执行
	if enable_brightness_change:
		# 保留当前的alpha值，避免与show_character的渐变冲突
		var current_alpha = canvas_group.self_modulate.a
		# 如果当前alpha太小（可能正在渐变中），使用1.0作为目标alpha
		if current_alpha < 0.9:
			current_alpha = 1.0
		var dark_color = Color(0.25, 0.25, 0.25, current_alpha)  # 使用当前alpha
		tween.tween_property(canvas_group, "self_modulate", dark_color, duration)
		tween.set_trans(Tween.TRANS_LINEAR)

	tween.finished.connect(func():
		if has_meta("move_tween"):
			remove_meta("move_tween")
	)

	return tween

# 角色向右移动（模拟RenPy的move_right transform）
func move_right(to_xalign: float, duration: float = 0.3, enable_brightness_change: bool = true):
	"""角色向右移动并变亮，类似RenPy的move_right transform
	参数:
	- to_xalign: 目标X位置（百分比，0.0-1.0）
	- duration: 动画时长（默认0.3秒）
	- enable_brightness_change: 是否启用变亮动画（默认true）
	"""
	if not canvas_group:
		push_error("CanvasGroup节点未找到")
		return

	# 停止之前可能正在运行的移动和颜色动画
	_stop_move_tween()
	_stop_color_tween()

	# 获取屏幕宽度用于计算目标位置
	var screen_width = get_viewport().get_visible_rect().size.x
	var target_xpos = screen_width * to_xalign

	# 调试输出
	print("move_right 调试信息:")
	print("  屏幕宽度: ", screen_width)
	print("  当前位置: ", position.x)
	print("  目标百分比: ", to_xalign)
	print("  目标位置: ", target_xpos)
	print("  移动方向: ", "右" if target_xpos > position.x else "左")
	print("  启用变亮动画: ", enable_brightness_change)

	# 创建动画
	var tween = create_tween()
	if enable_brightness_change:
		tween.set_parallel(true)  # 如果需要颜色动画，允许并行动画
	set_meta("move_tween", tween)

	# 位置动画：linear 0.3 xalign to_xpos
	tween.tween_property(self, "position:x", target_xpos, duration)
	tween.set_trans(Tween.TRANS_LINEAR)

	# 颜色动画：仅当enable_brightness_change为true时才执行
	if enable_brightness_change:
		# 保留当前的alpha值，避免与show_character的渐变冲突
		var current_alpha = canvas_group.self_modulate.a
		# 如果当前alpha太小（可能正在渐变中），使用1.0作为目标alpha
		if current_alpha < 0.9:
			current_alpha = 1.0
		var normal_color = Color(1.0, 1.0, 1.0, current_alpha)  # 使用当前alpha
		tween.tween_property(canvas_group, "self_modulate", normal_color, duration)
		tween.set_trans(Tween.TRANS_LINEAR)

	tween.finished.connect(func():
		if has_meta("move_tween"):
			remove_meta("move_tween")
	)

	return tween

# 内部方法：停止移动动画
func _stop_move_tween():
	"""停止当前正在运行的移动动画"""
	if has_meta("move_tween"):
		var old_tween = get_meta("move_tween")
		if old_tween and is_instance_valid(old_tween):
			old_tween.kill()
		remove_meta("move_tween")
