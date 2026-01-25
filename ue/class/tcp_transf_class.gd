extends Node
class_name TCP_TRANSF_C

var serverip:String = "0.0.0.0"
var serverport:int = 0
var error_retry_cnt:int = 3
var _socket:StreamPeerTCP = StreamPeerTCP.new()

var rec_data_thread:Thread = null
var rec_data_running:bool = false
var upload_thread:Thread = null
var upload_running:bool = false
var download_thread:Thread = null
var download_running:bool = false
var write_thread:Thread = null
var write_running:bool = false

var req_upload_ack:Dictionary = {}
var req_download_ack:Dictionary = {}

var tmp_format:String = '.dtmp'
var dl_tmpfilepath:String = ''
var dl_buffer:Array = []
var dl_mute:Mutex = Mutex.new()
var crc32_class:CRC32_C = CRC32_C.new()
var UPLOAD_BUF_SIZE:int = 4096

signal connection_status_changed(is_connected:bool, message:String)

var upload_file:String = r''
var download_file:String = r''
var download_dir:String = r''
var error_cnt = 1

func _init(sip, sport, ercnt=3) -> void:
	serverip = sip
	serverport = sport
	error_retry_cnt = ercnt
	connection_status_changed.connect(_on_status_changed)

############################## connection ###################
func connect_to_server() -> void:
	var socket_status = _socket.get_status()
	if socket_status in [StreamPeerTCP.STATUS_CONNECTED, StreamPeerTCP.STATUS_CONNECTING]:
		return
	req_upload_ack = {}
	req_download_ack = {}
	upload_running = false
	download_running = false
	dl_tmpfilepath = r''
	dl_buffer = []
	rec_data_running = true
	
	emit_signal("connection_status_changed", true, 'connecting... ...')
	var error = _socket.connect_to_host(serverip, serverport)
	match error:
		OK:
			_socket.poll()
			emit_signal("connection_status_changed", true, 'success connected to %s:%s'%[serverip, serverport])
			rec_data_thread = Thread.new()
			rec_data_thread.start(receiving_data_thread)
		_:
			emit_signal("connection_status_changed", true, 'unknown error')
			
func disconnect_to_server() -> void:
	rec_data_running = false
	download_running = false
	rec_data_running = false
	write_running = false
	req_upload_ack = {}
	req_download_ack = {}
	upload_running = false
	download_running
	dl_tmpfilepath = r''
	dl_buffer = []
	var socket_status = _socket.get_status()
	if socket_status != StreamPeerTCP.STATUS_CONNECTED:
		emit_signal("connection_status_changed", true, 'not connected')
		return
	_socket.disconnect_from_host()
	emit_signal("connection_status_changed", true, 'success disconnected to %s:%s'%[serverip, serverport])
	
	
	
#############################  upload ########################
func upload_a_file(filepath) -> void:
	upload_file = filepath
	connect_to_server()
	upload_running = true
	upload_thread = Thread.new()
	upload_thread.start(upload_a_file_thread.bind(filepath))
	
func upload_a_file_thread(filepath) -> void:
	var loop_cnt:int = 0
	while upload_running and loop_cnt <= 3:
		var stime = Time.get_ticks_msec()
		print("will send req_upload, cnt=%s, socket_status:%s"%[loop_cnt, _socket.get_status()])
		request_upload(filepath)
		while req_upload_ack.size() == 0:
			var ctime = Time.get_ticks_msec()
			if ctime - stime > 3 * 1000:
				loop_cnt += 1
				break
		if req_upload_ack.size() > 0:
			break
	var rt_status = req_upload_ack.get('status', '')
	if rt_status == 'OK':
		upload_running = true
		upload_data(filepath, req_upload_ack.get('offset', 0))
	else:
		print('upload failed:%s'%[req_upload_ack.get('message', 'unknown error')])
		disconnect_to_server()
		
func upload_data(filepath, offset) -> void:
	var uploadfile = FileAccess.open(filepath, FileAccess.READ)
	if uploadfile == null:
		return
	uploadfile.seek(offset)
	var files_size:int = FileAccess.get_size(filepath)
	var dat_format:PackedByteArray = "|GD>SV|DO:".to_utf8_buffer()
	var idx = 0
	while upload_running and offset < files_size:
		var block:PackedByteArray = uploadfile.get_buffer(UPLOAD_BUF_SIZE)
		var block_len:PackedByteArray = ("%04X"%[block.size() + 6 + 8]).to_utf8_buffer()
		var idxx:PackedByteArray = ("%06X"%[idx]).to_utf8_buffer()
		var crc:PackedByteArray = ("%08X"%[crc32_class.fCRC32(block)]).to_utf8_buffer()
		var frame:PackedByteArray = dat_format + block_len + idxx + block + crc
		_socket.put_data(frame)
		offset += block.size()
		idx += 1
	if upload_running == false and req_upload_ack.get('status', '') == 'FINISH':
		request_a_message({'req_type':'upload', 'status':'FINISH'})


