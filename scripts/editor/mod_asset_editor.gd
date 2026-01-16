extends Control

enum Mode { BACKGROUND, MUSIC, CHARACTER, TITLE }

const UI_FONT: FontFile = preload("res://assets/gui/font/方正兰亭准黑_GBK.ttf")
const ASSETS_FILENAME: String = "custom_assets.json"
const BG_VIEW_SIZE: Vector2i = Vector2i(1280, 720) # 游戏视口
const BG_CANVAS_SIZE: Vector2i = Vector2i(1024, 576) # NovelInterface.tscn 的 BG(Sprite2D) 纹理基准尺寸（配合 scale=1.25）
const BG_COMPILED_DIR_REL: String = "images/bg_compiled"

@onready var back_button: Button = $TopBar/BackButton
@onready var save_button: Button = $TopBar/SaveButton
@onready var unsaved_label: Label = $TopBar/UnsavedLabel
@onready var title_label: Label = $TopBar/TitleLabel
@onready var project_label: Label = $TopBar/ProjectLabel

@onready var mode_tabs: TabBar = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/ModeTabs
@onready var primary_button: Button = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/ActionRow/PrimaryButton
@onready var delete_button: Button = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/ActionRow/DeleteButton

@onready var character_action_row: HBoxContainer = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharacterActionRow
@onready var import_base_button: Button = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharacterActionRow/ImportBaseButton
@onready var add_expression_button: Button = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharacterActionRow/AddExpressionButton
@onready var delete_expression_button: Button = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharacterActionRow/DeleteExpressionButton

@onready var resource_list: VBoxContainer = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/ResourceScroll/ResourceList

@onready var inspector_title: Label = $MainContainer/LeftPanel/InspectorPanel/InspectorContainer/InspectorTitle
@onready var inspector_list: VBoxContainer = $MainContainer/LeftPanel/InspectorPanel/InspectorContainer/InspectorScroll/InspectorList

@onready var workspace_tabs: TabContainer = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs

@onready var bg_canvas: Control = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Background/Aspect/Frame/BgCanvas
@onready var bg_texture: TextureRect = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Background/Aspect/Frame/BgCanvas/BgTexture

@onready var music_player: AudioStreamPlayer = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/AudioStreamPlayer
@onready var music_name: Label = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/Info/MusicName
@onready var music_play_button: Button = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/Buttons/PlayButton
@onready var music_stop_button: Button = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/Buttons/StopButton
@onready var music_seek_slider: HSlider = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/SeekRow/SeekSlider
@onready var music_current_time: Label = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/SeekRow/CurrentTime
@onready var music_duration_time: Label = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/SeekRow/DurationTime
@onready var music_volume_slider: HSlider = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/OptionsRow/VolumeSlider
@onready var music_loop_check: CheckBox = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Music/OptionsRow/LoopCheck

@onready var char_canvas: Control = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Character/Aspect/Frame/CharCanvas
@onready var char_base: TextureRect = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Character/Aspect/Frame/CharCanvas/Base
@onready var char_face: TextureRect = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Character/Aspect/Frame/CharCanvas/Face

@onready var title_input: LineEdit = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Title/Form/TitleRow/TitleInput
@onready var desc_input: TextEdit = $MainContainer/CenterPanel/CenterMargin/CenterVBox/WorkspaceTabs/Title/Form/DescInput

@onready var image_dialog: FileDialog = $ImageDialog
@onready var audio_dialog: FileDialog = $AudioDialog
@onready var message_dialog: AcceptDialog = $MessageDialog

@onready var create_char_dialog: ConfirmationDialog = $CreateCharacterDialog
@onready var create_char_name_input: LineEdit = $CreateCharacterDialog/CreateCharMargin/CreateCharVBox/NameRow/NameInput
@onready var create_char_outfit_check: CheckBox = $CreateCharacterDialog/CreateCharMargin/CreateCharVBox/OutfitCheck
@onready var create_char_outfit_input: LineEdit = $CreateCharacterDialog/CreateCharMargin/CreateCharVBox/OutfitRow/OutfitInput
@onready var create_char_error: Label = $CreateCharacterDialog/CreateCharMargin/CreateCharVBox/CreateCharError

@onready var add_expr_dialog: ConfirmationDialog = $AddExpressionDialog
@onready var add_expr_input: LineEdit = $AddExpressionDialog/AddExprMargin/AddExprVBox/ExprInput
@onready var add_expr_error: Label = $AddExpressionDialog/AddExprMargin/AddExprVBox/AddExprError

@onready var unsaved_confirm_dialog: ConfirmationDialog = $UnsavedConfirmDialog

var _project_root: String = ""
var _assets_path: String = ""
var _assets: Dictionary = {}
var _dirty: bool = false
var _mode: int = Mode.BACKGROUND

var _staged_files: Dictionary = {} # rel_path -> {"source": String, "convert_to_png": bool}
var _pending_delete_files: Dictionary = {} # rel_path -> true

var _selected_bg_rel: String = ""
var _selected_music_rel: String = ""
var _selected_character_id: String = ""
var _selected_expression_name: String = ""

var _music_selected_rel_loaded: String = ""
var _music_seeking: bool = false
var _music_duration_sec: float = 0.0

var _bg_inspector_updating: bool = false
var _bg_inspector_path_value: Label = null
var _bg_inspector_zoom: SpinBox = null
var _bg_inspector_offset_x: SpinBox = null
var _bg_inspector_offset_y: SpinBox = null

var _pending_import_kind: String = "" # "background" | "music" | "char_base" | "char_expr"
var _pending_char_id: String = ""
var _pending_expr_name: String = ""

var _bg_dragging: bool = false
var _bg_drag_start_mouse: Vector2 = Vector2.ZERO
var _bg_drag_start_pos: Vector2 = Vector2.ZERO

var _char_dragging: bool = false
var _char_drag_target: String = "" # "base" | "face"
var _char_drag_start_mouse: Vector2 = Vector2.ZERO
var _char_drag_start_pos: Vector2 = Vector2.ZERO
var _char_drag_start_base_pos: Vector2 = Vector2.ZERO
var _char_drag_start_face_pos: Vector2 = Vector2.ZERO

var _main_bgm_player: AudioStreamPlayer = null
var _main_bgm_suspended: bool = false
var _main_bgm_was_playing: bool = false
var _main_bgm_was_paused: bool = false
var _main_bgm_volume_db: float = 0.0
var _main_bgm_playback_pos: float = 0.0
var _main_bgm_stream: AudioStream = null


