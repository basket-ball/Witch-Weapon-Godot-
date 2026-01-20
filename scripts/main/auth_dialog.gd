extends Control

signal closed
signal auth_success

@onready var background: ColorRect = $"Background"
@onready var close_button: Button = $"WindowPanel/Margin/Content/Header/CloseButton"

@onready var logged_in_row: HBoxContainer = $"WindowPanel/Margin/Content/LoggedInRow"
@onready var logged_in_label: Label = $"WindowPanel/Margin/Content/LoggedInRow/LoggedInLabel"
@onready var logout_button: Button = $"WindowPanel/Margin/Content/LoggedInRow/LogoutButton"

@onready var tabs: TabContainer = $"WindowPanel/Margin/Content/Tabs"
@onready var status_label: Label = $"WindowPanel/Margin/Content/StatusLabel"

@onready var login_email: LineEdit = $"WindowPanel/Margin/Content/Tabs/Login/Email"
@onready var login_password: LineEdit = $"WindowPanel/Margin/Content/Tabs/Login/Password"
@onready var login_code: LineEdit = $"WindowPanel/Margin/Content/Tabs/Login/Code"
@onready var login_send_code_button: Button = $"WindowPanel/Margin/Content/Tabs/Login/SendCodeButton"
@onready var login_verify_button: Button = $"WindowPanel/Margin/Content/Tabs/Login/VerifyButton"

@onready var reg_email: LineEdit = $"WindowPanel/Margin/Content/Tabs/Register/Email"
@onready var reg_password: LineEdit = $"WindowPanel/Margin/Content/Tabs/Register/Password"
@onready var reg_code: LineEdit = $"WindowPanel/Margin/Content/Tabs/Register/Code"
@onready var reg_send_code_button: Button = $"WindowPanel/Margin/Content/Tabs/Register/SendCodeButton"
@onready var reg_verify_button: Button = $"WindowPanel/Margin/Content/Tabs/Register/VerifyButton"

var _busy: bool = false

func _ready() -> void:
	close_button.pressed.connect(_close)
	logout_button.pressed.connect(_on_logout_pressed)
	background.gui_input.connect(_on_background_gui_input)

	login_send_code_button.pressed.connect(_on_send_code_pressed.bind(false))
	login_verify_button.pressed.connect(_on_verify_pressed.bind(false))
	reg_send_code_button.pressed.connect(_on_send_code_pressed.bind(true))
	reg_verify_button.pressed.connect(_on_verify_pressed.bind(true))

	if has_node("/root/AuthManager"):
		var am := get_node("/root/AuthManager")
		am.auth_state_changed.connect(func(_is_logged_in: bool): _refresh_logged_in_ui())
		am.profile_changed.connect(func(_p: Dictionary): _refresh_logged_in_ui())

	_refresh_logged_in_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _refresh_logged_in_ui() -> void:
	if not has_node("/root/AuthManager"):
		logged_in_row.visible = false
		return

	var is_in: bool = AuthManager.is_logged_in()
	logged_in_row.visible = is_in
	if is_in:
		var mail: String = str(AuthManager.email)
		logged_in_label.text = ("已登录：%s" % mail) if mail != "" else "已登录"

func _set_busy(busy: bool) -> void:
	_busy = busy
	login_send_code_button.disabled = busy
	login_verify_button.disabled = busy
	reg_send_code_button.disabled = busy
	reg_verify_button.disabled = busy
	logout_button.disabled = busy

func _validate_email(s: String) -> bool:
	return s.strip_edges().find("@") != -1

func _on_send_code_pressed(is_register: bool) -> void:
	if _busy or not has_node("/root/AuthManager"):
		return

	var email_in := (reg_email.text if is_register else login_email.text).strip_edges()
	var password_in := reg_password.text if is_register else login_password.text

	if not _validate_email(email_in):
		_set_status("请输入正确的邮箱。")
		return
	if password_in.strip_edges() == "":
		_set_status("请输入密码。")
		return

	_set_busy(true)
	_set_status("正在发送验证码…")
	var res: Dictionary = await AuthManager.send_code(email_in, password_in, is_register)
	_set_busy(false)

	if res.get("ok", false):
		_set_status("验证码已发送，请查收邮箱。")
	else:
		_set_status("发送失败(%s)：%s" % [str(res.get("status", 0)), _extract_error(res)])

func _on_verify_pressed(is_register: bool) -> void:
	if _busy or not has_node("/root/AuthManager"):
		return

	var email_in := (reg_email.text if is_register else login_email.text).strip_edges()
	var code_in := (reg_code.text if is_register else login_code.text).strip_edges()

	if not _validate_email(email_in):
		_set_status("请输入正确的邮箱。")
		return
	if code_in == "":
		_set_status("请输入验证码。")
		return

	_set_busy(true)
	_set_status("正在验证…")
	var res: Dictionary = await AuthManager.verify_code(email_in, code_in)
	if res.get("ok", false):
		await AuthManager.fetch_profile()
		_set_busy(false)
		_set_status("登录成功。")
		auth_success.emit()
		_close()
		return

	_set_busy(false)
	_set_status("验证失败(%s)：%s" % [str(res.get("status", 0)), _extract_error(res)])

func _on_logout_pressed() -> void:
	if _busy or not has_node("/root/AuthManager"):
		return
	AuthManager.logout()
	_refresh_logged_in_ui()
	_set_status("已退出登录。")

func _set_status(msg: String) -> void:
	status_label.text = msg

func _extract_error(res: Dictionary) -> String:
	if res.has("error"):
		return str(res["error"])
	var data = res.get("data")
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("message"):
			return str(data["message"])
		if data.has("error"):
			return str(data["error"])
	return str(res.get("raw", ""))
