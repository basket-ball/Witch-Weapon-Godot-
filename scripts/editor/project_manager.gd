# =============================================================================
# Mod工程管理器 (Project Manager)
# =============================================================================
# 功能概述：
# 1. 显示所有已创建的mod工程
# 2. 新建mod工程
# 3. 打开选中的工程进入编辑器
# 4. 删除选中的工程
# 5. 返回到同人列表界面
# =============================================================================

extends Control

# 节点引用
@onready var project_list: VBoxContainer = $ProjectListContainer/ProjectScrollContainer/ProjectList
@onready var new_project_button: Button = $ButtonContainer/NewProjectButton
@onready var open_project_button: Button = $ButtonContainer/OpenProjectButton
@onready var delete_project_button: Button = $ButtonContainer/DeleteProjectButton
@onready var back_button: Button = $BackButton
@onready var new_project_dialog: Window = $NewProjectDialog
@onready var project_name_input: LineEdit = $NewProjectDialog/DialogContent/ProjectNameInput
@onready var empty_label: Label = get_node_or_null("EmptyLabel") as Label
@onready var search_input: LineEdit = get_node_or_null("SearchInput") as LineEdit
@onready var delete_confirm_dialog: ConfirmationDialog = get_node_or_null("DeleteConfirmDialog") as ConfirmationDialog

# 常量
const PROJECTS_PATH: String = "user://mod_projects"
const EDITOR_SCENE_PATH: String = "res://scenes/editor/mod_editor.tscn"
const UI_FONT: FontFile = preload("res://assets/gui/font/方正兰亭准黑_GBK.ttf")

# 变量
var selected_project: String = ""
var project_items: Array = []
var pending_delete_project: String = ""

var _row_style_normal: StyleBoxFlat
var _row_style_selected: StyleBoxFlat

func _ready():
	_init_row_styles()
	_load_projects()
	open_project_button.disabled = true
	delete_project_button.disabled = true

	if search_input:
		search_input.text_changed.connect(_on_search_text_changed)

	if delete_confirm_dialog:
		delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)

	_update_empty_state()
	_apply_search_filter(search_input.text if search_input else "")

func _init_row_styles() -> void:
	_row_style_normal = StyleBoxFlat.new()
	_row_style_normal.bg_color = Color(1, 1, 1, 0.04)
	_row_style_normal.corner_radius_top_left = 10
	_row_style_normal.corner_radius_top_right = 10
	_row_style_normal.corner_radius_bottom_right = 10
	_row_style_normal.corner_radius_bottom_left = 10
	_row_style_normal.content_margin_left = 12
	_row_style_normal.content_margin_right = 12
	_row_style_normal.content_margin_top = 10
	_row_style_normal.content_margin_bottom = 10

	_row_style_selected = StyleBoxFlat.new()
	_row_style_selected.bg_color = Color(0.35, 0.55, 1.0, 0.16)
	_row_style_selected.border_width_left = 1
	_row_style_selected.border_width_top = 1
	_row_style_selected.border_width_right = 1
	_row_style_selected.border_width_bottom = 1
	_row_style_selected.border_color = Color(0.5, 0.7, 1.0, 0.55)
	_row_style_selected.corner_radius_top_left = 10
	_row_style_selected.corner_radius_top_right = 10
	_row_style_selected.corner_radius_bottom_right = 10
	_row_style_selected.corner_radius_bottom_left = 10
	_row_style_selected.content_margin_left = 12
	_row_style_selected.content_margin_right = 12
	_row_style_selected.content_margin_top = 10
	_row_style_selected.content_margin_bottom = 10

func _update_empty_state() -> void:
	if not empty_label:
		return
	var is_empty := project_items.is_empty()
	empty_label.visible = is_empty
	if is_empty:
		empty_label.text = "还没有任何Mod工程\n点击下方“新建工程”开始"

func _on_search_text_changed(new_text: String) -> void:
	_apply_search_filter(new_text)

func _apply_search_filter(query: String) -> void:
	if not search_input and query.is_empty():
		return

	query = query.strip_edges()
	if query.is_empty():
		for item in project_items:
			var panel: Control = item.get("panel")
			if panel:
				panel.visible = true
		return

	var has_any_visible := false
	var query_lower := query.to_lower()
	for item in project_items:
		var panel: Control = item.get("panel")
		if not panel:
			continue
		var project_name: String = item.get("name", "")
		var is_match := project_name.to_lower().find(query_lower) != -1
		panel.visible = is_match
		has_any_visible = has_any_visible or is_match

	if not selected_project.is_empty():
		for item in project_items:
			if item.get("name", "") == selected_project:
				var selected_panel: Control = item.get("panel")
				if selected_panel and not selected_panel.visible:
					selected_project = ""
					open_project_button.disabled = true
					delete_project_button.disabled = true
				break

	if not has_any_visible:
		selected_project = ""
		open_project_button.disabled = true
		delete_project_button.disabled = true

