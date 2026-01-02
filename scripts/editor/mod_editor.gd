# =============================================================================
# Mod可视化编辑器 (Mod Visual Editor) - 重构版
# =============================================================================
# 功能概述：
# 1. 三列布局：左侧Inspector+资源，中间预览+工具箱，右侧脚本序列
# 2. 点击脚本块在Inspector显示详细参数
# 3. 工具箱Tab分类
# 4. 资源列表智能筛选
# =============================================================================

extends Control

# 脚本块类型枚举
enum BlockType {
	TEXT_ONLY,          # 纯文本（旁白）
	DIALOG,             # 对话（带说话人）
	SHOW_CHARACTER_1,   # 显示第一个角色
	HIDE_CHARACTER_1,   # 隐藏第一个角色
	SHOW_CHARACTER_2,   # 显示第二个角色
	HIDE_CHARACTER_2,   # 隐藏第二个角色
	SHOW_CHARACTER_3,   # 显示第三个角色
	HIDE_CHARACTER_3,   # 隐藏第三个角色
	HIDE_ALL_CHARACTERS,# 隐藏所有角色
	BACKGROUND,         # 更改背景
	MUSIC,              # 播放音乐
	EXPRESSION,         # 更改表情
	SHOW_BACKGROUND,    # 显示背景（可渐变）
	CHANGE_MUSIC,       # 切换音乐
	STOP_MUSIC,         # 停止音乐
}

# 脚本块分类
const BLOCK_CATEGORIES = {
	"对话": [BlockType.TEXT_ONLY, BlockType.DIALOG],
	"角色": [BlockType.SHOW_CHARACTER_1, BlockType.HIDE_CHARACTER_1,
			 BlockType.SHOW_CHARACTER_2, BlockType.HIDE_CHARACTER_2,
			 BlockType.SHOW_CHARACTER_3, BlockType.HIDE_CHARACTER_3,
			 BlockType.HIDE_ALL_CHARACTERS],
	"场景": [BlockType.BACKGROUND, BlockType.SHOW_BACKGROUND, BlockType.MUSIC, BlockType.CHANGE_MUSIC, BlockType.STOP_MUSIC],
}

# 脚本块数据类
class ScriptBlock:
	var block_type: BlockType
	var params: Dictionary = {}
	var ui_node: Control = null  # 右侧列表中的简化UI
	var has_error: bool = false  # 是否有验证错误
	var error_message: String = ""  # 错误信息

	func _init(type: BlockType):
		block_type = type

	func validate() -> bool:
		"""验证脚本块参数，返回true表示无错误"""
		has_error = false
		error_message = ""

		match block_type:
			BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
				# 验证角色名称
				var char_name = params.get("character_name", "")
				if char_name.is_empty():
					has_error = true
					error_message = "角色名称不能为空"
					return false

				# 验证X位置 (0-1范围)
				var x_pos = params.get("x_position", 0.5)
				if typeof(x_pos) == TYPE_STRING:
					x_pos = x_pos.to_float()
				if x_pos < 0.0 or x_pos > 1.0:
					has_error = true
					error_message = "X位置必须在0-1之间"
					return false

			BlockType.TEXT_ONLY:
				var text = params.get("text", "")
				if text.is_empty():
					has_error = true
					error_message = "文本内容不能为空"
					return false

			BlockType.DIALOG:
				var text = params.get("text", "")
				var speaker = params.get("speaker", "")
				if text.is_empty():
					has_error = true
					error_message = "对话内容不能为空"
					return false
				if speaker.is_empty():
					has_error = true
					error_message = "说话人不能为空"
					return false

			BlockType.BACKGROUND:
				var bg_path = params.get("background_path", "")
				if bg_path.is_empty():
					has_error = true
					error_message = "背景路径不能为空"
					return false

			BlockType.SHOW_BACKGROUND:
				var bg_path = params.get("background_path", "")
				if bg_path.is_empty():
					has_error = true
					error_message = "背景路径不能为空"
					return false
				var fade_time = params.get("fade_time", 0.0)
				if typeof(fade_time) == TYPE_STRING:
					fade_time = fade_time.to_float()
				if fade_time < 0.0:
					has_error = true
					error_message = "渐变时间不能小于0"
					return false

			BlockType.MUSIC:
				var music_path = params.get("music_path", "")
				if music_path.is_empty():
					has_error = true
					error_message = "音乐路径不能为空"
					return false

			BlockType.CHANGE_MUSIC:
				var music_path = params.get("music_path", "")
				if music_path.is_empty():
					has_error = true
					error_message = "音乐路径不能为空"
					return false

		return true

	func get_summary() -> String:
		"""获取脚本块的简要描述"""
		match block_type:
			BlockType.TEXT_ONLY:
				var text = params.get("text", "")
				return "旁白: " + text.substr(0, 20) + ("..." if text.length() > 20 else "")
			BlockType.DIALOG:
				var speaker = params.get("speaker", "未设置")
				var text = params.get("text", "")
				return speaker + ": " + text.substr(0, 15) + ("..." if text.length() > 15 else "")
			BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
				var char_name = params.get("character_name", "未设置")
				return "显示角色: " + char_name
			BlockType.HIDE_CHARACTER_1:
				return "隐藏角色1"
			BlockType.HIDE_CHARACTER_2:
				return "隐藏角色2"
			BlockType.HIDE_CHARACTER_3:
				return "隐藏角色3"
			BlockType.HIDE_ALL_CHARACTERS:
				return "隐藏所有角色"
			BlockType.BACKGROUND:
				return "切换背景(渐变)"
			BlockType.MUSIC:
				return "播放音乐"
			BlockType.SHOW_BACKGROUND:
				var bg_path = params.get("background_path", "")
				return "显示背景: " + bg_path.get_file()
			BlockType.CHANGE_MUSIC:
				var music_path = params.get("music_path", "")
				return "切换音乐: " + music_path.get_file()
			BlockType.STOP_MUSIC:
				return "停止音乐"
			BlockType.EXPRESSION:
				var expression = params.get("expression", "未设置")
				return "表情: " + expression
			_:
				return "未知类型"

# === 节点引用 ===
# TopBar
@onready var back_button: Button = $TopBar/BackButton
@onready var run_button: Button = $TopBar/RunButton
@onready var export_button: Button = $TopBar/ExportButton
@onready var project_name_label: Label = $TopBar/ProjectNameLabel

# 左侧面板
@onready var inspector_content: VBoxContainer = $MainContainer/LeftPanel/InspectorPanel/InspectorContainer/InspectorScroll/InspectorContent
@onready var characters_list: ItemList = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharactersList
@onready var backgrounds_list: ItemList = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/BackgroundsList
@onready var music_list: ItemList = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/MusicList

# 中间面板
@onready var preview_viewport: SubViewport = $MainContainer/CenterPanel/PreviewPanel/PreviewContainer/PreviewAspect/PreviewArea/SubViewport
@onready var dialog_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/对话/DialogBlocksContainer
@onready var character_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/角色/CharacterBlocksContainer
@onready var scene_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/场景/SceneBlocksContainer
@onready var control_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/控制/ControlBlocksContainer

