extends Node2D

var CFG_PATH:String = "user://db/cfg.ini"
var SETTING_PATH:String = "user://db/setting.ini"
var ICON_DIR:String = "user://db/icon/"
var UE_ROOT_DIR:String = r'/storage/emulated/0'
var SCAN_DIR_DIC:Dictionary = {'DCIM':'yes', 'Pictures':'yes', 'Download':'yes'}
var SERVER_IP:String = ''
var UPLOAD_PORT:int = 6666
var DOWNLOAD_PORT:int = 7777
var USR:String = ''
var PSD:String = ''

var DIS_SIZE:String = 'DAY'
var DIS_DURATION:Array = [0, 4290604800]
var SORT_METHOD:String = 'NAME_AZ'# NAME_ZA, TIME_AZ, TIME_ZA, SIZE_AZ, SIZE_ZA
var UE_SAVE_TIME:int = 30
var DIS_FILE_TYPE:Dictionary = {'Picture':{'JPG':'yes', 'JPEG':'yes', 'PNG':'yes', 'GIF':'yes', 'BMP':'yes', 'HEIC':'yes', 'WEBP':'yes', 'TIFF':'yes'},
'Vedio': {'MP4':'yes', '3GP':'yes', '3G2':'yes', 'AVI':'yes', 'MOV':'yes', 'MKV':'yes', 'M4V':'yes', 'WMV':'yes', 'ASF':'yes', 'FLV':'yes'},
'Music': {'MP3':'yes', 'WMA':'yes', 'OGG':'yes', 'FLAC':'yes', 'APE':'yes', 'WAV':'yes', 'AAC':'yes', 'M4A':'yes', 'AMR':'yes', '3GPP':'yes', 'MKA':'yes', 'AC3':'yes', 'DTS':'yes'},
'Others': {}}
var file_type_line_max_cnt:int = 6
var DEFAULT_FONT_SIZE:int = 60
var DEFAULT_FONT_HALF_SIZE:int = 30
var label_setting_font_60:LabelSettings = null
var label_setting_font_30:LabelSettings = null
var label_setting_font_15:LabelSettings = null
var label_setting_font_red:LabelSettings = null
var label_setting_font_blue:LabelSettings = null


var win_size:Vector2i = Vector2i.ZERO
var hbox_l1:HBoxContainer = null
var vbox_l1_1_login:VBoxContainer = null
var vbox_l1_2_setting:VBoxContainer = null
var hbox_l2:HBoxContainer = null
var vbox_l3:VBoxContainer = null
var vbox_l3_vbox:VBoxContainer = null
var scan_bt:Button = null
var upload_bt:Button = null
var delete_bt:Button = null
var logs_show:Label = null
var logs_dic:Dictionary = {'pre_current_status':'', 'current_status':'', 'res1':'', 'res2':'', 'message':''}
var TIME_ITEM:Array = [1986, 2106]

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
var pre_current_state:String = 'init'
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

var log_window = null
var debug_on_win:bool = false

func _ready() -> void:
	debug_on_win = true if OS.get_name() == 'Windows' else false
	log_window = preload("res://class/log_window.tscn").instantiate()
	add_child(log_window)
	print(ProjectSettings.globalize_path("user://"))
	label_setting_font_60 = LabelSettings.new()
	label_setting_font_60.font_size = 60
	label_setting_font_30 = LabelSettings.new()
	label_setting_font_30.font_size = 30
	label_setting_font_15 = LabelSettings.new()
	label_setting_font_15.font_size = 15
	label_setting_font_red = LabelSettings.new()
	label_setting_font_red.font_color = Color(1.0, 0.0, 0.0, 1.0)
	label_setting_font_blue = LabelSettings.new()
	label_setting_font_blue.font_color = Color(0.0, 1.0, 0.0, 1.0)
	
	load_cfg()
	load_setting()
	log_window.add_log("%s, %s, %s, %s" % [UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, DOWNLOAD_PORT])
	build_gui()
	#if current_state == 'init':
	#	update_state()
	#for_test()

func for_test() -> void:
	#current_state = 'query_files'
	#query_files()
	
	current_state = 'push_files_table'
	update_state()

