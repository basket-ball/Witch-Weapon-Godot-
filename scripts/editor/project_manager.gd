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
@onready var project_list: VBoxContainer = $WindowPanel/Margin/Content/Body/LeftPanel/ProjectScrollContainer/ProjectList
@onready var new_project_button: Button = $WindowPanel/Margin/Content/Footer/NewProjectButton
@onready var open_project_button: Button = $WindowPanel/Margin/Content/Footer/OpenProjectButton
@onready var delete_project_button: Button = $WindowPanel/Margin/Content/Footer/DeleteProjectButton
@onready var back_button: Button = $WindowPanel/Margin/Content/Header/BackButton
@onready var new_project_dialog: Window = $NewProjectDialog
@onready var project_name_input: LineEdit = $NewProjectDialog/DialogContent/ProjectNameInput
@onready var new_project_error_label: Label = get_node_or_null("NewProjectDialog/DialogContent/ErrorLabel") as Label
@onready var empty_label: Label = get_node_or_null("EmptyLabel") as Label
@onready var search_input: LineEdit = get_node_or_null("WindowPanel/Margin/Content/Header/SearchInput") as LineEdit
@onready var delete_confirm_dialog: ConfirmationDialog = get_node_or_null("DeleteConfirmDialog") as ConfirmationDialog
@onready var preview_file_dialog: FileDialog = get_node_or_null("PreviewFileDialog") as FileDialog
@onready var export_zip_dialog: FileDialog = get_node_or_null("ExportZipDialog") as FileDialog
@onready var install_mods_confirm_dialog: ConfirmationDialog = get_node_or_null("InstallModsConfirmDialog") as ConfirmationDialog

@onready var project_title_input: LineEdit = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/NameRow/ProjectTitleInput") as LineEdit
@onready var project_preview: TextureRect = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/NameRow/ProjectPreview") as TextureRect
@onready var project_desc_input: TextEdit = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/ProjectDescInput") as TextEdit
@onready var episode_list: ItemList = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/EpisodeList") as ItemList
@onready var add_episode_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/EpisodesHeader/AddEpisodeButton") as Button
@onready var delete_episode_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/EpisodesHeader/DeleteEpisodeButton") as Button
@onready var export_zip_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/ProjectActions/ExportZipButton") as Button
@onready var install_to_mods_button: Button = get_node_or_null("WindowPanel/Margin/Content/Body/RightPanel/DetailScroll/DetailForm/ProjectActions/InstallToModsButton") as Button

# 常量
const PROJECTS_PATH: String = "user://mod_projects"
const MODS_PATH: String = "user://mods"
const EDITOR_SCENE_PATH: String = "res://scenes/editor/mod_editor.tscn"
const UI_FONT: FontFile = preload("res://assets/gui/font/方正兰亭准黑_GBK.ttf")
const DEFAULT_PREVIEW_IMAGE: String = "res://assets/gui/main_menu/Story00_Main_01.png"
const PROJECT_PREVIEW_FILE: String = "preview/cover.png"
const PROJECT_PREVIEW_SIZE: Vector2i = Vector2i(206, 178)

# 与 mod_editor.gd 的 enum BlockType 保持一致（用于导出/打包）
enum BlockType {
	TEXT_ONLY,
	DIALOG,
	SHOW_CHARACTER_1,
	HIDE_CHARACTER_1,
	SHOW_CHARACTER_2,
	HIDE_CHARACTER_2,
	SHOW_CHARACTER_3,
	HIDE_CHARACTER_3,
	HIDE_ALL_CHARACTERS,
	BACKGROUND,
	MUSIC,
	EXPRESSION,
	SHOW_BACKGROUND,
	CHANGE_MUSIC,
	STOP_MUSIC,
	MOVE_CHARACTER_1_LEFT,
	MOVE_CHARACTER_2_LEFT,
	MOVE_CHARACTER_3_LEFT,
	CHANGE_EXPRESSION_1,
	CHANGE_EXPRESSION_2,
	CHANGE_EXPRESSION_3,
	HIDE_BACKGROUND,
	HIDE_BACKGROUND_FADE,
	CHARACTER_LIGHT_1,
	CHARACTER_LIGHT_2,
	CHARACTER_LIGHT_3,
	CHARACTER_DARK_1,
	CHARACTER_DARK_2,
	CHARACTER_DARK_3,
}

# 变量
var selected_project: String = ""
var project_items: Array = []
var pending_delete_project: String = ""

var _row_style_normal: StyleBoxFlat
var _row_style_selected: StyleBoxFlat

var _is_loading_details: bool = false
var _selected_episode_title: String = ""
var _selected_episode_path: String = ""
var _last_preview_dir: String = ""
var _pending_export_project: String = ""
var _pending_install_project: String = ""

