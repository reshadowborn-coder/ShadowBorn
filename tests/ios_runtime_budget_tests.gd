extends SceneTree

const MAX_TOTAL_NODES:=900
const MAX_MESH_INSTANCES:=360
const MAX_UNIQUE_MESHES:=220
const MAX_UNIQUE_MATERIALS:=96
const MAX_COLLISION_SHAPES:=260
const MAX_LIGHTS:=8
const MAX_UNIQUE_VERTICES:=500000
const MAX_UNIQUE_INDICES:=1500000
# Broad CI guardrails until physical iPhone 13 Pro calibration replaces them.
const MAX_INSTANCE_VERTEX_REFERENCES:=2000000
const MAX_INSTANCE_INDEX_REFERENCES:=6000000
const MAX_RENDER_SURFACES:=800

var failures:=0
var total_nodes:=0
var mesh_instances:=0
var collision_shapes:=0
var lights:=0
var unique_vertices:=0
var unique_indices:=0
var instance_vertex_references:=0
var instance_index_references:=0
var render_surfaces:=0
var unique_meshes:Dictionary={}
var unique_materials:Dictionary={}

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _collect(node:Node)->void:
	total_nodes+=1
	if node is CollisionShape3D:
		collision_shapes+=1
	if node is Light3D:
		lights+=1
	if node is MeshInstance3D:
		mesh_instances+=1
		var instance:=node as MeshInstance3D
		var mesh:=instance.mesh
		if mesh!=null:
			var mesh_id:=mesh.get_instance_id()
			var first_resource_visit:=not unique_meshes.has(mesh_id)
			if first_resource_visit:
				unique_meshes[mesh_id]=true
				if mesh is PrimitiveMesh:
					var primitive_material:Material=(mesh as PrimitiveMesh).material
					if primitive_material!=null:
						unique_materials[primitive_material.get_instance_id()]=true

			for surface in range(mesh.get_surface_count()):
				render_surfaces+=1
				var arrays:=mesh.surface_get_arrays(surface)
				var surface_vertices:=0
				var surface_indices:=0
				if arrays.size()>Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX]!=null:
					surface_vertices=arrays[Mesh.ARRAY_VERTEX].size()
					instance_vertex_references+=surface_vertices
				if arrays.size()>Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX]!=null:
					surface_indices=arrays[Mesh.ARRAY_INDEX].size()
					instance_index_references+=surface_indices
				if first_resource_visit:
					unique_vertices+=surface_vertices
					unique_indices+=surface_indices
					var material:=mesh.surface_get_material(surface)
					if material!=null:
						unique_materials[material.get_instance_id()]=true
		if instance.material_override!=null:
			unique_materials[instance.material_override.get_instance_id()]=true
	for child in node.get_children():
		_collect(child)

func _run()->void:
	var packed:=load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed!=null,"iPhone runtime budget scene loads")
	if packed==null:
		quit(1)
		return

	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame
	_collect(chapter)

	print("IPHONE_RUNTIME_BUDGET nodes=%d meshes=%d unique_meshes=%d materials=%d surfaces=%d collisions=%d lights=%d unique_vertices=%d unique_indices=%d instance_vertices=%d instance_indices=%d"%[
		total_nodes,
		mesh_instances,
		unique_meshes.size(),
		unique_materials.size(),
		render_surfaces,
		collision_shapes,
		lights,
		unique_vertices,
		unique_indices,
		instance_vertex_references,
		instance_index_references
	])

	_check(total_nodes<=MAX_TOTAL_NODES,"Act 0 total node budget remains bounded for iPhone")
	_check(mesh_instances<=MAX_MESH_INSTANCES,"Act 0 MeshInstance count remains bounded")
	_check(unique_meshes.size()<=MAX_UNIQUE_MESHES,"Act 0 unique mesh resource count remains bounded")
	_check(unique_materials.size()<=MAX_UNIQUE_MATERIALS,"Act 0 unique material count remains bounded")
	_check(collision_shapes<=MAX_COLLISION_SHAPES,"Act 0 collision-shape count remains bounded")
	_check(lights<=MAX_LIGHTS,"Act 0 dynamic/static light count remains bounded")
	_check(unique_vertices<=MAX_UNIQUE_VERTICES,"Act 0 unique loaded vertex budget remains bounded")
	_check(unique_indices<=MAX_UNIQUE_INDICES,"Act 0 unique loaded index budget remains bounded")
	_check(instance_vertex_references<=MAX_INSTANCE_VERTEX_REFERENCES,"Act 0 per-instance vertex work stays below the provisional iPhone guardrail")
	_check(instance_index_references<=MAX_INSTANCE_INDEX_REFERENCES,"Act 0 per-instance index work stays below the provisional iPhone guardrail")
	_check(render_surfaces<=MAX_RENDER_SURFACES,"Act 0 rendered mesh-surface count stays below the provisional iPhone guardrail")

	chapter.queue_free()
	await process_frame
	print("iPhone runtime budget tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
