extends Node

signal auth_state_changed(is_logged_in: bool)
signal profile_changed(profile: Dictionary)

const BASE_URL := "https://auth.witchweapon.wiki"

var _http: HTTPRequest

var access_token: String = ""
var refresh_token: String = ""
var expires_at_unix: int = 0
var email: String = ""
var profile: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	_load_from_config()

func is_logged_in() -> bool:
	return access_token != "" and Time.get_unix_time_from_system() < expires_at_unix

func logout() -> void:
	access_token = ""
	refresh_token = ""
	expires_at_unix = 0
	email = ""
	profile = {}
	_save_to_config()
	auth_state_changed.emit(false)
	profile_changed.emit(profile)

func send_code(email_in: String, password_in: String, is_register: bool) -> Dictionary:
	var path := "/api/auth/register/send-code" if is_register else "/api/auth/login/send-code"
	var payload := {
		"email": email_in,
		"password": password_in,
		"type": "register" if is_register else "login",
	}
	return await _request_json(path, HTTPClient.METHOD_POST, payload, PackedStringArray())

func verify_code(email_in: String, code: String) -> Dictionary:
	var payload := {"email": email_in, "code": code}
	var res := await _request_json("/api/auth/verify", HTTPClient.METHOD_POST, payload, PackedStringArray())
	if not res.get("ok", false):
		return res

	var data := res.get("data")
	if typeof(data) == TYPE_DICTIONARY:
		access_token = str(data.get("access_token", ""))
		refresh_token = str(data.get("refresh_token", ""))
		var expires_in := int(data.get("expires_in", 0))
		expires_at_unix = int(Time.get_unix_time_from_system()) + max(expires_in, 0)
		email = email_in
		_save_to_config()
		auth_state_changed.emit(is_logged_in())
	return res

func fetch_profile() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "status": 0, "error": "not_logged_in"}
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % access_token,
	])
	var res := await _request_json("/api/user/profile", HTTPClient.METHOD_GET, {}, headers)
	if res.get("ok", false) and typeof(res.get("data")) == TYPE_DICTIONARY:
		profile = res["data"]
		_save_to_config()
		profile_changed.emit(profile)
	return res

func _request_json(path: String, method: int, payload: Dictionary, extra_headers: PackedStringArray) -> Dictionary:
	var url := BASE_URL + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	for h in extra_headers:
		headers.append(h)

	var body := ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var err := _http.request(url, headers, method, body)
	if err != OK:
		return {"ok": false, "status": 0, "error": "request_failed_%s" % err}

	var completed := await _http.request_completed
	var result := int(completed[0])
	var response_code := int(completed[1])
	var response_body: PackedByteArray = completed[3]

	var raw := response_body.get_string_from_utf8()
	var parsed := JSON.parse_string(raw)
	var ok := (result == HTTPRequest.RESULT_SUCCESS) and response_code >= 200 and response_code < 300

	return {
		"ok": ok,
		"result": result,
		"status": response_code,
		"data": parsed,
		"raw": raw,
	}

func _load_from_config() -> void:
	access_token = str(GameConfig.get_setting("auth", "access_token", ""))
	refresh_token = str(GameConfig.get_setting("auth", "refresh_token", ""))
	expires_at_unix = int(GameConfig.get_setting("auth", "expires_at_unix", 0))
	email = str(GameConfig.get_setting("auth", "email", ""))
	profile = GameConfig.get_setting("auth", "profile", {})
	auth_state_changed.emit(is_logged_in())
	profile_changed.emit(profile)

func _save_to_config() -> void:
	GameConfig.set_setting("auth", "access_token", access_token)
	GameConfig.set_setting("auth", "refresh_token", refresh_token)
	GameConfig.set_setting("auth", "expires_at_unix", expires_at_unix)
	GameConfig.set_setting("auth", "email", email)
	GameConfig.set_setting("auth", "profile", profile)
	GameConfig.save()

