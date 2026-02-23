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
var if_download_sys:bool = false
var write_thread:Thread = null
var write_running:bool = false

var req_upload_ack:Dictionary = {}
var req_download_ack:Dictionary = {}
var req_login_ack:Dictionary = {}

var tmp_format:String = '.dtmp'
var dl_tmpfilepath:String = ''
var dl_buffer:Array = []
var dl_l2_buffer:Array = []
var dl_mute:Mutex = Mutex.new()
var crc32_class:CRC32_C = CRC32_C.new()
var UPLOAD_BUF_SIZE:int = 1024

var usr:String = ''
var psd:String = ''
var overwrite = 'no'
var taskid:String = ''

signal report_result(who_i_am:String, taskid:String, req_type:String, infor:String, result:String)

var root_dir:String = ''
var upload_file:String = r''
var download_file:String = r''
var log_window = null
var error_cnt = 0

func _init(log_win, _taskid, rootdir, sip, sport, _usr, _psd, ercnt=3, ow='no') -> void:
	log_window = log_win
	taskid = _taskid
	root_dir = rootdir
	serverip = sip
	serverport = sport
	usr = _usr
	psd = _psd
	overwrite = ow
	error_retry_cnt = ercnt

############################## connection ###################
func connect_to_server(poolmax=10) -> void:
	log_window.add_log("[tcp_transf_class]->connect_to_server.")
	var socket_status = _socket.get_status()
	if socket_status in [StreamPeerTCP.STATUS_CONNECTED, StreamPeerTCP.STATUS_CONNECTING]:
		return
	req_upload_ack = {}
	req_download_ack = {}
	upload_running = false
	download_running = false
	if_download_sys = false
	dl_tmpfilepath = r''
	dl_buffer = []
	rec_data_running = true
	
	var error = _socket.connect_to_host(serverip, serverport)
	match error:
		OK:
			var stime:int = Time.get_ticks_msec()
			while _socket.get_status() == StreamPeerTCP.STATUS_CONNECTING:
				_socket.poll()
				if Time.get_ticks_msec() - stime > poolmax * 1000:
					break
			rec_data_thread = Thread.new()
			rec_data_thread.start(receiving_data_thread)
		_:
			log_window.add_log('[tcp_transf_class]->connect_to_server:connect error:%s'%[error])
	log_window.add_log("[tcp_transf_class]->connect_to_server:%s"%_socket.get_status())
func query_files(filedic:Dictionary) -> void:
	log_window.add_log('[tcp_transf_class]->query_files:%s'%[';'.join(filedic.keys())])
	connect_to_server()
	var r = login_do()
	if not r:
		log_window.add_log('[tcp_transf_class]->query_files:login failed!')
		disconnect_to_server()
		return
	var filestr:String = JSON.stringify(filedic)
	request_a_message({
		'req_type': 'query',
		'status': '-',
		'filedic': filestr,
	})
	
func login_do(loopmax=3) -> bool:
	log_window.add_log("[tcp_transf_class]->login_do.")
	if _socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		log_window.add_log("[tcp_transf_class]->login_do failed due to _socket status is %s"%[_socket.get_status()])
		return false
	var stime = Time.get_ticks_msec()
	var loop_cnt = 0
	while loop_cnt < loopmax:
		request_a_message({
			"req_type": 'login',
			"status": '-',
			"usr": usr,
			"psd": psd.sha256_text()
		})
		while req_login_ack.size() == 0:
			var ctime = Time.get_ticks_msec()
			if ctime - stime > 3 * 1000:
				loop_cnt += 1
				break
		if req_login_ack.size() > 0:
			break
	var rt_status =  req_login_ack.get('status', '')
	if rt_status == 'OK':
		emit_signal("report_result", "tcp_transf_class", taskid, "login", '', 'FINISH')
		return true
	else:
		log_window.add_log("[tcp_transf_class]->login_do:login failed:%s"%[req_login_ack.get('message', 'unknown error')])
		return false
		
func disconnect_to_server() -> void:
	log_window.add_log("[tcp_transf_class]->disconnect_to_server.")
	rec_data_running = false
	download_running = false
	if_download_sys = false
	rec_data_running = false
	write_running = false
	req_upload_ack = {}
	req_download_ack = {}
	upload_running = false
	dl_tmpfilepath = r''
	dl_buffer = []
	var socket_status = _socket.get_status()
	if socket_status != StreamPeerTCP.STATUS_CONNECTED:
		return
	_socket.disconnect_from_host()
	
