class_name CombatTagLedger
extends RefCounted

# tag -> { source_id -> contribution_count }
var _contributors:Dictionary = {}

func add(tag:StringName,source_id:StringName,amount:int=1)->bool:
	if tag==&"" or source_id==&"" or amount<=0:
		return false
	if not _contributors.has(tag):
		_contributors[tag]={}
	var sources:Dictionary=_contributors[tag]
	sources[source_id]=int(sources.get(source_id,0))+amount
	return true

func remove(tag:StringName,source_id:StringName,amount:int=1)->bool:
	if tag==&"" or source_id==&"" or amount<=0 or not _contributors.has(tag):
		return false
	var sources:Dictionary=_contributors[tag]
	if not sources.has(source_id):
		return false
	var next_count:=int(sources[source_id])-amount
	if next_count>0:
		sources[source_id]=next_count
	else:
		sources.erase(source_id)
	if sources.is_empty():
		_contributors.erase(tag)
	return true

func has(tag:StringName)->bool:
	return _contributors.has(tag) and not (_contributors[tag] as Dictionary).is_empty()

func contributor_count(tag:StringName)->int:
	if not _contributors.has(tag):
		return 0
	return (_contributors[tag] as Dictionary).size()

func total_contribution_count(tag:StringName)->int:
	if not _contributors.has(tag):
		return 0
	var total:=0
	for value in (_contributors[tag] as Dictionary).values():
		total+=int(value)
	return total

func source_count(tag:StringName,source_id:StringName)->int:
	if not _contributors.has(tag):
		return 0
	return int((_contributors[tag] as Dictionary).get(source_id,0))

func clear_source(source_id:StringName)->void:
	if source_id==&"":
		return
	for tag in _contributors.keys().duplicate():
		var sources:Dictionary=_contributors[tag]
		sources.erase(source_id)
		if sources.is_empty():
			_contributors.erase(tag)

func clear()->void:
	_contributors.clear()

func snapshot()->Dictionary:
	var out:Dictionary={}
	for raw_tag in _contributors:
		var tag:=StringName(raw_tag)
		var source_out:Dictionary={}
		for raw_source in (_contributors[tag] as Dictionary):
			source_out[str(raw_source)]=int((_contributors[tag] as Dictionary)[raw_source])
		out[str(tag)]=source_out
	return out

func restore(data:Dictionary)->bool:
	var rebuilt:Dictionary={}
	for raw_tag in data:
		if typeof(raw_tag) not in [TYPE_STRING,TYPE_STRING_NAME]:
			return false
		var tag:=StringName(str(raw_tag))
		if tag==&"" or typeof(data[raw_tag])!=TYPE_DICTIONARY:
			return false
		var raw_sources:Dictionary=data[raw_tag]
		var sources:Dictionary={}
		for raw_source in raw_sources:
			if typeof(raw_source) not in [TYPE_STRING,TYPE_STRING_NAME]:
				return false
			var source:=StringName(str(raw_source))
			var value=raw_sources[raw_source]
			if source==&"" or typeof(value)!=TYPE_INT or int(value)<=0:
				return false
			sources[source]=int(value)
		if sources.is_empty():
			return false
		rebuilt[tag]=sources
	_contributors=rebuilt
	return true
