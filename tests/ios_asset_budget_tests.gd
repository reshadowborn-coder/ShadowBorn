extends SceneTree

const ASSET_ROOT:="res://assets"
const MAX_SINGLE_SOURCE_BYTES:=64*1024*1024
const MAX_TOTAL_SOURCE_BYTES:=512*1024*1024
const MAX_TEXTURE_EDGE:=4096
const MAX_TOTAL_TEXTURE_RGBA_BYTES:=256*1024*1024
const TEXTURE_EXTENSIONS:=["png","jpg","jpeg","webp","svg"]

var failures:=0
var files:=0
var total_source_bytes:=0
var textures:=0
var estimated_texture_rgba_bytes:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _scan_file(path:String)->void:
	files+=1
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:
		_check(false,"asset can be opened: "+path)
		return
	var bytes:=file.get_length()
	file.close()
	total_source_bytes+=bytes
	_check(bytes<=MAX_SINGLE_SOURCE_BYTES,"asset source stays below 64 MiB: "+path)

	var ext:=path.get_extension().to_lower()
	if ext not in TEXTURE_EXTENSIONS:
		return
	var resource:=load(path)
	_check(resource is Texture2D,"texture asset imports as Texture2D: "+path)
	if not resource is Texture2D:
		return
	var texture:=resource as Texture2D
	var width:=texture.get_width()
	var height:=texture.get_height()
	textures+=1
	estimated_texture_rgba_bytes+=width*height*4
	_check(width>0 and height>0,"texture has non-zero dimensions: "+path)
	_check(width<=MAX_TEXTURE_EDGE and height<=MAX_TEXTURE_EDGE,"texture stays within 4096px source edge: "+path)

func _scan_dir(path:String)->void:
	var dir:=DirAccess.open(path)
	if dir==null:
		return
	dir.list_dir_begin()
	var name:=dir.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var full:=path.path_join(name)
			if dir.current_is_dir():
				_scan_dir(full)
			else:
				_scan_file(full)
		name=dir.get_next()
	dir.list_dir_end()

func _run()->void:
	_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ASSET_ROOT)),"asset root exists")
	_scan_dir(ASSET_ROOT)
	print("IPHONE_ASSET_BUDGET files=%d source_bytes=%d textures=%d estimated_rgba_bytes=%d"%[
		files,total_source_bytes,textures,estimated_texture_rgba_bytes
	])
	_check(total_source_bytes<=MAX_TOTAL_SOURCE_BYTES,"Act 0 source asset tree stays below 512 MiB")
	_check(estimated_texture_rgba_bytes<=MAX_TOTAL_TEXTURE_RGBA_BYTES,"worst-case source texture RGBA footprint stays below 256 MiB")
	print("iPhone asset budget tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
