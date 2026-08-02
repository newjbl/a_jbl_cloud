extends Node2D

## cfg of service
var CFG_PATH:String = "user://db/cfg.ini"
var SETTING_PATH:String = "user://db/setting.ini"
var ICON_DIR:String = "user://db/icon/"
var UE_ROOT_DIR:String = r'/storage/emulated/0/'
var SCAN_DIR_DIC:Dictionary = {'DCIM':'yes', 'Pictures':'yes', 'Download':'yes'}
var SERVER_IP:String = ''
var UPLOAD_PORT:int = 6666
var DOWNLOAD_PORT:int = 7777
var USR:String = ''
var PSD:String = ''

## cfg of gui
var DIS_SIZE:String = 'DAY'
var DIS_DURATION:Array = [0, 4290604800]
var SORT_METHOD:String = 'NAME_AZ'# NAME_ZA, TIME_AZ, TIME_ZA, SIZE_AZ, SIZE_ZA
var UE_SAVE_TIME:int = 30
var DIS_FILE_TYPE:Dictionary = {'Picture':{'JPG':'yes', 'JPEG':'yes', 'PNG':'yes', 'GIF':'yes', 'BMP':'yes', 'HEIC':'yes', 'WEBP':'yes', 'TIFF':'yes'},
'Video': {'MP4':'yes', '3GP':'yes', '3G2':'yes', 'AVI':'yes', 'MOV':'yes', 'MKV':'yes', 'M4V':'yes', 'WMV':'yes', 'ASF':'yes', 'FLV':'yes'},
'Music': {'MP3':'yes', 'WMA':'yes', 'OGG':'yes', 'FLAC':'yes', 'APE':'yes', 'WAV':'yes', 'AAC':'yes', 'M4A':'yes', 'AMR':'yes', '3GPP':'yes', 'MKA':'yes', 'AC3':'yes', 'DTS':'yes'},
'Others': {'PDF':'yes', 'DOC':'yes', 'DOCX':'yes', 'APK':'yes'}}
var EXT_TYPE_DIC:Dictionary = {'JPG':'Picture', 'JPEG':'Picture', 'PNG':'Picture', 'GIF':'Picture', 'BMP':'Picture', 'HEIC':'Picture', 'WEBP':'Picture', 'TIFF':'Picture',
'MP4':'Video', '3GP':'Video', '3G2':'Video', 'AVI':'Video', 'MOV':'Video', 'MKV':'Video', 'M4V':'Video', 'WMV':'Video', 'ASF':'Video', 'FLV':'Video',
'MP3':'Music', 'WMA':'Music', 'OGG':'Music', 'FLAC':'Music', 'APE':'Music', 'WAV':'Music', 'AAC':'Music', 'M4A':'Music', 'AMR':'Music', '3GPP':'Music', 'MKA':'Music', 'AC3':'Music', 'DTS':'Music',
'PDF':'Document', 'DOC':'Document', 'DOCX':'Document', 'TXT':'Document', 'INI':'Document',
'APK':'Apk'}
var DIS_TYPE_KEY_LIST:Array = ['Picture']
var file_type_line_max_cnt:int = 6
var DEFAULT_FONT_SIZE:int = 60
var DEFAULT_FONT_HALF_SIZE:int = 30
var label_setting_font_60:LabelSettings = null
var label_setting_font_30:LabelSettings = null
var label_setting_font_15:LabelSettings = null
var label_setting_font_red:LabelSettings = null
var label_setting_font_blue:LabelSettings = null
var bt_theme:StyleBoxFlat = null
var input_theme:StyleBoxFlat = null

var win_size:Vector2i = Vector2i.ZERO
var hbox_l1:HBoxContainer = null
var vbox_l1_1_login:VBoxContainer = null
var vbox_l1_2_setting:VBoxContainer = null
var vbox_l1_3_uploadlist:VBoxContainer = null
var hbox_l2:HBoxContainer = null
var vbox_l3:VBoxContainer = null
var vbox_l3_vbox:VBoxContainer = null
var scroll_container:ScrollContainer = null
var scan_bt:Button = null
var upload_bt:Button = null
var delete_bt:Button = null

## cfg of show
var logs_show:Label = null
var logs_show_scan:Label = null
var logs_show_upload:Label = null
var logs_show_delete:Label = null
var e2z_dic:Dictionary = {
	'upload':'上传',
	'download':'下载',
	'login':'登录',
	'scan':'扫描',
}
var TIME_ITEM:Array = [1986, 2106]

## cfg of status control
var current_doing:String = ''
#var update_show_thread:Thread = null
#var upload_thread:Thread = null
#var update_files_aupload_thread:Thread = null
#var update_files_adelete_thread:Thread = null
var clear_dic:Dictionary = {}
var search_key:String = ''
var display_file_dic:Dictionary = {}
var need_clear_ui:bool = false
var need_update_ui:bool = false

## steps dic
var scan_file_rt:Dictionary = {}
var upload_dic:Dictionary = {}
var download_file_rt:Dictionary = {}
var delete_dic:Dictionary = {}

## show in multil page
var dis_sidx_list:Array = []
var dis_sidx:int = 0
var dis_height:int = 0
var go_next_pag_try_cnt:int = 0
var go_next_page_delay:int = 0

## touch control
var drag_threshold: float = 50.0
var long_press_threshold:float = 0.5
var is_pressing:bool = false
var is_long_pressing:bool = false
var press_start_pos:Vector2 = Vector2.ZERO
var last_scroll: int = 0
var texture_touch_dic:Dictionary = {}

var comtimer:Timer = null 
var log_window = null
var debug_on_win:bool = false
var task_dic:Dictionary = {}
var thread_list:Array = []