func _ready() -> void:
	title_label.text = "导入自定义素材"
	inspector_title.text = "Inspector"
	workspace_tabs.tabs_visible = false
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	project_label.clip_text = true
	project_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	music_name.clip_text = true
	music_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	unsaved_label.visible = false
	save_button.disabled = true

	if mode_tabs.get_tab_count() == 0:
		mode_tabs.add_tab("背景")
		mode_tabs.add_tab("音乐")
		mode_tabs.add_tab("人物")
		mode_tabs.add_tab("标题")

	_suspend_main_menu_bgm()

	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	mode_tabs.tab_changed.connect(_on_mode_tab_changed)
	primary_button.pressed.connect(_on_primary_pressed)
	delete_button.pressed.connect(_on_delete_pressed)

	import_base_button.pressed.connect(_on_import_base_pressed)
	add_expression_button.pressed.connect(_on_add_expression_pressed)
	delete_expression_button.pressed.connect(_on_delete_expression_pressed)

	music_play_button.pressed.connect(_on_music_play_pressed)
	music_stop_button.pressed.connect(_on_music_stop_pressed)
	music_seek_slider.drag_started.connect(_on_music_seek_drag_started)
	music_seek_slider.drag_ended.connect(_on_music_seek_drag_ended)
	music_seek_slider.value_changed.connect(_on_music_seek_value_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	music_loop_check.toggled.connect(_on_music_loop_toggled)
	music_player.finished.connect(_on_music_finished)
	_on_music_volume_changed(float(music_volume_slider.value))

	bg_canvas.gui_input.connect(_on_bg_canvas_gui_input)
	bg_canvas.resized.connect(_on_bg_canvas_resized)
	char_canvas.gui_input.connect(_on_char_canvas_gui_input)

	title_input.text_changed.connect(_on_title_text_changed)
	desc_input.text_changed.connect(_on_desc_text_changed)

	image_dialog.file_selected.connect(_on_file_selected)
	audio_dialog.file_selected.connect(_on_file_selected)

	create_char_outfit_check.toggled.connect(_on_create_char_outfit_toggled)
	create_char_dialog.confirmed.connect(_on_create_character_confirmed)
	add_expr_dialog.confirmed.connect(_on_add_expression_confirmed)
	unsaved_confirm_dialog.confirmed.connect(_on_unsaved_confirmed_exit)

	_configure_file_dialogs()
	_reset_runtime_state()
	_set_mode(Mode.BACKGROUND)
	set_process(true)


func _exit_tree() -> void:
	if music_player and music_player.playing:
		music_player.stop()
	_resume_main_menu_bgm()

func _process(_delta: float) -> void:
	if _mode == Mode.MUSIC:
		_update_music_player_ui()


func load_project(project_root: String) -> void:
	_project_root = project_root.replace("\\", "/").trim_suffix("/")
	_assets_path = "" if _project_root.is_empty() else (_project_root + "/" + ASSETS_FILENAME)
	project_label.text = _project_root.get_file()

	_reset_runtime_state()
	_load_assets_from_disk()
	_load_mod_config_into_inputs()
	_refresh_all()


func _reset_runtime_state() -> void:
	_assets = {}
	_staged_files = {}
	_pending_delete_files = {}
	_dirty = false
	_selected_bg_rel = ""
	_selected_music_rel = ""
	_selected_character_id = ""
	_selected_expression_name = ""
	_pending_import_kind = ""
	_pending_char_id = ""
	_pending_expr_name = ""
	_update_dirty_ui()


func _configure_file_dialogs() -> void:
	image_dialog.title = "选择图片文件"
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg, *.jpeg ; JPG", "*.webp ; WEBP"])

	audio_dialog.title = "选择音频文件"
	audio_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	audio_dialog.access = FileDialog.ACCESS_FILESYSTEM
	audio_dialog.filters = PackedStringArray(["*.ogg ; OGG", "*.mp3 ; MP3", "*.wav ; WAV"])


func _ensure_assets_schema() -> void:
	if _assets.is_empty():
		_assets = {"version": 1, "backgrounds": [], "music": [], "characters": {}}
	if not _assets.has("version"):
		_assets["version"] = 1
	if not _assets.has("backgrounds") or typeof(_assets.get("backgrounds")) != TYPE_ARRAY:
		_assets["backgrounds"] = []
	if not _assets.has("music") or typeof(_assets.get("music")) != TYPE_ARRAY:
		_assets["music"] = []
	if not _assets.has("characters") or typeof(_assets.get("characters")) != TYPE_DICTIONARY:
		_assets["characters"] = {}


func _bg_base_scale() -> float:
	# NovelInterface.tscn: BG(Sprite2D) scale=1.25，且原背景资源为 1024x576
	if BG_CANVAS_SIZE.x <= 0:
		return 1.0
	return float(BG_VIEW_SIZE.x) / float(BG_CANVAS_SIZE.x)


func _migrate_background_entries_if_needed() -> void:
	# 旧版本的预览未考虑 NovelInterface 的 BG(Sprite2D) 基础缩放(1.25)，导致“编辑器看到的”和“Mod编辑器/游戏里看到的”不一致。
	# 新版本在预览阶段乘以 base_scale，使所见即所得；历史数据无需改数值，只补一个版本字段即可（保持旧工程的实际效果不变）。
	var list: Array = _assets.get("backgrounds", []) as Array
	if list.is_empty():
		return

	var changed := false
	for i in range(list.size()):
		if typeof(list[i]) != TYPE_DICTIONARY:
			continue
		var entry := list[i] as Dictionary
		var ver := int(entry.get("transform_ver", 1))
		if ver >= 2:
			continue

		entry["transform_ver"] = 2
		list[i] = entry
		changed = true

	if changed:
		_assets["backgrounds"] = list


func _migrate_characters_if_needed() -> void:
	var chars_any: Variant = _assets.get("characters", {})
	if typeof(chars_any) != TYPE_DICTIONARY:
		return
	var chars := chars_any as Dictionary
	if chars.is_empty():
		return

	var changed := false
	for cid_any in chars.keys():
		var cid := str(cid_any)
		var char_data_any: Variant = chars.get(cid)
		if typeof(char_data_any) != TYPE_DICTIONARY:
			continue
		var char_data := char_data_any as Dictionary

		var ver := int(char_data.get("face_transform_ver", 1))
		if ver >= 2:
			continue

		var base_scale := _vec2_from_any(char_data.get("base_scale", [1.0, 1.0]))
		if absf(base_scale.x) <= 0.00001:
			base_scale.x = 1.0
		if absf(base_scale.y) <= 0.00001:
			base_scale.y = 1.0

		# v1: face_offset/face_scale 直接存的是“绝对预览值”；v2: 存“相对 base_scale 的本地值”
		var face_offset_abs := _vec2_from_any(char_data.get("face_offset", [0.0, 0.0]))
		var face_scale_abs := _vec2_from_any(char_data.get("face_scale", [1.0, 1.0]))
		var face_offset_local := Vector2(face_offset_abs.x / base_scale.x, face_offset_abs.y / base_scale.y)
		var face_scale_local := Vector2(face_scale_abs.x / base_scale.x, face_scale_abs.y / base_scale.y)

		char_data["face_offset"] = [float(face_offset_local.x), float(face_offset_local.y)]
		char_data["face_scale"] = [float(face_scale_local.x), float(face_scale_local.y)]
		char_data["face_transform_ver"] = 2

		var exprs_any: Variant = char_data.get("expressions", {})
		if typeof(exprs_any) == TYPE_DICTIONARY:
			var exprs := exprs_any as Dictionary
			for k_any in exprs.keys():
				var k := str(k_any)
				var ed_any: Variant = exprs.get(k)
				if typeof(ed_any) != TYPE_DICTIONARY:
					continue
				var ed := ed_any as Dictionary
				var off_abs := _vec2_from_any(ed.get("offset", face_offset_abs))
				var sc_abs := _vec2_from_any(ed.get("scale", face_scale_abs))
				var off_local := Vector2(off_abs.x / base_scale.x, off_abs.y / base_scale.y)
				var sc_local := Vector2(sc_abs.x / base_scale.x, sc_abs.y / base_scale.y)
				ed["offset"] = [float(off_local.x), float(off_local.y)]
				ed["scale"] = [float(sc_local.x), float(sc_local.y)]
				exprs[k] = ed
			char_data["expressions"] = exprs

		chars[cid] = char_data
		changed = true

	if changed:
		_assets["characters"] = chars


func _load_assets_from_disk() -> void:
	_assets = {}
	if _assets_path.is_empty() or not FileAccess.file_exists(_assets_path):
		_ensure_assets_schema()
		return

	var f := FileAccess.open(_assets_path, FileAccess.READ)
	if f == null:
		_ensure_assets_schema()
		return

	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		_ensure_assets_schema()
		return

	_assets = json.data as Dictionary
	_ensure_assets_schema()
	_migrate_background_entries_if_needed()
	_migrate_characters_if_needed()


func _save_assets_to_disk() -> void:
	if _assets_path.is_empty():
		return
	_ensure_assets_schema()
	var f := FileAccess.open(_assets_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_assets, "\t"))
	f.close()


func _mark_dirty() -> void:
	if _dirty:
		return
	_dirty = true
	_update_dirty_ui()


func _clear_dirty() -> void:
	_dirty = false
	_update_dirty_ui()


func _update_dirty_ui() -> void:
	unsaved_label.visible = _dirty
	save_button.disabled = not _dirty


func _refresh_all() -> void:
	_set_mode(_mode)


func _set_mode(mode: int) -> void:
	_mode = mode
	mode_tabs.current_tab = mode
	workspace_tabs.current_tab = mode

	if mode != Mode.MUSIC:
		if music_player and (music_player.playing or music_player.stream_paused):
			music_player.stop()
			music_player.stream_paused = false

	if mode != Mode.BACKGROUND:
		_selected_bg_rel = ""
	if mode != Mode.MUSIC:
		_selected_music_rel = ""
	if mode != Mode.CHARACTER:
		_selected_character_id = ""
		_selected_expression_name = ""

	match _mode:
		Mode.BACKGROUND:
			primary_button.text = "导入背景"
			delete_button.text = "移除"
			primary_button.disabled = false
			delete_button.disabled = _selected_bg_rel.is_empty()
		Mode.MUSIC:
			primary_button.text = "导入音乐"
			delete_button.text = "移除"
			primary_button.disabled = false
			delete_button.disabled = _selected_music_rel.is_empty()
		Mode.CHARACTER:
			primary_button.text = "创建自定义人物"
			delete_button.text = "删除人物"
			primary_button.disabled = false
			delete_button.disabled = _selected_character_id.is_empty()
		Mode.TITLE:
			primary_button.text = "（无）"
			delete_button.text = "（无）"
			primary_button.disabled = true
			delete_button.disabled = true

	_refresh_resource_list()
	_refresh_workspace()
	_refresh_inspector()
	_refresh_character_action_row()
	_update_action_buttons_state()


func _on_mode_tab_changed(tab: int) -> void:
	_set_mode(tab)


func _update_action_buttons_state() -> void:
	if _mode == Mode.CHARACTER:
		delete_button.disabled = _selected_character_id.is_empty()
	elif _mode == Mode.BACKGROUND:
		delete_button.disabled = _selected_bg_rel.is_empty()
	elif _mode == Mode.MUSIC:
		delete_button.disabled = _selected_music_rel.is_empty()

	delete_expression_button.disabled = _selected_expression_name.is_empty()


func _refresh_character_action_row() -> void:
	var should_show := _mode == Mode.CHARACTER and not _selected_character_id.is_empty()
	character_action_row.visible = should_show


func _refresh_resource_list() -> void:
	for child in resource_list.get_children():
		child.queue_free()

	match _mode:
		Mode.BACKGROUND:
			_add_section_label("背景")
			var list: Array = _assets.get("backgrounds", []) as Array
			for entry_any in list:
				if typeof(entry_any) != TYPE_DICTIONARY:
					continue
				var rel := str((entry_any as Dictionary).get("path", ""))
				if rel.is_empty():
					continue
				_add_resource_row(rel.get_file(), rel == _selected_bg_rel, _on_select_background.bind(rel))
		Mode.MUSIC:
			_add_section_label("音乐")
			var list: Array = _assets.get("music", []) as Array
			for entry_any in list:
				if typeof(entry_any) != TYPE_DICTIONARY:
					continue
				var rel := str((entry_any as Dictionary).get("path", ""))
				if rel.is_empty():
					continue
				_add_resource_row(rel.get_file(), rel == _selected_music_rel, _on_select_music.bind(rel))
		Mode.CHARACTER:
			_add_section_label("人物")
			var chars: Dictionary = _assets.get("characters", {}) as Dictionary
			var ids: Array[String] = []
			for key_any in chars.keys():
				var cid := str(key_any)
				if not cid.is_empty():
					ids.append(cid)
			ids.sort()
			for cid in ids:
				var is_sel := cid == _selected_character_id and _selected_expression_name.is_empty()
				_add_resource_row(cid, is_sel, _on_select_character.bind(cid))

			if not _selected_character_id.is_empty():
				_add_spacer()
				_add_section_label("表情")
				var exprs := _get_character_expressions(_selected_character_id)
				var names: Array[String] = []
				for k in exprs.keys():
					names.append(str(k))
				names.sort()
				for n in names:
					_add_resource_row(n, n == _selected_expression_name, _on_select_expression.bind(n))
		Mode.TITLE:
			_add_section_label("标题/简介")
			_add_hint_label("修改后点击右上角“保存”才会写入工程文件。")


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	resource_list.add_child(label)


func _add_hint_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	resource_list.add_child(label)


func _add_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	resource_list.add_child(spacer)


func _add_resource_row(title: String, selected: bool, cb: Callable) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 38)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = title
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
			get_viewport().set_input_as_handled()
	)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var label := Label.new()
	label.text = title
	label.tooltip_text = title
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	row.add_child(label)

	if selected:
		var mark := Label.new()
		mark.text = "✓"
		mark.add_theme_font_override("font", UI_FONT)
		mark.add_theme_font_size_override("font_size", 18)
		mark.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0, 1.0))
		row.add_child(mark)

	panel.add_child(row)
	resource_list.add_child(panel)


func _on_select_background(rel: String) -> void:
	_selected_bg_rel = rel
	_refresh_resource_list()
	_refresh_workspace()
	_refresh_inspector()
	_update_action_buttons_state()


func _on_select_music(rel: String) -> void:
	_selected_music_rel = rel
	_refresh_resource_list()
	_refresh_workspace()
	_refresh_inspector()
	_update_action_buttons_state()


func _on_select_character(cid: String) -> void:
	_selected_character_id = cid
	_selected_expression_name = ""
	var exprs := _get_character_expressions(cid)
	if not exprs.is_empty():
		var keys: Array[String] = []
		for k in exprs.keys():
			keys.append(str(k))
		keys.sort()
		_selected_expression_name = keys[0]
	_refresh_resource_list()
	_refresh_character_action_row()
	_refresh_workspace()
	_refresh_inspector()
	_update_action_buttons_state()


func _on_select_expression(expr: String) -> void:
	_selected_expression_name = expr
	_refresh_resource_list()
	_refresh_character_action_row()
	_refresh_workspace()
	_refresh_inspector()
	_update_action_buttons_state()


