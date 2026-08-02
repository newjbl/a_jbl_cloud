extends Node

class_name ICONER_C
var log_window = null
var _plugin_name = "Iconer"
var _android_plugin = null


func _init(_log_window) -> void:
	log_window = _log_window
	if Engine.has_singleton(_plugin_name):
		_android_plugin = Engine.get_singleton(_plugin_name)
	else:
		log_window.add_log("[iconer_class]->_init:Couldn't find plugin " + _plugin_name)	

func create_icon(file_dic, outdir, icon_size=256) -> void:
	log_window.add_log("[iconer_class]->create_icon")	
	if _android_plugin:
		_android_plugin.create_icon(JSON.stringify(file_dic), outdir, icon_size)
		log_window.add_log("[iconer_class]->create_icon finish")	
	else:
		log_window.add_log("_android_plugin is null")	
	
