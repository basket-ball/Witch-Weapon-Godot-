# 模组管理器：管理已安装的 user://mods 下的模组（查看信息 / 删除 / 导入 ZIP）

extends Control

signal mods_changed

const MODS_FOLDER_PATH: String = "user://mods"
const MOD_CONFIG_FILENAME: String = "mod_config.json"
const MOD_ICON_FILENAME: String = "icon.png"
const PLATFORM_MODS_LIST_PATH: String = "/api/mods"
const PLATFORM_MOD_DOWNLOAD_PATH_FORMAT: String = "/api/mods/%d/download"
const PLATFORM_MOD_DELETE_PATH_FORMAT: String = "/api/mods/%d"
const PLATFORM_MY_MODS_PATH: String = "/api/user/mods"
const PLATFORM_ADMIN_MODS_PATH: String = "/api/admin/mods"
const PLATFORM_ADMIN_MOD_REVIEW_PATH_FORMAT: String = "/api/admin/mods/%d/review"
const PLATFORM_ADMIN_MOD_DELETE_PATH_FORMAT: String = "/api/admin/mods/%d"

@onready var backdrop: ColorRect = $"Backdrop"
@onready var close_button: Button = $"Window/Margin/Root/Header/CloseButton"
@onready var mod_list: ItemList = $"Window/Margin/Root/Body/LeftColumn/ModList"
@onready var import_zip_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/ImportZipButton"
@onready var refresh_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/RefreshButton"
@onready var delete_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/DeleteButton"
@onready var left_buttons: HBoxContainer = $"Window/Margin/Root/Body/LeftColumn/LeftButtons"
@onready var icon_rect: TextureRect = $"Window/Margin/Root/Body/RightColumn/Icon"
@onready var mod_title_label: Label = $"Window/Margin/Root/Body/RightColumn/ModTitleLabel"
@onready var mod_info_text: RichTextLabel = $"Window/Margin/Root/Body/RightColumn/ModInfoText"
@onready var message_dialog: AcceptDialog = $"MessageDialog"
@onready var confirm_delete_dialog: ConfirmationDialog = $"ConfirmDeleteDialog"
@onready var import_zip_dialog: FileDialog = $"ImportZipDialog"

var _mods: Array[Dictionary] = []
var _selected_index: int = -1
var _pending_delete_folder: String = ""
var _mods_dirty: bool = false
var _online_button: Button = null
var _online_http: HTTPRequest = null
var _online_dialog: AcceptDialog = null
var _online_list: ItemList = null
var _online_sort: OptionButton = null
var _online_refresh_button: Button = null
var _online_download_button: Button = null
var _online_delete_button: Button = null
var _online_admin_approve_button: Button = null
var _online_admin_reject_button: Button = null
var _online_delete_confirm_dialog: ConfirmationDialog = null
var _online_mods: Array[Dictionary] = []
var _online_busy: bool = false
var _online_is_admin: bool = false
var _online_pending_delete_item: Dictionary = {}
var _is_quitting: bool = false


func _ready() -> void:
	mod_list.allow_reselect = true
	mod_list.select_mode = ItemList.SELECT_SINGLE

	backdrop.gui_input.connect(_on_backdrop_gui_input)
	close_button.pressed.connect(_close)
	refresh_button.pressed.connect(_refresh_mods)
	import_zip_button.pressed.connect(_open_import_dialog)
	import_zip_dialog.file_selected.connect(_on_import_zip_selected)
	delete_button.pressed.connect(_on_delete_pressed)
	confirm_delete_dialog.confirmed.connect(_on_confirm_delete)
	mod_list.item_selected.connect(_on_mod_selected)

	_online_http = HTTPRequest.new()
	_online_http.use_threads = false
	add_child(_online_http)

	_ensure_online_button()
	var root_window: Window = get_tree().root
	if root_window != null and root_window.has_signal("close_requested") and not root_window.close_requested.is_connected(_on_root_close_requested):
		root_window.close_requested.connect(_on_root_close_requested)
	_ensure_mods_folder_exists()
	_refresh_mods()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_game_quit()

func _on_root_close_requested() -> void:
	_request_game_quit()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	if _mods_dirty:
		mods_changed.emit()
	queue_free()

func _request_game_quit() -> void:
	if _is_quitting:
		return
	_is_quitting = true
	if _online_http != null:
		_online_http.cancel_request()
	if _online_delete_confirm_dialog != null:
		_online_delete_confirm_dialog.hide()
	if _online_dialog != null:
		_online_dialog.hide()
	if message_dialog != null:
		message_dialog.hide()
	get_tree().quit()

func _exit_tree() -> void:
	if _online_http != null:
		_online_http.cancel_request()
	if _online_delete_confirm_dialog != null:
		_online_delete_confirm_dialog.hide()
	if _online_dialog != null:
		_online_dialog.hide()
	if message_dialog != null:
		message_dialog.hide()


func _open_import_dialog() -> void:
	import_zip_dialog.popup_centered_ratio(0.8)


func _show_message(title: String, text: String) -> void:
	if _is_quitting:
		return
	if message_dialog == null:
		return
	message_dialog.exclusive = false
	message_dialog.title = title
	message_dialog.dialog_text = text
	if message_dialog.visible:
		return
	message_dialog.popup_centered()


func _ensure_mods_folder_exists() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")
	if not user_dir:
		push_error("无法打开 user:// 目录")
		return
	if not user_dir.dir_exists("mods"):
		var err: int = user_dir.make_dir("mods")
		if err != OK:
			push_error("无法创建 mods 目录: user://mods")