#############################  upload ########################
func upload_a_file(filepath:String) -> void:
	log_window.add_log("[tcp_transf_class]->upload_a_file:%s"%[filepath])
	connect_to_server()
	var r = login_do()
	if not r:
		log_window.add_log('[tcp_transf_class]->upload_a_file:login failed!')
		disconnect_to_server()
		return
	upload_file = filepath
	upload_running = true
	upload_thread = Thread.new()
	upload_thread.start(upload_a_file_thread.bind(filepath))
	
func upload_a_file_thread(filepath) -> void:
	log_window.add_log("[tcp_transf_class]->upload_a_file_thread:%s"%[filepath])
	var loop_cnt:int = 0
	while upload_running and loop_cnt <= 3:
		var stime = Time.get_ticks_msec()
		log_window.add_log("[tcp_transf_class]->upload_a_file_thread:will send req_upload, cnt=%s, socket_status:%s"%[loop_cnt, _socket.get_status()])
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
	elif rt_status == 'ERROR2':
		log_window.add_log('[tcp_transf_class]->upload_a_file_thread: upload failed but already exist')
		disconnect_to_server()
		emit_signal("report_result", 'tcp_transf_class', taskid, 'upload', upload_file, 'FINISH')
	else:
		log_window.add_log('[tcp_transf_class]->upload_a_file_thread:upload failed:%s'%[req_upload_ack.get('message', 'unknown error')])
		disconnect_to_server()
		emit_signal("report_result", 'tcp_transf_class', taskid, 'upload', upload_file, 'FAILED')
		
func upload_data(filepath, offset) -> void:
	log_window.add_log("[tcp_transf_class]->upload_data:%s  %s"%[filepath, offset])
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
		log_window.add_log('[tcp_transf_class]->upload_data: finish: %s'%[filepath])
		emit_signal("report_result", "tcp_transf_class", taskid, 'upload', 'FINISH')
		request_a_message({'req_type':'upload', 'status':'FINISH'})

######################### download #########################
func download_a_file(filepath:String, file_size:int, md5:String) -> void:
	log_window.add_log("[tcp_transf_class]->download_a_file:%s"%[filepath])
	if FileAccess.file_exists(filepath) and overwrite == 'no':
		log_window.add_log("[tcp_transf_class]->download_a_file: file not exist!")
		return
	connect_to_server()
	var r = login_do()
	if not r:
		log_window.add_log('login failed!')
		disconnect_to_server()
		return
	download_file = filepath
	var dl_dir = DirAccess.open(root_dir)
	if not dl_dir:
		DirAccess.make_dir_absolute(root_dir)
	var filename:String = filepath.get_file()
	var filedir:String = filepath.get_base_dir()
	dl_tmpfilepath = filedir.path_join("%s_%s_%s"%[md5, filename, tmp_format])
	var offset = 0
	if FileAccess.file_exists(filepath):
		if overwrite == 'yes':
			var err = DirAccess.remove_absolute(filepath)
			if err != Error.OK:
				log_window.add_log('[tcp_transf_class]->download_a_file:remove file failed in download overwrite mode')
				return
		else:
			var md5_check:String = FileAccess.get_md5(filepath)
			if md5_check == md5:
				log_window.add_log('[tcp_transf_class]->download_a_file:already have this file')
				return
			else:
				var err = DirAccess.remove_absolute(filepath)
				if err != Error.OK:
					log_window.add_log('[tcp_transf_class]->download_a_file:remove error md5 file failed in download')
					return
	if FileAccess.file_exists(dl_tmpfilepath):
		if overwrite == 'yes':
			var err = DirAccess.remove_absolute(dl_tmpfilepath)
			if err != Error.OK:
				log_window.add_log('[tcp_transf_class]->download_a_file:remove tmp file failed in download overwrite mode')
				return
		else:
			offset = FileAccess.get_size(dl_tmpfilepath)
	download_running = true
	write_running = true
	download_thread = Thread.new()
	download_thread.start(download_a_file_thread.bind(filepath,file_size, md5, offset))
	write_thread = Thread.new()
	write_thread.start(write_a_file_thread.bind(filepath, file_size, md5, offset))