func _ready() -> void:
	comtimer = $Timer
	comtimer.connect("timeout", _on_long_press_timeout)
	$bd_color.color = Color(0.818, 0.818, 0.818, 1.0)
	debug_on_win = true if OS.get_name() == 'Windows' else false
	log_window = preload("res://class/log_window.tscn").instantiate()
	add_child(log_window)
	if OS.get_name() == 'Android':
		OS.request_permissions()
		var p:PackedStringArray = OS.get_granted_permissions()
		log_window.add_log("got these permissions:%s"%p)
	
	log_window.add_log("ue cfg dir is: %s"%ProjectSettings.globalize_path("user://"))
	log_window.add_log("ue scan root dir is: %s"%ProjectSettings.globalize_path(UE_ROOT_DIR))
	if not DirAccess.dir_exists_absolute("user://db//"):
		DirAccess.make_dir_recursive_absolute("user://db//")
	if not DirAccess.dir_exists_absolute("user://db/icon//"):
		DirAccess.make_dir_recursive_absolute("user://db/icon//")
	label_setting_font_60 = LabelSettings.new()
	label_setting_font_60.font_size = 60
	label_setting_font_60.font_color = Color(0.0, 0.0, 0.0, 1.0)
	label_setting_font_30 = LabelSettings.new()
	label_setting_font_30.font_size = 30
	label_setting_font_30.font_color = Color(0.0, 0.0, 0.0, 1.0)
	label_setting_font_15 = LabelSettings.new()
	label_setting_font_15.font_size = 15
	label_setting_font_15.font_color = Color(0.0, 0.0, 0.0, 1.0)
	label_setting_font_red = LabelSettings.new()
	label_setting_font_red.font_color = Color(1.0, 0.0, 0.0, 1.0)
	label_setting_font_blue = LabelSettings.new()
	label_setting_font_blue.font_color = Color(0.0, 1.0, 0.0, 1.0)
	bt_theme = StyleBoxFlat.new()
	bt_theme.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	bt_theme.border_width_left = 0
	bt_theme.border_width_right = 0
	bt_theme.border_width_top = 0
	bt_theme.border_width_bottom = 0
	input_theme = StyleBoxFlat.new()
	input_theme.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	input_theme.border_width_left = 0
	input_theme.border_width_right = 0
	input_theme.border_width_top = 0
	input_theme.border_width_bottom = 1
	input_theme.border_color = Color(0.5, 0.5, 0.5, 1.0)
	input_theme.set_corner_radius_all(4)  # 圆角半径
	
	load_cfg()
	load_setting()
	log_window.add_log("%s, %s, %s, %s" % [UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, DOWNLOAD_PORT])
	build_gui()
	update_and_show_files()
	
	#if current_state == 'init':
	#	update_state()
	for_test1()

func for_test1():
	# 确保在 Android 平台才执行
	if OS.get_name() != "Android":
		return

	# 1. 获取 Android 核心对象和上下文 (Context)
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	var context = android_runtime.get_context()

	# 2. 获取 PackageManager
	var package_manager = context.getPackageManager()

	# 3. 创建并设置查询 Intent (ACTION_MAIN + CATEGORY_LAUNCHER 表示所有“可启动”应用)
	var intent_class = JavaClassWrapper.wrap("android.content.Intent")
	var filter = intent_class.new("android.intent.action.MAIN")
	filter.addCategory("android.intent.category.LAUNCHER")

	# 4. 查询可解析此 Intent 的应用列表 (ResolveInfo)
	var activities = package_manager.queryIntentActivities(filter, 0)

	# 5. 遍历并获取应用名和包名
	var result_str = "Installed Apps:\n"
	for i in range(activities.size()):
		var resolve_info = activities.get(i)
		var app_info = resolve_info.activityInfo.applicationInfo

		# 获取应用名 (App Name)
		var app_name = package_manager.getApplicationLabel(app_info).toString()
		# 获取包名 (Package Name)
		var package_name = app_info.packageName

		result_str += "- App Name: {0}, Package: {1}\n".format([app_name, package_name])
		# 你也可以用 app_info.loadLabel(package_manager) 来获取名称

	print(result_str)

func for_test() -> void:
	var filepath = "/storage/emulated/0/ab/02.jpg"

	# 1. 检查文件是否存在
	if not FileAccess.file_exists(filepath):
		print("文件不存在: ", filepath)
		return

	# 2. 获取 Android 运行时和 Activity
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	if not android_runtime:
		print("AndroidRuntime not available")
		return
	var activity = android_runtime.getActivity()

	# 3. 包装需要的 Java 类
	var MediaStore = JavaClassWrapper.wrap("android.provider.MediaStore")
	var ImagesMedia = JavaClassWrapper.wrap("android.provider.MediaStore$Images$Media")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")

	# 4. 通过静态方法获取 content:// URI，而不是直接访问静态字段
	#    调用 MediaStore.getContentUri(String volumeName) 方法
	var external_uri = MediaStore.getContentUri("external")  # "external" 代表外部存储

	# 5. 准备查询参数，通过 DATA 字段匹配文件路径
	var resolver = activity.getContentResolver()
	var projection = ["_id"]
	var selection = ImagesMedia.DATA + "=?"
	var selection_args = [filepath]

	# 6. 执行查询，获取文件的 _id
	var cursor = resolver.query(external_uri, projection, selection, selection_args, null)
	var content_uri = null
	if cursor != null and cursor.moveToFirst():
		var id_column_index = cursor.getColumnIndex("_id")
		var id = cursor.getLong(id_column_index)
		content_uri = Uri.withAppendedPath(external_uri, str(id))
		cursor.close()

	# 7. 如果查询失败，尝试将文件复制到应用私有目录作为备选方案
	if content_uri == null:
		print("MediaStore 查询失败，尝试备选方案...")
		var dst_dir = "user://temp/"
		var dir = DirAccess.open("user://")
		if not dir.dir_exists("temp"):
			dir.make_dir("temp")
		var dst_path = "user://temp/" + filepath.get_file()
		var src = FileAccess.open(filepath, FileAccess.READ)
		var dst = FileAccess.open(dst_path, FileAccess.WRITE)
		dst.store_buffer(src.get_buffer(src.get_length()))
		dst.close()

		# 获取应用私有目录下文件的 content:// URI
		var FileProvider = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
		var context = activity.getApplicationContext()
		var authority = activity.getPackageName() + ".fileprovider"
		var file_obj = JavaClassWrapper.wrap("java.io.File").File(dst_path)
		content_uri = FileProvider.getUriForFile(context, authority, file_obj)

	# 8. 如果最终获取 URI 失败，退出
	if content_uri == null:
		print("无法获取文件的 content URI")
		return

	# 9. 创建并启动 Intent
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var intent = Intent.Intent()
	intent.setAction(Intent.ACTION_VIEW)
	intent.setDataAndType(content_uri, "image/jpeg")
	intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	activity.startActivity(intent)
	print("Intent 已启动")
		
########################################### for GUI ################################
func type_display_style(a, font_size, t=bt_theme) -> void:
	a.set('theme_override_colors/font_color', Color(0.0, 0.0, 0.0, 1.0))
	a.set('theme_override_colors/font_hover_color', Color(0.494, 0.0, 0.0, 1.0))
	a.add_theme_stylebox_override("normal", t)
	a.add_theme_stylebox_override("hover", t)
	a.add_theme_stylebox_override("pressed", t)
	a.add_theme_font_size_override('font_size', font_size)
	