########################################### for GUI ################################
func build_gui() -> void:
	log_window.add_log('[connect_home]->build_gui')
	win_size = DisplayServer.window_get_size() - Vector2i(100, 100)
	log_window.add_log("%s, %s"%[win_size.x, win_size.y])
	var vbox_top:VBoxContainer = VBoxContainer.new()
	vbox_top.name = 'TOP'
	vbox_top.size = win_size
	vbox_top.position = Vector2i(50, 50)
	
	var hbox_l0:HBoxContainer = HBoxContainer.new()
	hbox_l0.name = 'title'
	var app_title_label:Label = Label.new()
	app_title_label.text = '文件回家 V0.3.4'
	app_title_label.size = Vector2i(win_size.x, 50)
	app_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_title_label.label_settings = label_setting_font_60
	hbox_l0.add_child(app_title_label)
	
	var hbox_l0_1:HBoxContainer = HBoxContainer.new()
	hbox_l0_1.name = 'logs_show'
	logs_show = Label.new()
	logs_show.text = ''
	logs_show.name = 'log_show'
	logs_show.size = Vector2i(win_size.x, 50)
	logs_show.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logs_show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_show.label_settings = label_setting_font_15
	hbox_l0_1.add_child(logs_show)
	
	hbox_l1 = HBoxContainer.new()
	hbox_l1.size = Vector2i(win_size.x - 5, 40)
	hbox_l1.name = 'L1'
	
	vbox_l1_1_login = VBoxContainer.new()
	vbox_l1_1_login.size = Vector2i(win_size.x - 5, 300)
	vbox_l1_1_login.visible = false
	vbox_l1_1_login.name = 'vbox_l1_1_login'
	
	vbox_l1_2_setting = VBoxContainer.new()
	vbox_l1_2_setting.size = Vector2i(win_size.x - 5, 300)
	vbox_l1_2_setting.visible = false
	vbox_l1_2_setting.name = 'vbox_l1_2_setting'
	
	hbox_l2 = HBoxContainer.new()
	hbox_l2.size = Vector2i(win_size.x - 5, 40)
	hbox_l2.name = 'L2'
	
	vbox_l3 = VBoxContainer.new()
	vbox_l3.size = Vector2i(win_size.x - 10, win_size.y - 100 - 40 - 40)
	vbox_l3.name = 'L3'
	
	add_child(vbox_top)
	vbox_top.add_child(hbox_l0)
	vbox_top.add_child(hbox_l0_1)
	vbox_top.add_child(hbox_l1)
	vbox_top.add_child(vbox_l1_1_login)
	vbox_top.add_child(vbox_l1_2_setting)
	vbox_top.add_child(hbox_l2)
	vbox_top.add_child(vbox_l3)
	
	### L1
	var login_bt:Button = Button.new()
	login_bt.text = '登录'
	login_bt.name = 'login_bt'
	login_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	login_bt.connect("pressed", _on_login_bt_pressed)
	hbox_l1.add_child(login_bt)
	
	scan_bt = Button.new()
	scan_bt.text = '1. 扫描文件'
	scan_bt.name = 'scan_bt'
	scan_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	scan_bt.connect("pressed", _on_scan_bt_pressed)
	hbox_l1.add_child(scan_bt)
	
	upload_bt = Button.new()
	upload_bt.text = '2. 上传文件'
	upload_bt.name = 'upload_bt'
	upload_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	upload_bt.connect("pressed", _on_upload_bt_pressed)
	hbox_l1.add_child(upload_bt)
	
	delete_bt = Button.new()
	delete_bt.text = '3. 删除文件'
	delete_bt.name = 'delete_bt'
	delete_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	delete_bt.connect("pressed", _on_delete_bt_pressed)
	hbox_l1.add_child(delete_bt)
	
	var setting_bt:Button = Button.new()
	setting_bt.text = '···'
	setting_bt.name = 'setting'
	setting_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	setting_bt.connect("pressed", _on_setting_bt_pressed)
	hbox_l1.add_child(setting_bt)
	
	### l1 login
	var hbox_login_l1:HBoxContainer = HBoxContainer.new()
	var hbox_login_l2:HBoxContainer = HBoxContainer.new()
	var hbox_login_l3:HBoxContainer = HBoxContainer.new()
	var hbox_login_l4:HBoxContainer = HBoxContainer.new()
	var hbox_login_l5:HBoxContainer = HBoxContainer.new()
	var hbox_login_l6:HBoxContainer = HBoxContainer.new()
	var hbox_login_l7:HBoxContainer = HBoxContainer.new()
	var hbox_login_le:HBoxContainer = HBoxContainer.new()
	hbox_login_l1.name = 'hbox_login_l1'
	hbox_login_l2.name = 'hbox_login_l2'
	hbox_login_l3.name = 'hbox_login_l3'
	hbox_login_l4.name = 'hbox_login_l4'
	hbox_login_l5.name = 'hbox_login_l5'
	hbox_login_l6.name = 'hbox_login_l6'
	hbox_login_l7.name = 'hbox_login_l7'
	hbox_login_le.name = 'hbox_login_le'
	vbox_l1_1_login.add_child(hbox_login_l1)
	vbox_l1_1_login.add_child(hbox_login_l2)
	vbox_l1_1_login.add_child(hbox_login_l3)
	vbox_l1_1_login.add_child(hbox_login_l4)
	vbox_l1_1_login.add_child(hbox_login_l5)
	vbox_l1_1_login.add_child(hbox_login_l6)
	vbox_l1_1_login.add_child(hbox_login_l7)
	vbox_l1_1_login.add_child(hbox_login_le)
	
	var login_tiltle_label:Label = Label.new()
	login_tiltle_label.name = 'login_tiltle_label'
	login_tiltle_label.text = '登陆信息'
	login_tiltle_label.label_settings = label_setting_font_60
	login_tiltle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_tiltle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_login_l1.add_child(login_tiltle_label)
	
	var server_ip_label:Label = Label.new()
	server_ip_label.name = 'server_ip_label'
	server_ip_label.text = '服务器IP:'
	server_ip_label.label_settings = label_setting_font_60
	hbox_login_l2.add_child(server_ip_label)
	var server_ip_input:LineEdit = LineEdit.new()
	server_ip_input.name = 'server_ip_input'
	server_ip_input.text = SERVER_IP
	server_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_ip_input.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_login_l2.add_child(server_ip_input)
	
	var upload_port_label:Label = Label.new()
	upload_port_label.name = 'upload_port_label'
	upload_port_label.text = '上传端口:'
	upload_port_label.label_settings = label_setting_font_60
	hbox_login_l3.add_child(upload_port_label)
	var upload_port_input:LineEdit = LineEdit.new()
	upload_port_input.name = 'upload_port_input'
	upload_port_input.text = "%s"%UPLOAD_PORT
	upload_port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_port_input.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_login_l3.add_child(upload_port_input)
	
	var download_port_label:Label = Label.new()
	download_port_label.name = 'download_port_label'
	download_port_label.text = '下载端口:'
	download_port_label.label_settings = label_setting_font_60
	hbox_login_l4.add_child(download_port_label)
	var download_port_input:LineEdit = LineEdit.new()
	download_port_input.name = 'download_port_input'
	download_port_input.text = "%s"%DOWNLOAD_PORT
	download_port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	download_port_input.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_login_l4.add_child(download_port_input)
	
	var usr_label:Label = Label.new()
	usr_label.name = 'usr_label'
	usr_label.text = '用户名:'
	usr_label.label_settings = label_setting_font_60
	hbox_login_l5.add_child(usr_label)
	var usr_input:LineEdit = LineEdit.new()
	usr_input.name = 'usr_input'
	usr_input.text = USR
	usr_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	usr_input.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_login_l5.add_child(usr_input)
	
	var psd_label:Label = Label.new()
	psd_label.name = 'psd_label'
	psd_label.text = '密码:'
	psd_label.label_settings = label_setting_font_60
	hbox_login_l6.add_child(psd_label)
	var psd_input:LineEdit = LineEdit.new()
	psd_input.name = 'psd_input'
	psd_input.text = PSD
	psd_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	psd_input.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_login_l6.add_child(psd_input)
	
	var save_cfg_bt:Button = Button.new()
	save_cfg_bt.name = 'save_cfg_bt'
	save_cfg_bt.text = '登录&保存信息'
	save_cfg_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_cfg_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	save_cfg_bt.connect("pressed", _on_save_cfg_bt_pressed.bind(login_tiltle_label, save_cfg_bt,
	server_ip_input, upload_port_input, download_port_input, usr_input, psd_input))
	hbox_login_l7.add_child(save_cfg_bt)
	var test_bt:Button = Button.new()
	test_bt.name = 'test_bt'
	test_bt.text = '测试连接'
	test_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	test_bt.connect("pressed", _on_test_bt_pressed.bind(login_tiltle_label, test_bt,
	server_ip_input, upload_port_input, download_port_input, usr_input, psd_input))
	hbox_login_l7.add_child(test_bt)
	
	var line1:Line2D = Line2D.new()
	line1.name = 'line1'
	line1.add_point(Vector2i(0, 0))
	line1.add_point(Vector2i(win_size.x, 0))
	hbox_login_le.add_child(line1)
	
	if _on_test_bt_pressed(login_tiltle_label, test_bt,
	server_ip_input, upload_port_input, download_port_input, usr_input, psd_input, 3, 1):
		login_bt.text = USR
	
	### l2 setting
	var hbox_setting_l1:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l1_0:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l1_1:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l1_2:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l2:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l3:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l4:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l5:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l6:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l6_1:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l6_2:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l6_3:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l6_4:HBoxContainer = HBoxContainer.new()
	var hbox_setting_l7:HBoxContainer = HBoxContainer.new()
	var hbox_setting_le:HBoxContainer = HBoxContainer.new()
	hbox_setting_l1.name = 'hbox_setting_l1'
	hbox_setting_l1_0.name = 'hbox_setting_l1_0'
	hbox_setting_l1_1.name = 'hbox_setting_l1_1'
	hbox_setting_l1_2.name = 'hbox_setting_l1_2'
	hbox_setting_l2.name = 'hbox_setting_l2'
	hbox_setting_l3.name = 'hbox_setting_l3'
	hbox_setting_l4.name = 'hbox_setting_l4'
	hbox_setting_l5.name = 'hbox_setting_l5'
	hbox_setting_l6.name = 'hbox_setting_l6'
	hbox_setting_l6_1.name = 'hbox_setting_l6_1'
	hbox_setting_l6_2.name = 'hbox_setting_l6_2'
	hbox_setting_l6_3.name = 'hbox_setting_l6_3'
	hbox_setting_l6_4.name = 'hbox_setting_l6_4'
	hbox_setting_l7.name = 'hbox_setting_l7'
	hbox_setting_le.name = 'hbox_setting_le'
	vbox_l1_2_setting.add_child(hbox_setting_l1)
	vbox_l1_2_setting.add_child(hbox_setting_l1_0)
	vbox_l1_2_setting.add_child(hbox_setting_l1_1)
	vbox_l1_2_setting.add_child(hbox_setting_l1_2)
	vbox_l1_2_setting.add_child(hbox_setting_l2)
	vbox_l1_2_setting.add_child(hbox_setting_l3)
	vbox_l1_2_setting.add_child(hbox_setting_l4)
	vbox_l1_2_setting.add_child(hbox_setting_l5)
	vbox_l1_2_setting.add_child(hbox_setting_l6)
	vbox_l1_2_setting.add_child(hbox_setting_l6_1)
	vbox_l1_2_setting.add_child(hbox_setting_l6_2)
	vbox_l1_2_setting.add_child(hbox_setting_l6_3)
	vbox_l1_2_setting.add_child(hbox_setting_l6_4)
	vbox_l1_2_setting.add_child(hbox_setting_l7)
	vbox_l1_2_setting.add_child(hbox_setting_le)
	
	var setting_save_bt:Button = Button.new()
	setting_save_bt.name = 'setting_save_bt'
	setting_save_bt.text = '保存配置'
	setting_save_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	setting_save_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_save_bt.connect("pressed", _on_setting_save_bt_pressed.bind(setting_save_bt))
	hbox_setting_l1.add_child(setting_save_bt)
	
	var ue_root_dir_label:Label = Label.new()
	ue_root_dir_label.name = 'ue_root_dir_label'
	ue_root_dir_label.text = '根目录'
	ue_root_dir_label.label_settings = label_setting_font_60
	hbox_setting_l1_0.add_child(ue_root_dir_label)
	var ue_root_dir_input:LineEdit = LineEdit.new()
	ue_root_dir_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ue_root_dir_input.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	ue_root_dir_input.text = UE_ROOT_DIR
	ue_root_dir_input.connect("text_changed", _on_ue_root_dir_changed)
	hbox_setting_l1_0.add_child(ue_root_dir_input)
	
	var scan_dir_label:Label = Label.new()
	scan_dir_label.name = 'scan_dir_label'
	scan_dir_label.text = '同步目录:'
	scan_dir_label.label_settings = label_setting_font_60
	hbox_setting_l1_1.add_child(scan_dir_label)
	for eachdir in SCAN_DIR_DIC:
		var cb_r:CheckBox = CheckBox.new()
		cb_r.name = eachdir
		cb_r.text = eachdir
		cb_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb_r.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
		if SCAN_DIR_DIC[eachdir] == 'yes':
			cb_r.set_pressed_no_signal(true)
		elif SCAN_DIR_DIC[eachdir] == 'no':
			cb_r.set_pressed_no_signal(false)
		cb_r.connect("toggled", _on_scan_dir_cb_toggled.bind(cb_r))
		hbox_setting_l1_1.add_child(cb_r)
	var new_scan_dir_input:LineEdit = LineEdit.new()
	new_scan_dir_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_scan_dir_input.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	var add_scan_dir_bt:Button = Button.new()
	add_scan_dir_bt.name = 'add_scan_dir_bt'
	add_scan_dir_bt.text = '新增目录'
	add_scan_dir_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_scan_dir_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	add_scan_dir_bt.connect("pressed", _on_add_scan_dir_bt_pressed.bind('add', new_scan_dir_input, hbox_setting_l1_1))
	var del_scan_dir_bt:Button = Button.new()
	del_scan_dir_bt.name = 'del_scan_dir_bt'
	del_scan_dir_bt.text = '删除目录'
	del_scan_dir_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_scan_dir_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	del_scan_dir_bt.connect("pressed", _on_add_scan_dir_bt_pressed.bind('del', new_scan_dir_input, hbox_setting_l1_1))
	hbox_setting_l1_2.add_child(new_scan_dir_input)
	hbox_setting_l1_2.add_child(add_scan_dir_bt)
	hbox_setting_l1_2.add_child(del_scan_dir_bt)
	
	var dis_size_label:Label = Label.new()
	dis_size_label.name = 'dis_size_label'
	dis_size_label.text = '显示粒度:'
	dis_size_label.label_settings = label_setting_font_60
	hbox_setting_l2.add_child(dis_size_label)
	var radio_group:ButtonGroup = ButtonGroup.new()
	var radio_day:CheckBox = CheckBox.new()
	var radio_week:CheckBox = CheckBox.new()
	var radio_month:CheckBox = CheckBox.new()
	radio_day.button_group = radio_group
	radio_week.button_group = radio_group
	radio_month.button_group = radio_group
	radio_day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio_week.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio_month.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio_day.name = 'DAY'
	radio_day.text = '日'
	radio_week.name = 'WEEK'
	radio_week.text = '周'
	radio_month.name = 'MONTH'
	radio_month.text = '月'
	radio_day.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
	radio_week.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
	radio_month.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
	radio_day.connect("toggled", _on_dis_size_toggled.bind(radio_day))
	radio_week.connect("toggled", _on_dis_size_toggled.bind(radio_week))
	radio_month.connect("toggled", _on_dis_size_toggled.bind(radio_month))
	if DIS_SIZE == 'DAY':
		radio_day.set_pressed_no_signal(true)
	elif DIS_SIZE == 'WEEK':
		radio_week.set_pressed_no_signal(true)
	elif DIS_SIZE == 'MONTH':
		radio_month.set_pressed_no_signal(true)
	hbox_setting_l2.add_child(radio_day)
	hbox_setting_l2.add_child(radio_week)
	hbox_setting_l2.add_child(radio_month)
	
	var duration_label:Label = Label.new()
	duration_label.name = 'duration_label'
	duration_label.text = '时间范围:'
	duration_label.label_settings = label_setting_font_60
	hbox_setting_l3.add_child(duration_label)
	var y1:OptionButton = OptionButton.new()
	var m1:OptionButton = OptionButton.new()
	var d1:OptionButton = OptionButton.new()
	var s:Control = Control.new()
	var y2:OptionButton = OptionButton.new()
	var m2:OptionButton = OptionButton.new()
	var d2:OptionButton = OptionButton.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y1.name = 'y1'
	m1.name = 'm1'
	d1.name = 'd1'
	y2.name = 'y2'
	m2.name = 'm2'
	d2.name = 'd2'
	y1.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	m1.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	d1.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	y2.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	m2.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	d2.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	y1.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	m1.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	d1.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	y2.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	m2.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	d2.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	for idx in range(TIME_ITEM[1] - TIME_ITEM[0]):
		y1.add_item("%s"%[TIME_ITEM[0] + idx], idx)
	for idx in range(TIME_ITEM[1] - TIME_ITEM[0]):
		y2.add_item("%s"%[TIME_ITEM[0] + idx], idx)
	for idx in range(12):
		m1.add_item("%s"%[idx + 1], idx)
	for idx in range(12):
		m2.add_item("%s"%[idx + 1], idx)
	for idx in range(31):
		d1.add_item("%s"%[idx + 1], idx)
	for idx in range(31):
		d2.add_item("%s"%[idx + 1], idx)
	y1.connect("item_selected", _on_time_duration_selectd.bind(y1, m1, d1, y2, m2, d2))
	m1.connect("item_selected", _on_time_duration_selectd.bind(y1, m1, d1, y2, m2, d2))
	d1.connect("item_selected", _on_time_duration_selectd.bind(y1, m1, d1, y2, m2, d2))
	y2.connect("item_selected", _on_time_duration_selectd.bind(y1, m1, d1, y2, m2, d2))
	m2.connect("item_selected", _on_time_duration_selectd.bind(y1, m1, d1, y2, m2, d2))
	d2.connect("item_selected", _on_time_duration_selectd.bind(y1, m1, d1, y2, m2, d2))
	var time_dict_1:Dictionary = Time.get_datetime_dict_from_unix_time(DIS_DURATION[0])
	var time_dict_2:Dictionary = Time.get_datetime_dict_from_unix_time(DIS_DURATION[1])
	if time_dict_1.year >= TIME_ITEM[0] and time_dict_1.year <= TIME_ITEM[TIME_ITEM.size() - 1]:
		y1.select(time_dict_1.year - TIME_ITEM[0])
		m1.select(time_dict_1.month - 1)
		d1.select(time_dict_1.day -1)
		y2.select(time_dict_2.year - TIME_ITEM[0])
		m2.select(time_dict_2.month - 1)
		d2.select(time_dict_2.day -1)
	hbox_setting_l3.add_child(y1)
	hbox_setting_l3.add_child(m1)
	hbox_setting_l3.add_child(d1)
	hbox_setting_l3.add_child(s)
	hbox_setting_l3.add_child(y2)
	hbox_setting_l3.add_child(m2)
	hbox_setting_l3.add_child(d2)
	
	var sort_method_label:Label = Label.new()
	sort_method_label.name = 'sort_method_label'
	sort_method_label.text = '排序方式:'
	sort_method_label.label_settings = label_setting_font_60
	hbox_setting_l4.add_child(sort_method_label)
	var radio_group_1:ButtonGroup = ButtonGroup.new()
	var nameaz_bt:CheckBox = CheckBox.new()
	var nameza_bt:CheckBox = CheckBox.new()
	var timeaz_bt:CheckBox = CheckBox.new()
	var timeza_bt:CheckBox = CheckBox.new()
	var sizeaz_bt:CheckBox = CheckBox.new()
	var sizeza_bt:CheckBox = CheckBox.new()
	nameaz_bt.button_group = radio_group_1
	nameza_bt.button_group = radio_group_1
	timeaz_bt.button_group = radio_group_1
	timeza_bt.button_group = radio_group_1
	sizeaz_bt.button_group = radio_group_1
	sizeza_bt.button_group = radio_group_1
	nameaz_bt.text = '名字\n顺序'
	nameaz_bt.name = 'NAME_AZ'
	nameza_bt.text = '名字\n倒序'
	nameza_bt.name = 'NAME_ZA'
	timeaz_bt.text = '时间\n顺序'
	timeaz_bt.name = 'TIME_AZ'
	timeza_bt.text = '时间\n倒序'
	timeza_bt.name = 'TIME_ZA'
	sizeaz_bt.text = '大小\n顺序'
	sizeaz_bt.name = 'SIZE_AZ'
	sizeza_bt.text = '大小\n逆序'
	sizeza_bt.name = 'SIZE_ZA'
	nameaz_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	nameza_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	timeaz_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	timeza_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	sizeaz_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	sizeza_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	nameaz_bt.connect('toggled', _on_sort_method_toggled.bind(nameaz_bt))
	nameza_bt.connect('toggled', _on_sort_method_toggled.bind(nameza_bt))
	timeaz_bt.connect('toggled', _on_sort_method_toggled.bind(timeaz_bt))
	timeza_bt.connect('toggled', _on_sort_method_toggled.bind(timeza_bt))
	sizeaz_bt.connect('toggled', _on_sort_method_toggled.bind(sizeaz_bt))
	sizeza_bt.connect('toggled', _on_sort_method_toggled.bind(sizeza_bt))
	if SORT_METHOD == 'NAME_AZ':
		nameaz_bt.set_pressed_no_signal(true)
	elif SORT_METHOD == 'NAME_ZA':
		nameza_bt.set_pressed_no_signal(true)
	elif SORT_METHOD == 'TIME_AZ':
		timeaz_bt.set_pressed_no_signal(true)
	elif SORT_METHOD == 'TIME_ZA':
		timeza_bt.set_pressed_no_signal(true)
	elif SORT_METHOD == 'SIZE_AZ':
		sizeaz_bt.set_pressed_no_signal(true)
	elif SORT_METHOD == 'SIZE_ZA':
		sizeza_bt.set_pressed_no_signal(true)
	hbox_setting_l4.add_child(nameaz_bt)
	hbox_setting_l4.add_child(nameza_bt)
	hbox_setting_l4.add_child(timeaz_bt)
	hbox_setting_l4.add_child(timeza_bt)
	hbox_setting_l4.add_child(sizeaz_bt)
	hbox_setting_l4.add_child(sizeza_bt)
	
	var ue_save_duration_label:Label = Label.new()
	ue_save_duration_label.name = 'ue_save_duration_label'
	ue_save_duration_label.text = '手机存储天数:'
	ue_save_duration_label.label_settings = label_setting_font_60
	hbox_setting_l5.add_child(ue_save_duration_label)
	var ue_save_duration_input:LineEdit = LineEdit.new()
	ue_save_duration_input.name = 'ue_save_duration_input'
	ue_save_duration_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ue_save_duration_input.text = "%s"%UE_SAVE_TIME
	ue_save_duration_input.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	ue_save_duration_input.connect("text_changed", _on_ue_save_time_changed)
	hbox_setting_l5.add_child(ue_save_duration_input)
	
	var rl:Dictionary = {'Picture': ['图片类型', hbox_setting_l6],
	'Vedio': ['视频类型', hbox_setting_l6_1], 
	'Music': ['音频类型', hbox_setting_l6_2], 
	'Others': ['其他类型', hbox_setting_l6_3], }
	for filetype in DIS_FILE_TYPE:
		var vbox_this_type:VBoxContainer = VBoxContainer.new()
		var a:Array = rl.get(filetype, ['', null])
		var hbox_type_list:Array = []
		var type_label:Label = Label.new()
		type_label.name = a[0]
		type_label.text = a[0]
		type_label.label_settings = label_setting_font_60
		var ext_dic:Dictionary = DIS_FILE_TYPE[filetype]
		var idx = 0
		for eacht in ext_dic:
			if idx % file_type_line_max_cnt == 0:
				hbox_type_list.append(HBoxContainer.new())
			idx += 1
			var r:CheckBox = CheckBox.new()
			r.name = eacht
			r.text = eacht
			r.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
			r.connect("toggled", _on_file_type_cb_toggled.bind(filetype, r))
			if ext_dic[eacht] == 'yes':
				r.set_pressed_no_signal(true)
			else:
				r.set_pressed_no_signal(false)
			hbox_type_list[hbox_type_list.size() - 1].add_child(r)
		for eachtt in hbox_type_list:
			vbox_this_type.add_child(eachtt)
		if a[1] != null:
			a[1].add_child(type_label)
			a[1].add_child(vbox_this_type)
	var add_type_input:LineEdit = LineEdit.new()
	add_type_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_type_input.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	var add_type_bt:Button = Button.new()
	add_type_bt.name = 'add_type_bt'
	add_type_bt.text = '增加类型'
	add_type_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_type_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	add_type_bt.connect("pressed", _on_add_type_bt_pressed.bind('add', add_type_input, hbox_setting_l6_3))
	var del_type_bt:Button = Button.new()
	del_type_bt.name = 'del_type_bt'
	del_type_bt.text = '删除类型'
	del_type_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_type_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	del_type_bt.connect("pressed", _on_add_type_bt_pressed.bind('del', add_type_input, hbox_setting_l6_3))
	hbox_setting_l6_4.add_child(add_type_input)
	hbox_setting_l6_4.add_child(add_type_bt)
	hbox_setting_l6_4.add_child(del_type_bt)
	
	var iabout:Button = Button.new()
	iabout.name = 'iabout'
	iabout.text = '关于...'
	iabout.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	iabout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_setting_l7.add_child(iabout)
	
	var line2:Line2D = Line2D.new()
	line2.name = 'line2'
	line2.add_point(Vector2i(0, 0))
	line2.add_point(Vector2i(win_size.x, 0))
	hbox_setting_le.add_child(line2)
		
	### L2
	var input_txt:LineEdit = LineEdit.new()
	input_txt.name = 'search_input'
	input_txt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_l2.add_child(input_txt)
	input_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cfm_bt:Button = Button.new()
	cfm_bt.text = '查询'
	cfm_bt.name = 'search_cfm'
	cfm_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	hbox_l2.add_child(cfm_bt)
	
	### L3
	## add by add_one_block
	var scroll_container:ScrollContainer = ScrollContainer.new()
	scroll_container.name = 'scroll_container'
	vbox_l3_vbox = VBoxContainer.new()
	vbox_l3_vbox.name = 'vbox_l3_vbox'
	vbox_l3.add_child(scroll_container)
	scroll_container.add_child(vbox_l3_vbox)
	scroll_container.custom_minimum_size.y = win_size.y - 20 - hbox_l1.size.y - hbox_l2.size.y
	