func _refresh_mods() -> void:
	_mods = _scan_mods()

	mod_list.clear()
	for i in range(_mods.size()):
		var mod_data: Dictionary = _mods[i]
		var display_title: String = _get_mod_display_title(mod_data)
		mod_list.add_item(display_title)
		mod_list.set_item_metadata(i, mod_data.get("folder_name", ""))

	_selected_index = -1
	_clear_details()


func _clear_details() -> void:
	delete_button.disabled = true
	icon_rect.texture = null
	mod_title_label.text = "未选择模组"
	mod_info_text.text = ""


func _on_mod_selected(index: int) -> void:
	_selected_index = index
	_update_details()


func _update_details() -> void:
	if _selected_index < 0 or _selected_index >= _mods.size():
		_clear_details()
		return

	var mod_data: Dictionary = _mods[_selected_index]
	delete_button.disabled = false

	var folder_name: String = str(mod_data.get("folder_name", ""))
	var config_ok: bool = bool(mod_data.get("config_ok", false))
	var config_error: String = str(mod_data.get("config_error", ""))
	var config: Dictionary = mod_data.get("config", {}) as Dictionary
	var icon_texture: Texture2D = mod_data.get("icon_texture", null) as Texture2D

	icon_rect.texture = icon_texture

	if config_ok:
		var title: String = str(config.get("title", folder_name))
		mod_title_label.text = title

		var author: String = str(config.get("author", ""))
		var version: String = str(config.get("version", ""))
		var description: String = str(config.get("description", ""))

		mod_info_text.text = _format_mod_info(folder_name, author, version, description)
	else:
		mod_title_label.text = folder_name
		mod_info_text.text = "该模组的配置文件无效：%s\n\n你可以选择删除该模组。" % config_error


func _format_mod_info(folder_name: String, author: String, version: String, description: String) -> String:
	var lines: Array[String] = []
	lines.append("[b]文件夹：[/b]%s" % folder_name)
	if not author.is_empty():
		lines.append("[b]作者：[/b]%s" % author)
	if not version.is_empty():
		lines.append("[b]版本：[/b]%s" % version)
	if not description.is_empty():
		lines.append("")
		lines.append("[b]描述：[/b]%s" % description)
	return "\n".join(lines)


func _get_mod_display_title(mod_data: Dictionary) -> String:
	var folder_name: String = str(mod_data.get("folder_name", ""))
	var config_ok: bool = bool(mod_data.get("config_ok", false))
	if not config_ok:
		return "%s（配置无效）" % folder_name

	var config: Dictionary = mod_data.get("config", {}) as Dictionary
	var title: String = str(config.get("title", folder_name))
	var version: String = str(config.get("version", ""))
	if not version.is_empty():
		return "%s v%s" % [title, version]
	return title


func _scan_mods() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var mods_dir: DirAccess = DirAccess.open(MODS_FOLDER_PATH)
	if not mods_dir:
		return result

	mods_dir.list_dir_begin()
	var folder_name: String = mods_dir.get_next()
	while folder_name != "":
		if mods_dir.current_is_dir() and not folder_name.begins_with("."):
			result.append(_load_mod_folder(folder_name))
		folder_name = mods_dir.get_next()
	mods_dir.list_dir_end()

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("folder_name", "")).nocasecmp_to(str(b.get("folder_name", ""))) < 0
	)
	return result


func _load_mod_folder(folder_name: String) -> Dictionary:
	var mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	var config_path: String = mod_path + "/" + MOD_CONFIG_FILENAME
	var icon_path: String = mod_path + "/" + MOD_ICON_FILENAME

	var config_result: Dictionary = _try_load_mod_config(config_path)
	if bool(config_result.get("ok", false)):
		_repair_story_scene_script_paths(mod_path, config_result.get("data", {}) as Dictionary)
	var icon_texture: Texture2D = _load_mod_icon(icon_path)

	return {
		"folder_name": folder_name,
		"mod_path": mod_path,
		"config_ok": bool(config_result.get("ok", false)),
		"config": config_result.get("data", {}),
		"config_error": str(config_result.get("error", "")),
		"icon_texture": icon_texture,
	}


func _try_load_mod_config(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return {"ok": false, "data": {}, "error": "缺少 %s" % MOD_CONFIG_FILENAME}

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return {"ok": false, "data": {}, "error": "无法读取配置文件"}

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: int = json.parse(json_string)
	if parse_err != OK:
		return {"ok": false, "data": {}, "error": "JSON 解析失败"}

	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "配置内容不是对象(JSON Dictionary)"}

	return {"ok": true, "data": json.data as Dictionary, "error": ""}