func build_gui() -> void:
	log_window.add_log('[connect_home]->build_gui')
	win_size = DisplayServer.window_get_size() - Vector2i(100, 100)
	$bd_color.custom_minimum_size = win_size + Vector2i(100, 100)
	log_window.add_log("%s, %s"%[win_size.x, win_size.y])
	var vbox_top:VBoxContainer = VBoxContainer.new()
	vbox_top.name = 'TOP'
	vbox_top.size = win_size
	vbox_top.position = Vector2i(50, 50)
	
	var hbox_l0:HBoxContainer = HBoxContainer.new()
	hbox_l0.name = 'title'
	var app_title_label:Label = Label.new()
	app_title_label.text = '文件回家 V0.4.3'
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
	logs_show.size = Vector2i(win_size.x, 20)
	logs_show.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logs_show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_show.label_settings = label_setting_font_15
	hbox_l0_1.add_child(logs_show)
	
	var hbox_l0_2:HBoxContainer = HBoxContainer.new()
	hbox_l0_2.name = 'logs_show_details'
	logs_show_scan = Label.new()
	logs_show_scan.text = ''
	logs_show_scan.name = 'log_show_scan'
	logs_show_scan.size = Vector2i(win_size.x, 20)
	logs_show_scan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logs_show_scan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_show_scan.label_settings = label_setting_font_15
	hbox_l0_2.add_child(logs_show_scan)
	logs_show_upload = Label.new()
	logs_show_upload.text = ''
	logs_show_upload.name = 'log_show_upload'
	logs_show_upload.size = Vector2i(win_size.x, 20)
	logs_show_upload.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logs_show_upload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_show_upload.label_settings = label_setting_font_15
	hbox_l0_2.add_child(logs_show_upload)
	logs_show_delete = Label.new()
	logs_show_delete.text = ''
	logs_show_delete.name = 'log_show_delete'
	logs_show_delete.size = Vector2i(win_size.x, 20)
	logs_show_delete.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logs_show_delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs_show_delete.label_settings = label_setting_font_15
	hbox_l0_2.add_child(logs_show_delete)
	
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
	
	vbox_l1_3_uploadlist = VBoxContainer.new()
	vbox_l1_3_uploadlist.size = Vector2i(win_size.x - 5, 500)
	vbox_l1_3_uploadlist.visible = false
	vbox_l1_3_uploadlist.name = 'vbox_l1_3_uploadlist'
	
	hbox_l2 = HBoxContainer.new()
	hbox_l2.size = Vector2i(win_size.x - 5, 40)
	hbox_l2.name = 'L2'
	
	vbox_l3 = VBoxContainer.new()
	vbox_l3.size = Vector2i(win_size.x - 10, win_size.y - 100 - 40 - 40)
	vbox_l3.name = 'L3'
	
	add_child(vbox_top)
	vbox_top.add_child(hbox_l0)
	vbox_top.add_child(hbox_l0_1)
	vbox_top.add_child(hbox_l0_2)
	vbox_top.add_child(hbox_l1)
	vbox_top.add_child(vbox_l1_1_login)
	vbox_top.add_child(vbox_l1_2_setting)
	vbox_top.add_child(vbox_l1_3_uploadlist)
	vbox_top.add_child(hbox_l2)
	vbox_top.add_child(vbox_l3)
	
	### L1
	var login_bt:Button = Button.new()
	login_bt.text = '登录'
	login_bt.name = 'login_bt'
	type_display_style(login_bt, DEFAULT_FONT_SIZE)
	login_bt.connect("pressed", _on_login_bt_pressed)
	hbox_l1.add_child(login_bt)
	
	scan_bt = Button.new()
	scan_bt.text = '扫描文件'
	scan_bt.name = 'scan_bt'
	type_display_style(scan_bt, DEFAULT_FONT_SIZE)
	scan_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_bt.connect("pressed", _on_scan_bt_pressed)
	hbox_l1.add_child(scan_bt)
	
	upload_bt = Button.new()
	upload_bt.text = '上传文件'
	upload_bt.name = 'upload_bt'
	type_display_style(upload_bt, DEFAULT_FONT_SIZE)
	upload_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_bt.connect("pressed", _on_upload_bt_pressed)
	hbox_l1.add_child(upload_bt)
	
	delete_bt = Button.new()
	delete_bt.text = '清理文件'
	delete_bt.name = 'delete_bt'
	type_display_style(delete_bt, DEFAULT_FONT_SIZE)
	delete_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_bt.connect("pressed", _on_delete_bt_pressed)
	hbox_l1.add_child(delete_bt)
	
	var setting_bt:Button = Button.new()
	setting_bt.text = '···'
	setting_bt.name = 'setting'
	type_display_style(setting_bt, DEFAULT_FONT_SIZE)
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
	save_cfg_bt.text = '登录&保存'
	save_cfg_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_cfg_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	save_cfg_bt.connect("pressed", _on_save_cfg_bt_pressed.bind(login_tiltle_label, save_cfg_bt,
	server_ip_input, upload_port_input, download_port_input, usr_input, psd_input))
	hbox_login_l7.add_child(save_cfg_bt)
	var clear_cfg_bt:Button = Button.new()
	clear_cfg_bt.name = 'clear_cfg_bt'
	clear_cfg_bt.text = '删除配置文件'
	clear_cfg_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_cfg_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	clear_cfg_bt.add_theme_color_override('font_color', Color(1.0, 0.0, 0.0, 1.0))
	clear_cfg_bt.connect("pressed", _on_delete_cfg_bt_pressed)
	hbox_login_l7.add_child(clear_cfg_bt)
	var test_bt:Button = Button.new()
	test_bt.name = 'test_bt'
	test_bt.text = '测试连接'
	test_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
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
	setting_save_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	setting_save_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_save_bt.connect("pressed", _on_setting_save_bt_pressed.bind(setting_save_bt))
	hbox_setting_l1.add_child(setting_save_bt)
	
	var setting_delete_bt:Button = Button.new()
	setting_delete_bt.name = 'setting_delete_bt'
	setting_delete_bt.text = '删除配置文件'
	setting_delete_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_HALF_SIZE)
	setting_delete_bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setting_delete_bt.connect("pressed", _on_setting_delete_bt_pressed)
	hbox_setting_l1.add_child(setting_delete_bt)
	
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
	'Video': ['视频类型', hbox_setting_l6_1], 
	'Music': ['音频类型', hbox_setting_l6_2], 
	'Others': ['其他类型', hbox_setting_l6_3], }
	for filetype in DIS_FILE_TYPE:
		var vbox_this_type:VBoxContainer = VBoxContainer.new()
		var a:Array = rl.get(filetype, ['-', null])
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
	
	### vbox_l1_3_uploadlist
	var uploadlistc_ctl:HBoxContainer = HBoxContainer.new()
	var bt_hide:Button = Button.new()
	bt_hide.name = 'bt_hide'
	bt_hide.text = '隐藏下载界面'
	bt_hide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bt_stopall:Button = Button.new()
	bt_stopall.name = 'bt_stopall'
	bt_stopall.text = '停止所有下载'
	bt_stopall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bt_retryall:Button = Button.new()
	bt_retryall.name = 'bt_retryall'
	bt_retryall.text = '重试所有下载'
	bt_retryall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uploadlistc_ctl.add_child(bt_hide)
	uploadlistc_ctl.add_child(bt_stopall)
	uploadlistc_ctl.add_child(bt_retryall)
	vbox_l1_3_uploadlist.add_child(uploadlistc_ctl)
	### auto update
		
	### L2
	var filter_type:OptionButton = OptionButton.new()
	filter_type.name = 'filter_type'
	type_display_style(filter_type, DEFAULT_FONT_HALF_SIZE)
	filter_type.add_item("图片", 0)
	filter_type.add_item("视频", 1)
	filter_type.add_item("图片和视频", 2)
	filter_type.add_item("音频", 3)
	filter_type.add_item("其他", 4)
	filter_type.add_item("所有", 5)
	var filter_type_pop:PopupMenu = filter_type.get_popup()
	type_display_style(filter_type_pop, DEFAULT_FONT_HALF_SIZE)
	filter_type.connect("item_selected", _on_filter_type_toggled.bind(filter_type))
	hbox_l2.add_child(filter_type)
	var input_txt:LineEdit = LineEdit.new()
	input_txt.name = 'search_input'
	type_display_style(input_txt, DEFAULT_FONT_SIZE, input_theme)
	hbox_l2.add_child(input_txt)
	input_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cfm_bt:Button = Button.new()
	cfm_bt.text = '查询'
	cfm_bt.name = 'search_cfm'
	type_display_style(cfm_bt, DEFAULT_FONT_HALF_SIZE)
	cfm_bt.add_theme_stylebox_override("normal", bt_theme)
	cfm_bt.add_theme_font_size_override('font_size', DEFAULT_FONT_SIZE)
	cfm_bt.connect('pressed', _on_search_bt_pressed.bind(input_txt))
	hbox_l2.add_child(cfm_bt)
	
	### L3
	## add by add_one_block
	scroll_container = ScrollContainer.new()
	scroll_container.name = 'scroll_container'
	vbox_l3_vbox = VBoxContainer.new()
	vbox_l3_vbox.name = 'vbox_l3_vbox'
	vbox_l3.add_child(scroll_container)
	scroll_container.add_child(vbox_l3_vbox)
	scroll_container.custom_minimum_size.y = 2000
	scroll_container.get_v_scroll_bar().connect("value_changed", _on_scroll_value_changed)
	
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
		var on_ue:String = filedic.get('on_ue', 'no')
		var on_server:String = filedic.get('on_server', 'no')
		var on_server_status:String = filedic.get('status', 'normal')
		var icon_path:String = ICON_DIR.path_join(filedic.get('md5', '')) + '.png'
		var texture_vbox:VBoxContainer = VBoxContainer.new()
		texture_vbox.name = 'texture_box_%s'%[idy]
		var texture_rec:TextureRect = TextureRect.new()
		texture_rec.name = "texture_rect_%s"%idy
		if on_server == 'yes':
			var texture_on_server:TextureRect = TextureRect.new()
			texture_on_server.name = 'texture_on_server'
			texture_on_server.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_on_server.custom_minimum_size = Vector2i(16, 16)
			texture_on_server.position = Vector2i(s - 30, 10)
			texture_on_server.texture = load("res://db/on_server.png")
			texture_rec.add_child(texture_on_server)
		if on_ue == 'yes':
			var texture_on_ue:TextureRect = TextureRect.new()
			texture_on_ue.name = 'texture_on_ue'
			texture_on_ue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_on_ue.custom_minimum_size = Vector2i(16, 16)
			texture_on_ue.position = Vector2i(s - 30, s - 30)
			texture_on_ue.texture = load("res://db/on_ue.png")
			texture_rec.add_child(texture_on_ue)
		if on_server_status != 'normal':
			var texture_on_ue_status:TextureRect = TextureRect.new()
			texture_on_ue_status.name = 'texture_on_ue_status'
			texture_on_ue_status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_on_ue_status.custom_minimum_size = Vector2i(16, 16)
			texture_on_ue_status.position = Vector2i(10, s - 30)
			if on_server_status == 'damaged':
				texture_on_ue_status.texture = load("res://db/file_damaged.png")
			elif on_server_status == 'lost':
				texture_on_ue_status.texture = load("res://db/file_lost.png")
			texture_rec.add_child(texture_on_ue_status)
		var texture_label:Label = Label.new()
		texture_label.name = 'texture_label'
		texture_label.label_settings = label_setting_font_15
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
		var are2d:Area2D = Area2D.new()
		are2d.name = 'area2d'
		are2d.position = Vector2(s / 2, s / 2)
		var coll2d:CollisionShape2D = CollisionShape2D.new()
		var recshape:RectangleShape2D = RectangleShape2D.new()
		recshape.size = Vector2(s, s)
		coll2d.shape = recshape
		are2d.add_child(coll2d)
		texture_rec.add_child(are2d)
		var filepath_onue:String = filedic.get('ue_dir', '')
		are2d.connect('input_event', _on_are2d_input.bind(UE_ROOT_DIR.path_join(filepath_onue), texture_rec))
		idy += 1
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
	var file_type_list:Array = []
	for k in DIS_FILE_TYPE:
		if k not in DIS_TYPE_KEY_LIST:
			continue
		for kk in DIS_FILE_TYPE[k]:
			if kk not in file_type_list:
				file_type_list.append(kk.to_upper())
	for filename in f_table:
		var info:Dictionary = f_table[filename]
		if info.get('filetype', '').to_upper() not in file_type_list:
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
	#if update_show_thread:
	#	update_show_thread.wait_to_finish()
	var _update_show_thread = Thread.new()
	thread_list.append(_update_show_thread)
	_update_show_thread.start(update_and_show_files_thread)

