extends Logger
class_name UE_LOGGER

var log_path:String = ''
var mutex:Mutex = Mutex.new()

func set_log_file(path:String) -> void:
	log_path = path

func _log_message(message:String, error:bool) -> void:
	if log_path == '':
		return
	mutex.lock()
	if not FileAccess.file_exists(log_path):
		var fc:FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
		if fc:
			fc.close()
	var f:FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_string('[%s] %s%s' % [Time.get_datetime_string_from_system(), message, '\n'])
		f.close()
	mutex.unlock()