func _ready():
	_ensure_projects_root()
	_init_row_styles()
	_load_projects()
	open_project_button.disabled = true
	delete_project_button.disabled = true
	if add_episode_button:
		add_episode_button.disabled = true
	if delete_episode_button:
		delete_episode_button.disabled = true

	if search_input:
		search_input.text_changed.connect(_on_search_text_changed)

	if new_project_button and not new_project_button.pressed.is_connected(_on_new_project_button_pressed):
		new_project_button.pressed.connect(_on_new_project_button_pressed)
	if open_project_button and not open_project_button.pressed.is_connected(_on_open_project_button_pressed):
		open_project_button.pressed.connect(_on_open_project_button_pressed)
	if delete_project_button and not delete_project_button.pressed.is_connected(_on_delete_project_button_pressed):
		delete_project_button.pressed.connect(_on_delete_project_button_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	if new_project_dialog:
		var confirm_button := new_project_dialog.get_node_or_null("DialogContent/ButtonRow/ConfirmButton") as Button
		if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_new_project):
			confirm_button.pressed.connect(_on_confirm_new_project)
		var cancel_button := new_project_dialog.get_node_or_null("DialogContent/ButtonRow/CancelButton") as Button
		if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_new_project):
			cancel_button.pressed.connect(_on_cancel_new_project)
		if project_name_input and not project_name_input.text_changed.is_connected(_clear_new_project_error):
			project_name_input.text_changed.connect(_clear_new_project_error)

	if delete_confirm_dialog:
		delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)

	if preview_file_dialog and not preview_file_dialog.file_selected.is_connected(_on_preview_file_selected):
		preview_file_dialog.file_selected.connect(_on_preview_file_selected)
	if export_zip_dialog and not export_zip_dialog.file_selected.is_connected(_on_export_zip_path_selected):
		export_zip_dialog.file_selected.connect(_on_export_zip_path_selected)
	if install_mods_confirm_dialog and not install_mods_confirm_dialog.confirmed.is_connected(_on_install_mods_confirmed):
		install_mods_confirm_dialog.confirmed.connect(_on_install_mods_confirmed)

	if project_title_input:
		project_title_input.text_changed.connect(_on_project_title_changed)
	if project_desc_input:
		project_desc_input.text_changed.connect(_on_project_desc_changed)
	if episode_list:
		episode_list.item_selected.connect(_on_episode_selected)
	if add_episode_button:
		add_episode_button.pressed.connect(_on_add_episode_pressed)
	if delete_episode_button:
		delete_episode_button.pressed.connect(_on_delete_episode_pressed)
	if project_preview and not project_preview.gui_input.is_connected(_on_project_preview_gui_input):
		project_preview.gui_input.connect(_on_project_preview_gui_input)
	if export_zip_button and not export_zip_button.pressed.is_connected(_on_export_zip_pressed):
		export_zip_button.pressed.connect(_on_export_zip_pressed)
	if install_to_mods_button and not install_to_mods_button.pressed.is_connected(_on_install_to_mods_pressed):
		install_to_mods_button.pressed.connect(_on_install_to_mods_pressed)

	_update_empty_state()
	_apply_search_filter(search_input.text if search_input else "")
	_show_empty_project_details()

func _show_new_project_error(message: String) -> void:
	if new_project_error_label:
		new_project_error_label.text = message
		new_project_error_label.visible = not message.is_empty()

func _clear_new_project_error() -> void:
	if new_project_error_label:
		new_project_error_label.text = ""
		new_project_error_label.visible = false

func _ensure_projects_root() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("mod_projects"):
		dir.make_dir("mod_projects")

func _ensure_mods_root() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("mods"):
		dir.make_dir("mods")

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
					_clear_project_selection()
				break

	if not has_any_visible:
		_clear_project_selection()

func _on_row_gui_input(event: InputEvent, project_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_project_selected(project_name)
		if event.double_click:
			_on_open_project_button_pressed()

func _load_projects():
	"""加载所有工程"""
	_ensure_projects_root()
	# 清空现有列表
	for child in project_list.get_children():
		child.queue_free()
	project_items.clear()
	_update_empty_state()
	_clear_project_selection()
	pending_delete_project = ""

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
	if selected_project.is_empty():
		_show_empty_project_details()

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
	select_button.custom_minimum_size = Vector2(56, 34)
	select_button.add_theme_font_override("font", UI_FONT)
	select_button.add_theme_font_size_override("font_size", 16)

	# 每个工程的导出/导入按钮
	var export_button = Button.new()
	export_button.text = "ZIP"
	export_button.pressed.connect(_on_export_zip_project_pressed.bind(project_name))
	export_button.custom_minimum_size = Vector2(52, 34)
	export_button.add_theme_font_override("font", UI_FONT)
	export_button.add_theme_font_size_override("font_size", 16)

	var install_button = Button.new()
	install_button.text = "Mods"
	install_button.pressed.connect(_on_install_to_mods_project_pressed.bind(project_name))
	install_button.custom_minimum_size = Vector2(60, 34)
	install_button.add_theme_font_override("font", UI_FONT)
	install_button.add_theme_font_size_override("font_size", 16)

	item_container.add_child(label)
	item_container.add_child(select_button)
	item_container.add_child(export_button)
	item_container.add_child(install_button)
	row_panel.add_child(item_container)
	project_list.add_child(row_panel)
	project_items.append({"name": project_name, "panel": row_panel})

func _on_project_selected(project_name: String):
	"""选择工程"""
	selected_project = project_name
	open_project_button.disabled = false
	delete_project_button.disabled = false
	if add_episode_button:
		add_episode_button.disabled = false

	# 高亮选中项
	for item in project_items:
		var panel: Control = item.get("panel")
		if not panel:
			continue
		if str(item.get("name", "")) == project_name:
			if _row_style_selected:
				panel.add_theme_stylebox_override("panel", _row_style_selected)
		else:
			if _row_style_normal:
				panel.add_theme_stylebox_override("panel", _row_style_normal)

	_load_project_details(project_name)

func _clear_project_selection() -> void:
	selected_project = ""
	open_project_button.disabled = true
	delete_project_button.disabled = true
	if add_episode_button:
		add_episode_button.disabled = true
	if delete_episode_button:
		delete_episode_button.disabled = true
	for item in project_items:
		var panel: Control = item.get("panel")
		if panel and _row_style_normal:
			panel.add_theme_stylebox_override("panel", _row_style_normal)
	_show_empty_project_details()

func _show_empty_project_details() -> void:
	if project_title_input:
		project_title_input.text = ""
		project_title_input.editable = false
	if project_desc_input:
		project_desc_input.text = ""
		project_desc_input.editable = false
	if project_preview:
		project_preview.texture = _load_texture_any(DEFAULT_PREVIEW_IMAGE)
	if episode_list:
		episode_list.clear()
	if delete_episode_button:
		delete_episode_button.disabled = true
	if add_episode_button:
		add_episode_button.disabled = true
	if export_zip_button:
		export_zip_button.disabled = true
	if install_to_mods_button:
		install_to_mods_button.disabled = true
	_selected_episode_title = ""
	_selected_episode_path = ""

func _get_project_root(project_name: String) -> String:
	return PROJECTS_PATH + "/" + project_name

func _get_mod_config_path(project_name: String) -> String:
	return _get_project_root(project_name) + "/mod_config.json"

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}