func add_one_block(idx:int, timek:String, block_dic:Array) -> void:
	log_window.add_log('[connect_home]->add_one_block')
	var s:int = (win_size.x - 10) / 3
	var vbox_block:VBoxContainer = VBoxContainer.new()
	vbox_block.name = 'vbox_block_%s'%[idx]
	var title_label:Label = Label.new()
	title_label.text = timek
	title_label.name = 'title_label'
	title_label.label_settings = label_setting_font_60
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
		texture_label.label_settings = label_setting_font_60
		var show_name_list:Array = wrap_txt("%s   %.1fMb"%[filename, filesize], 20)
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
	log_window.add_log('[connect_home]->sort_files_by_method_duration')
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
				log_window.add_log('[connect_home]->sort_files_by_method_duration: DIS_SIZE Error')
				return {}
		if not result.has(key):
			result[key] = []
		result[key].append(info)
	var rt:Dictionary = sort_dic(result)
	return rt

func update_and_show_files() -> void:
	log_window.add_log('[connect_home]->update_and_show_files')
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, DIS_FILE_TYPE)
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
	
func _on_login_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_login_bt_pressed')
	vbox_l1_1_login.visible = not vbox_l1_1_login.visible
	_force_win()
	
func _on_setting_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_setting_bt_pressed')
	vbox_l1_2_setting.visible = not vbox_l1_2_setting.visible
	_force_win()