# 右侧面板
@onready var script_sequence: VBoxContainer = $MainContainer/RightPanel/RightPanelContainer/ScriptSequenceScroll/ScriptSequence
@onready var script_sequence_scroll: ScrollContainer = $MainContainer/RightPanel/RightPanelContainer/ScriptSequenceScroll

# === 变量 ===
var project_path: String = ""
var project_config: Dictionary = {}
var script_blocks: Array[ScriptBlock] = []
var selected_block: ScriptBlock = null

# 预览相关
var novel_interface: Node = null
var is_previewing: bool = false
var preview_coroutine = null

# 资源列表相关
var current_editing_field: LineEdit = null  # 当前正在编辑的参数字段
var current_editing_param: String = ""  # 当前参数名（character_name, expression等）
var _resource_mode: String = "none"  # none|character|expression|background|music

var _character_scene_cache: Dictionary = {} # character_name -> PackedScene
var _character_base_dir_cache: Dictionary = {} # character_name -> String
var _character_thumbnail_cache: Dictionary = {} # character_name -> Texture2D
var _expression_thumbnail_cache: Dictionary = {} # "character|expression" -> Texture2D

# 错误追踪
var has_validation_errors: bool = false

# 拖拽排序辅助UI
var drop_placeholder: PanelContainer = null

func _ready():
	set_process_input(true)
	_create_block_palette()
	_setup_preview()

	_setup_resource_panel()

	# 连接资源列表的点击事件
	characters_list.item_selected.connect(_on_character_selected)
	backgrounds_list.item_selected.connect(_on_background_selected)
	music_list.item_selected.connect(_on_music_selected)

	# 连接按钮事件
	run_button.pressed.connect(_on_run_button_pressed)
	export_button.pressed.connect(_on_export_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	# 允许拖拽时把块丢到“空隙/空白区域/列表末尾”
	script_sequence.set_drag_forwarding(
		Callable(self, "_get_drag_data_noop_simple"),
		Callable(self, "_can_drop_data_for_sequence").bind(script_sequence),
		Callable(self, "_drop_data_for_sequence").bind(script_sequence)
	)
	script_sequence_scroll.set_drag_forwarding(
		Callable(self, "_get_drag_data_noop_simple"),
		Callable(self, "_can_drop_data_for_sequence").bind(script_sequence_scroll),
		Callable(self, "_drop_data_for_sequence").bind(script_sequence_scroll)
	)

func _setup_resource_panel() -> void:
	_set_resource_panel_mode("none")

	# 更适合显示缩略图
	characters_list.fixed_icon_size = Vector2i(64, 64)
	characters_list.max_columns = 1

func _input(event: InputEvent) -> void:
	# 结束拖拽（或取消拖拽）时隐藏插入指示线
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_hide_drop_placeholder()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_drop_placeholder()

func _setup_preview():
	"""初始化预览区域的NovelInterface"""
	# 加载NovelInterface场景
	var novel_interface_scene = load("res://scenes/dialog/NovelInterface.tscn")
	if novel_interface_scene:
		novel_interface = novel_interface_scene.instantiate()
		preview_viewport.add_child(novel_interface)

		# 使用size_2d_override设置虚拟分辨率，匹配NovelInterface的设计尺寸
		preview_viewport.size_2d_override = Vector2i(1280, 720)
		preview_viewport.size_2d_override_stretch = true

		print("预览区域初始化完成")

# ==================== 资源列表管理 ====================

func _set_resource_panel_mode(mode: String) -> void:
	_resource_mode = mode

	var resource_panel := get_node_or_null("MainContainer/LeftPanel/ResourcePanel") as Control
	var characters_label := get_node_or_null("MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharactersLabel") as Label
	var backgrounds_label := get_node_or_null("MainContainer/LeftPanel/ResourcePanel/ResourceContainer/BackgroundsLabel") as Control
	var music_label := get_node_or_null("MainContainer/LeftPanel/ResourcePanel/ResourceContainer/MusicLabel") as Control

	# 资源面板始终可见
	if resource_panel:
		resource_panel.visible = true

	# 根据模式显示对应的列表
	if characters_label:
		characters_label.visible = mode in ["character", "expression"]
		characters_label.text = "表情:" if mode == "expression" else "角色:"
	if characters_list:
		characters_list.visible = mode in ["character", "expression"]

	if backgrounds_label:
		backgrounds_label.visible = mode == "background"
	if backgrounds_list:
		backgrounds_list.visible = mode == "background"

	if music_label:
		music_label.visible = mode == "music"
	if music_list:
		music_list.visible = mode == "music"

	# 当模式为"none"时，清空所有列表（但不隐藏面板）
	if mode == "none":
		if characters_list:
			characters_list.clear()
		if backgrounds_list:
			backgrounds_list.clear()
		if music_list:
			music_list.clear()
		# 隐藏所有标签
		if characters_label:
			characters_label.visible = false
		if backgrounds_label:
			backgrounds_label.visible = false
		if music_label:
			music_label.visible = false

func _load_characters_list():
	"""扫描并加载角色列表"""
	_set_resource_panel_mode("character")
	characters_list.clear()

	var character_dir = DirAccess.open("res://scenes/character/")
	if character_dir:
		var names: Array[String] = []
		character_dir.list_dir_begin()
		var file_name = character_dir.get_next()

		while file_name != "":
			if not character_dir.current_is_dir() and file_name.ends_with(".tscn"):
				# 移除.tscn后缀，得到角色名
				var character_name = file_name.replace(".tscn", "")
				names.append(character_name)
			file_name = character_dir.get_next()

		character_dir.list_dir_end()
		names.sort()
		for character_name in names:
			var icon := _get_character_thumbnail(character_name)
			characters_list.add_item(character_name, icon)
		print("已加载 %d 个角色" % characters_list.item_count)

func _load_backgrounds_list():
	"""扫描并加载背景列表"""
	_set_resource_panel_mode("background")
	backgrounds_list.clear()

	# 尝试从 res://assets/images/bg/ 加载
	var bg_dir = DirAccess.open("res://assets/images/bg/")
	if not bg_dir:
		# 如果不存在，尝试 res://assets/background/
		bg_dir = DirAccess.open("res://assets/background/")

	if bg_dir:
		bg_dir.list_dir_begin()
		var file_name = bg_dir.get_next()

		while file_name != "":
			if not bg_dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg")):
				backgrounds_list.add_item(file_name)
			file_name = bg_dir.get_next()

		bg_dir.list_dir_end()
		print("已加载 %d 个背景" % backgrounds_list.item_count)
	else:
		push_warning("无法找到背景文件夹: res://assets/images/bg/ 或 res://assets/background/")

func _load_music_list():
	"""扫描并加载音乐列表"""
	_set_resource_panel_mode("music")
	music_list.clear()

	var music_dir = DirAccess.open("res://assets/audio/music/")
	if music_dir:
		music_dir.list_dir_begin()
		var file_name = music_dir.get_next()

		while file_name != "":
			if not music_dir.current_is_dir() and (file_name.ends_with(".ogg") or file_name.ends_with(".mp3") or file_name.ends_with(".wav")):
				music_list.add_item(file_name)
			file_name = music_dir.get_next()

		music_dir.list_dir_end()
		print("已加载 %d 首音乐" % music_list.item_count)

func _get_character_base_dir(character_name: String) -> String:
	if _character_base_dir_cache.has(character_name):
		return _character_base_dir_cache[character_name]

	var base_dir := "res://assets/images/role/"
	if "_" in character_name:
		for part in character_name.split("_"):
			base_dir += part + "/"
	else:
		base_dir += character_name + "/"

	if DirAccess.open(base_dir) == null:
		return ""

	_character_base_dir_cache[character_name] = base_dir
	return base_dir

func _get_texture_thumbnail(texture: Texture2D) -> Texture2D:
	if not texture:
		return null
	var image := texture.get_image()
	if not image:
		return texture
	image.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)