func _load_mod_icon(icon_path: String) -> Texture2D:
	if not FileAccess.file_exists(icon_path):
		return null
	var image: Image = Image.new()
	var err: int = image.load(icon_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _on_delete_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _mods.size():
		_show_message("提示", "请先选择一个模组。")
		return

	var mod_data: Dictionary = _mods[_selected_index]
	var folder_name: String = str(mod_data.get("folder_name", ""))
	var display_title: String = _get_mod_display_title(mod_data)

	_pending_delete_folder = folder_name
	confirm_delete_dialog.dialog_text = "确定删除模组「%s」吗？\n\n此操作不可撤销。" % display_title
	confirm_delete_dialog.popup_centered()


func _on_confirm_delete() -> void:
	if _pending_delete_folder.is_empty():
		return

	var folder_name: String = _pending_delete_folder
	_pending_delete_folder = ""

	var err: String = _delete_mod_folder(folder_name)
	if not err.is_empty():
		_show_message("删除失败", err)
		return

	_mods_dirty = true
	_show_message("删除成功", "已删除模组：%s" % folder_name)
	_refresh_mods()


func _delete_mod_folder(folder_name: String) -> String:
	if folder_name.is_empty() or folder_name.find("..") != -1 or folder_name.find("/") != -1 or folder_name.find("\\") != -1:
		return "模组文件夹名不合法。"

	var mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	if not _dir_exists(mod_path):
		return "模组不存在：%s" % folder_name

	var err: int = _delete_directory_recursive(mod_path)
	if err != OK:
		return "删除失败（错误码 %d）。" % err

	return ""


func _dir_exists(path: String) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(path)
	return DirAccess.open(abs_path) != null


func _delete_directory_recursive(path: String) -> int:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var dir: DirAccess = DirAccess.open(absolute_path)
	if not dir:
		return ERR_CANT_OPEN

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var file_path: String = absolute_path + "/" + file_name
		if dir.current_is_dir():
			var err_sub: int = _delete_directory_recursive(file_path)
			if err_sub != OK:
				dir.list_dir_end()
				return err_sub
		else:
			var err_remove: int = DirAccess.remove_absolute(file_path)
			if err_remove != OK:
				dir.list_dir_end()
				return err_remove
		file_name = dir.get_next()
	dir.list_dir_end()

	return DirAccess.remove_absolute(absolute_path)


func _on_import_zip_selected(zip_path: String) -> void:
	var result: Dictionary = _import_zip(zip_path)
	if bool(result.get("ok", false)):
		_mods_dirty = true
		_show_message("导入成功", str(result.get("message", "导入完成。")))
		_refresh_mods()
	else:
		_show_message("导入失败", str(result.get("message", "未知错误。")))


func _import_zip(zip_path: String) -> Dictionary:
	if not FileAccess.file_exists(zip_path):
		return {"ok": false, "message": "找不到 ZIP 文件。"}

	var zip: ZIPReader = ZIPReader.new()
	var err_open: int = zip.open(zip_path)
	if err_open != OK:
		return {"ok": false, "message": "无法打开 ZIP（错误码 %d）。" % err_open}

	var entries: PackedStringArray = zip.get_files()
	if entries.is_empty():
		return {"ok": false, "message": "ZIP 内没有任何文件。"}

	var config_entry: String = ""
	for entry in entries:
		if entry.ends_with("/") or entry.is_empty():
			continue
		if entry.get_file() == MOD_CONFIG_FILENAME:
			if not config_entry.is_empty():
				return {"ok": false, "message": "ZIP 内存在多个 %s，无法判断模组根目录。" % MOD_CONFIG_FILENAME}
			config_entry = entry

	if config_entry.is_empty():
		return {"ok": false, "message": "ZIP 内缺少 %s。" % MOD_CONFIG_FILENAME}

	# 仅允许：mod_config.json 或 <folder>/mod_config.json
	var config_parts: PackedStringArray = config_entry.split("/", false)
	if config_parts.size() > 2:
		return {"ok": false, "message": "%s 必须位于压缩包根目录或根目录下唯一文件夹中。" % MOD_CONFIG_FILENAME}

	var top_folder: String = ""
	if config_parts.size() == 2:
		top_folder = config_parts[0]

	var raw_folder_name: String = top_folder if not top_folder.is_empty() else zip_path.get_file().get_basename()
	var folder_name: String = _sanitize_folder_name(raw_folder_name)
	if folder_name.is_empty():
		var timestamp: int = int(Time.get_unix_time_from_system())
		folder_name = "mod_%d" % timestamp

	var dest_mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	if _dir_exists(dest_mod_path):
		return {"ok": false, "message": "已存在同名模组文件夹：%s\n请先删除或更换 ZIP 文件名后重试。" % folder_name}

	# 安全校验：禁止路径穿越
	for entry in entries:
		if not _is_safe_zip_entry(entry):
			return {"ok": false, "message": "ZIP 内包含非法路径，已拒绝导入。"}

	var user_dir: DirAccess = DirAccess.open("user://")
	if not user_dir:
		return {"ok": false, "message": "无法访问 user:// 目录。"}

	var err_mkdir: int = user_dir.make_dir_recursive("mods/" + folder_name)
	if err_mkdir != OK:
		return {"ok": false, "message": "无法创建目标目录（错误码 %d）。" % err_mkdir}

	var extracted_any: bool = false
	var prefix: String = top_folder + "/" if not top_folder.is_empty() else ""

	for entry in entries:
		if entry.is_empty():
			continue
		if not prefix.is_empty() and not entry.begins_with(prefix):
			continue

		var rel: String = entry
		if not prefix.is_empty():
			rel = entry.substr(prefix.length())

		if rel.is_empty():
			continue

		var dest_path: String = dest_mod_path + "/" + rel
		var base_dir: String = dest_path.get_base_dir()
		var rel_dir: String = base_dir.replace("user://", "")
		if not rel_dir.is_empty():
			var err_dir: int = user_dir.make_dir_recursive(rel_dir)
			if err_dir != OK:
				_delete_directory_recursive(dest_mod_path)
				return {"ok": false, "message": "创建目录失败（错误码 %d）。" % err_dir}

		if entry.ends_with("/"):
			continue

		var data: PackedByteArray = zip.read_file(entry)
		var out: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
		if not out:
			_delete_directory_recursive(dest_mod_path)
			return {"ok": false, "message": "写入文件失败：%s" % rel}
		out.store_buffer(data)
		out.close()
		extracted_any = true

	if not extracted_any:
		_delete_directory_recursive(dest_mod_path)
		return {"ok": false, "message": "没有可导入的文件。"}

	var dest_config_path: String = dest_mod_path + "/" + MOD_CONFIG_FILENAME
	var cfg_check: Dictionary = _try_load_mod_config(dest_config_path)
	if not bool(cfg_check.get("ok", false)):
		_delete_directory_recursive(dest_mod_path)
		return {"ok": false, "message": "导入后的配置文件无效：%s" % str(cfg_check.get("error", ""))}

	_repair_story_scene_script_paths(dest_mod_path, cfg_check.get("data", {}) as Dictionary)
	return {"ok": true, "message": "已导入到：%s" % dest_mod_path}


func _repair_story_scene_script_paths(mod_root: String, mod_config: Dictionary) -> void:
	var episodes_any: Variant = mod_config.get("episodes", {})
	if typeof(episodes_any) != TYPE_DICTIONARY:
		return

	var episodes: Dictionary = episodes_any as Dictionary
	for key_any in episodes.keys():
		var scene_rel: String = str(episodes.get(key_any, "")).strip_edges().replace("\\", "/")
		if scene_rel.is_empty():
			continue
		var scene_abs: String = mod_root + "/" + scene_rel
		if not FileAccess.file_exists(scene_abs):
			continue
		var expected_script_rel: String = scene_rel.get_file().get_basename() + ".gd"
		if expected_script_rel.is_empty():
			continue
		_rewrite_story_scene_script_path(scene_abs, expected_script_rel)

func _rewrite_story_scene_script_path(scene_path: String, expected_script_rel: String) -> void:
	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	var marker := "[ext_resource type=\"Script\""
	var marker_pos: int = text.find(marker)
	if marker_pos == -1:
		return

	var path_key := "path=\""
	var path_pos: int = text.find(path_key, marker_pos)
	if path_pos == -1:
		return

	var path_start: int = path_pos + path_key.length()
	var path_end: int = text.find("\"", path_start)
	if path_end == -1:
		return

	var current_path: String = text.substr(path_start, path_end - path_start)
	if current_path == expected_script_rel:
		return

	var rewritten: String = text.substr(0, path_start) + expected_script_rel + text.substr(path_end)
	var out: FileAccess = FileAccess.open(scene_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(rewritten)
	out.close()

func _is_safe_zip_entry(entry: String) -> bool:
	if entry.begins_with("/") or entry.begins_with("\\"):
		return false
	if entry.find(":") != -1:
		return false
	var parts: PackedStringArray = entry.split("/", false)
	for part in parts:
		if part == "..":
			return false
	return true


func _sanitize_folder_name(raw_name: String) -> String:
	var stripped: String = raw_name.strip_edges()
	if stripped.is_empty():
		return ""

	var out := PackedStringArray()
	for i in range(stripped.length()):
		var ch: String = stripped.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		var is_upper: bool = code >= 65 and code <= 90
		var is_lower: bool = code >= 97 and code <= 122
		if is_digit or is_upper or is_lower or ch == "_" or ch == "-":
			out.append(ch)
		else:
			out.append("_")

	var joined: String = "".join(out)
	while joined.find("__") != -1:
		joined = joined.replace("__", "_")
	joined = joined.strip_edges()
	joined = joined.trim_prefix("_").trim_suffix("_")

	if joined.length() > 32:
		joined = joined.substr(0, 32)

	return joined



func _ensure_online_button() -> void:
	if _online_button != null and is_instance_valid(_online_button):
		return
	if left_buttons == null:
		return

	var button := Button.new()
	button.text = "Online Mods"
	button.pressed.connect(_open_online_dialog)
	left_buttons.add_child(button)
	_online_button = button

func _open_online_dialog() -> void:
	if not has_node("/root/AuthManager"):
		_show_message("Notice", "AuthManager is missing.")
		return

	if not await AuthManager.ensure_valid_token():
		_show_message("Notice", "Please login before downloading online mods.")
		return

	# Refresh profile so role changes apply immediately.
	await AuthManager.fetch_profile()
	_refresh_online_admin_mode()

	_ensure_online_dialog()
	if _online_dialog == null:
		return

	_online_dialog.popup_centered_ratio(0.85)
	await _load_online_mods()

func _refresh_online_admin_mode() -> void:
	_online_is_admin = false
	if has_node("/root/AuthManager") and AuthManager.has_method("is_admin"):
		_online_is_admin = bool(AuthManager.is_admin())
	_update_online_admin_actions_state()

func _ensure_online_dialog() -> void:
	if _online_dialog != null and is_instance_valid(_online_dialog):
		return

	var dialog := AcceptDialog.new()
	dialog.exclusive = false
	dialog.title = "Online Mods"
	if dialog.has_signal("close_requested") and not dialog.close_requested.is_connected(_on_online_dialog_close_requested):
		dialog.close_requested.connect(_on_online_dialog_close_requested)
	dialog.ok_button_text = "Close"
	dialog.min_size = Vector2i(860, 520)
	add_child(dialog)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)

	var sort_label := Label.new()
	sort_label.text = "Sort"
	toolbar.add_child(sort_label)

	var sort_option := OptionButton.new()
	sort_option.add_item("Newest", 0)
	sort_option.add_item("Downloads", 1)
	sort_option.add_item("Rating", 2)
	sort_option.item_selected.connect(func(_idx: int):
		if _online_dialog and _online_dialog.visible:
			_load_online_mods()
	)
	toolbar.add_child(sort_option)
	_online_sort = sort_option

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_on_online_refresh_pressed)
	toolbar.add_child(refresh_btn)
	_online_refresh_button = refresh_btn

	var list := ItemList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_online_item_selected)
	root.add_child(list)
	_online_list = list

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root.add_child(footer)

	var approve_btn := Button.new()
	approve_btn.text = "Approve"
	approve_btn.pressed.connect(_on_online_approve_pressed)
	footer.add_child(approve_btn)
	_online_admin_approve_button = approve_btn

	var reject_btn := Button.new()
	reject_btn.text = "Reject"
	reject_btn.pressed.connect(_on_online_reject_pressed)
	footer.add_child(reject_btn)
	_online_admin_reject_button = reject_btn

	var delete_btn := Button.new()
	delete_btn.text = "Delete Upload"
	delete_btn.pressed.connect(_on_online_delete_pressed)
	footer.add_child(delete_btn)
	_online_delete_button = delete_btn

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	var download_btn := Button.new()
	download_btn.text = "Download & Install"
	download_btn.pressed.connect(_on_online_download_pressed)
	footer.add_child(download_btn)
	_online_download_button = download_btn

	var delete_confirm := ConfirmationDialog.new()
	delete_confirm.exclusive = false
	delete_confirm.title = "Delete Upload"
	delete_confirm.confirmed.connect(_on_online_delete_confirmed)
	dialog.add_child(delete_confirm)
	_online_delete_confirm_dialog = delete_confirm

	_online_dialog = dialog
	_update_online_admin_actions_state()