func _refresh_workspace() -> void:
	match _mode:
		Mode.BACKGROUND:
			_refresh_background_workspace()
		Mode.MUSIC:
			_refresh_music_workspace()
		Mode.CHARACTER:
			_refresh_character_workspace()
		Mode.TITLE:
			pass


func _refresh_background_workspace() -> void:
	bg_texture.texture = null
	bg_texture.scale = Vector2.ONE
	bg_texture.position = Vector2.ZERO

	if _selected_bg_rel.is_empty():
		return

	var path := _resolve_preview_path(_selected_bg_rel)
	var tex := _load_texture_any(path)
	if tex == null:
		return

	bg_texture.texture = tex
	bg_texture.size = tex.get_size()
	var center := bg_canvas.size * 0.5

	var entry := _find_bg_entry(_selected_bg_rel)
	var zoom_canvas := float(entry.get("zoom", 1.0)) if not entry.is_empty() else 1.0
	var offset_any: Variant = entry.get("offset", [0.0, 0.0]) if not entry.is_empty() else [0.0, 0.0]
	var offset_canvas := _vec2_from_any(offset_any)
	var preview_scale := _bg_preview_scale_factor()
	var base_scale := _bg_base_scale()
	var zoom_game := zoom_canvas * base_scale
	var offset_game := offset_canvas * base_scale
	var scale_preview := zoom_game * preview_scale

	bg_texture.scale = Vector2(scale_preview, scale_preview)
	var scaled_size := Vector2(tex.get_width(), tex.get_height()) * scale_preview
	var top_left := (center + offset_game * preview_scale) - scaled_size * 0.5
	bg_texture.position = top_left


func _refresh_music_workspace() -> void:
	music_name.text = _selected_music_rel.get_file() if not _selected_music_rel.is_empty() else "未选择音乐"

	if _selected_music_rel.is_empty():
		_music_selected_rel_loaded = ""
		_music_duration_sec = 0.0
		music_seek_slider.editable = false
		music_seek_slider.value = 0.0
		music_seek_slider.max_value = 1.0
		music_current_time.text = "00:00"
		music_duration_time.text = "--:--"
		music_play_button.text = "播放"
		music_stop_button.disabled = true
		return

	if _music_selected_rel_loaded != _selected_music_rel:
		if music_player.playing or music_player.stream_paused:
			music_player.stop()
			music_player.stream_paused = false
		var path := _resolve_preview_path(_selected_music_rel)
		var stream := _load_audio_stream(path)
		music_player.stream = stream
		_music_selected_rel_loaded = _selected_music_rel

	_music_duration_sec = _get_music_duration_seconds()
	music_seek_slider.editable = _music_duration_sec > 0.0
	music_seek_slider.max_value = _music_duration_sec if _music_duration_sec > 0.0 else 1.0
	music_duration_time.text = _format_time(_music_duration_sec) if _music_duration_sec > 0.0 else "--:--"
	_update_music_player_ui()


func _refresh_character_workspace() -> void:
	char_base.texture = null
	char_face.texture = null

	if _selected_character_id.is_empty():
		return

	_ensure_character_face_transform(_selected_character_id)

	var char_data := _get_character_data(_selected_character_id)
	if char_data.is_empty():
		return

	var base_rel := str(char_data.get("base_path", ""))
	if not base_rel.is_empty():
		var tex := _load_texture_any(_resolve_preview_path(base_rel))
		if tex:
			char_base.texture = tex
			char_base.size = tex.get_size()
			char_base.pivot_offset = tex.get_size() * 0.5

	var base_pos := _vec2_from_any(char_data.get("base_pos", [607.0, 400.0]))
	var base_scale := _vec2_from_any(char_data.get("base_scale", [1.0, 1.0]))
	var preview_scale := _char_preview_scale_factor()
	var base_center_preview := base_pos * preview_scale
	char_base.position = base_center_preview - char_base.pivot_offset
	char_base.scale = base_scale * preview_scale

	if _selected_expression_name.is_empty():
		return

	var expr_data := _get_expression_data(_selected_character_id, _selected_expression_name)
	if expr_data.is_empty():
		return

	var expr_rel := str(expr_data.get("path", ""))
	if not expr_rel.is_empty():
		var etex := _load_texture_any(_resolve_preview_path(expr_rel))
		if etex:
			char_face.texture = etex
			char_face.size = etex.get_size()
			char_face.pivot_offset = etex.get_size() * 0.5

	var face_offset := _vec2_from_any(char_data.get("face_offset", [0.0, 0.0]))
	var face_scale := _vec2_from_any(char_data.get("face_scale", [1.0, 1.0]))
	var face_center_preview := (base_pos + Vector2(face_offset.x * base_scale.x, face_offset.y * base_scale.y)) * preview_scale
	char_face.position = face_center_preview - char_face.pivot_offset
	char_face.scale = Vector2(face_scale.x * base_scale.x, face_scale.y * base_scale.y) * preview_scale


func _refresh_inspector() -> void:
	for child in inspector_list.get_children():
		child.queue_free()

	_bg_inspector_path_value = null
	_bg_inspector_zoom = null
	_bg_inspector_offset_x = null
	_bg_inspector_offset_y = null

	match _mode:
		Mode.BACKGROUND:
			_refresh_background_inspector()
		Mode.MUSIC:
			_add_inspector_kv("类型", "音乐")
			_add_inspector_kv("路径", _selected_music_rel)
		Mode.CHARACTER:
			_add_inspector_kv("类型", "人物")
			_add_inspector_kv("角色ID", _selected_character_id)
			_add_inspector_kv("表情", _selected_expression_name)
			var char_data := _get_character_data(_selected_character_id)
			if not char_data.is_empty():
				_add_inspector_kv("Base", str(char_data.get("base_path", "")))
				_add_inspector_kv("BasePos", str(char_data.get("base_pos", [0, 0])))
				_add_inspector_kv("BaseScale", str(char_data.get("base_scale", [1, 1])))
				_add_inspector_kv("FaceOffset", str(char_data.get("face_offset", [0, 0])))
				_add_inspector_kv("FaceScale", str(char_data.get("face_scale", [1, 1])))
			var expr_data := _get_expression_data(_selected_character_id, _selected_expression_name)
			if not expr_data.is_empty():
				_add_inspector_kv("Expr", str(expr_data.get("path", "")))
				_add_inspector_kv("（同步）", "表情位置/缩放跟随人物 FaceOffset/FaceScale")
		Mode.TITLE:
			_add_inspector_kv("类型", "标题")
			_add_inspector_kv("标题", title_input.text)


func _add_inspector_kv(k: String, v: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var lk := Label.new()
	lk.text = k
	lk.add_theme_font_override("font", UI_FONT)
	lk.add_theme_font_size_override("font_size", 16)
	lk.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	lk.custom_minimum_size = Vector2(90, 0)

	var lv := Label.new()
	lv.text = v
	lv.tooltip_text = v
	lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.clip_text = true
	lv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_font_override("font", UI_FONT)
	lv.add_theme_font_size_override("font_size", 16)
	lv.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))

	row.add_child(lk)
	row.add_child(lv)
	inspector_list.add_child(row)

