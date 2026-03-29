extends Node
class_name TCP_TRANSF_C

var REQ_HEADER = '|SV>GD|RQ:'
var DO_HEADER = '|SV>GD|DO:'
var serverip:String = "0.0.0.0"
var serverport:int = 0
var error_retry_cnt:int = 3
var _socket:StreamPeerTCP = StreamPeerTCP.new()

var upload_thread:Thread = null
var upload_running:bool = false
var download_thread:Thread = null
var download_running:bool = false

var tmp_format:String = '.dtmp'
var dl_tmpfilepath:String = ''
var crc32_class:CRC32_C = CRC32_C.new()
var UPLOAD_BUF_SIZE:int = 1024

var usr:String = ''
var psd:String = ''
var overwrite = 'no'
var taskid:String = ''

signal report_result(who_i_am:String, taskid:String, req_type:String, infor:String, result:String)

var root_dir:String = ''
var upload_file:String = r''
var download_file_dic:Dictionary = {}
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
	upload_running = false
	download_running = false
	dl_tmpfilepath = r''
	
	var error = _socket.connect_to_host(serverip, serverport)
	match error:
		OK:
			var stime:int = Time.get_ticks_msec()
			while _socket.get_status() == StreamPeerTCP.STATUS_CONNECTING:
				_socket.poll()
				if Time.get_ticks_msec() - stime > poolmax * 1000:
					break
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

func rec_a_datablock(timeout=3) -> Array:
	#log_window.add_log('[tcp_transf_class]->rec_a_datablock')
	if _socket == null:
		log_window.add_log('[tcp_transf_class]->rec_a_datablock:_socket is null')
		return ['', 'error-1']
	var stime:int = Time.get_ticks_msec()
	while _socket and _socket.get_available_bytes() < 10:
		if Time.get_ticks_msec() - stime > timeout * 1000:
			return ['', 'error0']
	var header:String = ''
	var data:Array = _socket.get_data(10) if _socket else []
	if _socket and data and  data[0] == Error.OK and data[1].size() > 0:
		header = data[1].get_string_from_utf8()
		if header == REQ_HEADER:
			stime = Time.get_ticks_msec()
			while _socket.get_available_bytes() < 4:
				if Time.get_ticks_msec() - stime > timeout * 1000:
					return ['', 'error11']
			var len_int:int = 0
			var data1:Array = _socket.get_data(4)
			if data1[0] == Error.OK and data1[1].size() > 0:
				len_int = data1[1].get_string_from_utf8().hex_to_int()
			if len_int > 0:
				stime = Time.get_ticks_msec()
				while _socket.get_available_bytes() < len_int:
					if Time.get_ticks_msec() - stime > timeout * 1000:
						return ['', 'error12']
				var data2:Array = _socket.get_data(len_int)
				if data2[0] == Error.OK and data2[1].size() > 0:
					var a:PackedByteArray = data2[1].slice(0, len_int - 8)
					var b:PackedByteArray = data2[1].slice(len_int - 8)
					var datablock:String = a.get_string_from_utf8()
					var crc:int = b.get_string_from_utf8().hex_to_int()
					var crc_check:int = crc32_class.fCRC32(a)
					if crc == crc_check:
						var req_dic:Dictionary = JSON.parse_string(datablock)
						return [header, req_dic]
				else:
					log_window.add_log('[tcp_transf_class]->rec_a_datablock:error13')
					return ['', 'error13']
			log_window.add_log('[tcp_transf_class]->rec_a_datablock:error14')
			return ['', 'error14']
		elif header == DO_HEADER:
			stime = Time.get_ticks_msec()
			while _socket.get_available_bytes() < 4:
				if Time.get_ticks_msec() - stime > timeout * 1000:
					return ['', 'error21']
			var len_int:int = 0
			var data1:Array = _socket.get_data(4)
			if data1[0] == Error.OK and data1[1].size() > 0:
				len_int = data1[1].get_string_from_utf8().hex_to_int()
			if len_int > 0:
				stime = Time.get_ticks_msec()
				while _socket.get_available_bytes() < len_int:
					if Time.get_ticks_msec() - stime > timeout * 1000:
						return ['', 'error22']
				var data2:Array = _socket.get_data(len_int)
				if data2[0] == Error.OK and data2[1].size() > 0:
					return [header, data2[1]]
				else:
					log_window.add_log('[tcp_transf_class]->rec_a_datablock:error23')
					return ['', 'error23']
			log_window.add_log('[tcp_transf_class]->rec_a_datablock:error24')
			return ['', 'error24']
		else:
			log_window.add_log('[tcp_transf_class]->rec_a_datablock:error2')
			return ['', 'error2']
	else:
		log_window.add_log('[tcp_transf_class]->rec_a_datablock:error1')
		return ['', 'error1']