func _set_online_busy(busy: bool) -> void:
	_online_busy = busy
	if _online_refresh_button:
		_online_refresh_button.disabled = busy
	if _online_download_button:
		_online_download_button.disabled = busy
	if _online_sort:
		_online_sort.disabled = busy
	_update_online_admin_actions_state()

func _on_online_dialog_close_requested() -> void:
	if _online_http != null:
		_online_http.cancel_request()
	_set_online_busy(false)
	if _online_dialog != null:
		_online_dialog.hide()

func _update_online_admin_actions_state() -> void:
	var can_show: bool = _online_is_admin
	if _online_admin_approve_button:
		_online_admin_approve_button.visible = can_show
	if _online_admin_reject_button:
		_online_admin_reject_button.visible = can_show

	var selected_item: Dictionary = _get_selected_online_item()
	var can_delete: bool = (not _online_busy) and _can_delete_online_item(selected_item)
	if _online_delete_button:
		_online_delete_button.disabled = not can_delete

	if not can_show:
		if _online_admin_approve_button:
			_online_admin_approve_button.disabled = true
		if _online_admin_reject_button:
			_online_admin_reject_button.disabled = true
		return

	var can_review: bool = (not _online_busy) and _is_online_item_reviewable(selected_item)
	if _online_admin_approve_button:
		_online_admin_approve_button.disabled = not can_review
	if _online_admin_reject_button:
		_online_admin_reject_button.disabled = not can_review