######################### download #########################
func download_a_file(filedir, filename, file_size, md5) -> void:
	download_file = filename
	download_dir = filedir
	connect_to_server()
	var dl_dir = DirAccess.open(download_dir)
	if not dl_dir:
		DirAccess.make_dir_absolute(download_dir)
	dl_tmpfilepath = download_dir.path_join(filedir).path_join("%s_%s_%s"%[md5, filename, tmp_format])
	var offset = 0
	if FileAccess.file_exists(dl_tmpfilepath):
		offset = FileAccess.get_size(dl_tmpfilepath)
	download_running = true
	write_running = true
	download_thread = Thread.new()
	download_thread.start(download_a_file_thread.bind(filedir, filename, file_size, md5, offset))
	write_thread = Thread.new()
	write_thread.start(write_a_file_thread.bind(filedir, filename, file_size, md5, offset))

func download_a_file_thread(filedir, filename, file_size, md5, offset) -> void:
	var stime = Time.get_ticks_msec()
	var loop_cnt = 0
	while download_running and loop_cnt <= 3:
		request_download(filedir, filename, file_size, md5, offset)
		while req_download_ack.size() == 0:
			var ctime = Time.get_ticks_msec()
			if ctime - stime > 3 * 1000:
				loop_cnt += 1
				break
		if req_download_ack.size() > 0:
			break
	var rt_status = req_download_ack.get('status', '')
	if rt_status == 'OK':
		download_running = true
		request_a_message(
			{'status': 'OK', 
			'file_size' :file_size,
			'filename': filename,
			'md5': md5,
			'offset': offset,
			})
	else:
		print('download failed:%s'%[req_download_ack.get('message', 'unknown error')])
		disconnect_to_server()


#####################  receive data #########################
func receiving_data_thread():
	while rec_data_running:
		if _socket and _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var rec_len = _socket.get_available_bytes()
			if rec_len > 0:
				var data = _socket.get_data(rec_len)
				if data[0] == Error.OK:
					if data[1].size() > 0:
						var hd:Array = received_get_header(data[1])
						received_and_deal_data(hd[0], hd[1])
						
func received_and_deal_data(header:String, data:PackedByteArray) -> void:
	if header == '|SV>GD|RQ:':
		var r:Dictionary = receive_parser_req_data(header + data.get_string_from_utf8())
		print("|SV>GD|RQ: %s is :"%[len(header) + len(data)], r)
		var req_type = r.data.get('req_type', '')
		if req_type == 'upload':
			req_upload_ack = r.data
			var status = req_upload_ack.get('status', '')
			if status in ['ERROR3', 'ERROR4', 'ERROR5']:
				if error_retry_cnt > 0:
					print("!!!! receive error from server:%s, will retry %s" % [status, error_retry_cnt])
					error_retry_cnt += 1
					disconnect_to_server()
					connect_to_server()
					upload_a_file(upload_file)
				else:
					disconnect_to_server()
		elif req_type == 'download':
			req_download_ack = r.data
	elif header == '|SV>GD|DO:':
		dl_buffer.append(data)
		
func receive_parser_req_data(data:String):
	var data_size:String = data.substr(10, 4)
	if not data_size.is_valid_hex_number():
		return {'r':false, 'detail':'date size error', 'data':{}}
	var data_size_int:int = data_size.hex_to_int()
	if data_size_int <= 8:
		return {'r':false, 'detail':'date size < 8', 'data':{}}
	if len(data) < data_size_int + 14:
		return {'r':false, 'detail':'date size too short', 'data':{}}
	var _data:String = data.substr(14, data_size_int)
	var data_block:String = _data.substr(0, data_size_int - 8)
	var crc = _data.substr(data_size_int - 8, 8)
	if not crc.is_valid_hex_number():
		return {'r':false, 'detail':'crc error', 'data':{}}
	var crc_int:int = crc.hex_to_int()
	var crc_check:int = crc32_class.fCRC32(data_block.to_utf8_buffer())
	if crc_int != crc_check:
		return {'r':false, 'detail':'date size error', 'data':{}}
	var parser = JSON.new()
	var err = parser.parse(data_block)
	if err == OK:
		return {'r':true, 'detail':'', 'data':parser.data}
	return {'r':false, 'detail':'null', 'data':{}}
	
