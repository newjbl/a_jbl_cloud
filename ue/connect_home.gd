extends Node2D

var CFG_PATH:String = "res://db/cfg.ini"
var ICON_DIR:String = "res://db/icon/"
var UE_ROOT_DIR:String = r''
var SERVER_IP:String = ''
var UPLOAD_PORT:int = 6666
var DOWNLOAD_PORT:int = 7777
var USR:String = ''
var PSD:String = ''

var DIS_SIZE:String = 'DAY'
var DIS_DURATION:Array = [0, 4290604800]
var SORT_METHOD:String = 'NAME_AZ'# NAME_ZA, TIME_AZ, TIME_ZA, SIZE_AZ, SIZE_ZA
var UE_SAVE_TIME:int = 30
var DIS_FILE_TYPE:Array = ['zip']
var label_setting_font_10:LabelSettings = null

var win_size:Vector2i = Vector2i.ZERO
var hbox_l1:HBoxContainer = null
var hbox_l2:HBoxContainer = null
var vbox_l3:VBoxContainer = null
var vbox_l3_vbox:VBoxContainer = null

var states:Dictionary = {
	'init':{'next_state': 'pull_files_table', 'func': null},
	'pull_files_table':{'next_state': 'scan_files', 'func': pull_files_table},
	'scan_files':{'next_state': 'deal_files', 'func': scan_files},
	'deal_files':{'next_state': 'upload_files', 'func': deal_files},
	'upload_files':{'next_state': 'query_files', 'func': upload_files},
	'query_files':{'next_state': 'delete_files', 'func': query_files},
	'delete_files':{'next_state': 'push_files_table', 'func': delete_files},
	'push_files_table':{'next_state': 'update_and_show_files', 'func': push_files_table},
	'update_and_show_files':{'next_state': 'finish', 'func': update_and_show_files},
	'finish':{'next_state': 'finish', 'func': null},
}

var current_state:String = 'init'
var push_obj:TCP_TRANSF_C = null
var pull_obj:TCP_TRANSF_C = null
var upload_obj:TCP_TRANSF_C = null
var download_obj:TCP_TRANSF_C = null
var query_obj:TCP_TRANSF_C = null
var scan_files_obj:SCAN_C = null

var upload_dic:Dictionary = {}
var delete_dic:Dictionary = {}
var query_rt:String = ''
var upload_finish:bool = false

func _ready() -> void:
	label_setting_font_10 = LabelSettings.new()
	label_setting_font_10.font_size = 10
	
	load_cfg()
	print(UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, DOWNLOAD_PORT)
	build_gui()
	#if current_state == 'init':
	#	update_state()
	for_test()

func for_test() -> void:
	current_state = 'push_files_table'
	update_state()

########################################### for GUI ################################
func build_gui() -> void:
	print('[connect_home]->build_gui')
	win_size = DisplayServer.window_get_size()
	print(win_size)
	var vbox_top:VBoxContainer = VBoxContainer.new()
	vbox_top.name = 'TOP'
	vbox_top.size = win_size
	
	hbox_l1 = HBoxContainer.new()
	hbox_l1.size = Vector2i(win_size.x, 40)
	hbox_l1.name = 'L1'
	
	hbox_l2 = HBoxContainer.new()
	hbox_l2.size = Vector2i(win_size.x, 40)
	hbox_l2.name = 'L2'
	
	vbox_l3 = VBoxContainer.new()
	vbox_l3.size = Vector2i(win_size.x, win_size.y - 100 - 40 - 40)
	vbox_l3.name = 'L3'
	
	add_child(vbox_top)
	vbox_top.add_child(hbox_l1)
	vbox_top.add_child(hbox_l2)
	vbox_top.add_child(vbox_l3)
	
	### L1
	var login_bt:Button = Button.new()
	login_bt.text = '登录'
	login_bt.name = 'login_bt'
	hbox_l1.add_child(login_bt)
	var sp:Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.name = 'space'
	hbox_l1.add_child(sp)
	var setting_bt:Button = Button.new()
	setting_bt.text = '···'
	setting_bt.name = 'setting'
	hbox_l1.add_child(setting_bt)
	
	### L2
	var opt_bt:OptionButton = OptionButton.new()
	opt_bt.name = 'show_type'
	hbox_l2.add_child(opt_bt)
	var input_txt:LineEdit = LineEdit.new()
	input_txt.name = 'search_input'
	hbox_l2.add_child(input_txt)
	input_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cfm_bt:Button = Button.new()
	cfm_bt.text = '查询'
	cfm_bt.name = 'search_cfm'
	hbox_l2.add_child(cfm_bt)
	
	### L3
	## add by add_one_block
	var scroll_container:ScrollContainer = ScrollContainer.new()
	scroll_container.name = 'scroll_container'
	vbox_l3_vbox = VBoxContainer.new()
	vbox_l3_vbox.name = 'vbox_l3_vbox'
	vbox_l3.add_child(scroll_container)
	scroll_container.add_child(vbox_l3_vbox)
	scroll_container.custom_minimum_size.y = win_size.y - 100 - hbox_l1.size.y - hbox_l2.size.y
	