func _on_save_cfg_bt_pressed(_login_tiltle_label:Label, save_cfg_bt:Button, server_ip_input:LineEdit, 
upload_port_input:LineEdit, download_port_input:LineEdit, usr_input:LineEdit, psd_input:LineEdit) -> void:
	log_window.add_log('[connect_home]->_on_save_cfg_bt_pressed')
	save_cfg_bt.text = '保存中... ...'
	SERVER_IP = server_ip_input.text
	UPLOAD_PORT = int(upload_port_input.text)
	DOWNLOAD_PORT = int(download_port_input.text)
	USR = usr_input.text
	PSD = psd_input.text
	save_cfg()
	save_cfg_bt.text = '登录&保存配置'
	var login_bt:Button = hbox_l1.get_child(0)
	login_bt.text = USR

func _on_test_bt_pressed(login_title_label:Label, test_bt:Button, server_ip_input:LineEdit, 
upload_port_input:LineEdit, download_port_input:LineEdit, usr_input:LineEdit, psd_input:LineEdit,
poolmax=10, loopmax=3):
	log_window.add_log('[connect_home]->_on_test_bt_pressed')
	var r = false
	test_bt.text = '测试中... ...'
	var _SERVER_IP:String = server_ip_input.text
	var _UPLOAD_PORT:int = int(upload_port_input.text)
	var _DOWNLOAD_PORT:int = int(download_port_input.text)
	var _USR:String = usr_input.text
	var _PSD:String = psd_input.text
	var taskid:String = generate_task_id()
	upload_obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, _SERVER_IP, _UPLOAD_PORT, _USR, _PSD, 3, 'no')
	upload_obj.connect_to_server(poolmax)
	r = upload_obj.login_do(loopmax)
	if r:
		login_title_label.text = '登录成功'
		login_title_label.label_settings = label_setting_font_blue
	else:
		login_title_label.text = '登录失败'
		login_title_label.label_settings = label_setting_font_red
		return false
	test_bt.text = '测试连接'
	upload_obj.disconnect_to_server()
	return r