func update_and_show_files_thread() -> void:
	log_window.add_log('[connect_home]->update_and_show_files_thread')
	var taskid:String = generate_task_id()
	var _obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, 
	DIS_FILE_TYPE, EXT_TYPE_DIC, ICON_DIR)
	task_dic[taskid] = _obj
	var f_table:Dictionary = _obj.read_db().get('all_files_dic', {})
	display_file_dic = sort_files_by_method_duration(f_table)
	get_dis_sidx_list()
	#call_deferred('clear_ui')
	#call_deferred('update_ui', file_dic)
	need_update_ui = true
	_obj._destory()
	#log_window.add_log('[connect_home]->update_and_show_files_thread:thread_finish:%s'%[display_file_dic.size()])

func get_dis_sidx_list() -> void:
	dis_sidx_list = []
	var timek_list:Array = display_file_dic.keys()
	timek_list.sort()
	var dis_cnt:int = 0
	var idx:int = 0
	var sidx:int = 0
	while idx < len(timek_list):
		var timek:String = timek_list[timek_list.size() - idx -1]
		for eachf in display_file_dic[timek]:
			if search_key == '' or search_key.to_upper() in eachf.filename.to_upper():
				dis_cnt += 1
		if dis_cnt >= 24:
			print('-->%s, %s, %s'%[timek, idx, dis_cnt])
			dis_sidx_list.append(sidx)
			sidx = idx + 1
			dis_cnt = 0
		idx += 1
	if dis_cnt < 24:
		dis_sidx_list.append(sidx)
	print('[connect_home]->get_dis_sidx_list:dis_sidx_list is:', dis_sidx_list)
	