func _get_character_thumbnail(character_name: String) -> Texture2D:
	if _character_thumbnail_cache.has(character_name):
		return _character_thumbnail_cache[character_name]

	var base_dir := _get_character_base_dir(character_name)
	if base_dir.is_empty():
		return null

	var base_path := base_dir + "base.png"
	if not ResourceLoader.exists(base_path):
		return null

	var texture := load(base_path) as Texture2D
	var thumbnail := _get_texture_thumbnail(texture)
	_character_thumbnail_cache[character_name] = thumbnail
	return thumbnail

func _get_expression_thumbnail(character_name: String, expression_name: String) -> Texture2D:
	var key := character_name + "|" + expression_name
	if _expression_thumbnail_cache.has(key):
		return _expression_thumbnail_cache[key]

	var base_dir := _get_character_base_dir(character_name)
	if base_dir.is_empty():
		return null

	var texture_path := base_dir + expression_name + ".png"
	if not ResourceLoader.exists(texture_path):
		return null

	var texture := load(texture_path) as Texture2D
	var thumbnail := _get_texture_thumbnail(texture)
	_expression_thumbnail_cache[key] = thumbnail
	return thumbnail

func _get_character_scene(character_name: String) -> PackedScene:
	if _character_scene_cache.has(character_name):
		return _character_scene_cache[character_name]

	var scene_path := "res://scenes/character/" + character_name + ".tscn"
	if not ResourceLoader.exists(scene_path):
		return null

	var scene := load(scene_path) as PackedScene
	if scene:
		_character_scene_cache[character_name] = scene
	return scene

func _get_character_expressions(character_name: String) -> Array[String]:
	var scene := _get_character_scene(character_name)
	if not scene:
		return []

	var instance := scene.instantiate()
	if not instance:
		return []

	var unique: Dictionary = {}
	var expressions: Array[String] = []
	var raw = instance.get("expression_list")
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) == TYPE_STRING:
				var expression_name := (entry as String).strip_edges()
				if not expression_name.is_empty() and not unique.has(expression_name):
					unique[expression_name] = true
					expressions.append(expression_name)

	instance.free()
	return expressions

func _load_expressions_list(character_name: String) -> void:
	if character_name.strip_edges().is_empty():
		_set_resource_panel_mode("none")
		return

	_set_resource_panel_mode("expression")
	characters_list.clear()

	var expressions := _get_character_expressions(character_name)
	expressions.sort()
	for expression_name in expressions:
		var icon := _get_expression_thumbnail(character_name, expression_name)
		characters_list.add_item(expression_name, icon)

func _on_character_selected(index: int):
	"""角色列表项被选中"""
	if not current_editing_field:
		return
	if current_editing_param == "character_name":
		var character_name = characters_list.get_item_text(index)
		current_editing_field.text = character_name
		# 触发text_changed信号以保存数据
		current_editing_field.text_changed.emit(character_name)

	elif current_editing_param == "expression":
		var expression_name = characters_list.get_item_text(index)
		current_editing_field.text = expression_name
		current_editing_field.text_changed.emit(expression_name)

func _on_background_selected(index: int):
	"""背景列表项被选中"""
	if current_editing_field and current_editing_param == "background_path":
		var bg_name = backgrounds_list.get_item_text(index)

		# 优先尝试 res://assets/images/bg/ 路径
		var full_path = "res://assets/images/bg/" + bg_name
		if not ResourceLoader.exists(full_path):
			# 如果不存在，尝试 res://assets/background/ 路径
			full_path = "res://assets/background/" + bg_name

		current_editing_field.text = full_path
		# 触发text_changed信号以保存数据
		current_editing_field.text_changed.emit(full_path)

func _on_music_selected(index: int):
	"""音乐列表项被选中"""
	if current_editing_field and current_editing_param == "music_path":
		var music_name = music_list.get_item_text(index)
		var full_path = "res://assets/audio/music/" + music_name
		current_editing_field.text = full_path
		# 触发text_changed信号以保存数据
		current_editing_field.text_changed.emit(full_path)

# ==================== 参数验证 ====================

func _validate_all_blocks() -> bool:
	"""验证所有脚本块，返回true表示无错误"""
	has_validation_errors = false

	for block in script_blocks:
		if not block.validate():
			has_validation_errors = true

	_update_buttons_state()
	_update_all_block_ui()
	return not has_validation_errors

func _update_buttons_state():
	"""根据验证状态更新按钮"""
	if has_validation_errors:
		run_button.disabled = true
		run_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
		export_button.disabled = true
		export_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		run_button.disabled = false
		run_button.modulate = Color.WHITE
		export_button.disabled = false
		export_button.modulate = Color.WHITE

func _update_all_block_ui():
	"""更新所有脚本块的UI显示（根据验证状态）"""
	for block in script_blocks:
		if block.ui_node:
			var block_button = _get_block_button(block)
			if block_button:
				if block.has_error:
					# 有错误：显示红色边框或背景
					block_button.modulate = Color(1.0, 0.5, 0.5)  # 红色调
					# 更新文本，添加错误标记
					var index = script_blocks.find(block) + 1
					block_button.text = "[%d] %s\n%s\n⚠ %s" % [index, _get_block_type_name(block.block_type), block.get_summary(), block.error_message]
				else:
					# 无错误：恢复正常颜色
					block_button.modulate = _get_block_color(block.block_type)
					# 更新文本，移除错误标记
					var index = script_blocks.find(block) + 1
					block_button.text = "[%d] %s\n%s" % [index, _get_block_type_name(block.block_type), block.get_summary()]

func load_project(path: String):
	"""加载工程"""
	project_path = path
	var config_file = FileAccess.open(path + "/project.json", FileAccess.READ)
	if config_file:
		var json = JSON.new()
		var parse_result = json.parse(config_file.get_as_text())
		if parse_result == OK:
			project_config = json.data
			project_name_label.text = project_config.get("project_name", "未命名工程")

			# 加载脚本块
			if project_config.has("scripts"):
				for script_data in project_config["scripts"]:
					_add_script_block_from_data(script_data)
		config_file.close()

