extends Control

# UI 节点引用
@onready var logo: Sprite2D = $"LaunchLogo"  # 启动Logo精灵
@onready var bg: Sprite2D = $"LoadingBg"     # 背景图片精灵
@onready var button: TextureButton = $StartButton  # 开始按钮

# 常量定义
const BASE_PATH = "res://assets/images/load/Loading_Bg_"  # 背景图片路径前缀
const BG_IMAGE_COUNT = 27  # 背景图片数量 (0-26)

# 动画时间常量
const LOGO_FADE_TIME = 1.0    # Logo淡入淡出时间
const LOGO_DISPLAY_TIME = 2.0  # Logo显示持续时间
const BG_SCALE_TIME = 0.2     # 背景缩放动画时间
const BG_INITIAL_SCALE = 1.1  # 背景初始缩放比例

func _ready():
	"""初始化场景，设置初始状态并播放启动动画"""
	_initialize_components()
	await _play_startup_sequence()

func _initialize_components():
	"""初始化UI组件的初始状态"""
	logo.modulate.a = 0.0  # 设置Logo为完全透明
	button.disabled = true  # 禁用开始按钮

func _play_startup_sequence():
	"""播放完整的启动动画序列"""
	await _animate_logo()
	_setup_background()
	_animate_background()

func _animate_logo():
	"""播放Logo动画：淡入-显示-淡出"""
	var tween = _create_smooth_tween()
	
	# 动画序列：淡入 -> 显示 -> 淡出
	tween.tween_property(logo, "modulate:a", 1.0, LOGO_FADE_TIME)
	tween.tween_interval(LOGO_DISPLAY_TIME)
	tween.tween_property(logo, "modulate:a", 0.0, LOGO_FADE_TIME)
	
	await tween.finished

func _setup_background():
	"""设置随机背景并启用开始按钮"""
	bg.texture = load(_get_random_bg_path())  # 加载随机背景图片
	button.z_index = 1      # 确保按钮在最上层
	button.disabled = false  # 启用开始按钮

func _get_random_bg_path() -> String:
	"""生成随机背景图片路径"""
	var random_index = randi_range(0, BG_IMAGE_COUNT - 1)
	return BASE_PATH + str(random_index) + ".png"
	
func _animate_background():
	"""播放背景缩放动画，从稍大缩放到正常大小"""
	bg.scale = Vector2(BG_INITIAL_SCALE, BG_INITIAL_SCALE)  # 设置初始缩放
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# 平滑缩放到正常大小
	tween.tween_property(bg, "scale", Vector2.ONE, BG_SCALE_TIME)

func _create_smooth_tween() -> Tween:
	"""创建带有平滑过渡效果的Tween对象"""
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	return tween