func download_a_file_thread(filepath, file_size, md5, offset) -> void:
	log_window.add_log("[tcp_transf_class]->download_a_file_thread:%s"%[filepath])
	var stime = Time.get_ticks_msec()
	var loop_cnt = 0
	while download_running and loop_cnt <= 3:
		request_download(filepath, file_size, md5, offset)
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
			{'req_type': 'download',
			'status': 'OK', 
			'file_size' :file_size,
			'filepath': filepath.replace(root_dir + '/', ''),
			'file_md5': md5,
			'offset': offset,
			})
	else:
		log_window.add_log('download failed:%s'%[req_download_ack.get('message', 'unknown error')])
		disconnect_to_server()


#####################  receive data #########################
func receiving_data_thread():
	while rec_data_running:
		if _socket and _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var rec_len = UPLOAD_BUF_SIZE + 28
			if not if_download_sys:
				rec_len = _socket.get_available_bytes()
			if rec_len > 0:
				var data = _socket.get_data(rec_len)
				if data[0] == Error.OK:
					if data[1].size() > 0:
						print('if_download_sys:%s'%[if_download_sys])
						if not if_download_sys:
							var hd:Array = received_get_header(data[1])
							var header:String = hd[0]
							var payload:PackedByteArray = hd[1]
							if header == '|SV>GD|DO:':
								print('if_download_sys=false, payload size:%s'%[payload.size()])
								var idx:int = 0
								while payload.size() > UPLOAD_BUF_SIZE + 18:
									dl_buffer.append(payload.slice(idx, UPLOAD_BUF_SIZE + 18))
									payload = payload.slice(UPLOAD_BUF_SIZE + 28, UPLOAD_BUF_SIZE + 18)
								var this_len:int = payload.slice(0, 4).get_string_from_utf8().hex_to_int()
								var need_len:int = this_len + 4 - payload.size()
								if need_len > 0:
									var need_payload:PackedByteArray = _socket.get_data(need_len)
									payload = payload + need_payload
								dl_buffer.append(payload)
								if_download_sys = true
							else:
								received_and_deal_data(header, payload)
						else:
							print('if_download_sys=true, payload size:%s'%[data[1].slice(10).size()])
							received_and_deal_data('|SV>GD|DO:', data[1].slice(10))
					else:
						log_window.add_log('[tcp_transf_class]->receiving_data_thread:data[1].size() <= 0')
				else:
					log_window.add_log('[tcp_transf_class]->receiving_data_thread:get data error')

func received_and_deal_data(header:String, data:PackedByteArray) -> void:
	if header == '|SV>GD|RQ:':
		var r:Dictionary = receive_parser_req_data(header + data.get_string_from_utf8())
		log_window.add_log("[tcp_transf_class]->received_and_deal_data:|SV>GD|RQ: %s is %s:"%[len(header) + len(data), r])
		var req_type = r.data.get('req_type', '')
		if req_type == 'upload':
			req_upload_ack = r.data
			var status = req_upload_ack.get('status', '')
			if status in ['ERROR3', 'ERROR4', 'ERROR5']:
				if error_retry_cnt > 0:
					log_window.add_log("[tcp_transf_class]->received_and_deal_data:!!!! receive error from server:%s, will retry %s" % [status, error_retry_cnt])
					error_retry_cnt += 1
					disconnect_to_server()
					connect_to_server()
					upload_a_file(upload_file)
				else:
					log_window.add_log('[tcp_transf_class]->received_and_deal_data:!!!! receive error from server'%[status, error_retry_cnt])
					disconnect_to_server()
			elif status == 'FINISH':
				log_window.add_log("[tcp_transf_class]->received_and_deal_data: upload FINISH")
				emit_signal("report_result", "tcp_transf_class", taskid, 'upload', upload_file, 'FINISH')
				
		elif req_type == 'download':
			req_download_ack = r.data
		elif req_type == 'login':
			req_login_ack = r.data
		elif req_type == 'query':
			if r.data.status != 'OK':
				emit_signal("report_result", "tcp_transf_class", taskid, 'query', '', 'FAILED')
			else:
				emit_signal("report_result", "tcp_transf_class", taskid, 'query', '', r.data.message)
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
		log_window.add_log("write_a_data_block: get data size failed")
		return {'s':0, 'd':1, 'idx':preidx}
	var data_size_int:int = data_size.hex_to_int()
	if data_size_int <= 18:
		log_window.add_log("write_a_data_block: data_size_int <= 18")
		return {'s':0, 'd':2, 'idx':preidx}
	if len(data_block) != data_size_int + 4:
		log_window.add_log("write_a_data_block: data_size_int too short:%s != %s + 4"%[data_block.size(), data_size_int])
		var aa = data_block.get_string_from_utf8()
		var bb = aa.substr(1024, 100)
		print(aa)
		return {'s':0, 'd':3, 'idx':preidx}
	var crc:String = data_block.slice(data_size_int - 8 + 4, data_size_int + 4).get_string_from_utf8()
	if not crc.is_valid_hex_number():
		log_window.add_log("write_a_data_block: get crc failed")
		return {'s':0, 'd':4, 'idx':preidx}
	var idx = data_block.slice(4, 10).get_string_from_utf8()
	if not idx.is_valid_hex_number():
		log_window.add_log("write_a_data_block: get idx failed")
		return {'s':0, 'd':5, 'idx':preidx}
	var idxint:int = idx.hex_to_int()
	if idxint != 0 and idxint - preidx != 1:
		log_window.add_log("write_a_data_block: idx not continue")
		return {'s':0, 'd':6, 'idx':preidx}
	var data_payload:PackedByteArray = data_block.slice(10, data_size_int - 8 + 4)
	var crc_int:int = crc.hex_to_int()
	var crc_check:int = crc32_class.fCRC32(data_payload)
	if crc_int != crc_check:
		log_window.add_log("write_a_data_block: crc check error")
		return {'s':0, 'd':7, 'idx':preidx}
	if crc_int % 100 == 0:
		log_window.add_log(crc_int)
	if f:
		f.seek_end()
	var _r = f.store_buffer(data_payload)
	return {'s':data_payload.size(), 'd':-1, 'idx':idxint}

