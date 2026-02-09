extends Node2D

var CFG_PATH:String = "res://db/cfg.ini"
var UE_ROOT_DIR:String = r''
var SERVER_IP:String = ''
var UPLOAD_PORT:int = 6666
var DOWNLOAD_PORT:int = 7777
var USR:String = ''
var PSD:String = ''

var states:Dictionary = {
	'init':{'next_state': 'pull_files_table', 'func': null},
	'pull_files_table':{'next_state': 'scan_files', 'func': pull_files_table},
	'scan_files':{'next_state': 'deal_files', 'func': scan_files},
	'deal_files':{'next_state': 'upload_files', 'func': deal_files},
	'upload_files':{'next_state': 'delete_files', 'func': upload_files},
	'delete_files':{'next_state': 'push_files_table', 'func': delete_files},
	'push_files_table':{'next_state': 'finish', 'func': push_files_table},
	'finish':{'next_state': 'finish', 'func': null},
}

var current_state:String = 'init'
var push_obj:TCP_TRANSF_C = null
var pull_obj:TCP_TRANSF_C = null
var upload_obj:TCP_TRANSF_C = null
var download_obj:TCP_TRANSF_C = null
var scan_files_obj:SCAN_C = null

var upload_list:Array = []
var delete_list:Array = []
var upload_finish:bool = false

func _ready() -> void:
	load_cfg()
	print(UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, DOWNLOAD_PORT)
	if current_state == 'init':
		update_state()

func deal_files() -> void:
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(taskid, UE_ROOT_DIR.path_join('files.txt'))
	var files_dic:Dictionary = scan_files_obj.read_db()
	var all_files_dic:Dictionary = files_dic.get("all_files_dic", {})
	for eachpath in all_files_dic:
		var fileloc = all_files_dic[eachpath]['fileloc']
		if fileloc == '01':#need upload
			upload_list.append(eachpath)
		elif fileloc == '11':#need check if need delete on UE
			if if_need_delete_ue_file(all_files_dic[eachpath], 7):
				delete_list.append(eachpath)
		elif fileloc == '10': ## no need do anything
			pass
	_on_class_report_result('connect_home', '', 'deal_files', 'FINISH')
	
	
func upload_files() -> void:
	var t = Thread.new()
	t.start(upload_files_thread)

func upload_files_thread() -> void:
	for filepath in upload_list:
		print("[connect_home]->upload_files_thread: will upload a file:%s"%[filepath])
		upload_a_file(filepath)
		while not upload_finish:
			pass
		upload_finish = false
	_on_class_report_result('connect_home', '', 'upload_files', 'FINISH')

func delete_files() -> void:
	for filepath in delete_list:
		if FileAccess.file_exists(filepath):
			DirAccess.remove_absolute(filepath)
	_on_class_report_result('connect_home', '', 'delete_files', 'FINISH')
	
func upload_a_file(filepath) -> bool:
	var taskid:String = generate_task_id()
	upload_obj = TCP_TRANSF_C.new(taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'no')
	upload_obj.connect("report_result", _on_class_report_result)
	upload_obj.upload_a_file(filepath)
	return true

func pull_files_table() -> void:
	print("[connect_home]->pull_files_table")
	var taskid:String = generate_task_id()
	pull_obj = TCP_TRANSF_C.new(taskid, UE_ROOT_DIR, SERVER_IP, DOWNLOAD_PORT, USR, PSD, 3, 'yes')
	pull_obj.connect("report_result", _on_class_report_result)
	var pull_file = UE_ROOT_DIR.path_join('files.txt')
	pull_obj.download_a_file(pull_file, 1, 'ignore')

func push_files_table() -> void:
	print("[connect_home]->push_files_table")
	var taskid:String = generate_task_id()
	push_obj = TCP_TRANSF_C.new(taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'yes')
	push_obj.connect("report_result", _on_class_report_result)
	var push_file = UE_ROOT_DIR.path_join('files.txt')
	push_obj.upload_a_file(push_file)

func scan_files() -> void:
	print("[connect_home]->push_files_table")
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(taskid, UE_ROOT_DIR.path_join('files.txt'))
	scan_files_obj.connect("scan_finished", _on_class_report_result)
	scan_files_obj.scan_a_dir(UE_ROOT_DIR)
	
func save_cfg():
	var cfg_infor:String = "UE_ROOT_DIR:%s\nSERVER_IP:%s\nUPLOAD_PORT:%s\nDOWNLOAD_PORT:%s\nUSR:%s\nPSD:%s\n"%[UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, DOWNLOAD_PORT, USR, PSD]
	var f = FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(cfg_infor)
	else:
		print('save cfg infor failed')

func load_cfg():
	var f = FileAccess.open(CFG_PATH, FileAccess.READ)
	if f:
		var cfg_infor = f.get_line()
		UE_ROOT_DIR = cfg_infor.replace('UE_ROOT_DIR:', '')
		cfg_infor = f.get_line()
		SERVER_IP = cfg_infor.replace('SERVER_IP:', '')
		cfg_infor = f.get_line()
		UPLOAD_PORT = cfg_infor.replace('UPLOAD_PORT:', '').to_int()
		cfg_infor = f.get_line()
		DOWNLOAD_PORT = cfg_infor.replace('DOWNLOAD_PORT:', '').to_int()
		cfg_infor = f.get_line()
		USR = cfg_infor.replace('USR:', '')
		cfg_infor = f.get_line()
		PSD = cfg_infor.replace('PSD:', '')
	else:
		print('load cfg failed2')

func generate_task_id() -> String:
	var time = Time.get_ticks_msec()
	var task_id = 'task' + str(time)
	return task_id
	
func if_need_delete_ue_file(file_dic:Dictionary, day:int=7) -> bool:
	var ctime = Time.get_unix_time_from_system()
	var modtime = file_dic.get('modtime', ctime)
	if ctime - modtime > day * 86400:
		return true
	return false

func update_state() -> void:
	var next_state = states.get(current_state, {}).get('next_satate', '')
	if next_state != '':
		print("[connect_home]->update_state:%s>%s"%[current_state, next_state])
		current_state = next_state
		var next_func = states.get(next_state, {}).get('func', null)
		if next_func != null:
			next_func.call()

func _on_class_report_result(who_i_am:String, taskid:String, req_type:String, result:String) -> void:
	print("[connect_home]->_on_class_report_result:%s-%s %s %s %s"%[who_i_am, taskid, req_type, result])
	if who_i_am == 'tcp_transf_class':
		if req_type == 'download' and taskid == pull_obj.taskid and result == 'FINISH':
			update_state()
		elif req_type == 'upload' and taskid == upload_obj.taskid and result == 'FINISH':
			upload_finish = true
	elif who_i_am == 'scan_class':
		if taskid == scan_files_obj.taskid and result == 'FINISH':
			update_state()
	elif who_i_am == 'connect_home':
		if req_type == 'deal_files' and result == 'FINISH':
			update_state()
		elif req_type == 'upload_files' and result == 'FINISH':
			update_state()
		elif req_type == 'delete_files' and result == 'FINISH':
			update_state()
		
	
	
	
	
	
