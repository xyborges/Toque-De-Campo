extends "res://modes/battle_royale/matchmaking/broker.gd"
## Test-only trust anchor. Production router always uses NavalAccounts.
var issuer_public: CryptoKey
func _verify_profile(envelope: Dictionary,device: String) -> Dictionary:
	var payload:=str(envelope.get("payload",""))
	if not issuer_public or payload.length()>16000:return {}
	if not Crypto.new().verify(HashingContext.HASH_SHA256,payload.sha256_buffer(),Marshalls.base64_to_raw(str(envelope.get("signature",""))),issuer_public):return {}
	var profile: Variant=JSON.parse_string(Marshalls.base64_to_utf8(payload))
	if not profile is Dictionary or str(profile.get("device",""))!=device or float(profile.get("expires",0.))<Time.get_unix_time_from_system():return {}
	return profile