func _save_json_file(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _ensure_mod_config(project_name: String) -> Dictionary:
	var config_path := _get_mod_config_path(project_name)
	var config := _load_json_file(config_path)

	var root := _get_project_root(project_name)
	var legacy_project_json := _load_json_file(root + "/project.json")
	var legacy_title := str(legacy_project_json.get("project_name", project_name))
	var today := Time.get_date_string_from_system()

	if config.is_empty():
		config = {
			"mod_id": project_name,
			"title": legacy_title,
			"author": "",
			"version": "1.0.0",
			"description": "",
			"preview_image": DEFAULT_PREVIEW_IMAGE,
			"episodes": {},
			"custom_characters": [],
			"custom_music": {},
			"custom_images": {"backgrounds": [], "roles": []},
			"created_date": today,
			"last_updated": today
		}

		# 兼容旧项目：把根目录作为第1节
		if FileAccess.file_exists(root + "/project.json"):
			config["episodes"]["第1节"] = "export/story.tscn"

		_save_json_file(config_path, config)
	else:
		if not config.has("preview_image"):
			config["preview_image"] = DEFAULT_PREVIEW_IMAGE
		if not config.has("episodes") or typeof(config.get("episodes")) != TYPE_DICTIONARY:
			config["episodes"] = {}
		if not config.has("title"):
			config["title"] = legacy_title
		if not config.has("description"):
			config["description"] = ""
		_save_json_file(config_path, config)

	return config

func _load_project_details(project_name: String) -> void:
	_is_loading_details = true
	var config := _ensure_mod_config(project_name)

	if project_title_input:
		project_title_input.editable = true
		project_title_input.text = str(config.get("title", project_name))
	if project_desc_input:
		project_desc_input.editable = true
		project_desc_input.text = str(config.get("description", ""))

	if project_preview:
		var preview_path := str(config.get("preview_image", DEFAULT_PREVIEW_IMAGE))
		var resolved := _resolve_project_relative_path(project_name, preview_path)
		var tex := _load_texture_any(resolved)
		project_preview.texture = tex if tex else _load_texture_any(DEFAULT_PREVIEW_IMAGE)

	_reload_episode_list(config)
	_is_loading_details = false
	if export_zip_button:
		export_zip_button.disabled = false
	if install_to_mods_button:
		install_to_mods_button.disabled = false

func _reload_episode_list(config: Dictionary) -> void:
	_selected_episode_title = ""
	_selected_episode_path = ""
	if delete_episode_button:
		delete_episode_button.disabled = true
	if episode_list == null:
		return

	episode_list.clear()
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		return

	var titles: Array[String] = []
	for k in (episodes as Dictionary).keys():
		titles.append(str(k))
	titles.sort_custom(func(a, b) -> bool:
		var ia := _parse_episode_index(str(a))
		var ib := _parse_episode_index(str(b))
		if ia > 0 and ib > 0:
			return ia < ib
		return str(a) < str(b)
	)

	for title in titles:
		var path := str((episodes as Dictionary).get(title, ""))
		var idx := episode_list.add_item(title)
		episode_list.set_item_metadata(idx, path)

func _touch_config(project_name: String, config: Dictionary) -> void:
	config["last_updated"] = Time.get_date_string_from_system()
	_save_json_file(_get_mod_config_path(project_name), config)

func _resolve_project_relative_path(project_name: String, path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return DEFAULT_PREVIEW_IMAGE
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed
	if trimmed.find(":/") != -1 or trimmed.begins_with("/"):
		return trimmed
	return _get_project_root(project_name) + "/" + trimmed

func _load_texture_any(path: String) -> Texture2D:
	if path.begins_with("res://"):
		var res: Resource = load(path)
		return res as Texture2D
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

func _make_cover_thumbnail(src: Image, target_size: Vector2i) -> Image:
	var result := Image.new()
	if src == null:
		return result
	var w: int = src.get_width()
	var h: int = src.get_height()
	if w <= 0 or h <= 0:
		return result

	var scale_x: float = float(target_size.x) / float(w)
	var scale_y: float = float(target_size.y) / float(h)
	var scale: float = maxf(scale_x, scale_y)
	var resized_w: int = maxi(1, ceili(float(w) * scale))
	var resized_h: int = maxi(1, ceili(float(h) * scale))

	var resized: Image = src.duplicate() as Image
	if resized == null:
		return result
	resized.resize(resized_w, resized_h, Image.INTERPOLATE_LANCZOS)
	var crop_x: int = maxi(0, int(float(resized_w - target_size.x) / 2.0))
	var crop_y: int = maxi(0, int(float(resized_h - target_size.y) / 2.0))

	result = Image.create(target_size.x, target_size.y, false, resized.get_format())
	result.blit_rect(resized, Rect2i(crop_x, crop_y, target_size.x, target_size.y), Vector2i.ZERO)
	return result

func _on_project_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_project.is_empty():
			push_error("请先选择一个工程再设置预览图")
			return
		if preview_file_dialog == null:
			return
		preview_file_dialog.current_dir = _last_preview_dir if not _last_preview_dir.is_empty() else ProjectSettings.globalize_path(_get_project_root(selected_project))
		preview_file_dialog.popup_centered_ratio(0.8)

func _on_preview_file_selected(path: String) -> void:
	if selected_project.is_empty():
		return
	_last_preview_dir = path.get_base_dir()

	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("无法加载图片: " + path)
		return

	var thumb := _make_cover_thumbnail(img, PROJECT_PREVIEW_SIZE)
	if thumb.is_empty():
		push_error("图片处理失败: " + path)
		return

	var root_dir := DirAccess.open(_get_project_root(selected_project))
	if root_dir:
		root_dir.make_dir_recursive("preview")

	var save_path := _get_project_root(selected_project) + "/" + PROJECT_PREVIEW_FILE
	var save_err := thumb.save_png(save_path)
	if save_err != OK:
		push_error("无法保存预览图: " + save_path)
		return

	var config := _ensure_mod_config(selected_project)
	config["preview_image"] = PROJECT_PREVIEW_FILE
	_touch_config(selected_project, config)

	if project_preview:
		project_preview.texture = ImageTexture.create_from_image(thumb)

func _on_export_zip_pressed() -> void:
	if selected_project.is_empty():
		return
	_begin_export_zip_for_project(selected_project)

func _on_export_zip_project_pressed(project_name: String) -> void:
	_begin_export_zip_for_project(project_name)

func _begin_export_zip_for_project(project_name: String) -> void:
	if export_zip_dialog == null:
		return
	_pending_export_project = project_name
	var config := _ensure_mod_config(project_name)
	var mod_id: String = str(config.get("mod_id", project_name)).strip_edges()
	var file_name: String = _sanitize_folder_name(mod_id)
	if file_name.is_empty():
		file_name = _sanitize_folder_name(project_name)
	export_zip_dialog.current_file = "%s.zip" % file_name
	export_zip_dialog.popup_centered_ratio(0.8)

func _on_export_zip_path_selected(path: String) -> void:
	if _pending_export_project.is_empty():
		return
	var project_name: String = _pending_export_project
	_pending_export_project = ""
	var err := _export_project_zip(project_name, path)
	if err != OK:
		push_error("导出ZIP失败: " + str(err))

func _on_install_to_mods_pressed() -> void:
	if selected_project.is_empty():
		return
	_begin_install_to_mods_for_project(selected_project)

func _on_install_to_mods_project_pressed(project_name: String) -> void:
	_begin_install_to_mods_for_project(project_name)

func _begin_install_to_mods_for_project(project_name: String) -> void:
	_pending_install_project = project_name
	var target_folder := _get_mod_folder_name_for_project(project_name)
	if target_folder.is_empty():
		push_error("无法确定mod文件夹名称")
		_pending_install_project = ""
		return
	_ensure_mods_root()
	var target_path := MODS_PATH + "/" + target_folder
	if DirAccess.open(target_path) != null:
		if install_mods_confirm_dialog:
			install_mods_confirm_dialog.popup_centered()
			return
	_on_install_mods_confirmed()

func _on_install_mods_confirmed() -> void:
	if _pending_install_project.is_empty():
		return
	var project_name: String = _pending_install_project
	_pending_install_project = ""
	var target_folder := _get_mod_folder_name_for_project(project_name)
	if target_folder.is_empty():
		return
	_ensure_mods_root()
	var target_path := MODS_PATH + "/" + target_folder
	if DirAccess.open(target_path) != null:
		_delete_directory_recursive(target_path)
	var err := _build_mod_folder(project_name, MODS_PATH, target_folder)
	if err != OK:
		push_error("导入到Mods失败: " + str(err))

func _sanitize_folder_name(name: String) -> String:
	var s := name.strip_edges()
	s = s.replace("\\", "_").replace("/", "_").replace(":", "_").replace("*", "_")
	s = s.replace("?", "_").replace("\"", "_").replace("<", "_").replace(">", "_").replace("|", "_")
	return s

func _get_mod_folder_name_for_project(project_name: String) -> String:
	var config := _ensure_mod_config(project_name)
	var mod_id: String = str(config.get("mod_id", project_name)).strip_edges()
	var folder := _sanitize_folder_name(mod_id)
	if folder.is_empty():
		folder = _sanitize_folder_name(project_name)
	return folder

func _export_project_zip(project_name: String, zip_path: String) -> int:
	var folder := _get_mod_folder_name_for_project(project_name)
	if folder.is_empty():
		return ERR_INVALID_DATA

	var temp_root := "user://__mod_export_tmp"
	if DirAccess.open(temp_root) != null:
		_delete_directory_recursive(temp_root)
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir("__mod_export_tmp")

	var err := _build_mod_folder(project_name, temp_root, folder)
	if err != OK:
		return err

	err = _zip_folder(temp_root + "/" + folder, zip_path, folder)
	_delete_directory_recursive(temp_root)
	return err

func _zip_folder(source_folder: String, zip_path: String, root_in_zip: String) -> int:
	if not ClassDB.class_exists("ZIPPacker"):
		return ERR_UNAVAILABLE
	var zip: Object = ClassDB.instantiate("ZIPPacker")
	if zip == null:
		return ERR_UNAVAILABLE
	var err: int = int(zip.call("open", zip_path))
	if err != OK:
		return err

	var files: Array[String] = []
	_collect_files_recursive(source_folder, files)
	for file_path in files:
		var rel := file_path.substr(source_folder.length() + 1).replace("\\", "/")
		var inside := ("%s/%s" % [root_in_zip, rel]).replace("\\", "/")
		var s_err: int = int(zip.call("start_file", inside))
		if s_err != OK:
			zip.call("close")
			return s_err
		var bytes := _read_all_bytes(file_path)
		var w_err: int = int(zip.call("write_file", bytes))
		if w_err != OK:
			if zip.has_method("close_file"):
				zip.call("close_file")
			zip.call("close")
			return w_err
		if zip.has_method("close_file"):
			zip.call("close_file")

	zip.call("close")
	return OK

func _collect_files_recursive(path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path + "/" + name
		if dir.current_is_dir():
			_collect_files_recursive(full, out_files)
		else:
			out_files.append(full)
		name = dir.get_next()
	dir.list_dir_end()

func _read_all_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var len: int = f.get_length()
	var bytes: PackedByteArray = f.get_buffer(len)
	f.close()
	return bytes

func _build_mod_folder(project_name: String, out_root: String, mod_folder: String) -> int:
	var out_mod_root := out_root + "/" + mod_folder
	var root_dir := DirAccess.open(out_root)
	if root_dir == null:
		return ERR_CANT_OPEN
	if not root_dir.dir_exists(mod_folder):
		root_dir.make_dir(mod_folder)

	# 复制 mod_config.json
	var config := _ensure_mod_config(project_name)
	var normalized_episodes: Dictionary = {}
	var src_episodes: Dictionary = config.get("episodes", {})
	if typeof(src_episodes) == TYPE_DICTIONARY:
		for episode_title in (src_episodes as Dictionary).keys():
			var episode_idx := _parse_episode_index(str(episode_title))
			if episode_idx <= 0:
				continue
			normalized_episodes[str(episode_title)] = "story/ep%02d.tscn" % episode_idx
	config["episodes"] = normalized_episodes
	_save_json_file(out_mod_root + "/mod_config.json", config)

	# icon.png：优先使用工程预览图
	var preview_abs := ProjectSettings.globalize_path(_get_project_root(project_name) + "/" + PROJECT_PREVIEW_FILE)
	var icon_path: String = out_mod_root + "/icon.png"
	if FileAccess.file_exists(preview_abs):
		_copy_file(preview_abs, icon_path)
	else:
		# 注意：导出版本中 `Image.load("res://xxx.png")` 可能找不到源文件（资源被导入/重映射），
		# 这里改为按资源加载 Texture2D，再从 Texture2D 获取 Image。
		var tex := _load_texture_any(DEFAULT_PREVIEW_IMAGE)
		if tex != null:
			var img: Image = tex.get_image()
			if img != null and not img.is_empty():
				var thumb := _make_cover_thumbnail(img, PROJECT_PREVIEW_SIZE)
				if not thumb.is_empty():
					thumb.save_png(icon_path)

	# 复制可选资源目录（若存在）
	for folder_name in ["music", "images", "characters"]:
		var src: String = _get_project_root(project_name) + "/" + folder_name
		if DirAccess.open(src) != null:
			_copy_directory_recursive(src, out_mod_root + "/" + folder_name)

	# 导出剧情节到 story/
	var story_dir := DirAccess.open(out_mod_root)
	if story_dir:
		story_dir.make_dir("story")

	for episode_title in normalized_episodes.keys():
		var episode_idx := _parse_episode_index(str(episode_title))
		if episode_idx <= 0:
			continue

		var out_ep_name := "ep%02d" % episode_idx
		var src_scene_rel := ""
		if typeof(src_episodes) == TYPE_DICTIONARY:
			src_scene_rel = str((src_episodes as Dictionary).get(episode_title, ""))

		var episode_project := ""
		var root_candidate := _get_project_root(project_name) + "/project.json"
		var from_path := _extract_ep_name_from_path(src_scene_rel)
		var folder := from_path if not from_path.is_empty() else out_ep_name

		# 优先尝试根目录（兼容旧结构/导出结构）；不存在时再尝试 episodes/<ep>/project.json
		if FileAccess.file_exists(root_candidate) and (src_scene_rel.begins_with("export/") or episode_idx == 1):
			episode_project = root_candidate
		else:
			var candidate := _get_project_root(project_name) + "/episodes/%s/project.json" % folder
			if FileAccess.file_exists(candidate):
				episode_project = candidate
			elif FileAccess.file_exists(root_candidate):
				episode_project = root_candidate
			else:
				# 兼容老结构：episode 文件夹可能在根目录下
				candidate = _get_project_root(project_name) + "/%s/project.json" % folder
				if FileAccess.file_exists(candidate):
					episode_project = candidate

		var episode_data := _load_json_file(episode_project) if not episode_project.is_empty() else {}
		var scripts_any: Variant = episode_data.get("scripts", [])
		var scripts: Array = scripts_any as Array

		var gd_code := _generate_story_gdscript(scripts)
		var gd_path := out_mod_root + "/story/%s.gd" % out_ep_name
		_write_text_file(gd_path, gd_code)
		var tscn_code := _generate_story_scene(mod_folder, out_ep_name)
		var tscn_path := out_mod_root + "/story/%s.tscn" % out_ep_name
		_write_text_file(tscn_path, tscn_code)
	return OK

func _extract_ep_name_from_path(path: String) -> String:
	if path.is_empty():
		return ""
	var parts := path.replace("\\", "/").split("/")
	for part in parts:
		var s := str(part)
		if s.begins_with("ep") and s.length() == 4 and s.substr(2, 2).is_valid_int():
			return s
	var base := path.get_file().get_basename()
	if base.begins_with("ep") and base.length() == 4 and base.substr(2, 2).is_valid_int():
		return base
	return ""

func _copy_file(from_abs: String, to_path: String) -> void:
	var bytes := _read_all_bytes(from_abs)
	var f := FileAccess.open(to_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(bytes)
	f.close()

func _copy_directory_recursive(from_path: String, to_path: String) -> void:
	var dir := DirAccess.open(from_path)
	if dir == null:
		return
	var out_dir := DirAccess.open(to_path.get_base_dir())
	if out_dir:
		out_dir.make_dir_recursive(to_path.get_file())
	var dst_dir := DirAccess.open(to_path)
	if dst_dir == null:
		return
	dir.list_dir_begin()
	var name: String = str(dir.get_next())
	while name != "":
		if name == "." or name == "..":
			name = str(dir.get_next())
			continue
		var src: String = from_path + "/" + name
		var dst: String = to_path + "/" + name
		if dir.current_is_dir():
			_copy_directory_recursive(src, dst)
		else:
			var bytes := _read_all_bytes(src)
			var f := FileAccess.open(dst, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()
		name = str(dir.get_next())
	dir.list_dir_end()

func _write_text_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(content)
	f.close()

func _generate_story_scene(mod_folder: String, episode_name: String) -> String:
	var scene := "[gd_scene load_steps=3 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"res://mods/%s/story/%s.gd\" id=\"1_script\"]\n" % [mod_folder, episode_name]
	scene += "[ext_resource type=\"PackedScene\" path=\"res://scenes/dialog/NovelInterface.tscn\" id=\"2_novel\"]\n\n"
	scene += "[node name=\"Story\" type=\"Node2D\"]\n"
	scene += "script = ExtResource(\"1_script\")\n\n"
	scene += "[node name=\"NovelInterface\" parent=\".\" instance=ExtResource(\"2_novel\")]\n"
	return scene

func _generate_story_gdscript(scripts: Array) -> String:
	var code := "extends Node2D\n\n"
	code += "@onready var novel_interface = $NovelInterface\n\n"
	code += "func _ready():\n"
	code += "\tif novel_interface.has_method(\"wait_until_initialized\"):\n"
	code += "\t\tawait novel_interface.wait_until_initialized()\n"
	code += "\telse:\n"
	code += "\t\tawait get_tree().process_frame\n"
	code += "\t\tawait get_tree().process_frame\n"
	code += "\tnovel_interface.scene_completed.connect(_on_scene_completed)\n"
	code += "\t_start_story()\n\n"
	code += "func _start_story():\n"
	var wrote_any: bool = false

	for i in range(scripts.size()):
		var entry_any: Variant = scripts[i]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var block_type: int = int(entry.get("type", 0))
		var params_any: Variant = entry.get("params", {})
		var params: Dictionary = params_any as Dictionary

		match block_type:
			BlockType.TEXT_ONLY:
				var text: String = str(params.get("text", ""))
				code += "\tawait novel_interface.show_text_only(\"%s\")\n" % text.c_escape()
				wrote_any = true
			BlockType.DIALOG:
				var speaker: String = str(params.get("speaker", ""))
				var text: String = str(params.get("text", ""))
				code += "\tawait novel_interface.show_dialog(\"%s\", \"%s\")\n" % [text.c_escape(), speaker.c_escape()]
				wrote_any = true
			BlockType.SHOW_CHARACTER_1:
				var char_name: String = str(params.get("character_name", ""))
				var expression: String = str(params.get("expression", ""))
				var x_pos: float = float(params.get("x_position", 0.0))
				code += "\tnovel_interface.show_character(\"%s\", \"%s\", %.2f)\n" % [char_name.c_escape(), expression.c_escape(), x_pos]
				wrote_any = true
			BlockType.HIDE_CHARACTER_1:
				code += "\tawait novel_interface.hide_character()\n"
				wrote_any = true
			BlockType.SHOW_CHARACTER_2:
				var char_name: String = str(params.get("character_name", ""))
				var expression: String = str(params.get("expression", ""))
				var x_pos: float = float(params.get("x_position", 0.0))
				code += "\tnovel_interface.show_2nd_character(\"%s\", \"%s\", %.2f)\n" % [char_name.c_escape(), expression.c_escape(), x_pos]
				wrote_any = true
			BlockType.HIDE_CHARACTER_2:
				code += "\tawait novel_interface.hide_2nd_character()\n"
				wrote_any = true
			BlockType.SHOW_CHARACTER_3:
				var char_name: String = str(params.get("character_name", ""))
				var expression: String = str(params.get("expression", ""))
				var x_pos: float = float(params.get("x_position", 0.0))
				code += "\tnovel_interface.show_3rd_character(\"%s\", \"%s\", %.2f)\n" % [char_name.c_escape(), expression.c_escape(), x_pos]
				wrote_any = true
			BlockType.HIDE_CHARACTER_3:
				code += "\tawait novel_interface.hide_3rd_character()\n"
				wrote_any = true
			BlockType.MOVE_CHARACTER_1_LEFT:
				var to_xalign: float = float(params.get("to_xalign", -0.25))
				var duration: float = float(params.get("duration", 0.3))
				var enable_bc: bool = bool(params.get("enable_brightness_change", true))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_bc).to_lower(), expression.c_escape()]
				wrote_any = true
			BlockType.MOVE_CHARACTER_2_LEFT:
				var to_xalign: float = float(params.get("to_xalign", -0.25))
				var duration: float = float(params.get("duration", 0.3))
				var enable_bc: bool = bool(params.get("enable_brightness_change", true))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_2nd_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_bc).to_lower(), expression.c_escape()]
				wrote_any = true
			BlockType.MOVE_CHARACTER_3_LEFT:
				var to_xalign: float = float(params.get("to_xalign", -0.25))
				var duration: float = float(params.get("duration", 0.3))
				var enable_bc: bool = bool(params.get("enable_brightness_change", true))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_3rd_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_bc).to_lower(), expression.c_escape()]
				wrote_any = true
			BlockType.HIDE_ALL_CHARACTERS:
				code += "\tawait novel_interface.hide_all_characters()\n"
				wrote_any = true
			BlockType.BACKGROUND:
				var bg_path: String = str(params.get("background_path", ""))
				code += "\tawait novel_interface.change_background(\"%s\")\n" % bg_path.c_escape()
				wrote_any = true
			BlockType.SHOW_BACKGROUND:
				var bg_path: String = str(params.get("background_path", ""))
				var fade_time: float = float(params.get("fade_time", 0.0))
				code += "\tawait novel_interface.show_background(\"%s\", %.2f)\n" % [bg_path.c_escape(), fade_time]
				wrote_any = true
			BlockType.HIDE_BACKGROUND:
				code += "\tawait novel_interface.hide_background()\n"
				wrote_any = true
			BlockType.HIDE_BACKGROUND_FADE:
				code += "\tawait novel_interface.hide_background_with_fade()\n"
				wrote_any = true
			BlockType.MUSIC:
				var music_path: String = str(params.get("music_path", ""))
				code += "\tnovel_interface.play_music(\"%s\")\n" % music_path.c_escape()
				wrote_any = true
			BlockType.CHANGE_MUSIC:
				var music_path: String = str(params.get("music_path", ""))
				code += "\tawait novel_interface.change_music(\"%s\")\n" % music_path.c_escape()
				wrote_any = true
			BlockType.STOP_MUSIC:
				code += "\tnovel_interface.stop_music()\n"
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1:
				var expression: String = str(params.get("expression", "")).strip_edges()
				if not expression.is_empty():
					code += "\tnovel_interface.change_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.CHANGE_EXPRESSION_2:
				var expression: String = str(params.get("expression", "")).strip_edges()
				if not expression.is_empty():
					code += "\tnovel_interface.change_2nd_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.CHANGE_EXPRESSION_3:
				var expression: String = str(params.get("expression", "")).strip_edges()
				if not expression.is_empty():
					code += "\tnovel_interface.change_3rd_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true
			BlockType.CHARACTER_LIGHT_1:
				var duration: float = float(params.get("duration", 0.35))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]
				wrote_any = true
			BlockType.CHARACTER_LIGHT_2:
				var duration: float = float(params.get("duration", 0.35))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_2nd_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]
				wrote_any = true
			BlockType.CHARACTER_LIGHT_3:
				var duration: float = float(params.get("duration", 0.35))
				var expression: String = str(params.get("expression", ""))
				code += "\tawait novel_interface.character_3rd_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]
				wrote_any = true
			BlockType.CHARACTER_DARK_1:
				code += "\tawait novel_interface.character_dark()\n"
				wrote_any = true
			BlockType.CHARACTER_DARK_2:
				code += "\tawait novel_interface.character_2nd_dark()\n"
				wrote_any = true
			BlockType.CHARACTER_DARK_3:
				code += "\tawait novel_interface.character_3rd_dark()\n"
				wrote_any = true
			_:
				code += "\tawait get_tree().process_frame\n"
				wrote_any = true

	if not wrote_any:
		code += "\tpass\n"

	code += "\nfunc _on_scene_completed():\n"
	code += "\tprint(\"Story completed\")\n"
	return code