func _on_setting_save_bt_pressed(setting_save_bt:Button) -> void:
	log_window.add_log('[connect_home]->_on_setting_save_bt_pressed:%s, %s, %s, %s, %s'%[JSON.stringify(SCAN_DIR_DIC), DIS_SIZE, '~'.join(DIS_DURATION),
	SORT_METHOD, UE_SAVE_TIME])
	save_setting()	
	setting_save_bt.add_theme_color_override('font_color', Color(0.0, 1.0, 0.0, 1.0))
	
func _on_dis_size_toggled(_idx:int, a:CheckBox) -> void:
	log_window.add_log('[connect_home]->_on_dis_size_toggled')
	DIS_SIZE = a.name

func _on_time_duration_selectd(_idx:int, y1:OptionButton, m1:OptionButton, d1:OptionButton, 
y2:OptionButton, m2:OptionButton, d2:OptionButton) -> void:
	log_window.add_log("%s, %s, %s,   %s, %s, %s"%[y1.selected, m1.selected, d1.selected, y2.selected, 
	m2.selected, d2.selected])
	var yy1:String = y1.get_item_text(y1.selected)
	var mm1:String = m1.get_item_text(m1.selected)
	var dd1:String = d1.get_item_text(d1.selected)
	var yy2:String = y2.get_item_text(y2.selected)
	var mm2:String = m2.get_item_text(m2.selected)
	var dd2:String = d2.get_item_text(d2.selected)
	log_window.add_log("%s, %s, %s,   %s, %s, %s"%[yy1, mm1, dd1, yy2, mm2, dd2])
	DIS_DURATION[0] = date_string_to_unix_timestamp(yy1, mm1, dd1)
	DIS_DURATION[1] = date_string_to_unix_timestamp(yy2, mm2, dd2)
	print(DIS_DURATION)