func add_one_block(idx:int, timek:String, block_dic:Dictionary) -> void:
	print('[connect_home]->add_one_block')
	var s:int = (win_size.x - 10) / 3
	var vbox_block:VBoxContainer = VBoxContainer.new()
	vbox_block.name = 'vbox_block_%s'%[idx]
	var title_label:Label = Label.new()
	title_label.text = timek
	title_label.name = 'title_label'
	var grid_container:GridContainer = GridContainer.new()
	grid_container.columns = 3
	grid_container.name = 'grid_container'
	var idy = 0
	for filedic in block_dic:
		var filename:String = filedic.get('filename', '')
		var filesize:float = filedic.get('filesize', 0) / 1024.0 / 1024.0
		var icon_path:String = ICON_DIR.path_join(filedic.get('md5', ''))
		var texture_vbox:VBoxContainer = VBoxContainer.new()
		texture_vbox.name = 'texture_box_%s'%[idy]
		idy += 1
		var texture_rec:TextureRect = TextureRect.new()
		texture_rec.name = "texture_rec"
		var texture_label:Label = Label.new()
		texture_label.name = 'texture_label'
		var show_name_list:Array = wrap_txt("%s   %s"%[filename, filesize], 20)
		if len(show_name_list) > 3:
			texture_label.text = "%s\n%s\n%s"%[show_name_list[0], '... ...', show_name_list[2]]
		else:
			texture_label.text = '\n'.join(show_name_list)
		texture_rec.custom_minimum_size = Vector2i(s, s)
		texture_rec.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if FileAccess.file_exists(icon_path):
			texture_rec.texture = load(icon_path)
		else:
			texture_rec.texture = load("res://icon.svg")
		grid_container.add_child(texture_vbox)
		texture_vbox.add_child(texture_rec)
		texture_vbox.add_child(texture_label)
	vbox_block.add_child(title_label)
	vbox_block.add_child(grid_container)
	vbox_l3_vbox.call_deferred('add_child', vbox_block)

func wrap_txt(intxt:String, maxlen:int) -> Array:
	if len(intxt) > maxlen:
		var outtxt:String = intxt.substr(0, maxlen)
		var nexttxt:Array = wrap_txt(intxt.substr(maxlen), maxlen)
		return [outtxt] + nexttxt
	return [intxt]
	
func sort_files_by_method_duration(f_table:Dictionary) -> Dictionary:
	print('[connect_home]->sort_files_by_method_duration')
	var result:Dictionary = {}
	var start_ts:int = DIS_DURATION[0]
	var end_ts:int = DIS_DURATION[1]
	for filename in f_table:
		var info:Dictionary = f_table[filename]
		if info.get('filetype', '') not in DIS_FILE_TYPE:
			continue
		var ts:int = info.get('modtime', -1)
		if ts < start_ts or ts > end_ts:
			continue
		var key:String = ''
		match DIS_SIZE.to_upper():
			'DAY':
				key = _ts_to_date_str(ts)
			'WEEK':
				key = _ts_to_week_str(ts)
			'MONTH':
				key = _ts_to_month_str(ts)
			_:
				print('[connect_home]->sort_files_by_method_duration: DIS_SIZE Error')
		if not result.has(key):
			result[key] = []
		result[key].append(info)
	var rt:Dictionary = sort_dic(result)
	return rt