func _on_project_title_changed(new_text: String) -> void:
	if _is_loading_details:
		return
	if selected_project.is_empty():
		return
	var config := _ensure_mod_config(selected_project)
	config["title"] = new_text.strip_edges()
	_touch_config(selected_project, config)

func _on_project_desc_changed() -> void:
	if _is_loading_details:
		return
	if selected_project.is_empty():
		return
	if project_desc_input == null:
		return
	var config := _ensure_mod_config(selected_project)
	config["description"] = project_desc_input.text
	_touch_config(selected_project, config)

func _on_episode_selected(index: int) -> void:
	if episode_list == null:
		return
	_selected_episode_title = episode_list.get_item_text(index)
	var metadata: Variant = episode_list.get_item_metadata(index)
	_selected_episode_path = str(metadata) if typeof(metadata) == TYPE_STRING else ""
	if delete_episode_button:
		delete_episode_button.disabled = _selected_episode_title.is_empty()

func _parse_episode_index(title: String) -> int:
	if not (title.begins_with("第") and title.ends_with("节")):
		return -1
	var num_str := title.substr(1, title.length() - 2)
	if not num_str.is_valid_int():
		return -1
	return int(num_str)

func _episode_folder_from_title(title: String) -> String:
	var idx := _parse_episode_index(title)
	if idx <= 0:
		return ""
	return "ep%02d" % idx

