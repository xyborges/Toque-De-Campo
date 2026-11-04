extends Node
class_name NavalAccounts
signal changed
signal connection_state(result: int, http_status: int)
var token := ""
var profile: Dictionary = {}
var ticket: Dictionary = {}
var busy := false
var client_key: CryptoKey
var persist_session := true
var service_auth := false
var api_url := ""
var ca_path := ""
var session_generation := 0
var validated_session := false
var preferences_sync: GameAccountPreferences

static func testing() -> bool:
	return "--naval-test-accounts" in OS.get_cmdline_user_args() and (OS.has_feature("editor") or OS.has_feature("qa"))

func _ready() -> void:
	var config := NavalStorage.read_json("res://assets/accounts/config.json")
	api_url = str(config.get("url",""))
	ca_path = str(config.get("ca",""))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--accounts-service-token="):
			token = FileAccess.get_file_as_string(arg.trim_prefix("--accounts-service-token=")).strip_edges()
			service_auth = true
			persist_session = false
	if not service_auth:
		load_session()
		preferences_sync=GameAccountPreferences.new();preferences_sync.setup(self);add_child(preferences_sync)

func device_key() -> CryptoKey:
	return client_key if client_key != null else NavalStorage.client_key()

func _cache_password() -> String:
	var key := device_key()
	return key.save_to_string().sha256_text() if key else ""

func load_session() -> void:
	var path := NavalStorage.folder().path_join("account-session.dat")
	if not FileAccess.file_exists(path): return
	var file := FileAccess.open_encrypted_with_pass(path,FileAccess.READ,_cache_password())
	if file == null: return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return
	token = str(data.get("token",""))
	profile = data.get("profile",{})
	ticket = data.get("ticket",{})

func save_session() -> void:
	if not persist_session: return
	var file := FileAccess.open_encrypted_with_pass(NavalStorage.folder().path_join("account-session.dat"),FileAccess.WRITE,_cache_password())
	if file: file.store_string(JSON.stringify({"token":token,"profile":profile,"ticket":ticket}))

func call_api(action: String, values: Dictionary = {}) -> Dictionary:
	var generation:=session_generation
	var response:=await _call_api_once(action,values)
	# Refreshing a profile is read-only. Retry a transport failure once so a
	# transient VPN/TLS failure does not leave deployment stuck after login.
	# Purchases, rewards and authentication are never replayed here.
	if action=="profile" and bool(response.get("_retry_profile",false)) and generation==session_generation:
		await get_tree().create_timer(.25).timeout
		if generation==session_generation: response=await _call_api_once(action,values)
	response.erase("_retry_profile")
	return response

func _call_api_once(action: String, values: Dictionary = {}) -> Dictionary:
	var generation:=session_generation
	if not api_url.begins_with("https://"):
		connection_state.emit(HTTPRequest.RESULT_CANT_CONNECT,0)
		return {"ok":false,"error":"O servidor de contas precisa usar HTTPS."}
	var request := HTTPRequest.new()
	# Loading a large 3D map may stall a render frame while shaders compile.
	# TLS/HTTP progress must not depend on those frames or consume its entire
	# timeout waiting for the rendering thread to become responsive.
	request.use_threads=true
	request.timeout = 8.0
	request.body_size_limit = 32000
	request.max_redirects = 0
	add_child(request)
	if not ca_path.is_empty():
		var cert := X509Certificate.new()
		if cert.load(ca_path) != OK:
			connection_state.emit(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,0)
			request.queue_free()
			return {"ok":false,"error":"Certificado do servidor de contas indisponível."}
		request.set_tls_options(TLSOptions.client(cert))
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty(): headers.append(("Authorization: Service " if service_auth else "Authorization: Bearer ")+token)
	var payload := values.duplicate(true)
	payload.action = action
	var error := request.request(api_url,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))
	if error != OK:
		connection_state.emit(HTTPRequest.RESULT_CANT_CONNECT,0)
		request.queue_free()
		return {"ok":false,"error":"Não foi possível acessar o servidor de contas."}
	var response: Array = await request.request_completed
	if generation!=session_generation:
		request.queue_free()
		return {"ok":false,"error":"Operação de uma sessão anterior descartada."}
	connection_state.emit(int(response[0]),int(response[1]))
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS: return {"ok":false,"error":"Sem conexão segura com o servidor de contas. Verifique a rede.","_retry_profile":true}
	var decoded: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if not decoded is Dictionary: return {"ok":false,"error":"Resposta inválida do servidor de contas."}
	if bool(decoded.get("ok",false)) and decoded.has("profile"):
		var verified := verify_ticket(decoded.get("ticket",{}),device_key().save_to_string(true).sha256_text())
		if verified.is_empty(): return {"ok":false,"error":"Assinatura do perfil inválida."}
		validated_session=true
		if profile.get("id","")==verified.id and int(profile.get("revision",0))>int(verified.revision):
			return {"ok":true,"profile":profile,"ticket":ticket}
		profile = decoded.profile
		ticket = decoded.ticket
		if decoded.has("token"): token = str(decoded.token)
		save_session()
		if action in ["login","register","profile"] and is_instance_valid(preferences_sync):
			await preferences_sync.activate(str(profile.id),generation)
			if generation!=session_generation: return {"ok":false,"error":"Operação de uma sessão anterior descartada."}
		changed.emit()
	elif int(response[1]) == 401 and action not in ["login","register"]:
		validated_session=false
		token = ""
		ticket.clear()
		save_session()
	return decoded

func sign_in(action: String, username: String, password: String) -> Dictionary:
	session_generation+=1
	var user := username.strip_edges().to_lower()
	var nonce := NavalCatalog.uid()
	var key := device_key()
	var signature := Crypto.new().sign(HashingContext.HASH_SHA256,("tdc-auth:"+user+":"+nonce).sha256_buffer(),key)
	return await call_api(action,{"username":user,"password":password,"public_key":key.save_to_string(true),"nonce":nonce,"proof":Marshalls.raw_to_base64(signature)})

func logout() -> void:
	if is_instance_valid(preferences_sync): preferences_sync.deactivate()
	validated_session=false
	session_generation+=1
	var generation:=session_generation
	if not token.is_empty(): await call_api("logout")
	if generation!=session_generation: return
	token = ""
	profile.clear()
	ticket.clear()
	save_session()
	changed.emit()

static func verify_ticket(envelope: Dictionary, device := "") -> Dictionary:
	var payload := str(envelope.get("payload",""))
	if payload.length()>16000 or payload.is_empty(): return {}
	var key := CryptoKey.new()
	if key.load("res://assets/accounts/accounts-public.pem",true) != OK: return {}
	if not Crypto.new().verify(HashingContext.HASH_SHA256,payload.sha256_buffer(),Marshalls.base64_to_raw(str(envelope.get("signature",""))),key): return {}
	var data: Variant = JSON.parse_string(Marshalls.base64_to_utf8(payload))
	if not data is Dictionary: return {}
	var now := Time.get_unix_time_from_system()
	if float(data.get("expires",0))<now or float(data.get("expires",0))>now+1800: return {}
	if data.get("issuer") != "toque-accounts-v1" or (not device.is_empty() and data.get("device") != device): return {}
	if not data.get("owned") is Array or data.owned.size()>5 or "light" not in data.owned: return {}
	for ship in data.owned:
		if not NavalCatalog.SHIPS.has(ship): return {}
	if data.get("selected") not in data.owned or str(data.get("id","")).length()!=32: return {}
	data["transactions"] = {}
	return data