func login_do(loopmax=3) -> bool:
	log_window.add_log("[tcp_transf_class]->login_do.")
	emit_signal("report_result", 'tcp_transf_class', taskid, 'login', '', 'START')
	if _socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		log_window.add_log("[tcp_transf_class]->login_do failed due to _socket status is %s"%[_socket.get_status()])
		return false
	var loop_cnt = 0
	while loop_cnt < loopmax:
		request_a_message({
			"req_type": 'login',
			"status": '-',
			"usr": usr,
			"psd": psd.sha256_text()
		})
		var r:Array = rec_a_datablock()
		if r[0] == REQ_HEADER:
			var rt_status =  r[1].get('status', '')
			if rt_status == 'OK':
				emit_signal("report_result", "tcp_transf_class", taskid, "login", '', 'FINISH')
				return true
			log_window.add_log("[tcp_transf_class]->login_do:login failed"%[r[1].get('message', 'unknown error')])
		loop_cnt += 1
	log_window.add_log("[tcp_transf_class]->login_do:login failed")
	return false
		
func disconnect_to_server() -> void:
	log_window.add_log("[tcp_transf_class]->disconnect_to_server.")
	if _socket == null:
		log_window.add_log("[tcp_transf_class]->disconnect_to_server. _socket is null")
		return
	download_running = false
	upload_running = false
	dl_tmpfilepath = r''
	var socket_status = _socket.get_status()
	if socket_status != StreamPeerTCP.STATUS_CONNECTED:
		return
	_socket.disconnect_from_host()
	
#############################  upload ########################
func upload_a_file(filepath:String) -> void:
	log_window.add_log("[tcp_transf_class]->upload_a_file:%s"%[filepath])
	if not filepath.ends_with('/files.txt'):
		emit_signal("report_result", 'tcp_transf_class', taskid, 'upload', filepath, 'START')
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
		log_window.add_log("[tcp_transf_class]->upload_a_file_thread:will send req_upload, cnt=%s, socket_status:%s"%[loop_cnt, _socket.get_status()])
		loop_cnt += 1	
		request_upload(filepath)
		var r1:Array = rec_a_datablock()
		if r1[0] == REQ_HEADER:
			var rt_status = r1[1].get('status', '')
			if rt_status == 'OK':
				upload_running = true
				upload_data(filepath, r1[1].get('offset', 0))
				var r2 = rec_a_datablock()
				if r2[0] == REQ_HEADER:
					rt_status = r2[1].get('status', '')
					if rt_status == 'FINISH':
						log_window.add_log('[tcp_transf_class]->upload_a_file_thread:%s upload finish, get response from server'%[filepath])
						upload_report_result('FINISH')
						return
					else:
						log_window.add_log('[tcp_transf_class]->upload_a_file_thread:%s upload failed:%s'%[filepath, rt_status])
			elif rt_status == 'ERROR2':
				log_window.add_log('[tcp_transf_class]->upload_a_file_thread:%s upload finish, already on server'%[filepath])
				upload_report_result('FINISH')
				return
			else:
				log_window.add_log('[tcp_transf_class]->upload_a_file_thread:%s upload failed:%s'%[filepath, rt_status])
	upload_report_result('FAILED')
	return
							