func _on_add_episode_pressed() -> void:
	if selected_project.is_empty():
		return
	var config := _ensure_mod_config(selected_project)
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		episodes = {}
		config["episodes"] = episodes

	var next_index := 1
	while true:
		var title_candidate := "第%d节" % next_index
		var folder_candidate := "ep%02d" % next_index
		if not episodes.has(title_candidate) and DirAccess.open(_get_project_root(selected_project) + "/episodes/" + folder_candidate) == null:
			var title := title_candidate
			var folder := folder_candidate
			_add_episode_internal(config, episodes, title, folder)
			return
		next_index += 1

func _add_episode_internal(config: Dictionary, episodes: Dictionary, title: String, folder: String) -> void:
	var episode_root := _get_project_root(selected_project) + "/episodes/" + folder
	var dir := DirAccess.open(_get_project_root(selected_project))
	if dir:
		dir.make_dir_recursive("episodes/" + folder)

	var episode_config := {
		"project_name": "%s - %s" % [str(config.get("title", selected_project)), title],
		"created_time": Time.get_datetime_string_from_system(),
		"scripts": []
	}
	_save_json_file(episode_root + "/project.json", episode_config)

	episodes[title] = "story/%s.tscn" % folder
	_touch_config(selected_project, config)
	_reload_episode_list(config)

