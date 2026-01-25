extends Node2D

var upload_file = r'D:\python_pro\a_jbl_cloud\ue\file_dir\test_for_upload.zip'
var download_file = r'test_for_download.zip'
var download_dir = r''


func _ready() -> void:
	var tcp_transfer:TCP_TRANSF_C = TCP_TRANSF_C.new("192.168.3.204", 6666, 3)
	tcp_transfer.upload_a_file(upload_file)
	
	#var tcp_transfer1:TCP_TRANSF_C = TCP_TRANSF_C.new("192.168.43.97", 7777, 3)
	#var f = r'D:\python_pro\a_jbl_cloud\server\file_dir\test_for_download.zip'
	#var md5 = FileAccess.get_md5(f)
	#var file_size = FileAccess.get_size(f)
	#var filedir = r''
	#tcp_transfer1.download_a_file(filedir, download_file, file_size, md5)