func upload_data(filepath, offset) -> void:
	log_window.add_log("[tcp_transf_class]->upload_data:%s  %s"%[filepath, offset])
	var uploadfile = FileAccess.open(filepath, FileAccess.READ)
	if uploadfile == null:
		return
	uploadfile.seek(offset)
	var files_size:int = FileAccess.get_size(filepath)
	var dat_format:PackedByteArray = "|GD>SV|DO:".to_utf8_buffer()
	var idx = 0
	var process:int = 0
	while upload_running and offset < files_size:
		var block:PackedByteArray = uploadfile.get_buffer(UPLOAD_BUF_SIZE)
		var block_len:PackedByteArray = ("%04X"%[block.size() + 6 + 8]).to_utf8_buffer()
		var idxx:PackedByteArray = ("%06X"%[idx]).to_utf8_buffer()
		var crc:PackedByteArray = ("%08X"%[crc32_class.fCRC32(block)]).to_utf8_buffer()
		var frame:PackedByteArray = dat_format + block_len + idxx + block + crc
		#print(idxx.get_string_from_utf8()+block.get_string_from_utf8()+crc.get_string_from_utf8())
		#print('%s, %s, %s'%[idx, block_len, crc32_class.fCRC32(block), ])
		_socket.put_data(frame)
		offset += block.size()
		idx += 1
		var n_process = int(100 * offset / files_size)
		if n_process > process:
			process = n_process
			emit_signal("report_result", 'tcp_transf_class', taskid, 'upload', 
			'%s;%s;%s'%[offset, filepath, files_size], 'PROCESS')
	log_window.add_log("[tcp_transf_class]->upload_data finish:%s  %s"%[filepath, offset])

func upload_report_result(rt:String) -> void:
		log_window.add_log('[tcp_transf_class]->upload_report_result:%s'%[rt])
		upload_running = false
		disconnect_to_server()
		emit_signal("report_result", 'tcp_transf_class', taskid, 'upload', upload_file, rt)

######################### download #########################
func download_a_file(filepath:String) -> void:
	log_window.add_log("[tcp_transf_class]->download_a_file:%s"%[filepath])
	if not filepath.ends_with('/files.txt'):
		emit_signal("report_result", 'tcp_transf_class', taskid, 'download', filepath, 'START')
	if FileAccess.file_exists(filepath) and overwrite == 'no':
		log_window.add_log("[tcp_transf_class]->download_a_file: file not exist!")
		return
	connect_to_server()
	var r = login_do()
	if not r:
		log_window.add_log('login failed!')
		disconnect_to_server()
		return
	download_running = true
	download_thread = Thread.new()
	download_thread.start(download_a_file_thread.bind(filepath))