func update_ui() -> void:
	log_window.add_log('[connect_home]->update_ui:%s, %s'%[dis_sidx, dis_sidx_list[dis_sidx]])
	clear_ui()
	var timek_list:Array = display_file_dic.keys()
	timek_list.sort()
	var dis_cnt:int = 0
	for idx in range(dis_sidx_list[dis_sidx], timek_list.size()):
		var timek:String = timek_list[timek_list.size() - idx -1]
		var show_list:Array = []
		for eachf in display_file_dic[timek]:
			if search_key == '' or search_key.to_upper() in eachf.filename.to_upper():
				show_list.append(eachf)
				dis_cnt += 1
		if show_list:
			add_one_block(dis_sidx, timek, show_list)
		if dis_cnt >= 24:
			break
	show_sub_log()
	dis_height = 0
	log_window.add_log('[connect_home]->update_ui end:%s, %s, %s'%[dis_sidx, dis_sidx_list[dis_sidx], dis_cnt])

func clear_ui() -> void:
	log_window.add_log('[connect_home]->clear_ui')
	for obj in vbox_l3_vbox.get_children():
		vbox_l3_vbox.remove_child(obj)
		obj.queue_free()
		
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
	var week_first_day_unix:int = ts - (dt['weekday'] - 1) * 86400
	var week_end_day_unix:int = week_first_day_unix + 6 * 86400
	return "%s ~ %s"%[_ts_to_date_str(week_first_day_unix), _ts_to_date_str(week_end_day_unix)]

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
	_on_login_bt_pressed()
	update_and_show_files()

func _on_delete_cfg_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_delete_cfg_bt_pressed')
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)
	
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
	var _obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, _SERVER_IP, _UPLOAD_PORT, _USR, _PSD, 3, 'no')
	#task_dic[taskid] = _obj
	_obj.connect_to_server(poolmax)
	r = _obj.login_do(loopmax)
	if r:
		login_title_label.text = '登录成功'
		login_title_label.label_settings = label_setting_font_blue
	else:
		login_title_label.text = '登录失败'
		login_title_label.label_settings = label_setting_font_red
		return false
	test_bt.text = '测试连接'
	_obj._destory()
	return r

func _on_setting_save_bt_pressed(setting_save_bt:Button) -> void:
	log_window.add_log('[connect_home]->_on_setting_save_bt_pressed:%s, %s, %s, %s, %s'%[JSON.stringify(SCAN_DIR_DIC), DIS_SIZE, '~'.join(DIS_DURATION),
	SORT_METHOD, UE_SAVE_TIME])
	save_setting()	
	setting_save_bt.add_theme_color_override('font_color', Color(0.0, 1.0, 0.0, 1.0))
	_on_setting_bt_pressed()
	update_and_show_files()

func _on_setting_delete_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_setting_delete_bt_pressed')
	if FileAccess.file_exists(SETTING_PATH):
		DirAccess.remove_absolute(SETTING_PATH)
	
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
	scan__start_scan()

### upload_files -> push_files_table -> update_and_show_files
func _on_upload_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_upload_bt_pressed')
	if upload_dic.get('notuploadyet', 0) > 0:
		upload__start_upload()
	else:
		log_window.add_log('[connect_home]->_on_upload_bt_pressed:no need upload')
		show_main_log('无需上传!')

### query_files -> delete_files -> push_files_table -> update_and_show_files
func _on_delete_bt_pressed() -> void:
	log_window.add_log('[connect_home]->_on_delete_bt_pressed')
	
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

func _on_filter_type_toggled(_idx:int, op:OptionButton) -> void:
	var a:String = op.get_item_text(op.selected)
	if a == "图片":
		DIS_TYPE_KEY_LIST = ['Picture']
	elif a == "视频":
		DIS_TYPE_KEY_LIST = ['Video']
	elif a == "图片和视频":
		DIS_TYPE_KEY_LIST = ['Picture', 'Video']
	elif a == "音频":
		DIS_TYPE_KEY_LIST = ['Music']
	elif a == "其他":
		DIS_TYPE_KEY_LIST = ['Others']
	elif a == "所有":
		DIS_TYPE_KEY_LIST = ['Picture', 'Video', 'Music', 'Others']
	print(DIS_TYPE_KEY_LIST)
	update_and_show_files()

func _on_search_bt_pressed(input_line:LineEdit) -> void:
	search_key = input_line.text
	update_and_show_files()

func _on_are2d_input(vp:Node, evt:InputEvent, si:int, filepath:String, _texture_rec:TextureRect) -> void:
	if evt is InputEventScreenTouch and evt.is_pressed():
		print("_on_are2d_input:%s, %s, %s, %s, %s"%[vp, evt, si, filepath, evt.position])
		texture_touch_dic = {'filepath': filepath, 'pos': evt.position}

func open_a_file(filepath:String) -> void:
	if not FileAccess.file_exists(filepath):
		download_a_file(filepath)
	if FileAccess.file_exists(filepath):
		open_a_file_now(filepath)
	else:
		show_main_log('文件不存在!')

func open_a_file_now(_filepath:String) -> void:
	print('open_a_file_now')

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
func delete_files() -> void:
	var upload_again_list:Array = []
	var upload_again_list_:Array = []
	var success_cnt:int = 0
	var failed_cnt:int = 0
	#if query_rt != 'all ok':
	#	upload_again_list_ = query_rt.split(';')
	for eachf in upload_again_list_:
		upload_again_list.append(UE_ROOT_DIR.path_join(eachf))
	for filepath in delete_dic:
		if filepath in upload_again_list:
			failed_cnt += 1
			continue
		log_window.add_log('[connect_home]->delete_files:will delete file: %s'%[filepath])
		if FileAccess.file_exists(filepath):
			DirAccess.remove_absolute(filepath)
			delete_dic[filepath] = 'deleted'
			success_cnt += 1
	update_files_table_after_delete()
	#_on_class_report_result('connect_home', '', 'delete_files', '应清理:%s个, 清理成功%s个, 清理失败%s个'%[
	#	delete_dic.keys().size(), success_cnt, failed_cnt], 'FINISH')

func download_a_file(_filepath:String) -> void:
	show_main_log('下载中... ...')
	#var taskid:String = generate_task_id()
	#download_obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, DOWNLOAD_PORT, USR, PSD, 3, 'no')
	#download_obj.download_a_file(filepath)

func update_files_table_after_upload() -> void:
	#if update_files_aupload_thread:
	#	update_files_aupload_thread.wait_to_finish()
	var _update_files_aupload_thread = Thread.new()
	thread_list.append(_update_files_aupload_thread)
	_update_files_aupload_thread.start(update_files_table_after_upload_thread)
	