func _on_sort_method_toggled(_idx:int, a:CheckBox) -> void:
	SORT_METHOD = a.name

func _on_file_type_cb_toggled(idx:int, filetype:String, cb:CheckBox) -> void:
	if cb.name not in DIS_FILE_TYPE.get(filetype, {}):
		return
	if idx == 0:
		DIS_FILE_TYPE[filetype][cb.name] = 'no'
	else:
		DIS_FILE_TYPE[filetype][cb.name] = 'yes'
	print(DIS_FILE_TYPE)
	
func _force_win() -> void:
	hbox_l1.size = Vector2i(win_size.x, 40)
	vbox_l1_1_login.size = Vector2i(win_size.x, 40)
	vbox_l1_2_setting.size = Vector2i(win_size.x, 40)
	hbox_l2.size = Vector2i(win_size.x, 40)
	vbox_l3.size = Vector2i(win_size.x, 40)

### init -> pull_files_table -> scan_files -> deal_files -> update_and_show_files
func _on_scan_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_scan_bt_pressed')
	current_state = 'init'
	pre_current_state = 'init'
	update_state()

### upload_files -> push_files_table -> update_and_show_files
func _on_upload_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_upload_bt_pressed:%s, %s'%[pre_current_state, current_state])
	if pre_current_state == 'upload_files':
		update_state()
	else:
		log_window.add_log('[connect_home]->_on_scan_bt_pressed:please do the scan first')

### query_files -> delete_files -> push_files_table -> update_and_show_files
func _on_delete_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_delete_bt_pressed')
	current_state = 'upload_files'
	pre_current_state = 'query_files'
	update_state()
	
func _on_scan_dir_cb_toggled(idx:int, cb:CheckBox) -> void:
	log_window.add_log('[connect_home]->_on_on_scan_dir_cb_toggled:%s, %s'%[idx, cb.name])
	print(SCAN_DIR_DIC)
	if cb.name not in SCAN_DIR_DIC:
		return
	if idx == 0:
		SCAN_DIR_DIC[cb.name] = 'no'
	elif idx == 1:
		SCAN_DIR_DIC[cb.name] = 'yes'

func _on_add_scan_dir_bt_pressed(opr:String, new_scan_dir_input:LineEdit, hbox_setting_l1_1:HBoxContainer) -> void:
	if opr == 'add':
		var cb_r:CheckBox = CheckBox.new()
		cb_r.name = new_scan_dir_input.text
		cb_r.text = new_scan_dir_input.text
		cb_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb_r.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
		cb_r.set_pressed_no_signal(true)
		cb_r.connect("toggled", _on_scan_dir_cb_toggled.bind(cb_r))
		SCAN_DIR_DIC[new_scan_dir_input.text] = 'yes'
		hbox_setting_l1_1.add_child(cb_r)
		new_scan_dir_input.text = ''
	elif opr == 'del':
		var delnode:CheckBox = null
		for a in hbox_setting_l1_1.get_children():
			if a.text == new_scan_dir_input.text:
				delnode = a
				break
		if delnode != null:
			hbox_setting_l1_1.remove_child(delnode)
			SCAN_DIR_DIC[new_scan_dir_input.text] = 'del'
		new_scan_dir_input.text = ''