func _on_delete_episode_pressed() -> void:
	if selected_project.is_empty():
		return
	if _selected_episode_title.is_empty():
		return
	var config := _ensure_mod_config(selected_project)
	var episodes: Dictionary = config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		return

	var path := str(episodes.get(_selected_episode_title, ""))
	episodes.erase(_selected_episode_title)
	_touch_config(selected_project, config)
	_reload_episode_list(config)

	# 尝试删除对应的episodes子目录（按“第X节”命名约定）
	var folder_from_title := _episode_folder_from_title(_selected_episode_title)
	if not folder_from_title.is_empty():
		_delete_directory_recursive(_get_project_root(selected_project) + "/episodes/" + folder_from_title)
	elif path.begins_with("episodes/"):
		var parts := path.split("/")
		if parts.size() >= 2:
			_delete_directory_recursive(_get_project_root(selected_project) + "/episodes/" + parts[1])

func _on_new_project_button_pressed():
	"""新建工程按钮点击"""
	project_name_input.text = ""
	_clear_new_project_error()
	new_project_dialog.visible = true
	new_project_dialog.popup_centered()

func _on_confirm_new_project():
	"""确认新建工程"""
	var project_name = project_name_input.text.strip_edges()

	if project_name.is_empty():
		_show_new_project_error("工程名称不能为空")
		return

	_ensure_projects_root()

	# 检查工程名是否已存在
	var dir = DirAccess.open(PROJECTS_PATH)
	if not dir:
		_show_new_project_error("无法创建工程目录")
		return
	if dir.dir_exists(project_name):
		_show_new_project_error("工程已存在，请换一个名称")
		return

	# 创建工程文件夹
	dir.make_dir(project_name)

	# 创建章节配置文件（mod_config.json）+ 默认第1节
	var mod_config := _ensure_mod_config(project_name)
	var folder := "ep01"
	var episode_root := _get_project_root(project_name) + "/episodes/" + folder
	var root_dir := DirAccess.open(_get_project_root(project_name))
	if root_dir:
		root_dir.make_dir_recursive("episodes/" + folder)
	var episode_config := {
		"project_name": "%s - 第1节" % str(mod_config.get("title", project_name)),
		"created_time": Time.get_datetime_string_from_system(),
		"scripts": []
	}
	_save_json_file(episode_root + "/project.json", episode_config)
	var episodes: Dictionary = mod_config.get("episodes", {})
	if typeof(episodes) != TYPE_DICTIONARY:
		episodes = {}
	mod_config["episodes"] = episodes
	episodes["第1节"] = "story/%s.tscn" % folder
	_touch_config(project_name, mod_config)

	new_project_dialog.visible = false
	_load_projects()
	print("创建工程成功: " + project_name)