func update_and_show_files() -> void:
	print('[connect_home]->update_and_show_files')
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(taskid, UE_ROOT_DIR.path_join('files.txt'))
	var f_table:Dictionary = scan_files_obj.read_db().get('all_files_dic', {})
	var file_dic:Dictionary = sort_files_by_method_duration(f_table)
	var idx:int = 0
	for timek in file_dic:
		add_one_block(idx, timek, file_dic[timek])
		idx += 1
		
func sort_dic(indic:Dictionary) -> Dictionary:
	for k in indic:
		var files:Array = indic[k]
		if SORT_METHOD == 'TIME_AZ':
			files.sort_custom(func(a, b):
				return a['modtime'] < b['modtime'])
		elif SORT_METHOD == 'TIME_ZA':
			files.sort_custom(func(a, b):
				return a['modtime'] > b['modtime'])
		elif SORT_METHOD == 'NAME_AZ':
			files.sort_custom(func(a, b):
				return a['filename'] < b['filename'])
		elif SORT_METHOD == 'NAME_ZA':
			files.sort_custom(func(a, b):
				return a['filename'] > b['filename'])
		elif SORT_METHOD == 'SIZE_AZ':
			files.sort_custom(func(a, b):
				return a['filesize'] > b['filesize'])
		elif SORT_METHOD == 'SIZE_ZA':
			files.sort_custom(func(a, b):
				return a['filesize'] < b['filesize'])
	return indic
	
func _ts_to_date_str(ts:int) -> String:
	var dt:Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d"%[dt['year'], dt['month'], dt['day']]

func _ts_to_week_str(ts:int) -> String:
	var dt:Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	var days_to_month:int = dt['weekday'] - 1
	var monday_ts:int = days_to_month * 86400
	return _ts_to_date_str(monday_ts)

func _ts_to_month_str(ts:int) -> String:
	var dt:Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d"%[dt['year'], dt['month']]
	
	
################################# for functions ##############################

func query_files() -> void:
	print("[connect_home]->query_files")
	var taskid:String = generate_task_id()
	query_obj = TCP_TRANSF_C.new(taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'yes')
	query_obj.connect("report_result", _on_class_report_result)
	var filedic:Dictionary = {}
	for eachf in delete_dic:
		var file_md5:String = FileAccess.get_md5(eachf)
		var filename:String = eachf.replace(UE_ROOT_DIR + '/', '')
		filedic[filename] = file_md5
	query_obj.query_files(filedic)
	
func deal_files() -> void:
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(taskid, UE_ROOT_DIR.path_join('files.txt'))
	var files_dic:Dictionary = scan_files_obj.read_db()
	var all_files_dic:Dictionary = files_dic.get("all_files_dic", {})
	for eachpath in all_files_dic:
		var on_server = all_files_dic[eachpath]['on_server']
		var on_ue = all_files_dic[eachpath]['on_ue']
		if on_server == 'no' and on_ue == 'yes':#need upload
			upload_dic[eachpath] = 'not upload yet'
		elif on_ue == 'yes' and on_server == 'yes':#need check if need delete on UE
			if if_need_delete_ue_file(all_files_dic[eachpath], 7):
				delete_dic[eachpath] == 'not delete yet'
	_on_class_report_result('connect_home', '', 'deal_files', '', 'FINISH')
	
func upload_files() -> void:
	var t = Thread.new()
	t.start(upload_files_thread)

func upload_files_thread() -> void:
	for filepath in upload_dic:
		print("[connect_home]->upload_files_thread: will upload a file:%s"%[filepath])
		upload_a_file(filepath)
		while not upload_finish:
			pass
		upload_finish = false
		update_files_table_after_upload()
	_on_class_report_result('connect_home', '', 'upload_files', '', 'FINISH')