func _on_add_type_bt_pressed(opr:String, add_type_input:LineEdit, hbox_setting_l6_3:HBoxContainer) -> void:
	var a:VBoxContainer = hbox_setting_l6_3.get_child(1)
	if opr == 'add':
		var cb_r:CheckBox = CheckBox.new()
		cb_r.name = add_type_input.text
		cb_r.text = add_type_input.text
		cb_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb_r.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
		cb_r.set_pressed_no_signal(true)
		cb_r.connect("toggled", _on_scan_dir_cb_toggled.bind(cb_r))
		DIS_FILE_TYPE['Others'][add_type_input.text] = 'yes'
		var idx:int = int(DIS_FILE_TYPE.get('Others', {}).keys().find(add_type_input.text)/file_type_line_max_cnt)
		var aa:HBoxContainer = null
		if idx < a.get_children().size():
			aa = a.get_child(idx)
		else:
			aa = HBoxContainer.new()
			a.add_child(aa)
		aa.add_child(cb_r)
		add_type_input.text = ''
	elif opr == 'del':
		var delnode:CheckBox = null
		var idx:int = int(DIS_FILE_TYPE.get('Others', {}).keys().find(add_type_input.text)/file_type_line_max_cnt)
		var aa:HBoxContainer = a.get_child(idx)
		if aa != null:
			for b in aa.get_children():
				if b.text == add_type_input.text:
					delnode = b
					break
		if delnode != null:
			aa.remove_child(delnode)
			DIS_FILE_TYPE['Others'][add_type_input.text] = 'del'
		add_type_input.text = ''

func _on_ue_root_dir_changed(t:String) -> void:
	UE_ROOT_DIR = t
	print(UE_ROOT_DIR)

func _on_ue_save_time_changed(t:String) -> void:
	UE_SAVE_TIME = t.to_int()
	print(UE_SAVE_TIME)
	
func date_string_to_unix_timestamp(y:String, m:String, d:String) -> int:
	# 2. 构造初始日期字典
	var date_dict = {
		"year": int(y),
		"month": int(m),
		"day": int(d)
	}
	var test_timestamp = Time.get_unix_time_from_datetime_dict(date_dict)
	var test_date_dict = Time.get_datetime_dict_from_unix_time(test_timestamp)
	if not (test_date_dict.year == date_dict.year and test_date_dict.month == date_dict.month and test_date_dict.day == date_dict.day):
		var max_day = get_days_in_month(int(m), int(y))
		date_dict["day"] = max_day
	return Time.get_unix_time_from_datetime_dict(date_dict)

func get_days_in_month(month: int, year: int) -> int:
	if month in [4, 6, 9, 11]:
		return 30
	elif month == 2:
		var is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
		return 29 if is_leap else 28
	else:
		return 31
################################# for functions ##############################

func query_files() -> void:
	log_window.add_log("[connect_home]->query_files")
	var taskid:String = generate_task_id()
	query_obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'no')
	query_obj.connect("report_result", _on_class_report_result)
	var filedic:Dictionary = {}
	for eachf in delete_dic:
		var file_md5:String = FileAccess.get_md5(eachf)
		var filename:String = eachf.replace(UE_ROOT_DIR + '/', '')
		filedic[filename] = file_md5
	query_obj.query_files(filedic)
	
func deal_files() -> void:
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, DIS_FILE_TYPE)
	var files_dic:Dictionary = scan_files_obj.read_db()
	var all_files_dic:Dictionary = files_dic.get("all_files_dic", {})
	for eachpath in all_files_dic:
		var on_server = all_files_dic[eachpath]['on_server']
		var on_ue = all_files_dic[eachpath]['on_ue']
		if on_server == 'no' and on_ue == 'yes':#need upload
			upload_dic[eachpath] = 'not upload yet'
		elif on_ue == 'yes' and on_server == 'yes':#need check if need delete on UE
			if if_need_delete_ue_file(all_files_dic[eachpath], 7):
				delete_dic[eachpath] = 'not delete yet'
	_on_class_report_result('connect_home', '', 'deal_files', '', 'FINISH')
	
func upload_files() -> void:
	var t = Thread.new()
	t.start(upload_files_thread)

func upload_files_thread() -> void:
	for filepath in upload_dic:
		log_window.add_log("[connect_home]->upload_files_thread: will upload a file:%s"%[filepath])
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
		log_window.add_log('[connect_home]->delete_files:will delete file: %s'%[filepath])
		if FileAccess.file_exists(filepath):
			DirAccess.remove_absolute(filepath)
			delete_dic[filepath] = 'deleted'
	update_files_table_after_delete()
	_on_class_report_result('connect_home', '', 'delete_files', '', 'FINISH')
	
func upload_a_file(filepath) -> bool:
	var taskid:String = generate_task_id()
	upload_obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'no')
	upload_obj.connect("report_result", _on_class_report_result)
	upload_obj.upload_a_file(filepath)
	logs_dic.message = 'upload_a_file:%s'%[filepath]
	update_log()
	return true

func pull_files_table() -> void:
	log_window.add_log("[connect_home]->pull_files_table")
	var taskid:String = generate_task_id()
	pull_obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, DOWNLOAD_PORT, USR, PSD, 3, 'yes')
	pull_obj.connect("report_result", _on_class_report_result)
	var pull_file = UE_ROOT_DIR.path_join('files.txt')
	pull_obj.download_a_file(pull_file)

func push_files_table() -> void:
	log_window.add_log("[connect_home]->push_files_table")
	var taskid:String = generate_task_id()
	push_obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'yes')
	push_obj.connect("report_result", _on_class_report_result)
	var push_file = UE_ROOT_DIR.path_join('files.txt')
	push_obj.upload_a_file(push_file)

func update_files_table_after_upload() -> void:
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, DIS_FILE_TYPE)
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
	scan_files_obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, DIS_FILE_TYPE)
	var f_table:Dictionary = scan_files_obj.read_db().get('all_files_dic', {})
	var d_table:Dictionary = scan_files_obj.read_db().get('rename_files_dic', {})
	for eachfile in delete_dic:
		if delete_dic[eachfile] != 'deleted':
			continue
		if eachfile in f_table:
			f_table[eachfile]['on_ue'] = 'no'
	scan_files_obj.write_db({'all_files_dic': f_table, 'rename_files_dic': d_table})
	