func write_a_file_thread(filepath, file_size, md5, offset):
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
		if data_block and f:
			var r:Dictionary = write_a_data_block(f, data_block, idx)
			if r['s'] == 0 and r['d'] in [4, 5, 6, 7]:
				need_retry = true
				break
			current_size += r['s']
			idx = r['idx']
			#if error_cnt > 0 and current_size >= file_size * 0.3:
				#error_cnt -= 1
				#download_running = false
			if current_size >= file_size:
				download_running = false
				if_download_sys = false
				log_window.add_log('[tcp_transf_class]->write_a_file_thread:stop download due to current_size >= file_size!')
		else:
			if current_size >= file_size:
				download_running = false
				if_download_sys = false
	f.close()
	var md5_check = FileAccess.get_md5(dl_tmpfilepath)
	if overwrite == 'yes' or md5 == md5_check:
		DirAccess.rename_absolute(dl_tmpfilepath, filepath)
		log_window.add_log('[tcp_transf_class]->write_a_file_thread:download finish!!')
		emit_signal("report_result", "tcp_transf_class", taskid, 'download', download_file, 'FINISH')
	else:
		need_retry = true
	if need_retry:
		log_window.add_log('md5 error!!!!')
		disconnect_to_server()
		connect_to_server()
		download_a_file(filepath, file_size, md5)
	
				
func request_download(filepath, file_size, md5, offset):
	log_window.add_log("[tcp_transf_class]->request_download:%s"%[filepath])
	var data = {
		'req_type': 'download',
		'filepath': filepath.replace(root_dir + '/', ''),
		'file_size': file_size,
		'file_md5': md5,
		'offset': offset,
		'status': '-'}
	request_a_message(data)

	
func request_upload(filepath) -> void:
	log_window.add_log("[tcp_transf_class]->request_upload:%s"%[filepath])
	if not FileAccess.file_exists(filepath):
		log_window.add_log('file not exist!!!')
		return
	var data = {
		'req_type': 'upload',
		'status': '-',
		'filepath': filepath.replace(root_dir + '/', ''),
		'file_size': FileAccess.get_size(filepath),
		'file_md5': FileAccess.get_md5(filepath),
		'overwrite': overwrite}
	request_a_message(data)

func request_a_message(req_dic:Dictionary):
	log_window.add_log("[tcp_transf_class]->request_a_message:|GD>SV|RQ:%s is %s"%[_socket.get_status(), req_dic])
	if _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var json_string = JSON.stringify(req_dic)
		var crcv = "%08X"%[crc32_class.fCRC32(json_string.to_utf8_buffer())]
		_socket.put_data(("|GD>SV|RQ:" + "%04X"%[len(json_string) + 8] + json_string + crcv).to_utf8_buffer())
	else:
		log_window.add_log('[tcp_transf_class]->request_a_message:disconnect, send message failed')
		
		