func delete_files() -> void:
	var upload_again_list:Array = []
	var upload_again_list_:Array = []
	if query_rt != 'all ok':
		upload_again_list_ = query_rt.split(';')
	for eachf in upload_again_list_:
		upload_again_list.append(UE_ROOT_DIR.path_join(eachf))
	for filepath in delete_dic:
		if filepath in upload_again_list:
			continue
		print('[connect_home]->delete_files:will delete file: %s'%[filepath])
		if FileAccess.file_exists(filepath):
			DirAccess.remove_absolute(filepath)
			delete_dic[filepath] = 'deleted'
	update_files_table_after_delete()
	_on_class_report_result('connect_home', '', 'delete_files', '', 'FINISH')
	
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

func update_files_table_after_upload() -> void:
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(taskid, UE_ROOT_DIR.path_join('files.txt'))
	var f_table:Dictionary = scan_files_obj.read_db().get('all_files_dic', {})
	var d_table:Dictionary = scan_files_obj.read_db().get('rename_files_dic', {})
	for eachfile in upload_dic:
		if upload_dic[eachfile] != 'uploaded':
			continue
		if eachfile in f_table:
			f_table[eachfile]['on_server'] = 'yes'
	scan_files_obj.write_db({'all_files_dic': f_table, 'rename_files_dic': d_table})
	
func update_files_table_after_delete() -> void:
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(taskid, UE_ROOT_DIR.path_join('files.txt'))
	var f_table:Dictionary = scan_files_obj.read_db().get('all_files_dic', {})
	var d_table:Dictionary = scan_files_obj.read_db().get('rename_files_dic', {})
	for eachfile in delete_dic:
		if delete_dic[eachfile] != 'deleted':
			continue
		if eachfile in f_table:
			f_table[eachfile]['on_ue'] = 'no'
	scan_files_obj.write_db({'all_files_dic': f_table, 'rename_files_dic': d_table})
	
func scan_files() -> void:
	print("[connect_home]->scan_files")
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
	var task_id = 'task_' + str(time)
	return task_id
	
func if_need_delete_ue_file(file_dic:Dictionary, day:int=7) -> bool:
	var ctime = Time.get_unix_time_from_system()
	var modtime = file_dic.get('modtime', ctime)
	if ctime - modtime > day:# * 86400:
		return true
	return false

func update_state() -> void:
	var next_state = states.get(current_state, {}).get('next_state', '')
	if next_state != '':
		print("[connect_home]->update_state:%s>%s"%[current_state, next_state])
		current_state = next_state
		var next_func = states.get(next_state, {}).get('func', null)
		if next_func != null:
			next_func.call()

func _on_class_report_result(who_i_am:String, taskid:String, req_type:String, infor:String, result:String) -> void:
	print("[connect_home]->_on_class_report_result:%s-%s %s %s %s"%[who_i_am, taskid, req_type, result])
	if who_i_am == 'tcp_transf_class':
		if current_state == 'pull_files_table':## pull finish
			if req_type == 'download' and taskid == pull_obj.taskid:# and result == 'FINISH':
				update_state()
		elif current_state == 'upload_files':## upload one file finish
			if req_type == 'upload' and taskid == upload_obj.taskid:# and result == 'FINISH':
				upload_finish = true
		elif current_state == 'query_files':# query finish
			if req_type == 'query' and taskid == query_obj.taskid:
				query_rt = result
				update_state()
		elif current_state == 'push_files_table':# push finish
			if req_type == 'upload' and taskid == push_obj.taskid:
				update_state()
				
	elif who_i_am == 'scan_class':
		if current_state == 'scan_files':# scan finish
			if taskid == scan_files_obj.taskid and result == 'FINISH':
				update_state()
				
	elif who_i_am == 'connect_home':
		if current_state == 'deal_files':# deal files finish
			if req_type == 'deal_files' and result == 'FINISH':
				update_state()
		elif current_state == 'upload_files':# upload all files finish
			if req_type == 'upload_files' and result == 'FINISH':
				update_state()
		elif current_state == 'delete_files':# delete files finish
			if req_type == 'delete_files' and result == 'FINISH':
				update_state()
		
	
	
	
	
	