func _create_block_palette():
	"""创建分类的脚本块工具箱"""
	var block_templates = {
		"对话": [
			{"type": BlockType.TEXT_ONLY, "name": "纯文本", "color": Color(0.4, 0.7, 1.0)},
			{"type": BlockType.DIALOG, "name": "对话", "color": Color(0.3, 0.6, 1.0)},
		],
		"角色": [
			{"type": BlockType.SHOW_CHARACTER_1, "name": "显示角色1", "color": Color(1.0, 0.6, 0.3)},
			{"type": BlockType.HIDE_CHARACTER_1, "name": "隐藏角色1", "color": Color(0.8, 0.4, 0.2)},
			{"type": BlockType.SHOW_CHARACTER_2, "name": "显示角色2", "color": Color(1.0, 0.7, 0.4)},
			{"type": BlockType.HIDE_CHARACTER_2, "name": "隐藏角色2", "color": Color(0.8, 0.5, 0.3)},
			{"type": BlockType.SHOW_CHARACTER_3, "name": "显示角色3", "color": Color(1.0, 0.8, 0.5)},
			{"type": BlockType.HIDE_CHARACTER_3, "name": "隐藏角色3", "color": Color(0.8, 0.6, 0.4)},
			{"type": BlockType.HIDE_ALL_CHARACTERS, "name": "隐藏所有", "color": Color(0.5, 0.5, 0.5)},
		],
		"场景": [
			{"type": BlockType.BACKGROUND, "name": "切换背景(渐变)", "color": Color(0.6, 1.0, 0.3)},
			{"type": BlockType.SHOW_BACKGROUND, "name": "显示背景", "color": Color(0.5, 0.95, 0.35)},
			{"type": BlockType.MUSIC, "name": "播放音乐", "color": Color(1.0, 0.3, 0.6)},
			{"type": BlockType.CHANGE_MUSIC, "name": "切换音乐", "color": Color(1.0, 0.4, 0.7)},
			{"type": BlockType.STOP_MUSIC, "name": "停止音乐", "color": Color(0.9, 0.25, 0.45)},
		],
	}

	# 为每个分类添加按钮
	for category in block_templates:
		var container: VBoxContainer = null
		match category:
			"对话": container = dialog_blocks_container
			"角色": container = character_blocks_container
			"场景": container = scene_blocks_container

		if container:
			# 使用HBoxContainer让按钮横向排列
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 5)
			container.add_child(hbox)

			for template in block_templates[category]:
				var block_button = Button.new()
				block_button.text = template["name"]
				block_button.custom_minimum_size = Vector2(80, 30)
				block_button.modulate = template["color"]
				block_button.pressed.connect(_on_palette_block_pressed.bind(template["type"]))
				hbox.add_child(block_button)

func _on_palette_block_pressed(block_type: BlockType):
	"""点击工具箱中的脚本块"""
	var block = ScriptBlock.new(block_type)
	script_blocks.append(block)
	_create_simplified_block_ui(block)
	_save_project()

func _create_simplified_block_ui(block: ScriptBlock, auto_select: bool = true):
	"""创建简化的脚本块UI（显示在右侧序列中）"""
	# 创建水平容器
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 50)

	# 创建线条样式背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.42, 0.39, 1.0, 0.6)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	hbox.add_theme_stylebox_override("panel", style)

	# 拖拽手柄（只从这里开始拖动，避免误触选择）
	var drag_handle = Button.new()
	drag_handle.name = "DragHandle"
	drag_handle.custom_minimum_size = Vector2(20, 50)
	drag_handle.text = "≡"
	drag_handle.focus_mode = Control.FOCUS_NONE
	drag_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_handle.tooltip_text = "拖拽调整顺序"
	drag_handle.modulate = Color(0.85, 0.85, 0.85)

	# 脚本块内容按钮（占大部分空间）
	var block_button = Button.new()
	block_button.name = "BlockButton"
	block_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	block_button.focus_mode = Control.FOCUS_NONE
	block_button.add_theme_font_size_override("font_size", 12)

	# 设置按钮文本
	var index = script_blocks.find(block) + 1
	block_button.text = "[%d] %s\n%s" % [index, _get_block_type_name(block.block_type), block.get_summary()]

	# 设置颜色
	block_button.modulate = _get_block_color(block.block_type)

	# 点击事件
	block_button.pressed.connect(_on_block_clicked.bind(block))

	# 拖拽排序：手柄负责开始拖动；块按钮/手柄都可作为放置目标
	drag_handle.set_drag_forwarding(
		Callable(self, "_get_drag_data_for_block").bind(drag_handle, block),
		Callable(self, "_can_drop_data_for_block").bind(block, drag_handle),
		Callable(self, "_drop_data_for_block").bind(block, drag_handle)
	)
	block_button.set_drag_forwarding(
		Callable(self, "_get_drag_data_noop").bind(block_button, block),
		Callable(self, "_can_drop_data_for_block").bind(block, block_button),
		Callable(self, "_drop_data_for_block").bind(block, block_button)
	)

	# 删除按钮
	var delete_button = Button.new()
	delete_button.name = "DeleteButton"
	delete_button.custom_minimum_size = Vector2(32, 50)
	delete_button.text = "🗑"
	delete_button.modulate = Color(1.0, 0.3, 0.3)  # 红色
	delete_button.pressed.connect(_on_delete_block.bind(block))

	# 添加到容器
	hbox.add_child(drag_handle)
	hbox.add_child(block_button)
	hbox.add_child(delete_button)

	block.ui_node = hbox
	script_sequence.add_child(hbox)

	# 可选择是否自动选中新添加的块
	if auto_select:
		_on_block_clicked(block)

func _get_block_button(block: ScriptBlock) -> Button:
	if not block or not block.ui_node:
		return null
	var node = block.ui_node.get_node_or_null("BlockButton")
	return node as Button

func _on_block_clicked(block: ScriptBlock):
	"""点击脚本块时"""
	# 如果正在预览，不响应点击
	if is_previewing:
		return

	# 取消之前选中的高亮
	current_editing_field = null
	current_editing_param = ""
	_set_resource_panel_mode("none")

	if selected_block and selected_block.ui_node:
		var prev_button = _get_block_button(selected_block)
		if prev_button:
			prev_button.add_theme_color_override("font_color", Color.WHITE)

	# 选中新的块
	selected_block = block
	if block.ui_node:
		var block_button = _get_block_button(block)
		if block_button:
			block_button.add_theme_color_override("font_color", Color.YELLOW)

	# 在Inspector中显示参数
	_show_inspector_for_block(block)