func _on_row_gui_input(event: InputEvent, project_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_project_selected(project_name)
		if event.double_click:
			_on_open_project_button_pressed()

func _load_projects():
	"""加载所有工程"""
	# 清空现有列表
	for child in project_list.get_children():
		child.queue_free()
	project_items.clear()
	_update_empty_state()
	selected_project = ""
	pending_delete_project = ""
	open_project_button.disabled = true
	delete_project_button.disabled = true

	# 读取工程文件夹
	var dir = DirAccess.open(PROJECTS_PATH)
	if not dir:
		print("工程文件夹不存在")
		return

	dir.list_dir_begin()
	var project_name = dir.get_next()
	while project_name != "":
		if dir.current_is_dir() and not project_name.begins_with("."):
			_create_project_item(project_name)
		project_name = dir.get_next()
	dir.list_dir_end()

	_update_empty_state()
	_apply_search_filter(search_input.text if search_input else "")

func _create_project_item(project_name: String):
	"""创建工程列表项"""
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 56)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if _row_style_normal:
		row_panel.add_theme_stylebox_override("panel", _row_style_normal)
	row_panel.gui_input.connect(_on_row_gui_input.bind(project_name))

	var item_container := HBoxContainer.new()
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.alignment = BoxContainer.ALIGNMENT_CENTER
	item_container.add_theme_constant_override("separation", 12)

	# 工程名称标签
	var label = Label.new()
	label.text = project_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))

	# 选择按钮
	var select_button = Button.new()
	select_button.text = "选择"
	select_button.pressed.connect(_on_project_selected.bind(project_name))
	select_button.custom_minimum_size = Vector2(96, 38)
	select_button.add_theme_font_override("font", UI_FONT)
	select_button.add_theme_font_size_override("font_size", 18)

	item_container.add_child(label)
	item_container.add_child(select_button)
	row_panel.add_child(item_container)
	project_list.add_child(row_panel)
	project_items.append({"name": project_name, "panel": row_panel})

func _on_project_selected(project_name: String):
	"""选择工程"""
	selected_project = project_name
	open_project_button.disabled = false
	delete_project_button.disabled = false

	# 高亮选中项
	for item in project_items:
		var panel: Control = item.get("panel")
		if not panel:
			continue
		if item.name == project_name:
			if _row_style_selected:
				panel.add_theme_stylebox_override("panel", _row_style_selected)
		else:
			if _row_style_normal:
				panel.add_theme_stylebox_override("panel", _row_style_normal)

func _on_new_project_button_pressed():
	"""新建工程按钮点击"""
	project_name_input.text = ""
	new_project_dialog.visible = true
	new_project_dialog.popup_centered()

func _on_confirm_new_project():
	"""确认新建工程"""
	var project_name = project_name_input.text.strip_edges()

	if project_name.is_empty():
		push_error("工程名称不能为空")
		return

	# 检查工程名是否已存在
	var project_path = PROJECTS_PATH + "/" + project_name
	var dir = DirAccess.open(PROJECTS_PATH)
	if dir.dir_exists(project_name):
		push_error("工程名称已存在")
		return

	# 创建工程文件夹
	dir.make_dir(project_name)

	# 创建工程配置文件
	var config = {
		"project_name": project_name,
		"created_time": Time.get_datetime_string_from_system(),
		"scripts": []
	}

	var config_file = FileAccess.open(project_path + "/project.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(config, "\t"))
		config_file.close()

	new_project_dialog.visible = false
	_load_projects()
	print("创建工程成功: " + project_name)

func _on_cancel_new_project():
	"""取消新建工程"""
	new_project_dialog.visible = false

func _on_open_project_button_pressed():
	"""打开工程"""
	if selected_project.is_empty():
		return

	var editor_scene = load(EDITOR_SCENE_PATH)
	if not editor_scene:
		push_error("无法加载编辑器场景: " + EDITOR_SCENE_PATH)
		return

	var editor = editor_scene.instantiate()
	if editor is Control:
		editor.z_index = z_index + 1
		editor.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(editor)
	get_parent().move_child(editor, get_parent().get_child_count() - 1)

	# 传递工程路径
	if editor.has_method("load_project"):
		editor.load_project(PROJECTS_PATH + "/" + selected_project)

func _on_delete_project_button_pressed():
	"""删除工程"""
	if selected_project.is_empty():
		return

	pending_delete_project = selected_project
	if delete_confirm_dialog:
		delete_confirm_dialog.dialog_text = '确定删除工程"%s"？此操作不可撤销。' % pending_delete_project
		delete_confirm_dialog.popup_centered()
		return

	_on_delete_confirmed()

func _on_delete_confirmed() -> void:
	if pending_delete_project.is_empty():
		return

	var project_path = PROJECTS_PATH + "/" + pending_delete_project
	_delete_directory_recursive(project_path)
	print("删除工程成功: " + pending_delete_project)

	pending_delete_project = ""
	_load_projects()

func _delete_directory_recursive(path: String):
	"""递归删除目录"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path + "/" + file_name
		if dir.current_is_dir():
			_delete_directory_recursive(file_path)
		else:
			DirAccess.remove_absolute(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(path)

func _on_back_button_pressed():
	"""返回按钮"""
	queue_free()