func download_a_file_thread(filepath) -> void:
	log_window.add_log("[tcp_transf_class]->download_a_file_thread:%s"%[filepath])
	if overwrite == 'yes':
		if not download_file_prepare_name_overwrite(filepath):
			log_window.add_log('[tcp_transf_class]->download_a_file:remove file failed in download overwrite mode')
			return
	var loop_cnt = 0
	while download_running and loop_cnt <= 3:
		loop_cnt += 1
		request_download(filepath)
		var r:Array = rec_a_datablock()
		if r[0] == REQ_HEADER:
			var rt_status = r[1].get('status', '')
			if rt_status == 'OK':
				var msg:Array = r[1].get('message', '0;0').split(';')
				var sv_file_size:int = msg[0].to_int()
				var download_file_md5:String = msg[1]
				var rr:Array = download_file_prepare_name(filepath, download_file_md5)
				if rr[0]:
					download_file_dic['filepath'] = filepath
					download_file_dic['file_size'] = sv_file_size
					download_file_dic['md5'] = download_file_md5
					download_file_dic['offset'] = rr[2]
					var sv_filepath = get_file_path(filepath)
					request_a_message({
						'req_type': 'download',
						'status': 'OK',
						'file_size': sv_file_size,
						'filepath': sv_filepath,
						'file_md5': download_file_md5,
						'offset': rr[2],
					})
					var idx:int = 0
					var current_size:int = rr[2]
					var f = FileAccess.open(dl_tmpfilepath, FileAccess.READ_WRITE)
					if f:
						f.seek_end()
					else:
						f = FileAccess.open(dl_tmpfilepath, FileAccess.WRITE)
					while true:
						var rrr = rec_a_datablock()
						if rrr[0] == DO_HEADER:
							var wr:Dictionary = write_a_data_block(f, rrr[1], idx)
							if wr['s'] == 0 and wr['d'] in [4, 5, 6, 7]:
								break
							current_size += wr['s']
							idx = wr['idx']
							if current_size >= sv_file_size:
								download_running = false
								log_window.add_log('[tcp_transf_class]->write_a_file_thread:stop download due to current_size >= file_size!')
								break
					f.close()
					var md5_check = FileAccess.get_md5(dl_tmpfilepath)
					if download_file_md5 == md5_check:
						DirAccess.rename_absolute(dl_tmpfilepath, filepath)
						log_window.add_log('[tcp_transf_class]->write_a_file_thread:md5 is ok, download finish!!')
						download_report_result('FINISH')
						return
					else:
						log_window.add_log('[tcp_transf_class]->write_a_file_thread:md5 is error, will retry %s time'%loop_cnt)
				else:
					log_window.add_log('[tcp_transf_class]->write_a_file_thread:prepare file failed, will retry %s time'%loop_cnt)						
			elif rt_status == 'ERROR7':
				download_report_result('ERROR7')
				return
			else:
				log_window.add_log("[tcp_transf_class]->download_a_file_thread:rt_status is %s, will try for %s time"%[rt_status, loop_cnt])
		else:
			log_window.add_log("[tcp_transf_class]->download_a_file_thread:get req_header failed, will try for %s time"%loop_cnt)
	log_window.add_log("[tcp_transf_class]->download_a_file_thread finish:%s"%[filepath])
	
func download_file_prepare_name_overwrite(filepath:String) -> bool:
	if FileAccess.file_exists(filepath):
		var err = DirAccess.remove_absolute(filepath)
		if err != Error.OK:
			log_window.add_log('[tcp_transf_class]->download_file_prepare_name_overwrite:remove file failed in download overwrite mode')
			return false
		return true
	return true
	
func download_file_prepare_name(filepath:String, sv_md5:String) -> Array:#[result, result1, offset
	download_file_dic['filepath'] = filepath
	var dl_dir = DirAccess.open(root_dir)
	if not dl_dir:
		DirAccess.make_dir_absolute(root_dir)
	var filename:String = filepath.get_file()
	var filedir:String = filepath.get_base_dir()
	dl_tmpfilepath = filedir.path_join("%s_%s_%s"%[sv_md5, filename, tmp_format])
	var offset = 0
	if FileAccess.file_exists(filepath):
		if overwrite == 'yes':
			var err = DirAccess.remove_absolute(filepath)
			if err != Error.OK:
				log_window.add_log('[tcp_transf_class]->download_a_file:remove file failed in download overwrite mode')
				return [false, false, 0]
		else:
			var md5_check:String = FileAccess.get_md5(filepath)
			if md5_check == sv_md5:
				log_window.add_log('[tcp_transf_class]->download_a_file:already have this file')
				return [false, true, 0]
			else:
				var err = DirAccess.remove_absolute(filepath)
				if err != Error.OK:
					log_window.add_log('[tcp_transf_class]->download_a_file:remove error md5 file failed in download')
					return [false, false, 0]
	if FileAccess.file_exists(dl_tmpfilepath):
		if overwrite == 'yes':
			var err = DirAccess.remove_absolute(dl_tmpfilepath)
			if err != Error.OK:
				log_window.add_log('[tcp_transf_class]->download_a_file:remove tmp file failed in download overwrite mode')
				return [false, false, 0]
		else:
			offset = FileAccess.get_size(dl_tmpfilepath)
	return [true, true, offset]

func download_report_result(rt:String) -> void:
	download_running = false
	disconnect_to_server()
	log_window.add_log('[tcp_transf_class]->download_report_result:download %s!!'%rt)
	emit_signal('report_result', 'tcp_transf_class', taskid, 'download', download_file_dic.get('filepath', ''), rt)
	