func _show_inspector_for_block(block: ScriptBlock):
	"""在Inspector中显示脚本块的详细参数"""
	# 清空Inspector
	for child in inspector_content.get_children():
		child.queue_free()

	# 添加标题
	var title_label = Label.new()
	title_label.text = _get_block_type_name(block.block_type)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_content.add_child(title_label)

	# 添加分隔线
	var separator = HSeparator.new()
	inspector_content.add_child(separator)

	# 根据类型添加参数控件
	match block.block_type:
		BlockType.TEXT_ONLY:
			_add_text_only_block_inspector(block)
		BlockType.DIALOG:
			_add_dialog_block_inspector(block)
		BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
			_add_show_character_inspector(block)
		BlockType.HIDE_CHARACTER_1, BlockType.HIDE_CHARACTER_2, BlockType.HIDE_CHARACTER_3, BlockType.HIDE_ALL_CHARACTERS:
			var hint = Label.new()
			hint.text = "此脚本块无需参数"
			inspector_content.add_child(hint)
		BlockType.BACKGROUND:
			_add_background_block_inspector(block)
		BlockType.SHOW_BACKGROUND:
			_add_show_background_block_inspector(block)
		BlockType.MUSIC, BlockType.CHANGE_MUSIC:
			_add_music_block_inspector(block)
		BlockType.STOP_MUSIC:
			var hint = Label.new()
			hint.text = "此脚本块无需参数"
			inspector_content.add_child(hint)
		BlockType.EXPRESSION:
			_add_expression_block_inspector(block)