func update_files_table_after_upload_thread() -> void:
	log_window.add_log("[connect_home]->update_files_table_after_upload_thread start")
	var taskid:String = generate_task_id()
	var _obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, 
	DIS_FILE_TYPE, EXT_TYPE_DIC, ICON_DIR)
	task_dic[taskid] = _obj
	var f_table:Dictionary = _obj.read_db().get('all_files_dic', {})
	var d_table:Dictionary = _obj.read_db().get('rename_files_dic', {})
	for eachfile in upload_dic['dic']:
		if upload_dic['dic'][eachfile]['rt'] != 'uploaded':
			continue
		if eachfile in f_table:
			f_table[eachfile]['on_server'] = 'yes'
	_obj.write_db({'all_files_dic': f_table, 'rename_files_dic': d_table})
	_obj._destory()
	log_window.add_log("[connect_home]->update_files_table_after_upload_thread finish")
	
func update_files_table_after_delete() -> void:
	#if update_files_adelete_thread:
	#	update_files_adelete_thread.wait_to_finish()
	var _update_files_adelete_thread = Thread.new()
	thread_list.append(_update_files_adelete_thread)
	_update_files_adelete_thread.start(update_files_table_after_delete_thread)
		
func update_files_table_after_delete_thread() -> void:
	var taskid:String = generate_task_id()
	var _obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, 
	DIS_FILE_TYPE, EXT_TYPE_DIC, ICON_DIR)
	task_dic[taskid] = _obj
	var f_table:Dictionary = _obj.read_db().get('all_files_dic', {})
	var d_table:Dictionary = _obj.read_db().get('rename_files_dic', {})
	for eachfile in delete_dic:
		if delete_dic[eachfile] != 'deleted':
			continue
		if eachfile in f_table:
			f_table[eachfile]['on_ue'] = 'no'
	_obj.write_db({'all_files_dic': f_table, 'rename_files_dic': d_table})
	_obj._destory()
		
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

func show_sub_log() -> void:
	if 'add' in scan_file_rt:
		logs_show_scan.call_deferred("set_text", "%s"%['扫描:%s, 新增:%s, 修改:%s, 可删除:%s'%[
			scan_file_rt.all, scan_file_rt.add, scan_file_rt.mod, scan_file_rt.del]])
	if upload_dic.get('notuploadyet', 0) + upload_dic.get('uploading', 0) + \
		upload_dic.get('uploaded', 0) + upload_dic.get('uploadfailed', 0) > 0:
		logs_show_upload.call_deferred("set_text", "%s"%['待上传:%s, 上传中:%s, 上传成功:%s, 上传失败:%s'%[
			upload_dic.notuploadyet, upload_dic.uploading, upload_dic.uploaded, upload_dic.uploadfailed]])
	#logs_show_delete.call_deferred("set_text", "%s"%[logs_dic.delete_rt])

func show_main_log(msg:String) -> void:
	var t:String = logs_show.text.replace(current_doing, '') + '>' + msg
	if len(t) > 70:
		t = t.substr(len(t) - 70)
	logs_show.call_deferred("set_text", current_doing + t)
	
func show_upload_process() -> void:
	var b:int = 0
	var c:int = 0
	for eachf in upload_dic['dic']:
		b += upload_dic['dic'][eachf]['process']
		c += upload_dic['dic'][eachf]['size']
	if c != 0:
		show_main_log('%.1f%%'%[100.0 * b / c]) 

############################################ function control begin #################################
## 1 ### init -> pull_files_table -> scan_files -> deal_files -> update_and_show_files
func scan__start_scan() -> void:
	current_doing = '【扫描】:'
	log_window.add_log('[connect_home]->scan__start_scan')
	show_main_log('开始扫描!')
	scan_file_rt = {}
	upload_dic = {'notuploadyet':0, 'uploading': 0, 'uploaded':0, 'uploadfailed':0, 'dic':{}}
	scan__start_pull_files_table()

func scan__start_pull_files_table() -> void:
	log_window.add_log('[connect_home]->scan__start_pull_files_table')
	show_main_log('拉取文件列表')
	var taskid:String = generate_task_id()
	var _obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, DOWNLOAD_PORT, USR, PSD, 3, 'yes')
	task_dic[taskid] = _obj
	_obj.connect("report_result", scan__end_pull_files_table.bind(taskid, _obj))
	var pull_file = UE_ROOT_DIR.path_join('files.txt')
	_obj.download_a_file(pull_file)
	
func scan__end_pull_files_table(who_i_am:String, taskid:String, req_type:String, infor:String, result:String, _taskid:String, _obj:TCP_TRANSF_C) -> void:
	log_window.add_log("[connect_home]->scan__end_pull_files_table:%s-%s %s %s %s, %s"%[who_i_am, taskid, req_type, infor, result, _taskid])
	if who_i_am == 'tcp_transf_class' and taskid == _taskid and req_type == 'download':
		if result in ['FINISH', 'ERROR7']:
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('拉取完成')
			scan__start_scan_files()
		elif result == 'FAILED':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('拉取失败，扫描停止!!!!!')
		else:
			log_window.add_log('[connect_home]->scan__end_pull_files_table, error result:%s, %s'%[req_type, result])
		show_sub_log()
	else:
		log_window.add_log('[connect_home]->scan__end_pull_files_table, error message:%s, %s'%[req_type, result])
	
func scan__start_scan_files() -> void:
	log_window.add_log('[connect_home]->scan__start_scan_files')
	show_main_log('开始扫描文件...')
	var taskid:String = generate_task_id()
	var _obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, 
	DIS_FILE_TYPE, EXT_TYPE_DIC, ICON_DIR)
	task_dic[taskid] = _obj
	_obj.connect("scan_finished", scan__end_scan_files.bind(taskid, _obj))
	_obj.scan_a_dir(UE_ROOT_DIR)
	
func scan__end_scan_files(who_i_am:String, taskid:String, req_type:String, infor:String, result:String, _taskid:String, _obj:SCAN_C) -> void:
	log_window.add_log("[connect_home]->scan__end_scan_files:%s-%s %s %s %s, %s"%[who_i_am, taskid, req_type, infor, result, _taskid])
	if who_i_am == 'scan_class' and taskid == _taskid and req_type == 'scan':
		if result == 'FINISH':
			scan_file_rt = JSON.parse_string(infor)
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('扫描文件完成!')
			scan__start_deal_files()
		elif result == 'FAILED':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('扫描文件失败, 扫描终止!!!!!')
		else:
			log_window.add_log('[connect_home]->scan__end_scan_files, error result:%s, %s'%[req_type, result])
		show_sub_log()
	else:
		log_window.add_log('[connect_home]->scan__end_scan_files, error message:%s, %s'%[req_type, result])
	