func scan_files() -> void:
	log_window.add_log("[connect_home]->scan_files")
	var taskid:String = generate_task_id()
	scan_files_obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, DIS_FILE_TYPE)
	scan_files_obj.connect("scan_finished", _on_class_report_result)
	scan_files_obj.scan_a_dir(UE_ROOT_DIR)
	
func save_cfg():
	var cfg_infor:String = "SERVER_IP:%s\nUPLOAD_PORT:%s\nDOWNLOAD_PORT:%s\nUSR:%s\nPSD:%s\n"%[SERVER_IP, UPLOAD_PORT, DOWNLOAD_PORT, USR, PSD]
	var dir:String = CFG_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_absolute(dir)
	var f = FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(cfg_infor)
	else:
		log_window.add_log('save cfg infor failed')

func load_cfg():
	var f = FileAccess.open(CFG_PATH, FileAccess.READ)
	if f:
		var cfg_infor = f.get_line()
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
		log_window.add_log('load cfg failed2')

func save_setting() -> void:
	var setting_infor:String = \
	"UE_ROOT_DIR:%s\nSCAN_DIR_DIC:%s\nDIS_SIZE:%s\nDIS_DURATION:%s\nSORT_METHOD:%s\nUE_SAVE_TIME:%s\nDIS_FILE_TYPE:%s"\
	%[UE_ROOT_DIR, JSON.stringify(SCAN_DIR_DIC), DIS_SIZE, '~'.join(DIS_DURATION), 
	SORT_METHOD, UE_SAVE_TIME, JSON.stringify(DIS_FILE_TYPE)]
	var dir:String = SETTING_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_absolute(dir)
	var f = FileAccess.open(SETTING_PATH, FileAccess.WRITE)
	if f:
		f.store_string(setting_infor)
	else:
		log_window.add_log('save setting infor failed')
		
func load_setting() -> void:
	var f = FileAccess.open(SETTING_PATH, FileAccess.READ)
	if f:
		var cfg_infor = f.get_line()
		UE_ROOT_DIR = cfg_infor.replace('UE_ROOT_DIR:', '')
		if debug_on_win and '/storage/emulated/' in UE_ROOT_DIR:
			UE_ROOT_DIR = r'E:\pythonProject\2'
		cfg_infor = f.get_line()
		SCAN_DIR_DIC = JSON.parse_string(cfg_infor.replace('SCAN_DIR_DIC:', ''))
		cfg_infor = f.get_line()
		DIS_SIZE = cfg_infor.replace('DIS_SIZE:', '')
		cfg_infor = f.get_line()
		var a:String = cfg_infor.replace('DIS_DURATION:', '')
		DIS_DURATION[0] = a.split('~')[0].to_int()
		DIS_DURATION[1] = a.split('~')[1].to_int()
		cfg_infor = f.get_line()
		SORT_METHOD = cfg_infor.replace('SORT_METHOD:', '')
		cfg_infor = f.get_line()
		UE_SAVE_TIME = cfg_infor.replace('UE_SAVE_TIME:', '').to_int()
		cfg_infor = f.get_line()
		DIS_FILE_TYPE = JSON.parse_string(cfg_infor.replace('DIS_FILE_TYPE:', ''))
	else:
		log_window.add_log('load cfg failed2')
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
		log_window.add_log("[connect_home]->update_state:%s>%s"%[current_state, next_state])
		current_state = next_state
		var next_func = states.get(next_state, {}).get('func', null)
		if next_func != null:
			logs_dic.pre_current_status = pre_current_state
			logs_dic.current_status = current_state
			next_func.call()

func update_log() -> void:
	logs_show.call_deferred('set', 'text', "%s, %s, %s, %s, %s" % \
	[logs_dic.pre_current_status, logs_dic.current_status, logs_dic.res1, logs_dic.res2,
	logs_dic.message])

func pre_update_state() -> void:
	var next_state = states.get(current_state, {}).get('next_state', '')
	if next_state != '':
		log_window.add_log("[connect_home]->pre_update_state:%s>%s"%[current_state, next_state])
		pre_current_state = next_state
		logs_dic.pre_current_status = pre_current_state
		logs_dic.current_status = current_state
		update_log()
		
func _on_class_report_result(who_i_am:String, taskid:String, req_type:String, infor:String, result:String) -> void:
	log_window.add_log("[connect_home]->_on_class_report_result:%s-%s %s %s %s"%[who_i_am, taskid, req_type, infor, result])
	## 1 ### init -> pull_files_table -> scan_files -> deal_files -> update_and_show_files
	## 2 ###         upload_files -> push_files_table -> update_and_show_files
	## 3 ###         query_files -> delete_files -> push_files_table -> update_and_show_files
	if who_i_am == 'tcp_transf_class':
		if current_state == 'pull_files_table':## pull finish                                       ## 1.1
			if req_type == 'download' and taskid == pull_obj.taskid:# and result == 'FINISH':
				update_state()
		elif current_state == 'upload_files':## upload one file finish
			if req_type == 'upload' and taskid == upload_obj.taskid:# and result == 'FINISH':       ## 2.1
				log_window.add_log("[connect_home]->_on_class_report_result:upload file:%s, result:%s"%[infor, result])
				if result == 'FINISH':
					upload_dic[infor] = 'uploaded'
				upload_finish = true
		elif current_state == 'query_files':# query finish                                          ## 3.1
			if req_type == 'query' and taskid == query_obj.taskid:
				query_rt = result
				update_state()
		elif current_state == 'push_files_table':# push finish                                      ## !2.3  !3.3
			if req_type == 'upload' and taskid == push_obj.taskid:
				pre_update_state()
				update_and_show_files()
				
	elif who_i_am == 'scan_class':###                                                               ## 1.2
		if current_state == 'scan_files':# scan finish
			if taskid == scan_files_obj.taskid and result == 'FINISH':
				update_state()
				
	elif who_i_am == 'connect_home':
		if current_state == 'deal_files':# deal files finish                                        ## !1.3
			if req_type == 'deal_files' and result == 'FINISH':
				pre_update_state()
				update_and_show_files()
		elif current_state == 'upload_files':# upload all files finish                              ## 2.2
			if req_type == 'upload_files' and result == 'FINISH':
				current_state = 'delete_files'## force to delete_files
				update_state()
		elif current_state == 'delete_files':# delete files finish                                  ## 3.2
			if req_type == 'delete_files' and result == 'FINISH':
				pre_update_state()
		
	
	
	
	
	
