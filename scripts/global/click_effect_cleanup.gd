extends Node2D

func _ready():
	# 获取动画播放器和粒子系统
	var anim_player = get_node_or_null("AnimationPlayer")
	var particles = get_node_or_null("SmallStars")
	var circle_sprite = get_node_or_null("Circle")
	
	# 计算最长生命时间
	var max_lifetime = 0.0
	
	# 检查Circle动画时长
	if circle_sprite and circle_sprite.sprite_frames:
		var frames = circle_sprite.sprite_frames.get_frame_count("circle")
		var speed = circle_sprite.speed_scale
		var circle_duration = frames / (8.0 * speed)  # 8.0是原始速度
		max_lifetime = max(max_lifetime, circle_duration)
	
	# 检查颜色动画时长
	if anim_player:
		var animation = anim_player.get_animation("circle_effect")
		if animation:
			max_lifetime = max(max_lifetime, animation.length)
	
	# 检查粒子系统时长
	if particles:
		max_lifetime = max(max_lifetime, particles.lifetime)
	
	# 添加0.2秒缓冲时间，确保所有效果完全结束
	max_lifetime += 0.2
	
	# 创建定时器用于自动销毁
	var cleanup_timer = Timer.new()
	add_child(cleanup_timer)
	cleanup_timer.wait_time = max_lifetime
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup)
	cleanup_timer.start()

func _cleanup():
	# 彻底销毁节点
	queue_free()