func _get_selected_online_item() -> Dictionary:
	if _online_list == null:
		return {}
	var selected: PackedInt32Array = _online_list.get_selected_items()
	if selected.is_empty():
		return {}
	var index: int = int(selected[0])
	if index < 0 or index >= _online_mods.size():
		return {}
	return _online_mods[index]

func _on_online_item_selected(_index: int) -> void:
	_update_online_admin_actions_state()

func _is_online_item_reviewable(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var status: int = int(item.get("status", 1))
	if status == 0:
		return true
	return typeof(item.get("pending_update")) == TYPE_DICTIONARY

func _is_online_item_owned_by_current_user(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if bool(item.get("__mine", false)):
		return true
	var item_user_id: int = int(item.get("user_id", 0))
	var profile_id: int = 0
	if has_node("/root/AuthManager"):
		profile_id = int(AuthManager.profile.get("id", 0))
	return item_user_id > 0 and profile_id > 0 and item_user_id == profile_id

func _can_delete_online_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if _online_is_admin:
		return true
	return _is_online_item_owned_by_current_user(item)

func _on_online_approve_pressed() -> void:
	if not _online_is_admin:
		return
	var item: Dictionary = _get_selected_online_item()
	if not _is_online_item_reviewable(item):
		_show_message("Notice", "Please select a pending mod or pending update.")
		return
	await _review_online_mod(item, true)

func _on_online_reject_pressed() -> void:
	if not _online_is_admin:
		return
	var item: Dictionary = _get_selected_online_item()
	if not _is_online_item_reviewable(item):
		_show_message("Notice", "Please select a pending mod or pending update.")
		return
	await _review_online_mod(item, false)

func _review_online_mod(item: Dictionary, approve: bool) -> void:
	var mod_id: int = int(item.get("id", 0))
	if mod_id <= 0:
		_show_message("Failed", "Invalid mod id.")
		return

	var has_pending_update: bool = typeof(item.get("pending_update")) == TYPE_DICTIONARY
	var next_status: int = 1 if approve else 3
	var review_note: String = "审核通过" if approve else "审核拒绝"
	var payload: Dictionary = {
		"status": next_status,
		"review_note": review_note,
	}
	if has_pending_update:
		var pending: Dictionary = item.get("pending_update", {}) as Dictionary
		var pending_id: int = int(pending.get("id", 0))
		if pending_id > 0:
			payload["pending_update_id"] = pending_id

	_set_online_busy(true)
	var path: String = PLATFORM_ADMIN_MOD_REVIEW_PATH_FORMAT % mod_id
	var response: Dictionary = await _api_post_json_with_auth(path, payload)
	_set_online_busy(false)

	if bool(response.get("ok", false)):
		_show_message("Done", "Review submitted.")
		await _load_online_mods()
	else:
		_show_message("Failed", _extract_api_error(response))

func _on_online_delete_pressed() -> void:
	if _online_busy:
		return
	var item: Dictionary = _get_selected_online_item()
	if item.is_empty():
		_show_message("Notice", "Please select one online mod first.")
		return
	if not _can_delete_online_item(item):
		_show_message("Notice", "You can only delete your own uploads.")
		return
	_online_pending_delete_item = item.duplicate(true)
	var title: String = str(item.get("mod_name", ""))
	var mod_id: int = int(item.get("id", 0))
	if _online_delete_confirm_dialog:
		_online_delete_confirm_dialog.dialog_text = "Delete online mod \"%s\" (ID:%d)?\n\nThis action cannot be undone." % [title, mod_id]
		_online_delete_confirm_dialog.popup_centered()
	else:
		await _delete_online_mod(_online_pending_delete_item)

func _on_online_delete_confirmed() -> void:
	await _delete_online_mod(_online_pending_delete_item)

func _delete_online_mod(item: Dictionary) -> void:
	if item.is_empty():
		return
	var mod_id: int = int(item.get("id", 0))
	if mod_id <= 0:
		_show_message("Failed", "Invalid mod id.")
		return
	if not _can_delete_online_item(item):
		_show_message("Failed", "Permission denied for this mod.")
		return

	var delete_paths: Array[String] = []
	if _online_is_admin:
		delete_paths.append(PLATFORM_ADMIN_MOD_DELETE_PATH_FORMAT % mod_id)
	delete_paths.append(PLATFORM_MOD_DELETE_PATH_FORMAT % mod_id)

	_set_online_busy(true)
	var response: Dictionary = {}
	for path in delete_paths:
		response = await _api_delete_with_auth(path)
		if bool(response.get("ok", false)):
			break
		if not _is_api_path_not_found(response):
			break
	_set_online_busy(false)
	_online_pending_delete_item.clear()

	if bool(response.get("ok", false)):
		_show_message("Done", "Mod deleted.")
		await _load_online_mods()
	elif _is_api_path_not_found(response):
		_show_message("Failed", "Server API path not found. Please deploy the latest auth worker routes.")
	else:
		_show_message("Failed", _extract_api_error(response))

func _on_online_refresh_pressed() -> void:
	if _online_busy:
		return
	await _load_online_mods()

func _on_online_download_pressed() -> void:
	if _online_busy or _online_list == null:
		return

	var selected: PackedInt32Array = _online_list.get_selected_items()
	if selected.is_empty():
		_show_message("Notice", "Please select one online mod first.")
		return

	var index: int = int(selected[0])
	if index < 0 or index >= _online_mods.size():
		return

	var item: Dictionary = _online_mods[index]
	var mod_id: int = int(item.get("id", 0))
	var mod_name: String = str(item.get("mod_name", ""))
	var status: int = int(item.get("status", 1))
	if mod_id <= 0:
		_show_message("Notice", "Mod data is invalid (missing id).")
		return
	if status != 1:
		_show_message("Notice", "This mod is not published yet and cannot be downloaded.")
		return

	_set_online_busy(true)
	var result: Dictionary = await _download_online_mod(mod_id)
	_set_online_busy(false)

	if bool(result.get("ok", false)):
		_mods_dirty = true
		_refresh_mods()
		_show_message("Done", "Installed online mod: %s" % (mod_name if not mod_name.is_empty() else str(mod_id)))
	else:
		_show_message("Failed", str(result.get("message", "Unknown error")))

func _current_sort_key() -> String:
	if _online_sort == null:
		return "new"
	match _online_sort.get_selected_id():
		1:
			return "downloads"
		2:
			return "rating"
		_:
			return "new"

func _load_online_mods() -> void:
	if _online_list == null:
		return
	if _online_busy:
		return

	_set_online_busy(true)
	_online_list.clear()
	_online_mods.clear()

	if _online_is_admin:
		var admin_path: String = "%s?page=1&limit=50&sort=%s" % [PLATFORM_ADMIN_MODS_PATH, _current_sort_key()]
		var admin_response: Dictionary = await _api_get_json_with_auth(admin_path)
		if bool(admin_response.get("ok", false)):
			_set_online_busy(false)
			_online_mods = _extract_mods_from_response(admin_response)
			_refresh_online_list_rows()
			_update_online_admin_actions_state()
			return
		if _is_api_path_not_found(admin_response):
			pass
		else:
			_set_online_busy(false)
			_show_message("Load Failed", _extract_api_error(admin_response))
			return

	var path := "%s?page=1&limit=50&sort=%s" % [PLATFORM_MODS_LIST_PATH, _current_sort_key()]
	var response: Dictionary = await _api_get_json_with_auth(path)
	if not bool(response.get("ok", false)):
		_set_online_busy(false)
		_show_message("Load Failed", _extract_api_error(response))
		return

	var existing_ids: Dictionary = {}
	var my_mod_ids: Dictionary = {}
	var public_mods: Array[Dictionary] = _extract_mods_from_response(response)
	for item in public_mods:
		_online_mods.append(item)
		var mod_id: int = int(item.get("id", 0))
		if mod_id > 0:
			existing_ids[mod_id] = true

	# Also append my own unpublished uploads so uploader can see review status.
	var my_response: Dictionary = await _api_get_json_with_auth("%s?page=1&limit=50" % PLATFORM_MY_MODS_PATH)
	if bool(my_response.get("ok", false)):
		var my_mods: Array[Dictionary] = _extract_mods_from_response(my_response)
		for mine in my_mods:
			var mine_id: int = int(mine.get("id", 0))
			if mine_id > 0:
				my_mod_ids[mine_id] = true
			if mine_id > 0 and existing_ids.has(mine_id):
				continue
			var mine_copy: Dictionary = mine.duplicate(true)
			mine_copy["__mine"] = true
			_online_mods.append(mine_copy)
			if mine_id > 0:
				existing_ids[mine_id] = true
	if not my_mod_ids.is_empty():
		for i in range(_online_mods.size()):
			var row: Dictionary = _online_mods[i]
			var row_id: int = int(row.get("id", 0))
			if row_id > 0 and my_mod_ids.has(row_id):
				row["__mine"] = true
				_online_mods[i] = row

	_set_online_busy(false)
	_refresh_online_list_rows()
	_update_online_admin_actions_state()

func _extract_mods_from_response(response: Dictionary) -> Array[Dictionary]:
	var parsed: Variant = response.get("data")
	var payload: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		if typeof(parsed.get("data")) == TYPE_DICTIONARY:
			payload = parsed["data"]
		else:
			payload = parsed

	var output: Array[Dictionary] = []
	var mods_any: Variant = payload.get("mods", [])
	if typeof(mods_any) != TYPE_ARRAY:
		return output

	for item_any in mods_any:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		output.append(item_any as Dictionary)
	return output

func _refresh_online_list_rows() -> void:
	if _online_list == null:
		return
	_online_list.clear()
	for item in _online_mods:
		var title: String = str(item.get("mod_name", "untitled"))
		var author: String = str(item.get("author_name", ""))
		var version: String = str(item.get("version", ""))
		var downloads: int = int(item.get("download_count", 0))
		var status: int = int(item.get("status", 1))
		var is_mine: bool = bool(item.get("__mine", false))
		var has_pending_update: bool = typeof(item.get("pending_update")) == TYPE_DICTIONARY
		var prefix: String = ""

		if _online_is_admin:
			if status == 0:
				prefix = "[Review New] "
			elif has_pending_update:
				prefix = "[Review Update] "
		elif is_mine and status != 1:
			prefix = "[Mine %s] " % _status_text(status)
		elif status != 1:
			prefix = "[%s] " % _status_text(status)

		var row := "%s%s  v%s  |  %s  |  DL:%d" % [prefix, title, version, author, downloads]
		_online_list.add_item(row)

func _status_text(status: int) -> String:
	match status:
		0:
			return "Pending"
		1:
			return "Published"
		2:
			return "Taken Down"
		3:
			return "Rejected"
		_:
			return "Status %d" % status

func _download_online_mod(mod_id: int) -> Dictionary:
	if not await AuthManager.ensure_valid_token():
		return {"ok": false, "message": "Please login first."}

	var path := PLATFORM_MOD_DOWNLOAD_PATH_FORMAT % mod_id
	var response: Dictionary = await _api_get_binary_with_auth(path)
	if not bool(response.get("ok", false)):
		return {"ok": false, "message": _extract_api_error(response)}

	var bytes: PackedByteArray = response.get("bytes", PackedByteArray())
	if bytes.is_empty():
		return {"ok": false, "message": "Server returned empty file."}

	var user_dir: DirAccess = DirAccess.open("user://")
	if user_dir == null:
		return {"ok": false, "message": "Cannot access user directory."}
	if not user_dir.dir_exists("__mod_download_cache"):
		var mk_err: int = user_dir.make_dir("__mod_download_cache")
		if mk_err != OK and not user_dir.dir_exists("__mod_download_cache"):
			return {"ok": false, "message": "Cannot create cache directory."}

	var zip_path := "user://__mod_download_cache/mod_%d.zip" % mod_id
	var out: FileAccess = FileAccess.open(zip_path, FileAccess.WRITE)
	if out == null:
		return {"ok": false, "message": "Cannot write downloaded file."}
	out.store_buffer(bytes)
	out.close()

	var install_result: Dictionary = _import_zip(zip_path)
	var abs_zip: String = ProjectSettings.globalize_path(zip_path)
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(abs_zip)

	if not bool(install_result.get("ok", false)):
		return {"ok": false, "message": str(install_result.get("message", "Install failed"))}

	return {"ok": true}

func _api_get_json_with_auth(path: String) -> Dictionary:
	if _online_http == null:
		return {"ok": false, "status": 0, "error": "http_unavailable"}

	if not await AuthManager.ensure_valid_token():
		return {"ok": false, "status": 401, "error": "not_logged_in"}

	var headers := PackedStringArray(["Authorization: Bearer %s" % AuthManager.access_token])
	var result: Dictionary = await _http_get(path, headers)
	if int(result.get("status", 0)) == 401:
		var refreshed: Dictionary = await AuthManager.refresh_access_token()
		if bool(refreshed.get("ok", false)):
			headers = PackedStringArray(["Authorization: Bearer %s" % AuthManager.access_token])
			result = await _http_get(path, headers)
	return result

func _api_get_binary_with_auth(path: String) -> Dictionary:
	if _online_http == null:
		return {"ok": false, "status": 0, "error": "http_unavailable"}

	if not await AuthManager.ensure_valid_token():
		return {"ok": false, "status": 401, "error": "not_logged_in"}

	var headers := PackedStringArray(["Authorization: Bearer %s" % AuthManager.access_token])
	var result: Dictionary = await _http_get_binary(path, headers)
	if int(result.get("status", 0)) == 401:
		var refreshed: Dictionary = await AuthManager.refresh_access_token()
		if bool(refreshed.get("ok", false)):
			headers = PackedStringArray(["Authorization: Bearer %s" % AuthManager.access_token])
			result = await _http_get_binary(path, headers)
	return result

func _api_post_json_with_auth(path: String, payload: Dictionary) -> Dictionary:
	if _online_http == null:
		return {"ok": false, "status": 0, "error": "http_unavailable"}

	if not await AuthManager.ensure_valid_token():
		return {"ok": false, "status": 401, "error": "not_logged_in"}

	var headers := PackedStringArray([
		"Authorization: Bearer %s" % AuthManager.access_token,
		"Content-Type: application/json",
	])
	var result: Dictionary = await _http_json_request(path, HTTPClient.METHOD_POST, headers, JSON.stringify(payload))
	if int(result.get("status", 0)) == 401:
		var refreshed: Dictionary = await AuthManager.refresh_access_token()
		if bool(refreshed.get("ok", false)):
			headers = PackedStringArray([
				"Authorization: Bearer %s" % AuthManager.access_token,
				"Content-Type: application/json",
			])
			result = await _http_json_request(path, HTTPClient.METHOD_POST, headers, JSON.stringify(payload))
	return result

func _api_delete_with_auth(path: String) -> Dictionary:
	if _online_http == null:
		return {"ok": false, "status": 0, "error": "http_unavailable"}

	if not await AuthManager.ensure_valid_token():
		return {"ok": false, "status": 401, "error": "not_logged_in"}

	var headers := PackedStringArray(["Authorization: Bearer %s" % AuthManager.access_token])
	var result: Dictionary = await _http_json_request(path, HTTPClient.METHOD_DELETE, headers, "")
	if int(result.get("status", 0)) == 401:
		var refreshed: Dictionary = await AuthManager.refresh_access_token()
		if bool(refreshed.get("ok", false)):
			headers = PackedStringArray(["Authorization: Bearer %s" % AuthManager.access_token])
			result = await _http_json_request(path, HTTPClient.METHOD_DELETE, headers, "")
	return result

func _is_api_path_not_found(response: Dictionary) -> bool:
	if int(response.get("status", 0)) != 404:
		return false
	var msg: String = _extract_api_error(response).to_lower()
	return msg.find("api path not found") != -1

func _http_json_request(path: String, method: int, headers: PackedStringArray, body: String = "") -> Dictionary:
	var url := AuthManager.BASE_URL + path
	var err: int = _online_http.request(url, headers, method, body)
	if err != OK:
		return {"ok": false, "status": 0, "error": "request_failed_%s" % err, "bytes": PackedByteArray()}

	var completed: Array = await _online_http.request_completed
	var result_code: int = int(completed[0])
	var status_code: int = int(completed[1])
	var response_body: PackedByteArray = completed[3]
	var raw: String = response_body.get_string_from_utf8()
	var parsed: Variant = _try_parse_json(raw)
	var ok: bool = (result_code == HTTPRequest.RESULT_SUCCESS) and status_code >= 200 and status_code < 300

	return {
		"ok": ok,
		"status": status_code,
		"result": result_code,
		"data": parsed,
		"raw": raw,
		"bytes": response_body,
	}

func _http_get(path: String, headers: PackedStringArray) -> Dictionary:
	var url := AuthManager.BASE_URL + path
	var err: int = _online_http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		return {"ok": false, "status": 0, "error": "request_failed_%s" % err, "bytes": PackedByteArray()}

	var completed: Array = await _online_http.request_completed
	var result_code: int = int(completed[0])
	var status_code: int = int(completed[1])
	var body: PackedByteArray = completed[3]
	var raw: String = body.get_string_from_utf8()
	var parsed: Variant = _try_parse_json(raw)
	var ok: bool = (result_code == HTTPRequest.RESULT_SUCCESS) and status_code >= 200 and status_code < 300

	return {
		"ok": ok,
		"status": status_code,
		"result": result_code,
		"data": parsed,
		"raw": raw,
		"bytes": body,
	}

func _http_get_binary(path: String, headers: PackedStringArray) -> Dictionary:
	var url := AuthManager.BASE_URL + path
	var err: int = _online_http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		return {"ok": false, "status": 0, "error": "request_failed_%s" % err, "bytes": PackedByteArray()}

	var completed: Array = await _online_http.request_completed
	var result_code: int = int(completed[0])
	var status_code: int = int(completed[1])
	var body: PackedByteArray = completed[3]
	var raw: String = body.get_string_from_utf8()
	var parsed: Variant = _try_parse_json(raw)
	var ok: bool = (result_code == HTTPRequest.RESULT_SUCCESS) and status_code >= 200 and status_code < 300

	return {
		"ok": ok,
		"status": status_code,
		"result": result_code,
		"data": parsed,
		"raw": raw,
		"bytes": body,
	}

func _try_parse_json(raw: String) -> Variant:
	var trimmed: String = raw.strip_edges()
	if trimmed.is_empty():
		return null
	var first_char: String = trimmed.substr(0, 1)
	if first_char != "{" and first_char != "[":
		return null
	return JSON.parse_string(trimmed)

func _extract_api_error(response: Dictionary) -> String:
	if response.has("error"):
		return str(response["error"])
	var parsed: Variant = response.get("data")
	if typeof(parsed) == TYPE_DICTIONARY:
		var root: Dictionary = parsed
		if root.has("error"):
			return str(root["error"])
		if root.has("message") and str(root["message"]).strip_edges() != "":
			return str(root["message"])
		if typeof(root.get("data")) == TYPE_DICTIONARY:
			var payload: Dictionary = root["data"]
			if payload.has("error"):
				return str(payload["error"])
			if payload.has("message") and str(payload["message"]).strip_edges() != "":
				return str(payload["message"])
	return str(response.get("raw", "request_failed"))