func _add_inspector_row_control(k: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var lk := Label.new()
	lk.text = k
	lk.add_theme_font_override("font", UI_FONT)
	lk.add_theme_font_size_override("font_size", 16)
	lk.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	lk.custom_minimum_size = Vector2(90, 0)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(lk)
	row.add_child(control)
	inspector_list.add_child(row)


func _apply_bg_transform_to_node(zoom: float, offset_std: Vector2) -> void:
	if bg_texture == null or bg_canvas == null:
		return
	if bg_texture.texture == null:
		return
	var center := bg_canvas.size * 0.5
	var preview_scale := _bg_preview_scale_factor()
	var base_scale := _bg_base_scale()
	var zoom_game := zoom * base_scale
	var offset_game := offset_std * base_scale
	var scale_preview := zoom_game * preview_scale

	bg_texture.scale = Vector2(scale_preview, scale_preview)
	var tex := bg_texture.texture
	var scaled_size := Vector2(tex.get_width(), tex.get_height()) * scale_preview
	var top_left := (center + offset_game * preview_scale) - scaled_size * 0.5
	bg_texture.position = top_left


func _bg_preview_scale_factor() -> float:
	if bg_canvas == null:
		return 1.0
	if bg_canvas.size.x <= 0.0:
		return 1.0
	return bg_canvas.size.x / float(BG_VIEW_SIZE.x)


func _char_preview_scale_factor() -> float:
	if char_canvas == null:
		return 1.0
	if char_canvas.size.x <= 0.0:
		return 1.0
	return char_canvas.size.x / float(BG_VIEW_SIZE.x)


func _sync_bg_inspector_from_entry() -> void:
	if _mode != Mode.BACKGROUND:
		return
	if _bg_inspector_zoom == null or _bg_inspector_offset_x == null or _bg_inspector_offset_y == null:
		return

	if _bg_inspector_path_value != null:
		_bg_inspector_path_value.text = _selected_bg_rel
		_bg_inspector_path_value.tooltip_text = _selected_bg_rel

	var entry := _find_bg_entry(_selected_bg_rel)
	var zoom_canvas := float(entry.get("zoom", 1.0)) if not entry.is_empty() else 1.0
	var offset_any: Variant = entry.get("offset", [0.0, 0.0]) if not entry.is_empty() else [0.0, 0.0]
	var offset_canvas := _vec2_from_any(offset_any)
	var base_scale := _bg_base_scale()

	_bg_inspector_updating = true
	_bg_inspector_zoom.value = zoom_canvas * base_scale
	_bg_inspector_offset_x.value = offset_canvas.x * base_scale
	_bg_inspector_offset_y.value = offset_canvas.y * base_scale
	_bg_inspector_updating = false


func _on_bg_inspector_value_changed(_v: float) -> void:
	if _bg_inspector_updating:
		return
	if _mode != Mode.BACKGROUND or _selected_bg_rel.is_empty():
		return
	if _bg_inspector_zoom == null or _bg_inspector_offset_x == null or _bg_inspector_offset_y == null:
		return
	var base_scale := _bg_base_scale()
	var zoom_game := float(_bg_inspector_zoom.value)
	var offset_game := Vector2(float(_bg_inspector_offset_x.value), float(_bg_inspector_offset_y.value))
	var zoom_canvas := zoom_game / base_scale
	var offset_canvas := offset_game / base_scale
	_set_bg_transform(zoom_canvas, offset_canvas)
	_mark_dirty()
	_apply_bg_transform_to_node(zoom_canvas, offset_canvas)


func _on_bg_inspector_reset_pressed() -> void:
	if _mode != Mode.BACKGROUND or _selected_bg_rel.is_empty():
		return
	_set_bg_transform(1.0, Vector2.ZERO)
	_mark_dirty()
	_apply_bg_transform_to_node(1.0, Vector2.ZERO)
	_sync_bg_inspector_from_entry()


func _refresh_background_inspector() -> void:
	_add_inspector_kv("类型", "背景")

	var path_value := Label.new()
	path_value.text = _selected_bg_rel
	path_value.tooltip_text = _selected_bg_rel
	path_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_value.clip_text = true
	path_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_value.add_theme_font_override("font", UI_FONT)
	path_value.add_theme_font_size_override("font_size", 16)
	path_value.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_bg_inspector_path_value = path_value
	_add_inspector_row_control("路径", path_value)

	if _selected_bg_rel.is_empty():
		_add_inspector_kv("提示", "请选择一个背景")
		return

	var base_scale := _bg_base_scale()

	var zoom := SpinBox.new()
	zoom.step = 0.01
	zoom.min_value = 0.2 * base_scale
	zoom.max_value = 6.0 * base_scale
	zoom.allow_greater = false
	zoom.allow_lesser = false
	zoom.add_theme_font_override("font", UI_FONT)
	zoom.add_theme_font_size_override("font_size", 16)
	zoom.value_changed.connect(_on_bg_inspector_value_changed)
	if zoom.get_line_edit() != null:
		zoom.get_line_edit().add_theme_font_override("font", UI_FONT)
		zoom.get_line_edit().add_theme_font_size_override("font_size", 16)
	_bg_inspector_zoom = zoom
	_add_inspector_row_control("缩放(游戏)", zoom)

	var ox := SpinBox.new()
	ox.step = 1.0
	ox.min_value = -4000.0
	ox.max_value = 4000.0
	ox.allow_greater = false
	ox.allow_lesser = false
	ox.add_theme_font_override("font", UI_FONT)
	ox.add_theme_font_size_override("font_size", 16)
	ox.value_changed.connect(_on_bg_inspector_value_changed)
	if ox.get_line_edit() != null:
		ox.get_line_edit().add_theme_font_override("font", UI_FONT)
		ox.get_line_edit().add_theme_font_size_override("font_size", 16)
	_bg_inspector_offset_x = ox
	_add_inspector_row_control("偏移X(游戏)", ox)

	var oy := SpinBox.new()
	oy.step = 1.0
	oy.min_value = -4000.0
	oy.max_value = 4000.0
	oy.allow_greater = false
	oy.allow_lesser = false
	oy.add_theme_font_override("font", UI_FONT)
	oy.add_theme_font_size_override("font_size", 16)
	oy.value_changed.connect(_on_bg_inspector_value_changed)
	if oy.get_line_edit() != null:
		oy.get_line_edit().add_theme_font_override("font", UI_FONT)
		oy.get_line_edit().add_theme_font_size_override("font_size", 16)
	_bg_inspector_offset_y = oy
	_add_inspector_row_control("偏移Y(游戏)", oy)

	var reset_btn := Button.new()
	reset_btn.text = "重置"
	reset_btn.custom_minimum_size = Vector2(0, 34)
	reset_btn.add_theme_font_override("font", UI_FONT)
	reset_btn.add_theme_font_size_override("font_size", 16)
	reset_btn.pressed.connect(_on_bg_inspector_reset_pressed)
	_add_inspector_row_control("", reset_btn)

	_sync_bg_inspector_from_entry()


func _on_bg_canvas_resized() -> void:
	if _mode != Mode.BACKGROUND or _selected_bg_rel.is_empty():
		return
	var entry := _find_bg_entry(_selected_bg_rel)
	if entry.is_empty():
		return
	var zoom := float(entry.get("zoom", 1.0))
	var offset_any: Variant = entry.get("offset", [0.0, 0.0])
	_apply_bg_transform_to_node(zoom, _vec2_from_any(offset_any))


func _on_primary_pressed() -> void:
	if _project_root.is_empty():
		_show_message("提示", "未设置工程路径")
		return

	match _mode:
		Mode.BACKGROUND:
			_pending_import_kind = "background"
			image_dialog.popup_centered_ratio(0.8)
		Mode.MUSIC:
			_pending_import_kind = "music"
			audio_dialog.popup_centered_ratio(0.8)
		Mode.CHARACTER:
			_open_create_character_dialog()
		Mode.TITLE:
			pass


func _on_delete_pressed() -> void:
	match _mode:
		Mode.BACKGROUND:
			if _selected_bg_rel.is_empty():
				return
			var entry := _find_bg_entry(_selected_bg_rel)
			var compiled_rel := str(entry.get("compiled_path", "")) if not entry.is_empty() else ""
			_remove_bg_entry(_selected_bg_rel)
			_mark_file_for_delete(_selected_bg_rel)
			if not compiled_rel.is_empty():
				_mark_file_for_delete(compiled_rel)
			_selected_bg_rel = ""
			_mark_dirty()
			_refresh_all()
		Mode.MUSIC:
			if _selected_music_rel.is_empty():
				return
			_remove_music_entry(_selected_music_rel)
			_mark_file_for_delete(_selected_music_rel)
			_selected_music_rel = ""
			_mark_dirty()
			_refresh_all()
		Mode.CHARACTER:
			if _selected_character_id.is_empty():
				return
			_remove_character(_selected_character_id)
			_selected_character_id = ""
			_selected_expression_name = ""
			_mark_dirty()
			_refresh_all()


func _on_import_base_pressed() -> void:
	if _selected_character_id.is_empty():
		return
	_pending_import_kind = "char_base"
	_pending_char_id = _selected_character_id
	image_dialog.popup_centered_ratio(0.8)


func _on_add_expression_pressed() -> void:
	if _selected_character_id.is_empty():
		return
	_open_add_expression_dialog()


func _on_delete_expression_pressed() -> void:
	if _selected_character_id.is_empty() or _selected_expression_name.is_empty():
		return
	_remove_expression(_selected_character_id, _selected_expression_name)
	_selected_expression_name = ""
	_mark_dirty()
	_refresh_all()


func _on_music_play_pressed() -> void:
	if _selected_music_rel.is_empty():
		return
	if _music_selected_rel_loaded != _selected_music_rel or music_player.stream == null:
		_refresh_music_workspace()
		if music_player.stream == null:
			_show_message("提示", "无法加载音频：" + _selected_music_rel)
			return

	if music_player.playing:
		music_player.stream_paused = not music_player.stream_paused
	else:
		music_player.stream_paused = false
		music_player.play()

	_update_music_player_ui()


func _on_music_stop_pressed() -> void:
	if music_player.playing or music_player.stream_paused:
		music_player.stop()
		music_player.stream_paused = false
	music_seek_slider.value = 0.0
	_update_music_player_ui()


func _on_music_seek_drag_started() -> void:
	_music_seeking = true


func _on_music_seek_drag_ended(_value_changed: bool) -> void:
	if music_player.stream == null:
		_music_seeking = false
		return
	if _music_duration_sec > 0.0:
		music_player.seek(float(music_seek_slider.value))
	_music_seeking = false
	_update_music_player_ui()


func _on_music_seek_value_changed(value: float) -> void:
	if not _music_seeking:
		return
	music_current_time.text = _format_time(float(value))


func _on_music_volume_changed(value: float) -> void:
	var v := clampf(float(value), 0.0, 1.0)
	music_player.volume_db = linear_to_db(max(v, 0.001))


func _on_music_loop_toggled(pressed: bool) -> void:
	music_loop_check.button_pressed = pressed


func _on_music_finished() -> void:
	if music_loop_check.button_pressed and music_player.stream != null:
		music_player.play(0.0)
	_update_music_player_ui()


func _get_music_duration_seconds() -> float:
	if music_player.stream == null:
		return 0.0
	var len := float(music_player.stream.get_length())
	return len if len > 0.0 else 0.0


func _update_music_player_ui() -> void:
	if _mode != Mode.MUSIC:
		return

	var has_stream := music_player.stream != null
	var is_playing := music_player.playing and not music_player.stream_paused

	music_play_button.disabled = not has_stream
	music_stop_button.disabled = not (music_player.playing or music_player.stream_paused)
	music_play_button.text = "暂停" if is_playing else "播放"

	if _music_duration_sec > 0.0 and has_stream:
		var pos := float(music_player.get_playback_position()) if music_player.playing else float(music_seek_slider.value)
		if not _music_seeking:
			music_seek_slider.value = clampf(pos, 0.0, _music_duration_sec)
			music_current_time.text = _format_time(float(music_seek_slider.value))
			music_duration_time.text = _format_time(_music_duration_sec)
	else:
		music_seek_slider.editable = false
		music_duration_time.text = "--:--"
		if not _music_seeking:
			music_current_time.text = "00:00"


func _format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "00:00"
	var s := int(floor(seconds))
	var m := int(s / 60)
	s = s % 60
	return "%02d:%02d" % [m, s]


func _on_file_selected(abs_path: String) -> void:
	var from_abs := abs_path.replace("\\", "/")
	if _pending_import_kind.is_empty():
		return

	match _pending_import_kind:
		"background":
			var rel := _stage_import_file(from_abs, "images/bg", "", false)
			if rel.is_empty():
				return
			_add_or_update_bg_entry(rel)
			_selected_bg_rel = rel
			_mark_dirty()
		"music":
			var rel := _stage_import_file(from_abs, "music", "", false)
			if rel.is_empty():
				return
			_add_or_update_music_entry(rel)
			_selected_music_rel = rel
			_mark_dirty()
		"char_base":
			var folder := _character_folder_for_id(_pending_char_id)
			var rel := _stage_import_file(from_abs, folder, "base", true)
			if rel.is_empty():
				return
			_set_character_base(_pending_char_id, rel)
			_mark_dirty()
		"char_expr":
			var folder := _character_folder_for_id(_pending_char_id)
			var rel := _stage_import_file(from_abs, folder, _pending_expr_name, true)
			if rel.is_empty():
				return
			_set_character_expression(_pending_char_id, _pending_expr_name, rel)
			_selected_character_id = _pending_char_id
			_selected_expression_name = _pending_expr_name
			_mark_dirty()

	_pending_import_kind = ""
	_pending_char_id = ""
	_pending_expr_name = ""
	_refresh_all()


func _stage_import_file(from_abs: String, to_folder_rel: String, rename_basename: String, force_png: bool) -> String:
	var filename := from_abs.get_file()
	var ext := filename.get_extension().to_lower()
	var base := filename.get_basename()
	if not rename_basename.is_empty():
		base = rename_basename

	var out_ext := "png" if force_png else ext
	var rel_folder := to_folder_rel.trim_prefix("/").trim_suffix("/")
	var rel := ("%s/%s.%s" % [rel_folder, base, out_ext]).trim_prefix("/")
	rel = _ensure_unique_rel(rel)

	_staged_files[rel] = {
		"source": from_abs,
		"convert_to_png": force_png and ext != "png",
	}
	return rel


func _ensure_unique_rel(rel: String) -> String:
	var normalized := rel.replace("\\", "/").trim_prefix("/")
	if not _rel_exists_or_staged(normalized):
		return normalized

	var folder := normalized.get_base_dir()
	var base := normalized.get_file().get_basename()
	var ext := normalized.get_extension()
	for i in range(2, 1000):
		var candidate := ("%s/%s_%d.%s" % [folder, base, i, ext]).trim_prefix("/")
		if not _rel_exists_or_staged(candidate):
			return candidate
	return normalized


func _rel_exists_or_staged(rel: String) -> bool:
	if _staged_files.has(rel):
		return true
	if _project_root.is_empty():
		return false
	return FileAccess.file_exists(_project_root + "/" + rel)


func _resolve_preview_path(rel: String) -> String:
	if rel.is_empty():
		return ""
	if _staged_files.has(rel):
		var data: Dictionary = _staged_files.get(rel) as Dictionary
		return str(data.get("source", ""))
	return _project_root + "/" + rel


func _unstage_if_needed(rel: String) -> void:
	if _staged_files.has(rel):
		_staged_files.erase(rel)


func _mark_file_for_delete(rel: String) -> void:
	var normalized := rel.replace("\\", "/").trim_prefix("/")
	if normalized.is_empty():
		return
	if normalized.find("..") != -1 or normalized.find("://") != -1:
		return

	if _staged_files.has(normalized):
		_staged_files.erase(normalized)
		return

	_pending_delete_files[normalized] = true


func _unmark_file_for_delete(rel: String) -> void:
	var normalized := rel.replace("\\", "/").trim_prefix("/")
	if normalized.is_empty():
		return
	if _pending_delete_files.has(normalized):
		_pending_delete_files.erase(normalized)


func _open_create_character_dialog() -> void:
	create_char_error.visible = false
	create_char_error.text = ""
	create_char_name_input.text = ""
	create_char_outfit_check.button_pressed = false
	create_char_outfit_input.text = ""
	create_char_outfit_input.editable = false
	create_char_dialog.popup_centered()
	create_char_name_input.grab_focus()


func _on_create_char_outfit_toggled(pressed: bool) -> void:
	create_char_outfit_input.editable = pressed
	if pressed:
		create_char_outfit_input.grab_focus()


func _on_create_character_confirmed() -> void:
	var base_name := create_char_name_input.text.strip_edges().to_lower()
	var has_outfit := create_char_outfit_check.button_pressed
	var outfit_name := create_char_outfit_input.text.strip_edges().to_lower()

	create_char_error.visible = false
	create_char_error.text = ""

	if not _is_valid_character_part(base_name):
		_show_create_char_error("角色名仅允许 a-z / 0-9，且不能为空。")
		return
	if has_outfit and not _is_valid_character_part(outfit_name):
		_show_create_char_error("服装名仅允许 a-z / 0-9，且不能为空。")
		return

	var cid := base_name + ("_" + outfit_name if has_outfit else "")
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	if chars.has(cid):
		_show_create_char_error("已存在同名人物：" + cid)
		return

	var parts: Array[String] = []
	parts.append(base_name)
	if has_outfit:
		parts.append(outfit_name)
	_create_character(cid, parts)
	_selected_character_id = cid
	_selected_expression_name = ""
	_mark_dirty()
	_set_mode(Mode.CHARACTER)
	create_char_dialog.hide()


func _show_create_char_error(msg: String) -> void:
	create_char_error.text = msg
	create_char_error.visible = true


func _open_add_expression_dialog() -> void:
	add_expr_error.visible = false
	add_expr_error.text = ""
	add_expr_input.text = ""
	add_expr_dialog.popup_centered()
	add_expr_input.grab_focus()


func _on_add_expression_confirmed() -> void:
	if _selected_character_id.is_empty():
		return

	var expr_name := add_expr_input.text.strip_edges().to_lower()
	add_expr_error.visible = false
	add_expr_error.text = ""
	if not _is_valid_character_part(expr_name):
		_show_add_expr_error("表情名仅允许 a-z / 0-9，且不能为空。")
		return

	var exprs := _get_character_expressions(_selected_character_id)
	if exprs.has(expr_name):
		_show_add_expr_error("表情已存在：" + expr_name)
		return

	_pending_import_kind = "char_expr"
	_pending_char_id = _selected_character_id
	_pending_expr_name = expr_name
	add_expr_dialog.hide()
	image_dialog.popup_centered_ratio(0.8)


func _show_add_expr_error(msg: String) -> void:
	add_expr_error.text = msg
	add_expr_error.visible = true


func _is_valid_character_part(s: String) -> bool:
	if s.is_empty():
		return false
	for ch in s:
		var code := ch.unicode_at(0)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not (is_lower or is_digit):
			return false
	return true


func _character_folder_for_id(cid: String) -> String:
	var char_data := _get_character_data(cid)
	var parts_any: Variant = char_data.get("parts", [])
	var parts: Array[String] = []
	if typeof(parts_any) == TYPE_ARRAY:
		for p_any in (parts_any as Array):
			var p := str(p_any).strip_edges()
			if not p.is_empty():
				parts.append(p)
	if parts.is_empty():
		parts = cid.split("_")
	return "images/role/" + "/".join(parts)


func _create_character(cid: String, parts: Array[String]) -> void:
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	chars[cid] = {
		"id": cid,
		"parts": parts,
		"base_path": "",
		"base_pos": [607.0, 400.0],
		"base_scale": [1.0, 1.0],
		"face_transform_ver": 2,
		"face_offset": [0.0, 0.0],
		"face_scale": [1.0, 1.0],
		"expressions": {}
	}
	_assets["characters"] = chars


func _get_character_data(cid: String) -> Dictionary:
	if cid.is_empty():
		return {}
	var chars_any: Variant = _assets.get("characters", {})
	if typeof(chars_any) != TYPE_DICTIONARY:
		return {}
	var data_any: Variant = (chars_any as Dictionary).get(cid, {})
	if typeof(data_any) != TYPE_DICTIONARY:
		return {}
	return data_any as Dictionary


func _get_character_expressions(cid: String) -> Dictionary:
	var char_data := _get_character_data(cid)
	if char_data.is_empty():
		return {}
	var expr_any: Variant = char_data.get("expressions", {})
	if typeof(expr_any) != TYPE_DICTIONARY:
		char_data["expressions"] = {}
		return {}
	return expr_any as Dictionary


func _get_expression_data(cid: String, expr: String) -> Dictionary:
	if cid.is_empty() or expr.is_empty():
		return {}
	var exprs := _get_character_expressions(cid)
	var data_any: Variant = exprs.get(expr, {})
	if typeof(data_any) != TYPE_DICTIONARY:
		return {}
	return data_any as Dictionary


func _ensure_character_face_transform(cid: String) -> void:
	if cid.is_empty():
		return
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(cid, {}) as Dictionary
	if char_data.is_empty():
		return

	var exprs: Dictionary = char_data.get("expressions", {}) as Dictionary

	var changed := false

	var face_offset := _vec2_from_any(char_data.get("face_offset", [0.0, 0.0]))
	var face_scale := _vec2_from_any(char_data.get("face_scale", [1.0, 1.0]))

	# 兼容：v1 的 face_offset/face_scale 是“绝对预览值”，这里迁移为 v2 的“相对 base_scale 的本地值”
	if int(char_data.get("face_transform_ver", 1)) < 2:
		var base_scale := _vec2_from_any(char_data.get("base_scale", [1.0, 1.0]))
		if absf(base_scale.x) <= 0.00001:
			base_scale.x = 1.0
		if absf(base_scale.y) <= 0.00001:
			base_scale.y = 1.0

		face_offset = Vector2(face_offset.x / base_scale.x, face_offset.y / base_scale.y)
		face_scale = Vector2(face_scale.x / base_scale.x, face_scale.y / base_scale.y)

		char_data["face_offset"] = [float(face_offset.x), float(face_offset.y)]
		char_data["face_scale"] = [float(face_scale.x), float(face_scale.y)]
		char_data["face_transform_ver"] = 2

		for k_any in exprs.keys():
			var k := str(k_any)
			var ed_any: Variant = exprs.get(k)
			if typeof(ed_any) != TYPE_DICTIONARY:
				continue
			var ed := ed_any as Dictionary
			var off_abs := _vec2_from_any(ed.get("offset", [0.0, 0.0]))
			var sc_abs := _vec2_from_any(ed.get("scale", [1.0, 1.0]))
			var off_local := Vector2(off_abs.x / base_scale.x, off_abs.y / base_scale.y)
			var sc_local := Vector2(sc_abs.x / base_scale.x, sc_abs.y / base_scale.y)
			ed["offset"] = [float(off_local.x), float(off_local.y)]
			ed["scale"] = [float(sc_local.x), float(sc_local.y)]
			exprs[k] = ed

		changed = true

	var has_face_offset := char_data.has("face_offset")
	var has_face_scale := char_data.has("face_scale")

	# 兼容旧数据：若人物未存 face_offset/face_scale，则从第一个表情的 offset/scale 推断
	if (not has_face_offset or not has_face_scale) and not exprs.is_empty():
		for entry_any in exprs.values():
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var ed := entry_any as Dictionary
			var off := _vec2_from_any(ed.get("offset", [0.0, 0.0]))
			var sc := _vec2_from_any(ed.get("scale", [1.0, 1.0]))
			face_offset = off
			face_scale = sc if sc != Vector2.ZERO else Vector2.ONE
			break

	if not has_face_offset:
		char_data["face_offset"] = [float(face_offset.x), float(face_offset.y)]
		changed = true
	if not has_face_scale:
		char_data["face_scale"] = [float(face_scale.x), float(face_scale.y)]
		changed = true

	# 同步：所有表情共享同一套 offset/scale
	for k_any in exprs.keys():
		var k := str(k_any)
		var ed_any: Variant = exprs.get(k)
		if typeof(ed_any) != TYPE_DICTIONARY:
			continue
		var ed := ed_any as Dictionary
		var off_old := _vec2_from_any(ed.get("offset", [0.0, 0.0]))
		var sc_old := _vec2_from_any(ed.get("scale", [1.0, 1.0]))
		if off_old != face_offset or sc_old != face_scale:
			ed["offset"] = [float(face_offset.x), float(face_offset.y)]
			ed["scale"] = [float(face_scale.x), float(face_scale.y)]
			exprs[k] = ed
			changed = true

	if changed:
		char_data["expressions"] = exprs
		chars[cid] = char_data
		_assets["characters"] = chars
		_mark_dirty()


func _set_character_base(cid: String, rel: String) -> void:
	_unmark_file_for_delete(rel)
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(cid, {}) as Dictionary
	char_data["base_path"] = rel
	chars[cid] = char_data
	_assets["characters"] = chars


func _set_character_expression(cid: String, expr: String, rel: String) -> void:
	_unmark_file_for_delete(rel)
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(cid, {}) as Dictionary
	var exprs: Dictionary = char_data.get("expressions", {}) as Dictionary
	var face_offset := _vec2_from_any(char_data.get("face_offset", [0.0, 0.0]))
	var face_scale := _vec2_from_any(char_data.get("face_scale", [1.0, 1.0]))
	if int(char_data.get("face_transform_ver", 1)) < 2:
		char_data["face_transform_ver"] = 2
	if not char_data.has("face_offset"):
		char_data["face_offset"] = [float(face_offset.x), float(face_offset.y)]
	if not char_data.has("face_scale"):
		char_data["face_scale"] = [float(face_scale.x), float(face_scale.y)]
	exprs[expr] = {
		"name": expr,
		"path": rel,
		"offset": [float(face_offset.x), float(face_offset.y)],
		"scale": [float(face_scale.x), float(face_scale.y)],
	}
	char_data["expressions"] = exprs
	chars[cid] = char_data
	_assets["characters"] = chars


func _remove_expression(cid: String, expr: String) -> void:
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(cid, {}) as Dictionary
	var exprs: Dictionary = char_data.get("expressions", {}) as Dictionary
	if exprs.has(expr):
		var data: Dictionary = exprs.get(expr) as Dictionary
		var rel := str(data.get("path", ""))
		_mark_file_for_delete(rel)
		exprs.erase(expr)
	char_data["expressions"] = exprs
	chars[cid] = char_data
	_assets["characters"] = chars


func _remove_character(cid: String) -> void:
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(cid, {}) as Dictionary
	var base_rel := str(char_data.get("base_path", ""))
	_mark_file_for_delete(base_rel)
	_mark_file_for_delete("characters/%s.tscn" % cid)
	_mark_file_for_delete("characters/%s.gd" % cid)
	var exprs: Dictionary = char_data.get("expressions", {}) as Dictionary
	for entry_any in exprs.values():
		if typeof(entry_any) == TYPE_DICTIONARY:
			_mark_file_for_delete(str((entry_any as Dictionary).get("path", "")))
	chars.erase(cid)
	_assets["characters"] = chars


func _find_bg_entry(rel: String) -> Dictionary:
	if rel.is_empty():
		return {}
	var list: Array = _assets.get("backgrounds", []) as Array
	for entry_any in list:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry := entry_any as Dictionary
		if str(entry.get("path", "")) == rel:
			return entry
	return {}


func _add_or_update_bg_entry(rel: String) -> void:
	_unmark_file_for_delete(rel)
	var list: Array = _assets.get("backgrounds", []) as Array
	for i in range(list.size()):
		if typeof(list[i]) == TYPE_DICTIONARY and str((list[i] as Dictionary).get("path", "")) == rel:
			var entry := list[i] as Dictionary
			if str(entry.get("compiled_path", "")).is_empty():
				entry["compiled_path"] = _ensure_unique_rel("%s/%s.png" % [BG_COMPILED_DIR_REL, rel.get_file().get_basename()])
			_unmark_file_for_delete(str(entry.get("compiled_path", "")))
			if int(entry.get("transform_ver", 1)) < 2:
				entry["transform_ver"] = 2
			list[i] = entry
			_assets["backgrounds"] = list
			return
	var compiled := _ensure_unique_rel("%s/%s.png" % [BG_COMPILED_DIR_REL, rel.get_file().get_basename()])
	_unmark_file_for_delete(compiled)
	list.append({
		"path": rel,
		"compiled_path": compiled,
		"transform_ver": 2,
		"zoom": 1.0,
		"offset": [0.0, 0.0],
	})
	_assets["backgrounds"] = list


func _remove_bg_entry(rel: String) -> void:
	var list: Array = _assets.get("backgrounds", []) as Array
	for i in range(list.size() - 1, -1, -1):
		if typeof(list[i]) == TYPE_DICTIONARY and str((list[i] as Dictionary).get("path", "")) == rel:
			list.remove_at(i)
	_assets["backgrounds"] = list


func _add_or_update_music_entry(rel: String) -> void:
	_unmark_file_for_delete(rel)
	var list: Array = _assets.get("music", []) as Array
	for i in range(list.size()):
		if typeof(list[i]) == TYPE_DICTIONARY and str((list[i] as Dictionary).get("path", "")) == rel:
			return
	list.append({"path": rel})
	_assets["music"] = list


func _remove_music_entry(rel: String) -> void:
	var list: Array = _assets.get("music", []) as Array
	for i in range(list.size() - 1, -1, -1):
		if typeof(list[i]) == TYPE_DICTIONARY and str((list[i] as Dictionary).get("path", "")) == rel:
			list.remove_at(i)
	_assets["music"] = list


func _on_bg_canvas_gui_input(event: InputEvent) -> void:
	if _mode != Mode.BACKGROUND or _selected_bg_rel.is_empty():
		return
	if bg_texture.texture == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_bg_dragging = true
				_bg_drag_start_mouse = mb.position
				_bg_drag_start_pos = bg_texture.position
			else:
				_bg_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_set_bg_transform(1.0, Vector2.ZERO)
			_mark_dirty()
			_refresh_workspace()
			_refresh_inspector()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_adjust_bg_zoom(1.08)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_adjust_bg_zoom(1.0 / 1.08)
	elif event is InputEventMouseMotion and _bg_dragging:
		var mm := event as InputEventMouseMotion
		bg_texture.position = _bg_drag_start_pos + (mm.position - _bg_drag_start_mouse)
		_write_bg_transform_from_node()


func _adjust_bg_zoom(factor: float) -> void:
	var base_scale := _bg_base_scale()
	var preview_scale := _bg_preview_scale_factor()
	var z: float = clampf(bg_texture.scale.x * factor, 0.2 * base_scale * preview_scale, 6.0 * base_scale * preview_scale)
	bg_texture.scale = Vector2(z, z)
	_write_bg_transform_from_node()


func _write_bg_transform_from_node() -> void:
	if _selected_bg_rel.is_empty():
		return
	var center := bg_canvas.size * 0.5
	var preview_scale := _bg_preview_scale_factor()
	var base_scale := _bg_base_scale()
	var tex := bg_texture.texture
	if tex == null:
		return

	var scale_preview := bg_texture.scale.x
	var scaled_size := Vector2(tex.get_width(), tex.get_height()) * scale_preview
	var center_pos_preview := bg_texture.position + scaled_size * 0.5

	var offset_view := (center_pos_preview - center) / preview_scale
	var offset_canvas := offset_view / base_scale
	var zoom_canvas := scale_preview / (base_scale * preview_scale)
	_set_bg_transform(zoom_canvas, offset_canvas)
	_mark_dirty()
	_sync_bg_inspector_from_entry()


func _set_bg_transform(zoom: float, offset: Vector2) -> void:
	var entry := _find_bg_entry(_selected_bg_rel)
	if entry.is_empty():
		return
	entry["zoom"] = float(zoom)
	entry["offset"] = [float(offset.x), float(offset.y)]


func _on_char_canvas_gui_input(event: InputEvent) -> void:
	if _mode != Mode.CHARACTER or _selected_character_id.is_empty():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_char_drag_target = _pick_char_target_global(mb.global_position)
				_char_dragging = not _char_drag_target.is_empty()
				_char_drag_start_mouse = mb.position
				_char_drag_start_pos = _get_char_target_node().position if _char_dragging else Vector2.ZERO
				_char_drag_start_base_pos = char_base.position
				_char_drag_start_face_pos = char_face.position
			else:
				_char_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_reset_character_transforms()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_adjust_character_scale(1.05)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_adjust_character_scale(1.0 / 1.05)
	elif event is InputEventMouseMotion and _char_dragging:
		var mm := event as InputEventMouseMotion
		var delta := mm.position - _char_drag_start_mouse
		if _char_drag_target == "base":
			char_base.position = _char_drag_start_base_pos + delta
			if char_face.texture != null:
				char_face.position = _char_drag_start_face_pos + delta
		elif _char_drag_target == "face":
			if char_face.texture != null:
				char_face.position = _char_drag_start_face_pos + delta
		else:
			return
		_write_character_transform_from_nodes()


func _pick_char_target_global(global_pos: Vector2) -> String:
	if char_face.texture != null and char_face.get_global_rect().has_point(global_pos):
		return "face"
	if char_base.texture != null and char_base.get_global_rect().has_point(global_pos):
		return "base"
	return ""


func _get_char_target_node() -> Control:
	if _char_drag_target == "face":
		return char_face
	if _char_drag_target == "base":
		return char_base
	return null


func _adjust_character_scale(factor: float) -> void:
	# 默认缩放：若未点选目标，优先缩放整个人物（base）
	if _char_drag_target.is_empty():
		_char_drag_target = "base"

	if _char_drag_target == "base":
		var old_scale := char_base.scale
		var new_scale := old_scale * factor
		new_scale.x = clampf(new_scale.x, 0.05, 6.0)
		new_scale.y = clampf(new_scale.y, 0.05, 6.0)

		var ratio := Vector2(
			new_scale.x / old_scale.x if absf(old_scale.x) > 0.00001 else 1.0,
			new_scale.y / old_scale.y if absf(old_scale.y) > 0.00001 else 1.0
		)

		var base_center := char_base.position + char_base.pivot_offset
		var face_center := char_face.position + char_face.pivot_offset
		var face_delta := face_center - base_center

		char_base.scale = new_scale
		if char_face.texture != null:
			# 保持 face 的“本地 offset/scale”不变：跟随 base_scale 同步变化
			var new_face_center := base_center + Vector2(face_delta.x * ratio.x, face_delta.y * ratio.y)
			char_face.position = new_face_center - char_face.pivot_offset
			char_face.scale = Vector2(char_face.scale.x * ratio.x, char_face.scale.y * ratio.y)
	elif _char_drag_target == "face":
		if char_face.texture == null:
			return
		var s := char_face.scale * factor
		s.x = clampf(s.x, 0.05, 6.0)
		s.y = clampf(s.y, 0.05, 6.0)
		char_face.scale = s
	else:
		return
	_write_character_transform_from_nodes()


func _reset_character_transforms() -> void:
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(_selected_character_id, {}) as Dictionary
	if char_data.is_empty():
		return

	char_data["base_pos"] = [607.0, 400.0]
	char_data["base_scale"] = [1.0, 1.0]
	char_data["face_transform_ver"] = 2
	char_data["face_offset"] = [0.0, 0.0]
	char_data["face_scale"] = [1.0, 1.0]

	var exprs: Dictionary = char_data.get("expressions", {}) as Dictionary
	for k_any in exprs.keys():
		var k := str(k_any)
		var expr_data_any: Variant = exprs.get(k)
		if typeof(expr_data_any) != TYPE_DICTIONARY:
			continue
		var expr_data := expr_data_any as Dictionary
		expr_data["offset"] = [0.0, 0.0]
		expr_data["scale"] = [1.0, 1.0]
		exprs[k] = expr_data
	char_data["expressions"] = exprs

	chars[_selected_character_id] = char_data
	_assets["characters"] = chars
	_mark_dirty()
	_refresh_workspace()
	_refresh_inspector()


func _write_character_transform_from_nodes() -> void:
	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	var char_data: Dictionary = chars.get(_selected_character_id, {}) as Dictionary
	if char_data.is_empty():
		return

	var preview_scale := _char_preview_scale_factor()
	if absf(preview_scale) <= 0.00001:
		preview_scale = 1.0

	var base_center_preview := char_base.position + char_base.pivot_offset
	var base_center := base_center_preview / preview_scale
	var base_scale := char_base.scale / preview_scale
	char_data["base_pos"] = [float(base_center.x), float(base_center.y)]
	char_data["base_scale"] = [float(base_scale.x), float(base_scale.y)]

	if char_face.texture != null:
		if absf(base_scale.x) <= 0.00001:
			base_scale.x = 1.0
		if absf(base_scale.y) <= 0.00001:
			base_scale.y = 1.0

		# 统一存“本地值”：face_offset/face_scale 相对于 base_scale
		var face_center_preview := char_face.position + char_face.pivot_offset
		var face_center := face_center_preview / preview_scale
		var face_offset_abs := face_center - base_center

		var face_scale_abs := char_face.scale / preview_scale
		var face_offset := Vector2(face_offset_abs.x / base_scale.x, face_offset_abs.y / base_scale.y)
		var face_scale := Vector2(face_scale_abs.x / base_scale.x, face_scale_abs.y / base_scale.y)

		char_data["face_transform_ver"] = 2
		char_data["face_offset"] = [float(face_offset.x), float(face_offset.y)]
		char_data["face_scale"] = [float(face_scale.x), float(face_scale.y)]

		# 同步：写回所有表情
		var exprs: Dictionary = char_data.get("expressions", {}) as Dictionary
		for k_any in exprs.keys():
			var k := str(k_any)
			var expr_data_any: Variant = exprs.get(k)
			if typeof(expr_data_any) != TYPE_DICTIONARY:
				continue
			var expr_data := expr_data_any as Dictionary
			expr_data["offset"] = [float(face_offset.x), float(face_offset.y)]
			expr_data["scale"] = [float(face_scale.x), float(face_scale.y)]
			exprs[k] = expr_data
		char_data["expressions"] = exprs

	chars[_selected_character_id] = char_data
	_assets["characters"] = chars
	_mark_dirty()
	_refresh_inspector()


func _load_texture_any(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	var err := img.load(path)
	if err != OK or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	if ext == "ogg" and ClassDB.class_exists("AudioStreamOggVorbis"):
		return AudioStreamOggVorbis.load_from_file(path)
	if ext == "mp3" and ClassDB.class_exists("AudioStreamMP3"):
		return AudioStreamMP3.load_from_file(path)
	if ext == "wav" and ClassDB.class_exists("AudioStreamWAV"):
		return AudioStreamWAV.load_from_file(path)
	return null


func _vec2_from_any(any: Variant) -> Vector2:
	if typeof(any) == TYPE_VECTOR2:
		return any as Vector2
	if typeof(any) == TYPE_ARRAY:
		var arr := any as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
	return Vector2.ZERO


func _show_message(title: String, text: String) -> void:
	message_dialog.title = title
	message_dialog.dialog_text = text
	message_dialog.popup_centered()


func _on_title_text_changed(_t: String) -> void:
	if _mode == Mode.TITLE:
		_mark_dirty()
		_refresh_inspector()


func _on_desc_text_changed() -> void:
	if _mode == Mode.TITLE:
		_mark_dirty()


func _load_mod_config_into_inputs() -> void:
	if _project_root.is_empty():
		return
	var config_path := _project_root + "/mod_config.json"
	if not FileAccess.file_exists(config_path):
		return

	var f := FileAccess.open(config_path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var config := json.data as Dictionary
	title_input.text = str(config.get("title", ""))
	desc_input.text = str(config.get("description", ""))


func _save_mod_config_from_inputs() -> void:
	if _project_root.is_empty():
		return
	var config_path := _project_root + "/mod_config.json"
	var config: Dictionary = {}
	if FileAccess.file_exists(config_path):
		var f := FileAccess.open(config_path, FileAccess.READ)
		if f:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
				config = json.data as Dictionary
			f.close()

	config["title"] = title_input.text.strip_edges()
	config["description"] = desc_input.text.strip_edges()

	var out := FileAccess.open(config_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(JSON.stringify(config, "\t"))
	out.close()


func _on_save_pressed() -> void:
	_save_all_to_disk()


func _save_all_to_disk() -> void:
	if _project_root.is_empty():
		return

	var root_dir := DirAccess.open(_project_root)
	if root_dir == null:
		_show_message("提示", "无法打开工程目录：" + _project_root)
		return

	for rel_any in _staged_files.keys():
		var rel := str(rel_any)
		var data: Dictionary = _staged_files.get(rel) as Dictionary
		var src := str(data.get("source", ""))
		if src.is_empty():
			continue

		var subdir := rel.get_base_dir()
		if not subdir.is_empty():
			root_dir.make_dir_recursive(subdir)

		var dst := _project_root + "/" + rel
		var convert_to_png := bool(data.get("convert_to_png", false))
		var ok := _write_file_from_source(src, dst, convert_to_png)
		if not ok:
			_show_message("提示", "保存失败：" + rel)
			return

	# 删除用户“移除/删除”标记的文件（同样走“保存”机制才会落盘）
	if not _build_compiled_backgrounds(root_dir):
		return
	if not _build_character_scenes_and_scripts(root_dir):
		return

	var used := _collect_used_rel_paths()
	for rel_any in _pending_delete_files.keys():
		var rel := str(rel_any).replace("\\", "/").trim_prefix("/")
		if rel.is_empty():
			continue
		if used.has(rel) or _staged_files.has(rel):
			continue
		_delete_project_file_if_exists(rel)

	_pending_delete_files = {}
	_staged_files = {}
	_save_assets_to_disk()
	_save_mod_config_from_inputs()
	_clear_dirty()
	_refresh_all()
	_show_message("提示", "保存成功")


func _build_character_scenes_and_scripts(root_dir: DirAccess) -> bool:
	var chars_any: Variant = _assets.get("characters", {})
	if typeof(chars_any) != TYPE_DICTIONARY:
		return true
	var chars := chars_any as Dictionary
	if chars.is_empty():
		return true

	root_dir.make_dir_recursive("characters")

	for cid_any in chars.keys():
		var cid := str(cid_any).strip_edges()
		if cid.is_empty():
			continue
		var char_data_any: Variant = chars.get(cid_any)
		if typeof(char_data_any) != TYPE_DICTIONARY:
			continue
		var char_data := char_data_any as Dictionary

		var script_rel := "characters/%s.gd" % cid
		var scene_rel := "characters/%s.tscn" % cid
		_unmark_file_for_delete(script_rel)
		_unmark_file_for_delete(scene_rel)

		var script_abs := _project_root + "/" + script_rel
		var scene_abs := _project_root + "/" + scene_rel

		var script_code := _generate_character_script_code(cid, char_data)
		if not _write_text_file(script_abs, script_code):
			_show_message("提示", "生成角色脚本失败：" + script_rel)
			return false

		var scene_code := _generate_character_scene_code(cid, script_abs, char_data)
		if not _write_text_file(scene_abs, scene_code):
			_show_message("提示", "生成角色场景失败：" + scene_rel)
			return false

	return true


func _write_text_file(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _escape_gd_string(s: String) -> String:
	return s.c_escape()


func _generate_character_script_code(cid: String, char_data: Dictionary) -> String:
	var base_rel := str(char_data.get("base_path", "")).replace("\\", "/").trim_prefix("/")
	var exprs_any: Variant = char_data.get("expressions", {})
	var exprs: Dictionary = exprs_any as Dictionary if typeof(exprs_any) == TYPE_DICTIONARY else {}

	var expr_names: Array[String] = []
	for k_any in exprs.keys():
		var k := str(k_any).strip_edges().to_lower()
		if not k.is_empty():
			expr_names.append(k)
	expr_names.sort()

	var default_expr := ""
	if expr_names.has("normal1"):
		default_expr = "normal1"
	elif expr_names.size() > 0:
		default_expr = expr_names[0]

	var expr_rel_lines: Array[String] = []
	for expr_name in expr_names:
		var ed_any: Variant = exprs.get(expr_name)
		if typeof(ed_any) != TYPE_DICTIONARY:
			continue
		var rel := str((ed_any as Dictionary).get("path", "")).replace("\\", "/").trim_prefix("/")
		if rel.is_empty():
			continue
		expr_rel_lines.append("\t\"%s\": \"%s\"" % [_escape_gd_string(expr_name), _escape_gd_string(rel)])

	var expr_list_items: Array[String] = []
	for expr_name in expr_names:
		expr_list_items.append("\"%s\"" % _escape_gd_string(expr_name))
	var expr_list_code := "[" + ", ".join(expr_list_items) + "]"

	var code := ""
	code += "# 由自定义素材导入编辑器自动生成\n"
	code += "extends CharacterNode\n\n"
	code += "const _BASE_REL: String = \"%s\"\n" % _escape_gd_string(base_rel)
	code += "const _EXPR_REL: Dictionary = {\n"
	code += (",\n".join(expr_rel_lines) + "\n") if expr_rel_lines.size() > 0 else ""
	code += "}\n\n"
	code += "func _init():\n"
	code += "\tcharacter_name = \"%s\"\n" % _escape_gd_string(cid)
	code += "\tdisplay_name = \"%s\"\n" % _escape_gd_string(cid)
	code += "\texpression_list = %s\n" % expr_list_code
	code += "\tcurrent_expression = \"%s\"\n" % _escape_gd_string(default_expr)
	code += "\n"
	code += "func _ready():\n"
	code += "\t# 覆盖基类的 res:// 加载逻辑：改为从角色场景所在的工程目录读取 images/ 下的文件\n"
	code += "\tload_character_resources()\n"
	code += "\tif current_expression != \"\" and has_method(\"set_expression\"):\n"
	code += "\t\tset_expression(current_expression)\n"
	code += "\n"
	code += "func _get_project_root_from_scene() -> String:\n"
	code += "\tvar p := scene_file_path\n"
	code += "\tif p == \"\":\n"
	code += "\t\tp = get_script().resource_path\n"
	code += "\tif p == \"\":\n"
	code += "\t\treturn \"\"\n"
	code += "\tvar dir := p.get_base_dir()\n"
	code += "\t# scene/script 通常位于 <root>/characters/\n"
	code += "\tif dir.get_file() == \"characters\":\n"
	code += "\t\treturn dir.get_base_dir()\n"
	code += "\treturn dir\n"
	code += "\n"
	code += "func _abs_path(rel: String) -> String:\n"
	code += "\tvar r := rel.replace(\"\\\\\\\\\", \"/\").trim_prefix(\"/\")\n"
	code += "\tif r.begins_with(\"res://\") or r.begins_with(\"user://\"):\n"
	code += "\t\treturn r\n"
	code += "\tvar root := _get_project_root_from_scene()\n"
	code += "\treturn (root + \"/\" + r) if root != \"\" else r\n"
	code += "\n"
	code += "func _load_texture_any(path: String):\n"
	code += "\tif path == \"\" or not FileAccess.file_exists(path):\n"
	code += "\t\treturn null\n"
	code += "\tvar img = Image.new()\n"
	code += "\tvar err = img.load(path)\n"
	code += "\tif err != OK or img.is_empty():\n"
	code += "\t\treturn null\n"
	code += "\treturn ImageTexture.create_from_image(img)\n"
	code += "\n"
	code += "func load_character_resources():\n"
	code += "\t# 复用 CharacterNode 的节点结构/接口，但不用它的 res:// 资源加载逻辑\n"
	code += "\texpressions.clear()\n"
	code += "\tvar base_path := _abs_path(_BASE_REL)\n"
	code += "\tvar base_tex = _load_texture_any(base_path)\n"
	code += "\tif base_tex != null:\n"
	code += "\t\tbase_sprite.texture = base_tex\n"
	code += "\telse:\n"
	code += "\t\tpush_error(\"无法加载自定义角色 base：\" + base_path)\n"
	code += "\t\tbase_sprite.texture = null\n"
	code += "\n"
	code += "\tfor expr in expression_list:\n"
	code += "\t\tvar expr_name := str(expr)\n"
	code += "\t\tvar rel = \"\"\n"
	code += "\t\tif _EXPR_REL.has(expr_name):\n"
	code += "\t\t\trel = str(_EXPR_REL.get(expr_name))\n"
	code += "\t\tif rel == \"\":\n"
	code += "\t\t\tcontinue\n"
	code += "\t\tvar expr_path := _abs_path(rel)\n"
	code += "\t\tvar tex = _load_texture_any(expr_path)\n"
	code += "\t\tif tex != null:\n"
	code += "\t\t\texpressions[expr_name] = tex\n"
	code += "\n"
	code += "\tif current_expression != \"\" and current_expression in expressions:\n"
	code += "\t\tface_sprite.texture = expressions[current_expression]\n"
	code += "\telse:\n"
	code += "\t\tface_sprite.texture = null\n"

	return code


func _generate_character_scene_code(_cid: String, script_abs: String, char_data: Dictionary) -> String:
	var base_pos := _vec2_from_any(char_data.get("base_pos", [607.0, 400.0]))
	var base_scale := _vec2_from_any(char_data.get("base_scale", [1.0, 1.0]))
	var face_offset := _vec2_from_any(char_data.get("face_offset", [0.0, 0.0]))
	var face_scale := _vec2_from_any(char_data.get("face_scale", [1.0, 1.0]))

	var code := ""
	code += "[gd_scene load_steps=2 format=3]\n\n"
	code += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_script\"]\n\n" % script_abs
	code += "[node name=\"CharacterNode\" type=\"Node2D\"]\n"
	code += "script = ExtResource(\"1_script\")\n\n"
	code += "[node name=\"CanvasGroup\" type=\"CanvasGroup\" parent=\".\"]\n\n"
	code += "[node name=\"Base\" type=\"Sprite2D\" parent=\"CanvasGroup\"]\n"
	code += "position = Vector2(%s, %s)\n" % [str(base_pos.x), str(base_pos.y)]
	code += "scale = Vector2(%s, %s)\n\n" % [str(base_scale.x), str(base_scale.y)]
	code += "[node name=\"Face\" type=\"Sprite2D\" parent=\"CanvasGroup/Base\"]\n"
	code += "position = Vector2(%s, %s)\n" % [str(face_offset.x), str(face_offset.y)]
	code += "scale = Vector2(%s, %s)\n" % [str(face_scale.x), str(face_scale.y)]
	return code


func _build_compiled_backgrounds(root_dir: DirAccess) -> bool:
	var list: Array = _assets.get("backgrounds", []) as Array
	if list.is_empty():
		return true

	var changed := false
	for i in range(list.size()):
		if typeof(list[i]) != TYPE_DICTIONARY:
			continue
		var entry := list[i] as Dictionary

		var src_rel := str(entry.get("path", "")).replace("\\", "/").trim_prefix("/")
		if src_rel.is_empty():
			continue

		var compiled_rel := str(entry.get("compiled_path", "")).replace("\\", "/").trim_prefix("/")
		if compiled_rel.is_empty():
			compiled_rel = _ensure_unique_rel("%s/%s.png" % [BG_COMPILED_DIR_REL, src_rel.get_file().get_basename()])
			entry["compiled_path"] = compiled_rel
			list[i] = entry
			changed = true

		var out_subdir := compiled_rel.get_base_dir()
		if not out_subdir.is_empty():
			root_dir.make_dir_recursive(out_subdir)

		var src_abs := _project_root + "/" + src_rel
		var dst_abs := _project_root + "/" + compiled_rel

		var zoom := float(entry.get("zoom", 1.0))
		var offset_any: Variant = entry.get("offset", [0.0, 0.0])
		var offset_std := _vec2_from_any(offset_any)

		if not _write_compiled_background_png(src_abs, dst_abs, zoom, offset_std):
			_show_message("提示", "背景导出失败：" + src_rel)
			return false

	if changed:
		_assets["backgrounds"] = list
	return true


func _write_compiled_background_png(src_abs: String, dst_path: String, zoom: float, offset_std: Vector2) -> bool:
	if src_abs.is_empty() or dst_path.is_empty():
		return false
	if not FileAccess.file_exists(src_abs):
		return false

	var img := Image.new()
	var err := img.load(src_abs)
	if err != OK or img.is_empty():
		return false

	img.convert(Image.FORMAT_RGBA8)

	var clamped_zoom := clampf(zoom, 0.2, 6.0)
	var target_w := int(max(1.0, round(float(img.get_width()) * clamped_zoom)))
	var target_h := int(max(1.0, round(float(img.get_height()) * clamped_zoom)))

	var scaled := img
	if target_w != img.get_width() or target_h != img.get_height():
		scaled = img.duplicate()
		scaled.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

	var canvas: Image = Image.create(BG_CANVAS_SIZE.x, BG_CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	var center := Vector2(float(BG_CANVAS_SIZE.x), float(BG_CANVAS_SIZE.y)) * 0.5
	var center_pos := center + offset_std
	var top_left := center_pos - Vector2(float(target_w), float(target_h)) * 0.5
	canvas.blend_rect(scaled, Rect2i(0, 0, target_w, target_h), Vector2i(int(round(top_left.x)), int(round(top_left.y))))

	return canvas.save_png(dst_path) == OK


func _write_file_from_source(src_abs: String, dst_path: String, convert_to_png: bool) -> bool:
	if not convert_to_png:
		var bytes := _read_all_bytes(src_abs)
		if bytes.is_empty():
			return false
		var out := FileAccess.open(dst_path, FileAccess.WRITE)
		if out == null:
			return false
		out.store_buffer(bytes)
		out.close()
		return true

	var img := Image.new()
	var err := img.load(src_abs)
	if err != OK or img.is_empty():
		return false
	return img.save_png(dst_path) == OK


func _collect_used_rel_paths() -> Dictionary:
	var used: Dictionary = {}

	var bgs: Array = _assets.get("backgrounds", []) as Array
	for entry_any in bgs:
		if typeof(entry_any) == TYPE_DICTIONARY:
			var rel := str((entry_any as Dictionary).get("path", "")).replace("\\", "/").trim_prefix("/")
			if not rel.is_empty():
				used[rel] = true
			var compiled := str((entry_any as Dictionary).get("compiled_path", "")).replace("\\", "/").trim_prefix("/")
			if not compiled.is_empty():
				used[compiled] = true

	var mus: Array = _assets.get("music", []) as Array
	for entry_any in mus:
		if typeof(entry_any) == TYPE_DICTIONARY:
			var rel := str((entry_any as Dictionary).get("path", "")).replace("\\", "/").trim_prefix("/")
			if not rel.is_empty():
				used[rel] = true

	var chars: Dictionary = _assets.get("characters", {}) as Dictionary
	for char_any in chars.values():
		if typeof(char_any) != TYPE_DICTIONARY:
			continue
		var char_data := char_any as Dictionary
		var cid := str(char_data.get("id", "")).strip_edges()
		if not cid.is_empty():
			used["characters/%s.tscn" % cid] = true
			used["characters/%s.gd" % cid] = true
		var base_rel := str(char_data.get("base_path", "")).replace("\\", "/").trim_prefix("/")
		if not base_rel.is_empty():
			used[base_rel] = true
		var exprs_any: Variant = char_data.get("expressions", {})
		if typeof(exprs_any) == TYPE_DICTIONARY:
			for expr_any in (exprs_any as Dictionary).values():
				if typeof(expr_any) != TYPE_DICTIONARY:
					continue
				var rel := str((expr_any as Dictionary).get("path", "")).replace("\\", "/").trim_prefix("/")
				if not rel.is_empty():
					used[rel] = true

	return used


func _delete_project_file_if_exists(rel: String) -> void:
	var normalized := rel.replace("\\", "/").trim_prefix("/")
	if normalized.is_empty():
		return
	if normalized.find("..") != -1 or normalized.find("://") != -1:
		return

	var path := _project_root + "/" + normalized
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_all_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return bytes


func _on_back_pressed() -> void:
	if _dirty:
		unsaved_confirm_dialog.popup_centered()
		return
	queue_free()


func _on_unsaved_confirmed_exit() -> void:
	queue_free()


func _suspend_main_menu_bgm() -> void:
	if _main_bgm_suspended:
		return

	var player := _find_main_menu_bgm_player()
	if player == null:
		return

	_main_bgm_player = player
	_main_bgm_stream = player.stream
	_main_bgm_volume_db = player.volume_db
	_main_bgm_was_playing = player.playing
	_main_bgm_was_paused = player.stream_paused
	_main_bgm_playback_pos = player.get_playback_position()

	if player.playing or player.stream_paused:
		player.stream_paused = false
		player.stop()

	_main_bgm_suspended = true


func _resume_main_menu_bgm() -> void:
	if not _main_bgm_suspended:
		return

	_main_bgm_suspended = false

	if _main_bgm_player == null or not is_instance_valid(_main_bgm_player):
		return

	if not _main_bgm_was_playing:
		return

	if _main_bgm_stream != null:
		_main_bgm_player.stream = _main_bgm_stream
	_main_bgm_player.volume_db = _main_bgm_volume_db
	_main_bgm_player.play(_main_bgm_playback_pos)
	_main_bgm_player.stream_paused = _main_bgm_was_paused


func _find_main_menu_bgm_player() -> AudioStreamPlayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	var direct := scene.get_node_or_null("BGMPlayer")
	if direct is AudioStreamPlayer:
		return direct as AudioStreamPlayer

	var found := scene.find_child("BGMPlayer", true, false)
	return found as AudioStreamPlayer