func _on_cancel_new_project():
	"""取消新建工程"""
	new_project_dialog.visible = false

func _on_open_project_button_pressed():
	"""打开选中剧情节"""
	if selected_project.is_empty():
		return
	if _selected_episode_title.is_empty() and episode_list and episode_list.item_count > 0:
		episode_list.select(0)
		_on_episode_selected(0)
	if _selected_episode_path.is_empty():
		push_error("请先选择一个剧情节")
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

	# 传递工程路径（剧情节工程目录）
	if editor.has_method("load_project"):
		var root := _get_project_root(selected_project)
		var episode_dir := root
		var folder := _episode_folder_from_title(_selected_episode_title)
		if not folder.is_empty():
			var candidate := root + "/episodes/" + folder
			if FileAccess.file_exists(candidate + "/project.json"):
				episode_dir = candidate
		elif _selected_episode_path.begins_with("episodes/"):
			var parts := _selected_episode_path.split("/")
			if parts.size() >= 2:
				var candidate := root + "/episodes/" + parts[1]
				if FileAccess.file_exists(candidate + "/project.json"):
					episode_dir = candidate
		elif _selected_episode_path.begins_with("export/"):
			episode_dir = root
		else:
			push_error("该剧情节不是由编辑器创建，暂不支持打开: " + _selected_episode_path)
			return
		editor.load_project(episode_dir)

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
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir = DirAccess.open(absolute_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var file_path = absolute_path + "/" + file_name
		if dir.current_is_dir():
			_delete_directory_recursive(file_path)
		else:
			DirAccess.remove_absolute(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(absolute_path)

func _on_back_button_pressed():
	"""返回按钮"""
	queue_free()
