extends RefCounted

# Only generated server health files use this worker. Never invoke account
# preference callbacks or touch scene objects from the writer thread.
var worker:=Thread.new()
var wake:=Semaphore.new()
var lock:=Mutex.new()
var pending_path:=""
var pending: Dictionary={}
var stopping:=false
var last_error:=OK

func submit(path: String,data: Dictionary) -> Error:
	if not worker.is_started():
		stopping=false
		var error:=worker.start(_run)
		if error!=OK:return error
	lock.lock()
	var notify:=pending_path.is_empty()
	pending_path=path;pending=data.duplicate(true)
	lock.unlock()
	if notify:wake.post()
	return OK

func _run() -> void:
	while true:
		wake.wait()
		lock.lock()
		var path:=pending_path;var data:=pending;var finish:=stopping
		pending_path="";pending={}
		lock.unlock()
		if not path.is_empty():
			var error:=_write(path,data)
			lock.lock();last_error=error;lock.unlock()
		if finish:return

func _write(path: String,data: Dictionary) -> Error:
	var error:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK:return error
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	error=file.get_error();file.close()
	if error!=OK:return error
	return DirAccess.rename_absolute(path+".tmp",path)

func close() -> void:
	if not worker.is_started():return
	lock.lock();stopping=true;lock.unlock()
	wake.post();worker.wait_to_finish()
	# A worker can finish its final write before consuming the shutdown wake.
	# Reset both primitives before this game node hosts another room.
	wake=Semaphore.new();stopping=false

func error() -> Error:
	lock.lock();var result:=last_error;lock.unlock()
	return result