func scan__start_deal_files() -> void:
	log_window.add_log('[connect_home]->scan__start_deal_files')
	show_main_log('整理文件!')
	var taskid:String = generate_task_id()
	var _obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, 
	DIS_FILE_TYPE, EXT_TYPE_DIC, ICON_DIR)
	task_dic[taskid] = _obj
	var files_dic:Dictionary = _obj.read_db()
	var all_files_dic:Dictionary = files_dic.get("all_files_dic", {})
	_obj._destory()
	for eachpath in all_files_dic:
		var on_server = all_files_dic[eachpath]['on_server']
		var on_ue = all_files_dic[eachpath]['on_ue']
		if on_server == 'no' and on_ue == 'yes':#need upload
			if eachpath not in upload_dic['dic']:
				upload_dic['dic'][eachpath] = {}
			upload_dic['dic'][eachpath]['rt'] = 'notuploadyet'
			upload_dic['dic'][eachpath]['process'] = 0
			upload_dic['dic'][eachpath]['size'] = 0
			upload_dic['notuploadyet'] += 1
		elif on_ue == 'yes' and on_server == 'yes':#need check if need delete on UE
			if if_need_delete_ue_file(all_files_dic[eachpath], 7):
				delete_dic[eachpath] = 'not delete yet'
	scan__end_scan()
	
func scan__end_scan() -> void:
	log_window.add_log('[connect_home]->scan__end_scan')
	show_main_log('扫描完成!')
	show_sub_log()
	update_and_show_files()
	
## 2 ###         upload_files -> push_files_table -> update_and_show_files
func upload__start_upload() -> void:
	current_doing = '【上传】:'
	log_window.add_log('[connect_home]->upload__start_upload')
	show_main_log('开始上传!')
	show_sub_log()
	#if upload_thread:
	#	upload_thread.wait_to_finish()
	var _upload_thread = Thread.new()
	thread_list.append(_upload_thread)
	_upload_thread.start(upload__start_upload_thread)
	#build_upload_task()
	
func upload__start_upload_thread() -> void:
	log_window.add_log('[connect_home]->upload__start_upload_thread')
	while upload_dic['notuploadyet'] > 0:
		var need_upload_cnt:int = max(0, 5 - upload_dic['uploading'])
		if need_upload_cnt <= 0:
			continue
		#log_window.add_log("[connect_home]->upload_files_thread:current upload_dic:%s"%[JSON.stringify(upload_dic['dic'])])
		for filepath in upload_dic['dic']:
			if upload_dic['dic'][filepath]['rt'] != 'notuploadyet':
				continue
			upload_dic['dic'][filepath]['rt'] = 'uploading'
			upload_dic['uploading'] += 1
			upload_dic['notuploadyet'] -= 1
			show_sub_log()
			log_window.add_log("[connect_home]->upload_files_thread:will upload:%s"%filepath)
			upload__upload_a_file(filepath)
			need_upload_cnt -= 1
			if need_upload_cnt <= 0:
				break
	log_window.add_log("[connect_home]->upload_files_thread:thread_finish")

func upload__upload_a_file(filepath:String) -> bool:
	var taskid:String = generate_task_id()
	var _obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'no')
	task_dic[taskid] = _obj
	_obj.connect("report_result", upload__receive_upload_finish.bind(taskid, _obj))
	_obj.upload_a_file(filepath)
	return true
	
func upload__receive_upload_finish(who_i_am:String, taskid:String, req_type:String, infor:String, result:String, _taskid:String, _obj:TCP_TRANSF_C) -> void:
	#log_window.add_log("[connect_home]->upload__receive_upload_finish:%s-%s %s %s %s, %s"%[who_i_am, taskid, req_type, infor, result, _taskid])
	if who_i_am == 'tcp_transf_class' and req_type == 'upload' and taskid == _taskid:
		#if result == 'START' and req_type in e2z_dic:
		#	pass
		#	show_main_log('开始%s:%s'%[e2z_dic.get(req_type, ''), infor])
		if result == 'PROCESS':
			var a:Array = infor.split(';')
			var filepath:String = a[1]
			if filepath in upload_dic['dic']:
				upload_dic['dic'][filepath]['process'] = a[0].to_int()
				upload_dic['dic'][filepath]['size'] = a[2].to_int()
			show_upload_process()	
		elif result == 'FAILED':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('失败!')
			log_window.add_log("[connect_home]->upload__receive_upload_finish:failed!!!!!!!")
			upload_dic['dic'][infor]['rt'] = 'uploadfailed'
			upload_dic['dic'][infor]['process'] = upload_dic['dic'][infor]['size']
			upload_dic['uploadfailed'] += 1
			upload_dic['uploading'] -= 1
			if upload_dic['notuploadyet'] + upload_dic['uploading'] == 0:
				show_upload_process()
				upload__start_query_files_dic(upload_dic)
		elif result in ['FINISH', 'ERROR2']:
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			log_window.add_log("[connect_home]->upload__receive_upload_finish:upload file:%s, result:%s"%[infor, result])
			if result == 'FINISH':
				show_main_log('上传完成:%s'%[infor])
			else:
				show_main_log('已经存在不需要上传:%s'%[infor])
			upload_dic['dic'][infor]['rt'] = 'uploaded'
			upload_dic['dic'][infor]['process'] = upload_dic['dic'][infor]['size']
			upload_dic['uploaded'] += 1
			upload_dic['uploading'] -= 1
			if upload_dic['notuploadyet'] + upload_dic['uploading'] == 0:
				show_upload_process()
				upload__start_query_files_dic(upload_dic)
		else:
			log_window.add_log("[connect_home]->upload__receive_upload_finish:other message")
		show_sub_log()
	else:
		log_window.add_log("[connect_home]->upload__receive_upload_finish:unknown message:%s, %s"%[req_type, result])

func upload__start_query_files_dic(_filedic:Dictionary) -> void:
	log_window.add_log("[connect_home]->upload__start_query_files_dic")
	var taskid:String = generate_task_id()
	var _obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'no')
	task_dic[taskid] = _obj
	_obj.connect("report_result", upload__end_query_files_dic.bind(taskid, _obj))
	var querydic:Dictionary = {}
	var _querydic:Dictionary = _filedic.get('dic', {})
	for eachf in _querydic:
		var file_md5:String = FileAccess.get_md5(eachf)
		var filename:String = eachf
		if UE_ROOT_DIR + '/' in eachf:
			filename = eachf.replace(UE_ROOT_DIR + '/', '')
		elif UE_ROOT_DIR in eachf:
			filename = eachf.replace(UE_ROOT_DIR, '')
		querydic[filename] = file_md5
	_obj.query_files(querydic)
	
func upload__end_query_files_dic(who_i_am:String, taskid:String, req_type:String, infor:String, result:String, _taskid:String, _obj:TCP_TRANSF_C) -> void:
	log_window.add_log("[connect_home]->upload__end_query_files_dic:%s-%s %s %s %s, %s"%[who_i_am, taskid, req_type, infor, result, _taskid])
	if who_i_am == 'tcp_transf_class' and req_type == 'query' and taskid == _taskid:
		if result == 'FINISH':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			if infor != 'all ok':
				var retry_dic:Dictionary = JSON.parse_string(infor)
				for eachf in retry_dic:
					if eachf in upload_dic.get('dic', {}):
						upload_dic['dic'][eachf]['rt'] = 'notuploadyet'
			upload__update_files_table_after_upload()
		elif result == 'FAILED':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			log_window.add_log("[connect_home]->upload__end_query_files_dic:failed!!!!!!!!!!!")
		else:
			log_window.add_log("[connect_home]->upload__end_query_files_dic:error result:%s, %s"%[req_type, result])
		show_sub_log()
	else:
		log_window.add_log("[connect_home]->upload__end_query_files_dic:error message:%s, %s"%[req_type, result])

