extends Node
class_name SCAN_C

var db_path:String = "res://db/files.txt"
var icon_dir:String = "res://db/icon/"
var ignore_file_list:Array = ['files.txt']
var ignore_ext_list:Array = ['dtmp']
var scan_dir_list:Array = []
var scan_thread:Thread = null
var scan_thread_running:bool = false
var taskid:String = ''
var new_files_dic:Dictionary = {}
var log_window = null
var scan_path_dic:Dictionary = {
	'DCIM': '/storage/emulated/0/DCIM',
	'Pictures': '/storage/emulated/0/Pictures',
	'download': '/storage/emulated/0/Download',
}
signal scan_finished(who_i_am:String, taskid:String, req_type:String, infor:String, result:String)

func _init(log_win, _taskid:String, db:String, dirlist:Array) -> void:
	log_window = log_win
	taskid = _taskid
	db_path = db
	scan_dir_list = dirlist
	scan_finished.connect(_on_scan_status_changed)
	_init_db()
	
func scan_a_dir(scan_root_dir:String) -> void:
	scan_thread_running = true
	scan_thread = Thread.new()
	scan_thread.start(scan_a_dir_thread.bind(scan_root_dir))

func scan_a_dir_thread(scan_root_dir:String) -> void:
	log_window.add_log('[scan_class]->scan_a_dir_thread:will scan:%s' %[scan_root_dir])
	get_all_files(scan_root_dir)
	scan_thread_running = false
	merger_table()
	emit_signal("scan_finished", 'scan_class', taskid, 'scan', '', 'FINISH')
	
func merger_table() -> void:
	var db_dic:Dictionary = read_db()
	var server_files_dic:Dictionary = db_dic.get('all_files_dic', {})
	var rename_files_dic:Dictionary = {}
	var rmv_files_list:Array = []
	for eachfile in server_files_dic:
		##remove
		if eachfile not in new_files_dic and server_files_dic[eachfile].get('on_server', '') == 'no':
			rmv_files_list.append(eachfile)
	for eachfile in rmv_files_list:
		log_window.add_log('[scan_class]->merger_table:remove %s'%[eachfile])
		server_files_dic.erase(eachfile)
	for eachfile in new_files_dic:
		var sdic = server_files_dic.get(eachfile, {})
		var ndic = new_files_dic[eachfile]
		##add
		if eachfile not in server_files_dic:
			log_window.add_log("[scan_class]->merger_table:add %s"%[eachfile])
			server_files_dic[eachfile] = ndic
			### create icon
			log_window.add_log('[scan_class]->merger_table:create icon finish:%s'%[eachfile])
		##mod
		else:
			var server_md5 = sdic['md5']
			var new_md5 = ndic['md5']
			if server_md5 != new_md5:
				var bakfile = eachfile.replace(".%s"%[sdic['filetype']], "_bak.%s"%[sdic['filetype']])
				server_files_dic[bakfile] = sdic
				server_files_dic[eachfile] = ndic
				rename_files_dic[eachfile] = bakfile
				log_window.add_log("mod:%s > %s"%[eachfile, bakfile])
	write_db({"all_files_dic": server_files_dic, "rename_files_dic": rename_files_dic})
	
func get_all_files(scaned_path:String) -> void:
	var dir:DirAccess = DirAccess.open(scaned_path)
	if dir == null:
		log_window.add_log("open dir failed:", scaned_path, " reason:", DirAccess.get_open_error())
		return
	dir.list_dir_begin()
	var current_name:String = dir.get_next()
	while current_name != "":
		var current_path:String = scaned_path.path_join(current_name)
		if dir.current_is_dir():
			var tmp:Array = dir.split('/')
			if tmp[tmp.size() - 1] not in scan_dir_list:
				continue
			get_all_files(current_path + '/')
		else:
			if current_name in ignore_file_list:
				log_window.add_log("[scan_class]->get_all_files:ignore file:%s"%[current_name])
				current_name = dir.get_next()
				continue
			var filetype = current_path.get_extension()
			if filetype in ignore_ext_list:
				log_window.add_log("[scan_class]->get_all_files:ignore ext file:%s"%[current_name])
				current_name = dir.get_next()
				continue
			var md5:String = FileAccess.get_md5(current_path)
			var modtime = FileAccess.get_modified_time(current_path)
			var filesize = FileAccess.get_size(current_path)
			if current_path not in new_files_dic:
				new_files_dic[current_path] = {'md5': md5, 'filename': current_name,
				'filesize': filesize, 'modtime': modtime, 'filetype': filetype, 'on_server': 'no', 
				'on_ue': 'yes', 'res1':'', 'res2':'', 'res3':''}
		current_name = dir.get_next()
	dir.list_dir_end()
	
func _init_db() -> bool:
	if not FileAccess.file_exists(db_path):
		var f = FileAccess.open(db_path, FileAccess.WRITE)
		if f:
			var _rt = f.store_string('{}')
			f.close()
			return true
		else:
			return false
	return true
	
func write_db(indic:Dictionary) -> bool:
	var instr:String = JSON.stringify(indic, '\t')
	var f = FileAccess.open(db_path, FileAccess.WRITE)
	if f:
		var r = f.store_string(instr)
		f.close()
		return r
	return false
func read_db() -> Dictionary:
	var f = FileAccess.open(db_path, FileAccess.READ_WRITE)
	if f:
		var outstr:String = f.get_as_text()
		f.close()
		var jsoner:JSON = JSON.new()
		var err = jsoner.parse(outstr)
		if err == Error.OK:
			return jsoner.data
	return {}

func _on_scan_status_changed(who_i_am:String, _taskid:String, req_type:String, infor:String, result:String) -> void:
	log_window.add_log("%s-%s %s %s %s" % [who_i_am, _taskid, req_type, infor, result])
	
			
	
