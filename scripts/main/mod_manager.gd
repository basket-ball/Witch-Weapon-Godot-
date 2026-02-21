extends Control

signal mods_changed

const MODS_FOLDER_PATH: String = "user://mods"
const MOD_CONFIG_FILENAME: String = "mod_config.json"
const MOD_ICON_FILENAME: String = "icon.png"

const ENTER_ANIMATION_DURATION: float = 0.22
const EXIT_ANIMATION_DURATION: float = 0.18

@onready var backdrop: ColorRect = $"Backdrop"
@onready var window_panel: Control = $"Window"
@onready var close_button: Button = $"Window/Margin/Root/Header/CloseButton"
@onready var mod_list: ItemList = $"Window/Margin/Root/Body/LeftColumn/ModList"
@onready var refresh_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/RefreshButton"
@onready var delete_button: Button = $"Window/Margin/Root/Body/LeftColumn/LeftButtons/DeleteButton"
@onready var icon_rect: TextureRect = $"Window/Margin/Root/Body/RightColumn/Icon"
@onready var mod_title_label: Label = $"Window/Margin/Root/Body/RightColumn/ModTitleLabel"
@onready var mod_info_text: RichTextLabel = $"Window/Margin/Root/Body/RightColumn/ModInfoText"
@onready var message_dialog: AcceptDialog = $"MessageDialog"
@onready var confirm_delete_dialog: ConfirmationDialog = $"ConfirmDeleteDialog"

var _mods: Array[Dictionary] = []
var _selected_index: int = -1
var _pending_delete_folder: String = ""
var _mods_dirty: bool = false
var _is_quitting: bool = false
var _is_exiting: bool = false


func _ready() -> void:
	mod_list.allow_reselect = true
	mod_list.select_mode = ItemList.SELECT_SINGLE

	if message_dialog:
		message_dialog.exclusive = false

	backdrop.gui_input.connect(_on_backdrop_gui_input)
	close_button.pressed.connect(_close)
	refresh_button.pressed.connect(_refresh_mods)
	delete_button.pressed.connect(_on_delete_pressed)
	confirm_delete_dialog.confirmed.connect(_on_confirm_delete)
	mod_list.item_selected.connect(_on_mod_selected)

	var root_window: Window = get_tree().root
	if root_window != null and root_window.has_signal("close_requested") and not root_window.close_requested.is_connected(_on_root_close_requested):
		root_window.close_requested.connect(_on_root_close_requested)

	_ensure_mods_folder_exists()
	_refresh_mods()
	_play_enter_animation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_game_quit()


func _on_root_close_requested() -> void:
	_request_game_quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _play_enter_animation() -> void:
	if backdrop:
		backdrop.modulate.a = 0.0
	if window_panel:
		window_panel.modulate.a = 0.0
		window_panel.scale = Vector2(0.98, 0.98)

	var tween := create_tween()
	tween.set_parallel(true)
	if backdrop:
		tween.tween_property(backdrop, "modulate:a", 1.0, ENTER_ANIMATION_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if window_panel:
		tween.tween_property(window_panel, "modulate:a", 1.0, ENTER_ANIMATION_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(window_panel, "scale", Vector2.ONE, ENTER_ANIMATION_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _close() -> void:
	if _is_exiting:
		return
	_is_exiting = true

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if backdrop:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if window_panel:
		window_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween := create_tween()
	tween.set_parallel(true)
	if backdrop:
		tween.tween_property(backdrop, "modulate:a", 0.0, EXIT_ANIMATION_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if window_panel:
		tween.tween_property(window_panel, "modulate:a", 0.0, EXIT_ANIMATION_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_property(window_panel, "scale", Vector2(0.97, 0.97), EXIT_ANIMATION_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if _mods_dirty:
			mods_changed.emit()
		queue_free()
	)


func _request_game_quit() -> void:
	if _is_quitting:
		return
	_is_quitting = true
	if message_dialog != null:
		message_dialog.hide()
	if confirm_delete_dialog != null:
		confirm_delete_dialog.hide()
	get_tree().quit()


func _exit_tree() -> void:
	if message_dialog != null:
		message_dialog.hide()
	if confirm_delete_dialog != null:
		confirm_delete_dialog.hide()


func _show_message(title: String, text: String) -> void:
	if _is_quitting or message_dialog == null:
		return
	message_dialog.title = title
	message_dialog.dialog_text = text
	if message_dialog.visible:
		return
	message_dialog.popup_centered()


func _ensure_mods_folder_exists() -> void:
	var user_dir: DirAccess = DirAccess.open("user://")
	if not user_dir:
		push_error("Cannot open user://")
		return
	if not user_dir.dir_exists("mods"):
		var err: int = user_dir.make_dir("mods")
		if err != OK:
			push_error("Cannot create user://mods")


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
	mod_title_label.text = "No mod selected"
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
		mod_info_text.text = "Invalid mod config: %s\n\nYou can delete this mod." % config_error


func _format_mod_info(folder_name: String, author: String, version: String, description: String) -> String:
	var lines: Array[String] = []
	lines.append("[b]Folder:[/b] %s" % folder_name)
	if not author.is_empty():
		lines.append("[b]Author:[/b] %s" % author)
	if not version.is_empty():
		lines.append("[b]Version:[/b] %s" % version)
	if not description.is_empty():
		lines.append("")
		lines.append("[b]Description:[/b] %s" % description)
	return "\n".join(lines)


func _get_mod_display_title(mod_data: Dictionary) -> String:
	var folder_name: String = str(mod_data.get("folder_name", ""))
	var config_ok: bool = bool(mod_data.get("config_ok", false))
	if not config_ok:
		return "%s (invalid config)" % folder_name

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
		return {"ok": false, "data": {}, "error": "Missing %s" % MOD_CONFIG_FILENAME}

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return {"ok": false, "data": {}, "error": "Cannot read config"}

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: int = json.parse(json_string)
	if parse_err != OK:
		return {"ok": false, "data": {}, "error": "JSON parse failed"}

	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "Config is not a JSON object"}

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
		_show_message("Notice", "Please select one mod first.")
		return

	var mod_data: Dictionary = _mods[_selected_index]
	var folder_name: String = str(mod_data.get("folder_name", ""))
	var display_title: String = _get_mod_display_title(mod_data)

	_pending_delete_folder = folder_name
	confirm_delete_dialog.dialog_text = "Delete mod '%s'?\n\nThis action cannot be undone." % display_title


	confirm_delete_dialog.popup_centered()


func _on_confirm_delete() -> void:
	if _pending_delete_folder.is_empty():
		return

	var folder_name: String = _pending_delete_folder
	_pending_delete_folder = ""

	var err: String = _delete_mod_folder(folder_name)
	if not err.is_empty():
		_show_message("Delete Failed", err)
		return

	_mods_dirty = true
	_show_message("Delete Success", "Deleted mod: %s" % folder_name)
	_refresh_mods()


func _delete_mod_folder(folder_name: String) -> String:
	if folder_name.is_empty() or folder_name.find("..") != -1 or folder_name.find("/") != -1 or folder_name.find("\\") != -1:
		return "Invalid mod folder name."

	var mod_path: String = MODS_FOLDER_PATH + "/" + folder_name
	if not _dir_exists(mod_path):
		return "Mod not found: %s" % folder_name

	var err: int = _delete_directory_recursive(mod_path)
	if err != OK:
		return "Delete failed (error %d)." % err

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