func upload__update_files_table_after_upload() -> void:
	log_window.add_log("[connect_home]->upload__update_files_table_after_upload start")
	var taskid:String = generate_task_id()
	var _obj = SCAN_C.new(log_window, taskid, UE_ROOT_DIR.path_join('files.txt'), UE_ROOT_DIR, SCAN_DIR_DIC, 
	DIS_FILE_TYPE, EXT_TYPE_DIC, ICON_DIR)
	task_dic[taskid] = _obj
	var f_table:Dictionary = _obj.read_db().get('all_files_dic', {})
	var d_table:Dictionary = _obj.read_db().get('rename_files_dic', {})
	for eachfile in upload_dic['dic']:
		if upload_dic['dic'][eachfile]['rt'] != 'uploaded':
			continue
		if eachfile in f_table:
			f_table[eachfile]['on_server'] = 'yes'
	_obj.write_db({'all_files_dic': f_table, 'rename_files_dic': d_table})
	_obj._destory()
	log_window.add_log("[connect_home]->update_files_table_after_upload_thread finish")
	show_sub_log()
	upload__start_push_files_table()
	
func upload__start_push_files_table() -> void:
	log_window.add_log("[connect_home]->upload__start_push_files_table")
	var taskid:String = generate_task_id()
	var _obj = TCP_TRANSF_C.new(log_window, taskid, UE_ROOT_DIR, SERVER_IP, UPLOAD_PORT, USR, PSD, 3, 'yes')
	task_dic[taskid] = _obj
	_obj.connect("report_result", upload__end_push_files_table.bind(taskid, _obj))
	var push_file = UE_ROOT_DIR.path_join('files.txt')
	_obj.upload_a_file(push_file)
	
func upload__end_push_files_table(who_i_am:String, taskid:String, req_type:String, infor:String, result:String, _taskid:String, _obj:TCP_TRANSF_C) -> void:
	log_window.add_log("[connect_home]->upload__end_push_files_table:%s-%s %s %s %s, %s"%[who_i_am, taskid, req_type, infor, result, _taskid])
	if who_i_am == 'tcp_transf_class' and req_type == 'upload' and taskid == _taskid:
		if result == 'FINISH':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('上传完成!')
			update_and_show_files()
		elif result == 'FAILED':
			clear_dic[taskid] = {'time':Time.get_ticks_msec(), 'obj':_obj}
			show_main_log('上传失败!')
			update_and_show_files()
		else:
			log_window.add_log("[connect_home]->upload__end_push_files_table: other result:%s"%result)
		show_sub_log()
	else:
		log_window.add_log("[connect_home]->upload__end_push_files_table: other message:%s, %s"%[req_type, result])

###################################### function control end #####################################
func go_next_page() -> void:
	go_next_pag_try_cnt += 1
	if go_next_pag_try_cnt >= 2:
		go_next_pag_try_cnt = 0
		var next_sidx = dis_sidx + 1
		if next_sidx < dis_sidx_list.size():
			dis_sidx = next_sidx
			update_ui()
			scroll_container.scroll_vertical = 5
		
func go_previous_page() -> void:
	go_next_pag_try_cnt += 1
	if go_next_pag_try_cnt >= 2:
		go_next_pag_try_cnt = 0
		var next_sidx = dis_sidx - 1
		if next_sidx >= 0:
			dis_sidx = next_sidx
			update_ui()
			scroll_container.scroll_vertical = 5

func _is_content_scrollable() -> bool:
	var v_scroll = scroll_container.get_v_scroll_bar()
	return v_scroll != null and v_scroll.visible

func _is_at_top() -> bool:
	return scroll_container.scroll_vertical <= 0

func _is_at_bottom() -> bool:
	if not _is_content_scrollable():
		return false
	var v_scroll = scroll_container.get_v_scroll_bar()
	var max_scroll = v_scroll.max_value
	var view_height = scroll_container.get_rect().size.y
	return scroll_container.scroll_vertical >= (max_scroll - view_height - 1)  # 允许1像素误差

func _on_scroll_value_changed(value: int):
	print(value)
	last_scroll = value

func _on_long_press_timeout() -> void:
	if not is_pressing:
		return
	if not is_long_pressing:
		is_long_pressing = true
		print('-----long pressed')

func _start_pressed() -> void:
	is_pressing = true
	is_long_pressing = false
	press_start_pos = get_global_mouse_position()
	last_scroll = scroll_container.scroll_vertical
	comtimer.wait_time = long_press_threshold
	comtimer.start()
		
func _end_pressed() -> void:
	var end_pos = get_global_mouse_position()
	var drag_delta = end_pos - press_start_pos
	var drag_distance = drag_delta.y
	if abs(drag_distance) < drag_threshold:
		return
	var can_scroll = _is_content_scrollable()
	if not can_scroll:
		if drag_distance < 0:
			go_next_page()
		else:
			go_previous_page()
		return
	if drag_distance < 0 and _is_at_bottom():
		go_next_page()
	elif drag_distance > 0 and _is_at_top():
		go_previous_page()
		
func _process(_del)	-> void:
	for taskid in clear_dic:
		if Time.get_ticks_msec() - clear_dic[taskid]['time'] > 1000 * 1:
			if clear_dic[taskid]['obj'] != null:
				clear_dic[taskid]['obj']._destory()
				clear_dic[taskid]['obj'] = null
				clear_dic.erase(taskid)

	for idx in range(len(thread_list)):
		var eachthread:Thread = thread_list[idx]
		if eachthread and not eachthread.is_alive():
			eachthread.wait_to_finish()
			eachthread = null
			thread_list[idx] = null	
	if need_clear_ui:
		clear_ui()
		need_clear_ui = false
	if need_update_ui:
		update_ui()
		need_update_ui = false
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
	#or event is InputEventScreenTouch:
		if event.pressed:
			print('--->touch pressed, %s'%event)
			_start_pressed()
		else:
			if is_pressing:
				_end_pressed()
			is_pressing = false
			print('----> touch unpressed, %s'%event)
			var new_pos:Vector2 = event.position
			var old_pos:Vector2 = texture_touch_dic.get('pos', Vector2.ZERO)
			if !is_long_pressing and old_pos.distance_to(new_pos) < 1.0:
				print('-----yes, i am click')
				var filepath:String = texture_touch_dic.get('filepath', '')
				open_a_file(filepath)