###################  write files #############################
func write_a_data_block(f:FileAccess, data_block:PackedByteArray, preidx:int) -> Dictionary:
	var data_size_int = data_block.size()
	var crc:String = data_block.slice(data_size_int - 8).get_string_from_utf8()
	if not crc.is_valid_hex_number():
		log_window.add_log("write_a_data_block: get crc failed")
		return {'s':0, 'd':4, 'idx':preidx}
	var idx = data_block.slice(0, 6).get_string_from_utf8()
	if not idx.is_valid_hex_number():
		log_window.add_log("write_a_data_block: get idx failed")
		return {'s':0, 'd':5, 'idx':preidx}
	var idxint:int = idx.hex_to_int()
	if idxint != 0 and idxint - preidx != 1:
		log_window.add_log("write_a_data_block: idx not continue: %s, %s"%[idxint, preidx])
		var _a = data_block.slice(0, 100).get_string_from_utf8()
		return {'s':0, 'd':6, 'idx':preidx}
	var data_payload:PackedByteArray = data_block.slice(6, data_size_int - 8)
	var crc_int:int = crc.hex_to_int()
	var crc_check:int = crc32_class.fCRC32(data_payload)
	if crc_int != crc_check:
		var _a = data_block.slice(0, 100).get_string_from_utf8()
		log_window.add_log("write_a_data_block: crc check error")
		return {'s':0, 'd':7, 'idx':preidx}
	if idxint % 100 == 0:
		log_window.add_log('[tcp_transf_class]->write_a_data_block:idx process:%s'%idxint)
	if f:
		f.seek_end()
	var _r = f.store_buffer(data_payload)
	return {'s':data_payload.size(), 'd':-1, 'idx':idxint}
				
func request_download(filepath):
	log_window.add_log("[tcp_transf_class]->request_download:%s"%[filepath])
	var sv_filepath = get_file_path(filepath)
	var data = {
		'req_type': 'download',
		'filepath': sv_filepath,
		'status': '-'}
	request_a_message(data)
	
func request_upload(filepath) -> void:
	log_window.add_log("[tcp_transf_class]->request_upload:%s"%[filepath])
	if not FileAccess.file_exists(filepath):
		log_window.add_log('file not exist!!!')
		return
	var sv_filepath = get_file_path(filepath)
	var data = {
		'req_type': 'upload',
		'status': '-',
		'filepath': sv_filepath,
		'file_size': FileAccess.get_size(filepath),
		'file_md5': FileAccess.get_md5(filepath),
		'overwrite': overwrite}
	request_a_message(data)

func request_a_message(req_dic:Dictionary):
	log_window.add_log("[tcp_transf_class]->request_a_message:|GD>SV|RQ:%s is %s"%[_socket.get_status(), req_dic])
	if _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var json_string:String = JSON.stringify(req_dic)
		var json_string_utf8:PackedByteArray = json_string.to_utf8_buffer()
		var crcv = "%08X"%[crc32_class.fCRC32(json_string_utf8)]
		_socket.put_data(("|GD>SV|RQ:" + "%04X"%[json_string_utf8.size() + 8] + json_string + crcv).to_utf8_buffer())
	else:
		log_window.add_log('[tcp_transf_class]->request_a_message:disconnect, send message failed')

func get_file_path(filepath) -> String:
	if root_dir + '/' in filepath:
		return filepath.replace(root_dir + '/', '')
	if root_dir in filepath:
		return filepath.replace(root_dir, '')
	return filepath
	
func _destory() -> void:
	log_window.add_log("[tcp_transf_class]->_destory start")
	disconnect_to_server()
	_socket = null
	if download_thread:
		download_thread.wait_to_finish()
	download_thread = null
	if upload_thread:
		upload_thread.wait_to_finish()
	upload_thread = null
	if crc32_class:
		crc32_class.free()
	queue_free()	
	log_window.add_log("[tcp_transf_class]->_destory finish")
		