func received_get_header(data:PackedByteArray) -> Array:
	var p1:PackedByteArray = data.slice(0, 10)
	var p2:PackedByteArray = data.slice(10, data.size())
	var header:String = p1.get_string_from_utf8()
	return [header, p2]
	
	
###################  write files #############################
func write_a_data_block(f:FileAccess, data_block:PackedByteArray, preidx:int) -> Dictionary:
	var data_size:String = data_block.slice(0, 4).get_string_from_utf8()
	if not data_size.is_valid_hex_number():
		return {'s':0, 'd':1, 'idx':preidx}
	var data_size_int:int = data_size.hex_to_int()
	if data_size_int <= 18:
		return {'s':0, 'd':2, 'idx':preidx}
	if len(data_block) != data_size_int + 4:
		return {'s':0, 'd':3, 'idx':preidx}
	var crc:String = data_block.slice(data_size_int - 8 + 4, data_size_int + 4).get_string_from_utf8()
	if not crc.is_valid_hex_number():
		return {'s':0, 'd':4, 'idx':preidx}
	var idx = data_block.slice(4, 10).get_string_from_utf8()
	if not idx.is_valid_hex_number():
		return {'s':0, 'd':5, 'idx':preidx}
	var idxint:int = idx.hex_to_int()
	if idxint != 0 and idxint - preidx != 1:
		return {'s':0, 'd':6, 'idx':preidx}
	var data_payload:PackedByteArray = data_block.slice(10, data_size_int - 8 + 4)
	var crc_int:int = crc.hex_to_int()
	var crc_check:int = crc32_class.fCRC32(data_payload)
	if crc_int != crc_check:
		return {'s':0, 'd':7, 'idx':preidx}
	if f:
		f.seek_end()
	var r = f.store_buffer(data_payload)
	return {'s':data_payload.size(), 'd':-1, 'idx':idxint}

func write_a_file_thread(filedir, filename, file_size, md5, offset):
	while not download_running:
		pass
	var f = FileAccess.open(dl_tmpfilepath, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
	else:
		f = FileAccess.open(dl_tmpfilepath, FileAccess.WRITE)
	var current_size:int = offset
	var idx = -1
	var need_retry = false
	while download_running:
		var data_block:PackedByteArray = []
		dl_mute.lock()
		if dl_buffer.size() > 0:
			data_block = dl_buffer.pop_front()
		dl_mute.unlock()
		if data_block:
			var r:Dictionary = write_a_data_block(f, data_block, idx)
			if r['s'] == 0 and r['d'] in [4, 5, 6, 7]:
				need_retry = true
				break
			current_size += r['s']
			idx = r['idx']
			if error_cnt > 0 and current_size >= file_size * 0.3:
				error_cnt -= 1
				download_running = false
			if current_size >= file_size:
				download_running = false
	f.close()
	var md5_check = FileAccess.get_md5(dl_tmpfilepath)
	if md5 == md5_check:
		DirAccess.rename_absolute(dl_tmpfilepath, download_dir.path_join(filename))
		print('download finish!!')
	else:
		need_retry = true
	if need_retry:
		print('md5 error!!!!')
		disconnect_to_server()
		connect_to_server()
		download_a_file(filedir, filename, file_size, md5)
	
				
func request_download(filedir, filename, file_size, md5, offset):
	var data = {
		'req_type': 'download',
		'filedir': filedir,
		'filename': filename,
		'file_size': file_size,
		'file_md5': md5,
		'offset': offset,
		'status': '-'}
	request_a_message(data)

	
func request_upload(filepath) -> void:
	if not FileAccess.file_exists(filepath):
		return
	var filename = filepath.get_file()
	var data = {
		'req_type': 'upload',
		'filename': filename,
		'file_size': FileAccess.get_size(filepath),
		'file_md5': FileAccess.get_md5(filepath)}
	request_a_message(data)

func request_a_message(req_dic:Dictionary):
	print("|GD>SV|%s is "%[_socket.get_status()], req_dic)
	if _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var json_string = JSON.stringify(req_dic)
		var crcv = "%08X"%[crc32_class.fCRC32(json_string.to_utf8_buffer())]
		_socket.put_data(("|GD>SV|RQ:" + "%04X"%[len(json_string) + 8] + json_string + crcv).to_utf8_buffer())
	else:
		print('disconnect, send message failed')
	
func _on_status_changed(is_connected:bool, msg:String):
	print('[TCP Status] %s' % [msg])