func _add_text_only_block_inspector(block: ScriptBlock):
	"""添加纯文本块参数到Inspector"""
	# 文本内容
	var text_label = Label.new()
	text_label.text = "文本内容:"
	inspector_content.add_child(text_label)

	var text_input = TextEdit.new()
	text_input.custom_minimum_size = Vector2(0, 100)
	text_input.text = block.params.get("text", "")
	text_input.text_changed.connect(func():
		block.params["text"] = text_input.text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(text_input)

func _add_dialog_block_inspector(block: ScriptBlock):
	"""添加对话块参数到Inspector"""
	# 说话人
	var speaker_label = Label.new()
	speaker_label.text = "说话人:"
	inspector_content.add_child(speaker_label)

	var speaker_input = LineEdit.new()
	speaker_input.placeholder_text = "角色名称"
	speaker_input.text = block.params.get("speaker", "")
	speaker_input.text_changed.connect(func(text):
		block.params["speaker"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(speaker_input)

	# 对话内容
	var text_label = Label.new()
	text_label.text = "对话内容:"
	inspector_content.add_child(text_label)

	var text_input = TextEdit.new()
	text_input.custom_minimum_size = Vector2(0, 100)
	text_input.text = block.params.get("text", "")
	text_input.text_changed.connect(func():
		block.params["text"] = text_input.text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(text_input)

func _add_show_character_inspector(block: ScriptBlock):
	"""添加显示角色块参数到Inspector"""
	# 角色名
	var name_label = Label.new()
	name_label.text = "角色名称:"
	inspector_content.add_child(name_label)

	var name_input = LineEdit.new()
	name_input.text = block.params.get("character_name", "")
	name_input.text_changed.connect(func(text):
		block.params["character_name"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	# 当输入框获得焦点时，加载角色列表
	name_input.focus_entered.connect(func():
		current_editing_field = name_input
		current_editing_param = "character_name"
		_load_characters_list()
	)
	inspector_content.add_child(name_input)

	# 表情
	var expr_label = Label.new()
	expr_label.text = "表情（可选）:"
	inspector_content.add_child(expr_label)

	var expr_input = LineEdit.new()
	expr_input.placeholder_text = "留空"
	expr_input.text = block.params.get("expression", "")
	expr_input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()
	)
	expr_input.focus_entered.connect(func():
		current_editing_field = expr_input
		current_editing_param = "expression"
		_load_expressions_list(block.params.get("character_name", ""))
	)
	inspector_content.add_child(expr_input)

	# X位置
	var xpos_label = Label.new()
	xpos_label.text = "X位置 (0-1):"
	inspector_content.add_child(xpos_label)

	var xpos_input = LineEdit.new()
	xpos_input.placeholder_text = "0.5"
	xpos_input.text = str(block.params.get("x_position", 0.5))
	xpos_input.text_changed.connect(func(text):
		var value = text.to_float()
		block.params["x_position"] = value
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(xpos_input)

func _add_background_block_inspector(block: ScriptBlock):
	"""添加背景块参数到Inspector"""
	var label = Label.new()
	label.text = "背景资源路径:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.placeholder_text = "res://assets/..."
	input.text = block.params.get("background_path", "")
	input.text_changed.connect(func(text):
		block.params["background_path"] = text
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	# 当输入框获得焦点时，加载背景列表
	input.focus_entered.connect(func():
		current_editing_field = input
		current_editing_param = "background_path"
		_load_backgrounds_list()
	)
	inspector_content.add_child(input)

func _add_show_background_block_inspector(block: ScriptBlock):
	"""添加显示背景块参数到Inspector（支持渐变）"""
	var label = Label.new()
	label.text = "背景资源路径:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.placeholder_text = "res://assets/..."
	input.text = block.params.get("background_path", "")
	input.text_changed.connect(func(text):
		block.params["background_path"] = text
		_save_project()
		_validate_all_blocks()
	)
	input.focus_entered.connect(func():
		current_editing_field = input
		current_editing_param = "background_path"
		_load_backgrounds_list()
	)
	inspector_content.add_child(input)

	var fade_label = Label.new()
	fade_label.text = "渐变时间(秒，可选):"
	inspector_content.add_child(fade_label)

	var fade_input = LineEdit.new()
	fade_input.placeholder_text = "0"
	fade_input.text = str(block.params.get("fade_time", 0.0))
	fade_input.text_changed.connect(func(text):
		block.params["fade_time"] = text.to_float()
		_save_project()
		_validate_all_blocks()
	)
	inspector_content.add_child(fade_input)

func _add_music_block_inspector(block: ScriptBlock):
	"""添加音乐块参数到Inspector"""
	var label = Label.new()
	label.text = "音乐资源路径:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.placeholder_text = "res://assets/..."
	input.text = block.params.get("music_path", "")
	input.text_changed.connect(func(text):
		block.params["music_path"] = text
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	# 当输入框获得焦点时，加载音乐列表
	input.focus_entered.connect(func():
		current_editing_field = input
		current_editing_param = "music_path"
		_load_music_list()
	)
	inspector_content.add_child(input)

func _add_expression_block_inspector(block: ScriptBlock):
	"""添加表情块参数到Inspector"""
	var label = Label.new()
	label.text = "表情名称:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.text = block.params.get("expression", "")
	input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
	)
	inspector_content.add_child(input)

func _update_block_summary(block: ScriptBlock):
	"""更新脚本块的显示摘要"""
	if block.ui_node:
		var index = script_blocks.find(block) + 1
		var block_button = _get_block_button(block)
		if block_button:
			block_button.text = "[%d] %s\n%s" % [index, _get_block_type_name(block.block_type), block.get_summary()]

func _get_block_type_name(type: BlockType) -> String:
	"""获取脚本块类型名称"""
	match type:
		BlockType.TEXT_ONLY: return "纯文本"
		BlockType.DIALOG: return "对话"
		BlockType.SHOW_CHARACTER_1: return "显示角色1"
		BlockType.HIDE_CHARACTER_1: return "隐藏角色1"
		BlockType.SHOW_CHARACTER_2: return "显示角色2"
		BlockType.HIDE_CHARACTER_2: return "隐藏角色2"
		BlockType.SHOW_CHARACTER_3: return "显示角色3"
		BlockType.HIDE_CHARACTER_3: return "隐藏角色3"
		BlockType.HIDE_ALL_CHARACTERS: return "隐藏所有角色"
		BlockType.BACKGROUND: return "切换背景(渐变)"
		BlockType.MUSIC: return "播放音乐"
		BlockType.SHOW_BACKGROUND: return "显示背景"
		BlockType.CHANGE_MUSIC: return "切换音乐"
		BlockType.STOP_MUSIC: return "停止音乐"
		BlockType.EXPRESSION: return "更改表情"
		_: return "未知"

func _get_block_color(type: BlockType) -> Color:
	"""获取脚本块颜色"""
	match type:
		BlockType.TEXT_ONLY: return Color(0.4, 0.7, 1.0)
		BlockType.DIALOG: return Color(0.3, 0.6, 1.0)
		BlockType.SHOW_CHARACTER_1: return Color(1.0, 0.6, 0.3)
		BlockType.HIDE_CHARACTER_1: return Color(0.8, 0.4, 0.2)
		BlockType.SHOW_CHARACTER_2: return Color(1.0, 0.7, 0.4)
		BlockType.HIDE_CHARACTER_2: return Color(0.8, 0.5, 0.3)
		BlockType.SHOW_CHARACTER_3: return Color(1.0, 0.8, 0.5)
		BlockType.HIDE_CHARACTER_3: return Color(0.8, 0.6, 0.4)
		BlockType.HIDE_ALL_CHARACTERS: return Color(0.5, 0.5, 0.5)
		BlockType.BACKGROUND: return Color(0.6, 1.0, 0.3)
		BlockType.MUSIC: return Color(1.0, 0.3, 0.6)
		BlockType.SHOW_BACKGROUND: return Color(0.5, 0.95, 0.35)
		BlockType.CHANGE_MUSIC: return Color(1.0, 0.4, 0.7)
		BlockType.STOP_MUSIC: return Color(0.9, 0.25, 0.45)
		BlockType.EXPRESSION: return Color(0.8, 0.8, 0.3)
		_: return Color.WHITE

func _on_delete_block(block: ScriptBlock):
	"""删除脚本块"""
	script_blocks.erase(block)
	if block.ui_node:
		block.ui_node.queue_free()

	# 如果删除的是选中的块，清空Inspector
	if selected_block == block:
		selected_block = null
		current_editing_field = null
		current_editing_param = ""
		_set_resource_panel_mode("none")
		for child in inspector_content.get_children():
			child.queue_free()
		var hint = Label.new()
		hint.name = "EmptyHint"
		hint.text = "请在右侧选择一个脚本块"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inspector_content.add_child(hint)

	_save_project()

	# 更新所有块的序号
	_refresh_all_block_numbers()

func _refresh_all_block_numbers():
	"""刷新所有脚本块的序号显示"""
	for i in range(script_blocks.size()):
		var block = script_blocks[i]
		if block.ui_node:
			var block_button = _get_block_button(block)
			if block_button:
				block_button.text = "[%d] %s\n%s" % [i + 1, _get_block_type_name(block.block_type), block.get_summary()]

# ==================== 拖放功能 ====================

func _get_drag_data_noop(_at_position: Vector2, _source_control: Control, _block: ScriptBlock) -> Variant:
	return null

func _get_drag_data_noop_simple(_at_position: Vector2) -> Variant:
	return null

func _get_drag_data_for_block(_at_position: Vector2, source_control: Control, block: ScriptBlock) -> Variant:
	"""开始拖动脚本块时调用"""
	# 如果正在预览，不允许拖动
	if is_previewing:
		return null

	_hide_drop_placeholder()

	# 创建拖动预览（一个简化的按钮显示）
	var preview = Button.new()
	preview.text = _get_block_type_name(block.block_type)
	preview.modulate = _get_block_color(block.block_type)
	preview.custom_minimum_size = Vector2(200, 40)
	if source_control:
		source_control.set_drag_preview(preview)

	# 返回被拖动的块
	return block

func _can_drop_data_for_block(at_position: Vector2, data: Variant, target_block: ScriptBlock, target_control: Control) -> bool:
	"""检查是否可以在此位置放下"""
	if is_previewing:
		_hide_drop_placeholder()
		return false

	# 只接受ScriptBlock类型的数据
	if not (data is ScriptBlock):
		_hide_drop_placeholder()
		return false

	var dragged_block: ScriptBlock = data
	if dragged_block == target_block:
		_hide_drop_placeholder()
		return false

	var target_index = script_blocks.find(target_block)
	if target_index == -1:
		_hide_drop_placeholder()
		return false

	var insert_index = target_index
	if target_control and at_position.y > target_control.size.y * 0.5:
		insert_index = target_index + 1
	insert_index = clampi(insert_index, 0, script_blocks.size())

	_show_drop_placeholder(insert_index)
	return true

func _drop_data_for_block(at_position: Vector2, data: Variant, target_block: ScriptBlock, target_control: Control) -> void:
	"""在此位置放下脚本块，执行重排序"""
	_hide_drop_placeholder()

	if not data is ScriptBlock:
		return

	var dragged_block: ScriptBlock = data

	# 获取拖动块和目标块的索引
	var dragged_index = script_blocks.find(dragged_block)
	var target_index = script_blocks.find(target_block)

	if dragged_index == -1 or target_index == -1:
		return

	# 如果是同一个块，不做处理
	if dragged_index == target_index:
		return

	var insert_index = target_index
	if target_control and at_position.y > target_control.size.y * 0.5:
		insert_index = target_index + 1
	_reorder_block_to_index(dragged_block, insert_index)

	print("脚本块已重排序: 从索引 %d 移动到 %d" % [dragged_index, insert_index])

func _reorder_block_to_index(dragged_block: ScriptBlock, insert_index: int) -> void:
	var dragged_index := script_blocks.find(dragged_block)
	if dragged_index == -1:
		return

	insert_index = clampi(insert_index, 0, script_blocks.size())

	script_blocks.remove_at(dragged_index)
	if dragged_index < insert_index:
		insert_index -= 1

	insert_index = clampi(insert_index, 0, script_blocks.size())
	script_blocks.insert(insert_index, dragged_block)

	_rebuild_script_sequence_ui()
	_save_project()

func _can_drop_data_for_sequence(at_position: Vector2, data: Variant, target_control: Control) -> bool:
	if is_previewing:
		_hide_drop_placeholder()
		return false

	if not (data is ScriptBlock):
		_hide_drop_placeholder()
		return false

	var dragged_block: ScriptBlock = data
	var insert_index = _compute_insert_index_from_position(target_control, at_position)
	var dragged_index = script_blocks.find(dragged_block)
	if dragged_index == -1:
		_hide_drop_placeholder()
		return false

	# 拖到自身原位置附近时不显示占位
	if insert_index == dragged_index or insert_index == dragged_index + 1:
		_hide_drop_placeholder()
		return false

	_show_drop_placeholder(insert_index)
	return true

func _drop_data_for_sequence(at_position: Vector2, data: Variant, target_control: Control) -> void:
	_hide_drop_placeholder()

	if not (data is ScriptBlock):
		return

	var dragged_block: ScriptBlock = data
	var insert_index = _compute_insert_index_from_position(target_control, at_position)
	_reorder_block_to_index(dragged_block, insert_index)

func _compute_insert_index_from_position(target_control: Control, at_position: Vector2) -> int:
	# 把目标控件坐标换算到 script_sequence 的局部坐标（Control 没有 to_global/to_local）
	var target_rect := target_control.get_global_rect()
	var sequence_rect := script_sequence.get_global_rect()
	var y_local := (target_rect.position.y + at_position.y) - sequence_rect.position.y

	for i in range(script_blocks.size()):
		var ui_node: Control = script_blocks[i].ui_node
		if not is_instance_valid(ui_node):
			continue
		var midpoint := ui_node.position.y + ui_node.size.y * 0.5
		if y_local < midpoint:
			return i
	return script_blocks.size()

func _ensure_drop_placeholder() -> void:
	if is_instance_valid(drop_placeholder):
		return
	drop_placeholder = PanelContainer.new()
	drop_placeholder.name = "DropPlaceholder"
	drop_placeholder.custom_minimum_size = Vector2(0, 50)
	drop_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_placeholder.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.9, 0.2, 0.12)
	style.border_color = Color(1.0, 0.9, 0.2, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	drop_placeholder.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "放到这里"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drop_placeholder.add_child(label)

func _show_drop_placeholder(insert_index: int) -> void:
	_ensure_drop_placeholder()
	if not is_instance_valid(drop_placeholder):
		return
	if drop_placeholder.get_parent() != script_sequence:
		script_sequence.add_child(drop_placeholder)

	insert_index = clampi(insert_index, 0, script_blocks.size())
	drop_placeholder.visible = true
	script_sequence.move_child(drop_placeholder, insert_index)

func _hide_drop_placeholder() -> void:
	if not is_instance_valid(drop_placeholder):
		return
	drop_placeholder.visible = false
	if drop_placeholder.get_parent() == script_sequence:
		script_sequence.remove_child(drop_placeholder)

func _rebuild_script_sequence_ui():
	"""重建脚本序列的UI显示"""
	# 保存当前选中的块
	var previously_selected = selected_block

	_hide_drop_placeholder()

	# 清空script_sequence中的所有子节点
	for child in script_sequence.get_children():
		child.queue_free()

	# 按新顺序重新创建UI（不自动选中）
	for block in script_blocks:
		_create_simplified_block_ui(block, false)

	# 重新应用验证状态的UI显示（错误标记/颜色等）
	_update_all_block_ui()

	# 恢复之前的选中状态
	if previously_selected:
		_on_block_clicked(previously_selected)

func _add_script_block_from_data(data: Dictionary):
	"""从数据创建脚本块"""
	var block_type = data.get("type", 0)
	var block = ScriptBlock.new(block_type)
	block.params = data.get("params", {})
	script_blocks.append(block)
	_create_simplified_block_ui(block)

func _save_project():
	"""保存工程"""
	if project_path.is_empty():
		return

	# 保存脚本块数据
	var scripts_data = []
	for block in script_blocks:
		scripts_data.append({
			"type": block.block_type,
			"params": block.params
		})

	project_config["scripts"] = scripts_data

	var config_file = FileAccess.open(project_path + "/project.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(project_config, "\t"))
		config_file.close()

func _on_export_button_pressed():
	"""导出工程"""
	if script_blocks.is_empty():
		push_error("没有脚本块可导出")
		return

	var gd_code = _generate_gdscript()
	var tscn_code = _generate_scene()

	# 保存文件
	var export_path = project_path + "/export"
	var dir = DirAccess.open(project_path)
	if not dir.dir_exists("export"):
		dir.make_dir("export")

	var gd_file = FileAccess.open(export_path + "/story.gd", FileAccess.WRITE)
	if gd_file:
		gd_file.store_string(gd_code)
		gd_file.close()

	var tscn_file = FileAccess.open(export_path + "/story.tscn", FileAccess.WRITE)
	if tscn_file:
		tscn_file.store_string(tscn_code)
		tscn_file.close()

	print("导出成功: " + export_path)

func _generate_gdscript() -> String:
	"""生成GDScript代码"""
	var code = "extends Node2D\n\n"
	code += "@onready var novel_interface = $NovelInterface\n\n"
	code += "func _ready():\n"
	code += "\tnovel_interface.scene_completed.connect(_on_scene_completed)\n"
	code += "\t_start_story()\n\n"
	code += "func _start_story():\n"

	for i in range(script_blocks.size()):
		var block = script_blocks[i]
		match block.block_type:
			BlockType.TEXT_ONLY:
				var text = block.params.get("text", "")
				code += "\tawait novel_interface.show_text_only(\"%s\")\n" % text.c_escape()

			BlockType.DIALOG:
				var speaker = block.params.get("speaker", "")
				var text = block.params.get("text", "")
				code += "\tawait novel_interface.show_dialog(\"%s\", \"%s\")\n" % [text.c_escape(), speaker]

			BlockType.SHOW_CHARACTER_1:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.5)
				if expression.is_empty():
					code += "\tnovel_interface.show_character(\"%s\", \"\", %.2f)\n" % [char_name, x_pos]
				else:
					code += "\tnovel_interface.show_character(\"%s\", \"%s\", %.2f)\n" % [char_name, expression, x_pos]

			BlockType.HIDE_CHARACTER_1:
				code += "\tawait novel_interface.hide_character()\n"

			BlockType.SHOW_CHARACTER_2:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.5)
				if expression.is_empty():
					code += "\tnovel_interface.show_2nd_character(\"%s\", \"\", %.2f)\n" % [char_name, x_pos]
				else:
					code += "\tnovel_interface.show_2nd_character(\"%s\", \"%s\", %.2f)\n" % [char_name, expression, x_pos]

			BlockType.HIDE_CHARACTER_2:
				code += "\tawait novel_interface.hide_2nd_character()\n"

			BlockType.SHOW_CHARACTER_3:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.5)
				if expression.is_empty():
					code += "\tnovel_interface.show_3rd_character(\"%s\", \"\", %.2f)\n" % [char_name, x_pos]
				else:
					code += "\tnovel_interface.show_3rd_character(\"%s\", \"%s\", %.2f)\n" % [char_name, expression, x_pos]

			BlockType.HIDE_CHARACTER_3:
				code += "\tawait novel_interface.hide_3rd_character()\n"

			BlockType.HIDE_ALL_CHARACTERS:
				code += "\tawait novel_interface.hide_all_character()\n"

			BlockType.BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				code += "\tawait novel_interface.change_background(\"%s\")\n" % bg_path

			BlockType.MUSIC:
				var music_path = block.params.get("music_path", "")
				code += "\tnovel_interface.play_music(\"%s\")\n" % music_path

			BlockType.SHOW_BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				var fade_time = block.params.get("fade_time", 0.0)
				code += "\tawait novel_interface.show_background(\"%s\", %.2f)\n" % [bg_path, float(fade_time)]

			BlockType.CHANGE_MUSIC:
				var music_path = block.params.get("music_path", "")
				code += "\tawait novel_interface.change_music(\"%s\")\n" % music_path

			BlockType.STOP_MUSIC:
				code += "\tnovel_interface.stop_music()\n"
				code += "\tawait get_tree().process_frame\n"

			BlockType.EXPRESSION:
				var expression = block.params.get("expression", "")
				code += "\tawait novel_interface.change_expression(\"%s\")\n" % expression

	code += "\nfunc _on_scene_completed():\n"
	code += "\tprint(\"Story completed\")\n"

	return code

func _generate_scene() -> String:
	"""生成场景文件"""
	var scene = "[gd_scene load_steps=3 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"res://export/story.gd\" id=\"1_script\"]\n"
	scene += "[ext_resource type=\"PackedScene\" uid=\"uid://tfmmwjuxwu4x\" path=\"res://scenes/dialog/NovelInterface.tscn\" id=\"2_novel\"]\n\n"
	scene += "[node name=\"Story\" type=\"Node2D\"]\n"
	scene += "script = ExtResource(\"1_script\")\n\n"
	scene += "[node name=\"NovelInterface\" parent=\".\" instance=ExtResource(\"2_novel\")]\n"

	return scene

func _on_back_button_pressed():
	"""返回按钮"""
	_save_project()
	queue_free()

func _on_run_button_pressed():
	"""运行预览按钮"""
	if script_blocks.is_empty():
		push_error("没有脚本块可运行")
		return

	if not novel_interface:
		push_error("预览区域未初始化")
		return

	if is_previewing:
		# 如果正在预览，则停止预览
		_stop_preview()
		run_button.text = "▶ 运行"
	else:
		# 开始预览
		run_button.text = "■ 停止"
		_start_preview()

func _start_preview():
	"""开始预览脚本"""
	is_previewing = true

	# 启动预览协程
	_run_preview_script()

func _stop_preview():
	"""停止预览"""
	is_previewing = false

	# 恢复所有脚本块的正常颜色
	for b in script_blocks:
		if b.ui_node:
			var button = _get_block_button(b)
			if button:
				button.modulate = _get_block_color(b.block_type)

	# 恢复选中块的高亮
	if selected_block and selected_block.ui_node:
		var block_button = _get_block_button(selected_block)
		if block_button:
			block_button.add_theme_color_override("font_color", Color.YELLOW)

	# 预览结束后重置，准备下一次运行
	await get_tree().create_timer(0.1).timeout  # 短暂延迟确保清理完成
	_reset_preview_viewport()

func _reset_preview_viewport():
	"""重置预览视口，重新创建NovelInterface实例"""
	# 移除旧的NovelInterface
	if novel_interface:
		novel_interface.queue_free()
		novel_interface = null
		await get_tree().process_frame  # 等待删除完成

	# 重新创建NovelInterface实例
	var novel_interface_scene = load("res://scenes/dialog/NovelInterface.tscn")
	if novel_interface_scene:
		novel_interface = novel_interface_scene.instantiate()
		preview_viewport.add_child(novel_interface)
		await get_tree().process_frame  # 等待节点准备完成
		print("预览区域已重置")

func _run_preview_script():
	"""执行预览脚本"""
	for i in range(script_blocks.size()):
		if not is_previewing:
			break

		var block = script_blocks[i]

		# 高亮当前正在执行的脚本块
		_highlight_running_block(block)

		match block.block_type:
			BlockType.TEXT_ONLY:
				var text = block.params.get("text", "")
				await novel_interface.show_text_only(text)

			BlockType.DIALOG:
				var speaker = block.params.get("speaker", "")
				var text = block.params.get("text", "")
				await novel_interface.show_dialog(text, speaker)

			BlockType.SHOW_CHARACTER_1:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.5)
				if expression.is_empty():
					novel_interface.show_character(char_name, "", x_pos)
				else:
					novel_interface.show_character(char_name, expression, x_pos)

			BlockType.HIDE_CHARACTER_1:
				await novel_interface.hide_character()

			BlockType.SHOW_CHARACTER_2:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.5)
				if expression.is_empty():
					novel_interface.show_2nd_character(char_name, "", x_pos)
				else:
					novel_interface.show_2nd_character(char_name, expression, x_pos)

			BlockType.HIDE_CHARACTER_2:
				await novel_interface.hide_2nd_character()

			BlockType.SHOW_CHARACTER_3:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.5)
				if expression.is_empty():
					novel_interface.show_3rd_character(char_name, "", x_pos)
				else:
					novel_interface.show_3rd_character(char_name, expression, x_pos)

			BlockType.HIDE_CHARACTER_3:
				await novel_interface.hide_3rd_character()

			BlockType.HIDE_ALL_CHARACTERS:
				await novel_interface.hide_all_character()

			BlockType.BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				if not bg_path.is_empty():
					await novel_interface.change_background(bg_path)

			BlockType.SHOW_BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				var fade_time = block.params.get("fade_time", 0.0)
				if not bg_path.is_empty():
					await novel_interface.show_background(bg_path, float(fade_time))

			BlockType.MUSIC:
				var music_path = block.params.get("music_path", "")
				if not music_path.is_empty():
					novel_interface.play_music(music_path)

			BlockType.CHANGE_MUSIC:
				var music_path = block.params.get("music_path", "")
				if not music_path.is_empty():
					await novel_interface.change_music(music_path)

			BlockType.STOP_MUSIC:
				novel_interface.stop_music()
				await get_tree().process_frame

			BlockType.EXPRESSION:
				var expression = block.params.get("expression", "")
				if not expression.is_empty():
					await novel_interface.change_expression(expression)

	# 预览结束
	_stop_preview()
	run_button.text = "▶ 运行"
	print("预览完成")

func _highlight_running_block(block: ScriptBlock):
	"""高亮正在运行的脚本块"""
	# 先取消所有高亮
	for b in script_blocks:
		if b.ui_node:
			var button = _get_block_button(b)
			if button:
				button.modulate = _get_block_color(b.block_type)

	# 高亮当前块
	if block.ui_node:
		var button = _get_block_button(block)
		if button:
			button.modulate = Color.WHITE
