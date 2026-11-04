extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var crypto := Crypto.new()
	if args.size() == 3 and args[0] == "keygen":
		var private_key := crypto.generate_rsa(3072)
		if private_key.save(args[1]) != OK or private_key.save(args[2], true) != OK:
			quit(1)
		else:
			quit(0)
	elif args.size() == 4 and args[0] == "sign":
		var private_key := CryptoKey.new()
		if private_key.load(args[1]) != OK:
			quit(1)
			return
		var payload := FileAccess.get_file_as_bytes(args[2])
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(payload)
		var signature := crypto.sign(HashingContext.HASH_SHA256, digest.finish(), private_key)
		var envelope := {"payload":Marshalls.raw_to_base64(payload), "signature":Marshalls.raw_to_base64(signature)}
		var output := FileAccess.open(args[3], FileAccess.WRITE)
		if output == null or signature.is_empty():
			quit(1)
			return
		output.store_string(JSON.stringify(envelope))
		output.close()
		quit(0)
	else:
		quit(2)
