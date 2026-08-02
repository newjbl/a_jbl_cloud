extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	if android_runtime:
		var activity = android_runtime.getActivity()
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var Intent_FLAG_GRANT_READ_URI_PERMISSION = 1
	var Uri = JavaClassWrapper.wrap("android.net.Uri")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
