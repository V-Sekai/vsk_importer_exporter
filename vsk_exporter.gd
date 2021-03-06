tool
extends Node

var vsk_editor: Node = null

var file_save_path: String = ""

var save_dialog: FileDialog = null
var current_scene_root: Node = null
var user_content_submission_cancelled: bool = false

var vsk_exporter_addon_interface: Reference = vsk_exporter_addon_interface_const.new()

const EXPORT_FLAGS = ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES

const vsk_types_const = preload("vsk_types.gd")

const vsk_exporter_addon_interface_const = preload("vsk_exporter_addon_interface.gd")

const avatar_lib_const = preload("res://addons/vsk_avatar/avatar_lib.gd")
const avatar_definition_const = preload("res://addons/vsk_avatar/vsk_avatar_definition.gd")
const avatar_definition_runtime_const = preload("res://addons/vsk_avatar/vsk_avatar_definition_runtime.gd")

const map_definition_const = preload("res://addons/vsk_map/vsk_map_definition.gd")
const map_definition_runtime_const = preload("res://addons/vsk_map/vsk_map_definition_runtime.gd")

const avatar_fixer_const = preload("res://addons/vsk_avatar/avatar_fixer.gd")
const bone_lib_const = preload("res://addons/vsk_avatar/bone_lib.gd")
const node_util_const = preload("res://addons/gdutil/node_util.gd")

const avatar_callback_const = preload("res://addons/vsk_avatar/avatar_callback.gd")
const map_callback_const = preload("res://addons/vsk_map/map_callback.gd")

const validator_avatar_const = preload("vsk_avatar_validator.gd")
const validator_map_const = preload("vsk_map_validator.gd")

const entity_node_const = preload("res://addons/entity_manager/entity.gd")
 
func get_valid_filenames(p_filename: String, p_validator: Reference, p_existing_valid_filenames: Array) -> Array:
	if p_validator.is_path_an_entity(p_filename):
		p_existing_valid_filenames.push_back(p_filename)
		
	if p_filename != "":
		if ResourceLoader.exists(p_filename):
			var packed_scene: PackedScene = ResourceLoader.load(p_filename)
			var instance: PackedScene = packed_scene.get_state().get_node_instance(0)
			if instance != null:
				p_existing_valid_filenames = get_valid_filenames(instance.get_path(), p_validator, p_existing_valid_filenames)
		else:
			printerr("File does not exist: %s" % p_filename)
		
	return p_existing_valid_filenames
	
func find_entity_id_from_filenames(p_filenames: Array):
	var networked_scenes:Array = []
	if ProjectSettings.has_setting("network/config/networked_scenes"):
		networked_scenes = ProjectSettings.get_setting("network/config/networked_scenes")
	
	for i in range(0, p_filenames.size()):
		var result: int = networked_scenes.find(p_filenames[i]) != -1
		if result != -1:
			return result
	
	return -1
	
func assign_filename_for_entity_id(p_node: Node, p_entity_id: int) -> void:
	var networked_scenes:Array = []
	if ProjectSettings.has_setting("network/config/networked_scenes"):
		networked_scenes = ProjectSettings.get_setting("network/config/networked_scenes")
		
	p_node.set_filename(networked_scenes[p_entity_id])
	
func get_valid_entity_id(p_node: Node, p_validator: Reference) -> int:
	var valid_filenames: Array = get_valid_filenames(p_node.get_filename(), p_validator, [])
	var entity_id: int = find_entity_id_from_filenames(valid_filenames)
	return entity_id
	
func is_valid_entity(p_node: Node, p_validator: Reference) -> bool:
	return get_valid_entity_id(p_node, p_validator) >= 0

func sanitise_array(p_array: Array, p_table: Dictionary, p_visited: Dictionary, p_root: Node, p_validator: Reference) -> Dictionary:
	var new_array = []
	if p_array:
		for i in range(0, p_array.size()):
			var element = p_array[i]
			match typeof(p_array[i]):
				TYPE_ARRAY:
					var result: Dictionary = sanitise_array(element, p_table, p_visited, p_root, p_validator)
					p_visited = result["visited"]
					new_array.push_back(result["array"])
				TYPE_DICTIONARY:
					var result: Dictionary = sanitise_dictionary(element, p_table, p_visited, p_root, p_validator)
					p_visited = result["visited"]
					new_array.push_back(result["dictionary"])
				TYPE_OBJECT:
					var subobject: Object = p_array[i]
					if subobject:
						if p_table.has(subobject):
							var duplicated_subobject: Object = p_table[subobject]
							if subobject is Resource:
								# If the resource isn't valid for this validator, remove it
								if ! p_validator.is_resource_type_valid(subobject) or ! p_validator.is_script_valid_for_resource(subobject.get_script()):
									print("property array index %s is invalid" % str(i))
									duplicated_subobject = null
							subobject = duplicated_subobject
								
						
						if subobject != null and p_visited["visited_nodes"].find(subobject) == -1:
							p_visited = sanitise_object(subobject, p_table, p_visited, p_root, p_validator)
						
						# Set the new object
						new_array.push_back(subobject)
				_:
					new_array.push_back(p_array[i])
					

	return {"visited":p_visited, "array":new_array}


func sanitise_dictionary(
	p_dictionary: Dictionary, p_table: Dictionary, p_visited: Dictionary, p_root: Node, p_validator: Reference) -> Dictionary:
	var new_dictionary: Dictionary = {}
	if p_dictionary:
		for key in p_dictionary.keys():
			match typeof(key):
				TYPE_ARRAY:
					var result: Dictionary = sanitise_array(key, p_table, p_visited, p_root, p_validator)
					p_visited = result["visited"]
					new_dictionary[key] = result["array"]
				TYPE_DICTIONARY:
					var result: Dictionary = sanitise_dictionary(key, p_table, p_visited, p_root, p_validator)
					p_visited = result["visited"]
					new_dictionary[key] = result["dictionary"]
				TYPE_OBJECT:
					var subobject: Object = p_dictionary[key]
					if subobject:
						if p_table.has(subobject):
							var duplicated_subobject: Object = p_table[subobject]
							if subobject is Resource:
								# If the resource isn't valid for this validator, remove it
								if ! p_validator.is_resource_type_valid(subobject) or ! p_validator.is_script_valid_for_resource(subobject.get_script()):
									print("property dictionary key %s is invalid" % str(key))
									duplicated_subobject = null
							subobject = duplicated_subobject
								
									
						if subobject != null and p_visited["visited_nodes"].find(subobject) == -1:
							p_visited = sanitise_object(subobject, p_table, p_visited, p_root, p_validator)
						
						# Set the new object
						new_dictionary[key] = subobject
				_:
					new_dictionary[key] = p_dictionary[key]
						
	return {"visited":p_visited, "dictionary":new_dictionary}


func sanitise_object(p_object: Object, p_table: Dictionary, p_visited: Dictionary, p_root: Node, p_validator: Reference) -> Dictionary:
	if p_object:
		p_visited["visited_nodes"].push_back(p_object)
		
		var property_list: Array = p_object.get_property_list()
		
		for property in property_list:
			match property["type"]:
				TYPE_ARRAY:
					var array = p_object.get(property["name"])
					if typeof(array) == TYPE_ARRAY:
						var result: Dictionary = sanitise_array(array, p_table, p_visited, p_root, p_validator)
						p_visited = result["visited"]
						
						p_object.set(property["name"], result["array"])
				TYPE_DICTIONARY:
					var dictionary = p_object.get(property["name"])
					if typeof(dictionary) == TYPE_DICTIONARY:
						var result: Dictionary = sanitise_dictionary(dictionary, p_table, p_visited, p_root, p_validator)
						p_visited = result["visited"]
						p_object.set(property["name"], result["dictionary"])
				TYPE_OBJECT:
					var subobject: Object = p_object.get(property["name"])
					if subobject:
						if p_table.has(subobject):
							var duplicated_subobject: Object = p_table[subobject]
							if subobject is Script:
								if p_object is Node:
									# Check if the script works in this node's context
									if p_object == p_root:
										if ! p_validator.is_script_valid_for_root(subobject, p_object.get_class()):
											duplicated_subobject = null
									else:
										if is_valid_entity(p_object, p_validator):
											if ! p_validator.is_valid_entity_script(subobject):
												duplicated_subobject = null
										else:
											if ! p_validator.is_script_valid_for_children(subobject, p_object.get_class()):
												duplicated_subobject = null
												
							elif subobject is Resource:
								# If the resource isn't valid for this validator, remove it
								if ! p_validator.is_resource_type_valid(subobject) or ! p_validator.is_script_valid_for_resource(subobject.get_script()):
									print("property %s is invalid" % property["name"])
									duplicated_subobject = null
							subobject = duplicated_subobject
								
									
						if subobject != null and p_visited["visited_nodes"].find(subobject) == -1:
							p_visited = sanitise_object(subobject, p_table, p_visited, p_root, p_validator)
							
						# Save all the existing properties just in case replacing
						# a resource erases other ones (creating a new mesh
						# for example will erase existing mesh instance materials
						var saved_properties: Dictionary = {}
						for property_to_save in property_list:
							if property_to_save["type"] == TYPE_OBJECT:
								if property_to_save["name"] != property["name"]:
									saved_properties[property_to_save["name"]] = p_object.get(property_to_save["name"])
						
						# Set the new object
						p_object.set(property["name"], subobject)
						
						# Restore the saved properties
						for property_to_restore in saved_properties.keys():
							p_object.set(property_to_restore, saved_properties[property_to_restore])

	return p_visited
	
func sanitise_instance(p_duplicate_node: Node, p_reference_node: Node, p_duplicate_root: Node, p_reference_root: Node, p_visited: Dictionary, p_validator: Reference) -> Dictionary:
	print("Sanitising Instance: %s" % p_duplicate_node.get_name())
	
	# Check if this node is deriving an entity scene
	if p_duplicate_node.get_filename() != "":
		print("Node filename %s" % p_duplicate_node.get_filename())
		# Check if this entity inherits any valid entity filenames
		if is_valid_entity(p_duplicate_node, p_validator):
			p_duplicate_node.clear_entity_signal_connections()
			
			# Assign correct entity filename
			var entity_id: int = get_valid_entity_id(p_duplicate_node, p_validator)
			if entity_id >= 0:
				assign_filename_for_entity_id(p_duplicate_node, entity_id)
			
			# Add it to the list
			p_visited["entity_nodes"].push_back(p_duplicate_node)
			# Scan through all the children
			for i in range(0, p_duplicate_node.get_child_count()):
				var child_duplicate_node = p_duplicate_node.get_child(i)
				var child_reference_node = null
				
				if p_reference_node:
					if i < p_reference_node.get_child_count():
						child_reference_node = p_reference_node.get_child(i)
					
				if is_valid_entity(child_duplicate_node, p_validator):
					sanitise_owner(child_duplicate_node, child_reference_node, p_duplicate_root, p_reference_root)
					entity_id = get_valid_entity_id(child_duplicate_node, p_validator)
					if entity_id >= 0:
						assign_filename_for_entity_id(child_duplicate_node, entity_id)
				else:
					child_duplicate_node.set_filename("")
		else:
			p_duplicate_node.set_filename("")
		sanitise_owner(p_duplicate_node, p_reference_node, p_duplicate_root, p_reference_root)
	else:
		p_duplicate_node.set_filename("")
		sanitise_owner(p_duplicate_node, p_reference_node, p_duplicate_root, p_reference_root)
			
	return p_visited
	
func sanitise_owner(
	p_duplicate_node: Node,
	p_reference_node: Node,
	p_duplicate_root: Node,
	p_reference_root: Node
	) -> void:
	var reassign_owner: bool = false
	
	if p_reference_node == null:
		reassign_owner = true
	else:
		if p_reference_node.get_owner():
			reassign_owner = true
	
	if reassign_owner:
		p_duplicate_node.set_owner(p_duplicate_root)

func sanitise_entity_children(
	p_duplicate_root: Node,
	p_reference_root: Node,
	p_table: Dictionary,
	p_visited: Dictionary,
	p_duplicate_node: Node,
	p_reference_node: Node,
	p_validator: Reference,
	p_entity_root: Node
	) -> Dictionary:
	if p_reference_node.get_owner() != p_entity_root:
		if is_valid_entity(p_duplicate_root, p_validator):
			p_visited = sanitise_node(p_duplicate_node, p_reference_node, p_table, p_visited, p_duplicate_root, p_reference_root, p_validator)
		else:
			p_duplicate_root.queue_free()
			if p_duplicate_root.get_parent():
				p_duplicate_root.get_parent().remove_child(p_duplicate_root)
	
	###
	if p_duplicate_root.is_inside_tree():
		for i in range(0, p_duplicate_node.get_child_count()):
			var child_duplicate_node = p_duplicate_node.get_child(i)
			var child_reference_node = null
			
			if p_reference_node:
				if i < p_reference_node.get_child_count():
					child_reference_node = p_reference_node.get_child(i)
				
			p_visited = sanitise_entity_children(p_duplicate_root, p_reference_root, p_table, p_visited, p_duplicate_node, p_reference_node, p_validator, p_entity_root)
	
	return p_visited

func sanitise_node(
	p_duplicate_node: Node,
	p_reference_node: Node,
	p_table: Dictionary,
	p_visited: Dictionary,
	p_duplicate_root: Node,
	p_reference_root: Node,
	p_validator: Reference
	) -> Dictionary:
	print("Sanitising node '%s'" % p_duplicate_root.get_path_to(p_duplicate_node))
	
	if ! p_validator.is_node_type_valid(p_duplicate_node, false):
		p_duplicate_node = p_validator.sanitise_node(p_duplicate_node)
	
	p_visited = sanitise_object(p_duplicate_node, p_table, p_visited, p_duplicate_root, p_validator)
	p_visited = sanitise_instance(p_duplicate_node, p_reference_node, p_duplicate_root, p_reference_root, p_visited, p_validator)

	# If this node is an entity, delete all the non-explicitly associated_nodes
	if p_visited["entity_nodes"].has(p_duplicate_node):
		for i in range(0, p_duplicate_node.get_child_count()):
			var child_duplicate_node = p_duplicate_node.get_child(i)
			var child_reference_node = null
			
			if p_reference_node:
				if i < p_reference_node.get_child_count():
					child_reference_node = p_reference_node.get_child(i)
				
			p_visited = sanitise_entity_children(
				p_duplicate_root,
				p_reference_root,
				p_table,
				p_visited,
				child_duplicate_node,
				child_reference_node,
				p_validator,
				p_reference_node)
	else:
		for i in range(0, p_duplicate_node.get_child_count()):
			var child_duplicate_node = p_duplicate_node.get_child(i)
			var child_reference_node = null
			
			if p_reference_node:
				if i < p_reference_node.get_child_count():
					child_reference_node = p_reference_node.get_child(i)
			
			p_visited = sanitise_node(child_duplicate_node, child_reference_node, p_table, p_visited, p_duplicate_root, p_reference_root, p_validator)
	
	return p_visited
	
func convert_object(p_table: Dictionary, p_subobject: Object, p_root: Node, p_validator: Reference) -> Dictionary:
	if p_subobject is StreamTexture:
		print("Texture %s processing..." % p_subobject.resource_path)
		var image: Image = p_subobject.get_data()
			
		print("Image loaded...")
			
		var new_image_texture: ImageTexture = ImageTexture.new()
		new_image_texture.create_from_image(image, p_subobject.flags)
		p_table[p_subobject] = new_image_texture
	elif p_subobject is TextureArray:
		print("TextureArray %s processing..." % p_subobject.resource_path)
		
		var new_tex_array: TextureArray = TextureArray.new()
		
		new_tex_array.resource_local_to_scene = true
		new_tex_array.take_over_path("")
		new_tex_array.setup_local_to_scene()
		
		for i in range(0, p_subobject.get_depth()):
			var image: Image = p_subobject.get_layer_data(i)
			
			image.resource_local_to_scene = true
			image.take_over_path("")
			image.setup_local_to_scene()
			
			if i == 0:
				new_tex_array.create(p_subobject.get_width(), p_subobject.get_height(), p_subobject.get_depth(), p_subobject.get_format(), p_subobject.flags)
			new_tex_array.set_layer_data(image, i)
		
		p_table[p_subobject] = new_tex_array
	else:
		if p_subobject is Resource:
			if p_subobject.resource_path != "":
				print("Duplicating resource: " + p_subobject.resource_path)
				var duplicate_resource: Resource = clone_resource(p_subobject)
				duplicate_resource.resource_local_to_scene = true
				duplicate_resource.take_over_path("")
				duplicate_resource.setup_local_to_scene()
				print("Duplicated resource: " + duplicate_resource.resource_path)
				p_table[p_subobject] = duplicate_resource
			else:
				p_table[p_subobject] = p_subobject
	
	return create_object_duplication_table_for_object(p_subobject, p_table, p_root, p_validator)

func create_object_duplication_table_for_array(
	p_array: Array,
	p_table: Dictionary,
	p_root: Node,
	p_validator: Reference
	) -> Dictionary:
	if p_array:
		for element in p_array:
			match typeof(element):
				TYPE_ARRAY:
					p_table = create_object_duplication_table_for_array(element, p_table, p_root, p_validator)
				TYPE_DICTIONARY:
					p_table = create_object_duplication_table_for_dictionary(
						element, p_table, p_root, p_validator)
				TYPE_OBJECT:
					var subobject: Object = element
					if ! p_table.has(subobject):
						p_table = convert_object(p_table, subobject, p_root, p_validator)

	return p_table


func create_object_duplication_table_for_dictionary(
	p_dictionary: Dictionary,
	p_table: Dictionary,
	p_root: Node,
	p_validator: Reference
) -> Dictionary:
	if p_dictionary:
		for key in p_dictionary.keys():
			match typeof(key):
				TYPE_ARRAY:
					p_table = create_object_duplication_table_for_array(key, p_table, p_root, p_validator)
				TYPE_DICTIONARY:
					p_table = create_object_duplication_table_for_dictionary(key, p_table, p_root, p_validator)
				TYPE_OBJECT:
					var subobject: Object = p_dictionary[key]
					if ! p_table.has(subobject):
						p_table = convert_object(p_table, subobject, p_root, p_validator)

	return p_table

# Why do I even need this?
static func clone_resource(p_resource: Resource) -> Resource:
	if p_resource:
		var property_list: Array  = p_resource.get_property_list()
		var prop_values: Dictionary = {}

		for property in property_list:
			if (property["usage"] & PROPERTY_USAGE_STORAGE):
				prop_values[property["name"]] = p_resource.get(property["name"])
		
		var orig_type = p_resource.get_class()
		var inst = ClassDB.instance(orig_type);
			
		for key in prop_values.keys():
			inst.set(key, prop_values[key]);
			
		return inst
	else:
		return null

func create_object_duplication_table_for_object(
	p_object: Object,
	p_table: Dictionary,
	p_root: Node,
	p_validator: Reference
	) -> Dictionary:
	for property in p_object.get_property_list():
		match property["type"]:
			TYPE_ARRAY:
				var array = p_object.get(property["name"])
				if typeof(array) == TYPE_ARRAY:
					p_table = create_object_duplication_table_for_array(array, p_table, p_root, p_validator)
			TYPE_DICTIONARY:
				var dictionary = p_object.get(property["name"])
				if typeof(dictionary) == TYPE_DICTIONARY:
					p_table = create_object_duplication_table_for_dictionary(
						dictionary, p_table, p_root, p_validator
					)
			TYPE_OBJECT:
				var subobject: Object = p_object.get(property["name"])
				if subobject:
					if ! p_table.has(subobject):
						p_table[subobject] = subobject
						if subobject is Script:
							if p_object is Node:
								if p_object == p_root:
									if ! p_validator.is_script_valid_for_root(subobject, p_object.get_class()):
										p_table[subobject] = null
									else:
										print("Valid script!")
								else:
									if is_valid_entity(p_object, p_validator):
										if ! p_validator.is_valid_entity_script(subobject):
											p_table[subobject] = null
										else:
											print("Valid entity script!")
									else:
										if ! p_validator.is_script_valid_for_children(subobject, p_object.get_class()):
											p_table[subobject] = null
										else:
											print("Valid script!")
							elif p_object is Resource:
								if ! p_validator.is_script_valid_for_resource(subobject):
									p_table[subobject] = null
								else:
									print("Valid script!")
							else:
								p_table[subobject] = null
						else:
							p_table = convert_object(p_table, subobject, p_root, p_validator)
	return p_table


func create_object_duplication_table_for_node(
	p_node: Node,
	p_table: Dictionary,
	p_root: Node,
	p_validator: Reference
	) -> Dictionary:
	p_table = create_object_duplication_table_for_object(p_node, p_table, p_root, p_validator)

	for node in p_node.get_children():
		p_table = create_object_duplication_table_for_node(node, p_table, p_root, p_validator)

	return p_table


func create_sanitised_duplication(p_node: Node, p_validator: Reference) -> Dictionary:
	var reference_node: Node = p_node.duplicate()
	
	# Run any addons on a duplicate of the scene before anything else
	reference_node = get_export_addon_interface().preprocess_scene(reference_node, p_validator)
	
	var duplicate_node: Node = reference_node.duplicate()

	print("Creating duplication table...")
	var duplication_table: Dictionary = create_object_duplication_table_for_node(
		duplicate_node, {}, duplicate_node, p_validator
	)
	print("Duplication table complete!")
	print("Sanitising nodes...")
	
	var visited: Dictionary = Dictionary()
	visited["visited_nodes"] = []
	visited["entity_nodes"] = []

	visited = sanitise_node(duplicate_node, reference_node, duplication_table, visited, duplicate_node, reference_node, p_validator)
		
	print("Node sanitisation complete!")
		
	reference_node.queue_free()
		
	return {"node":duplicate_node, "entity_nodes":visited["entity_nodes"]}

	
static func get_offset_from_bone(p_global_transform: Transform, p_skeleton: Skeleton, p_bone_name: String) -> Transform:
	var bone_id: int = p_skeleton.find_bone(p_bone_name)
	if bone_id != -1:
		var bone_global_rest_transfrom: Transform = bone_lib_const.get_bone_global_rest_transform(
			bone_id, p_skeleton
		)
		return p_global_transform * bone_global_rest_transfrom.inverse()
		
	return Transform()
	
static func evaluate_meta_spatial(p_root: Spatial, p_skeleton: Spatial, p_humanoid_data: HumanoidData, p_meta: Spatial, p_humanoid_bone_name: String) -> int:
	if p_meta and p_skeleton and p_humanoid_data:
		if p_root.is_a_parent_of(p_meta):
			if p_meta != p_skeleton and p_meta != p_root:
				var bone_name: String = p_humanoid_data.get(p_humanoid_bone_name)
				return p_skeleton.find_bone(bone_name)
				
	return -1
	
static func _fix_humanoid_skeleton(
	p_root: Node,
	p_node: Node) -> Dictionary:
	print("_fix_humanoid_skeleton")
		
	var err: int = avatar_callback_const.generic_error_check(p_node, p_node._skeleton_node)
	
	var eye_head_id: int = -1
	var eye_spatial : Spatial = null
	var eye_offset_transform: Transform = Transform()
	var mouth_head_id: int = -1
	var mouth_spatial: Spatial = null
	var mouth_offset_transform: Transform = Transform()
	
	# Get the eyes and mouth and store their relative transform to the head bone
	if err == avatar_callback_const.AVATAR_OK:
		var eye_node: Node = p_node.get_node_or_null(p_node.eye_transform_node_path)
		var mouth_node: Node = p_node.get_node_or_null(p_node.mouth_transform_node_path)
		mouth_head_id = evaluate_meta_spatial(p_node, p_node._skeleton_node, p_node.humanoid_data, mouth_node, "head_bone_name")
		eye_head_id = evaluate_meta_spatial(p_node, p_node._skeleton_node, p_node.humanoid_data, eye_node, "head_bone_name")
		
		var skeleton_gt: Transform = node_util_const.get_relative_global_transform(p_root, p_node._skeleton_node)
		
		if eye_head_id != -1:
			var meta_gt: Transform = node_util_const.get_relative_global_transform(p_root, eye_node)
			var bone_gt: Transform = skeleton_gt\
			* bone_lib_const.get_bone_global_rest_transform(eye_head_id, p_node._skeleton_node)
			
			eye_offset_transform = bone_gt.affine_inverse() * meta_gt
			eye_spatial = Position3D.new()
			
			eye_node.free()
		if mouth_head_id != -1:
			var meta_gt: Transform = node_util_const.get_relative_global_transform(p_root, mouth_node)
			var bone_gt: Transform = skeleton_gt\
			* bone_lib_const.get_bone_global_rest_transform(mouth_head_id, p_node._skeleton_node)
			
			mouth_offset_transform = bone_gt.affine_inverse() * meta_gt
			mouth_spatial = Position3D.new()
	
			mouth_node.free()
	
	"""
	TODO: create generic post-export plugin system
	"""
	
	"""
	var ik_pose_output: Dictionary = {}
	if err == avatar_callback_const.AVATAR_OK:
		if p_ik_pose_fixer:
			ik_pose_output = p_ik_pose_fixer.setup_ik_t_pose(p_node, p_node._skeleton_node, p_node.humanoid_data, false)
			err = ik_pose_output["result"]
	
	if err == avatar_callback_const.AVATAR_OK:
		if p_rotation_fixer:
			err = p_rotation_fixer.fix_rotations(p_node, p_node._skeleton_node, p_node.humanoid_data, ik_pose_output["custom_bone_pose_array"])
	
	if err == avatar_callback_const.AVATAR_OK:
		if p_external_transform_fixer:
			err = p_external_transform_fixer.fix_external_transform(p_node, p_node._skeleton_node)
	"""
	
	# Zero out the avatar node
	p_node.transform = Transform()
	
	# Create and assign new eye and mouth reference nodes
	if err == avatar_callback_const.AVATAR_OK:
		var skeleton_gt: Transform = node_util_const.get_relative_global_transform(p_root, p_node._skeleton_node)
		if eye_spatial:
			print("Assigning Eye...")
			eye_spatial.set_name("Eye")
			p_node.add_child(eye_spatial)
			eye_spatial.owner = p_node
			p_node.eye_transform_node_path = p_node.get_path_to(eye_spatial)
			
			var bone_gt: Transform = skeleton_gt\
			* bone_lib_const.get_bone_global_rest_transform(eye_head_id, p_node._skeleton_node)
			
			node_util_const.set_relative_global_transform(p_node, eye_spatial, bone_gt * eye_offset_transform)
			
		if mouth_spatial:
			print("Assigning Mouth...")
			mouth_spatial.set_name("Mouth")
			p_node.add_child(mouth_spatial)
			mouth_spatial.owner = p_node
			p_node.mouth_transform_node_path = p_node.get_path_to(mouth_spatial)
			
			var bone_gt: Transform = skeleton_gt\
			* bone_lib_const.get_bone_global_rest_transform(mouth_head_id, p_node._skeleton_node)
			
			node_util_const.set_relative_global_transform(p_node, mouth_spatial, bone_gt * mouth_offset_transform)
			
			
	return {"node":p_node, "err":err}
	
static func convert_to_runtime_user_content(p_node: Node, p_script: Script) -> Node:
	# Clear the preview camera
	var camera_node_path = p_node.get("vskeditor_preview_camera_path")
	if camera_node_path is NodePath:
		var camera: Camera = p_node.get_node_or_null(camera_node_path)
		if camera is Camera:
			camera.queue_free()
			camera.get_parent().remove_child(camera)
	
	# Clear all the pipelines
	var pipeline_paths = p_node.get("vskeditor_pipeline_paths")
	if pipeline_paths is Array:
		for pipeline_path in pipeline_paths:
			if pipeline_path is NodePath:
				var pipeline: Node = p_node.get_node_or_null(pipeline_path)
				if pipeline is Node:
					pipeline.queue_free()
					pipeline.get_parent().remove_child(pipeline)
	
	# Save all the properties
	var property_list: Array = p_node.get_property_list()
	var property_dictionary: Dictionary = {}
	for property in property_list:
		if property["usage"] & PROPERTY_USAGE_STORAGE:
			property_dictionary[property["name"]] = p_node.get(property["name"])
	
	# Replace the node with lighter script with the metadata removed
	p_node.set_script(p_script)
	
	for key in property_dictionary.keys():
		if key != "script":
			p_node.set(key, property_dictionary[key])
	
	return p_node
	
func save_user_content_resource(p_path: String, p_packed_scene: PackedScene) -> int:
	return ResourceSaver.save(p_path, p_packed_scene, EXPORT_FLAGS)
	
"""
Avatar
"""
	
func create_packed_scene_for_avatar(p_root: Node,\
	p_node: Node) -> Dictionary:
	
	var packed_scene_export: PackedScene = null
	var err: int = avatar_callback_const.AVATAR_FAILED
	
	var dictionary : Dictionary = create_sanitised_duplication(p_node,\
	validator_avatar_const.new())
	
	var duplicate_node: Node = dictionary["node"]
	if duplicate_node:
		p_root.add_child(duplicate_node)
		
		# Replace the node with lighter script with the metadata removed
		duplicate_node = convert_to_runtime_user_content(duplicate_node, avatar_definition_runtime_const)
		
		var has_humanoid_skeleton: bool = false
		
		if duplicate_node._skeleton_node and duplicate_node.humanoid_data:
			has_humanoid_skeleton = true
			
		
		if has_humanoid_skeleton:
			var humanoid_skeleton_dict: Dictionary = _fix_humanoid_skeleton(p_root, duplicate_node)
			err = humanoid_skeleton_dict["err"]
			duplicate_node = humanoid_skeleton_dict["node"]
		else:
			err = avatar_callback_const.AVATAR_OK
		
		if err == avatar_callback_const.AVATAR_OK:
			if has_humanoid_skeleton:
				# Apply the avatar fixes
				print("Applying avatar fixes")
				
				err = avatar_fixer_const.fix_avatar(
					duplicate_node,
					duplicate_node._skeleton_node,
					duplicate_node.humanoid_data)
				
			if err == avatar_callback_const.AVATAR_OK:
				var mesh_instances: Array = avatar_lib_const.find_mesh_instances_for_avatar_skeleton(p_root, p_root._skeleton_node, [])
				var skins: Array = []
				
				for mesh_instance in mesh_instances:
					if mesh_instance.skin:
						skins.push_back(mesh_instance.skin.duplicate())
						
					else:
						skins.push_back(null)
						
				if bone_lib_const.rename_skeleton_to_humanoid_bones(duplicate_node._skeleton_node, duplicate_node.humanoid_data, skins):
					packed_scene_export = PackedScene.new()
					
					duplicate_node.set_name(p_node.get_name()) # Reset name
					if packed_scene_export.pack(duplicate_node) == OK:
						err = avatar_callback_const.AVATAR_OK
	else:
		err = avatar_callback_const.AVATAR_COULD_NOT_SANITISE
	
	# Cleanup
	if duplicate_node:
		duplicate_node.free()
	
	return {"packed_scene":packed_scene_export, "err":err}
	
func export_avatar(\
	p_root: Node,\
	p_node: Node,\
	p_path: String) -> int:
	
	# Create a packed scene
	var packed_scene_dict: Dictionary = create_packed_scene_for_avatar(p_root,\
	p_node)
	
	var err: int = packed_scene_dict["err"]
	
	if err == avatar_callback_const.AVATAR_OK:
		err = save_user_content_resource(p_path, packed_scene_dict["packed_scene"])
		if err == OK:
			print("---Avatar exported successfully!---")
		else:
			print("---Avatar exported successfully!---")
	else:
		print("---Avatar export failed!---")
	
	return err
	
"""
Map
"""
	
func create_packed_scene_for_map(p_root, p_node) -> Dictionary:
	var validator:validator_map_const = validator_map_const.new()
		
	print("Creating sanitised duplicate...")
	var dictionary : Dictionary = create_sanitised_duplication(p_node, validator)
	print("Done sanitised duplicate...")

	var err: int = map_callback_const.MAP_FAILED

	var packed_scene_export: PackedScene = null
	var duplicate_node: Node = dictionary["node"]
	
	if duplicate_node:
		var entity_resource_array : Array = []
		
		packed_scene_export = PackedScene.new()
		
		print("Converting to runtime user content...")
		duplicate_node = convert_to_runtime_user_content(duplicate_node, map_definition_runtime_const)
		duplicate_node.map_resources = entity_resource_array

		print("Add entity nodes to instance list...")
		for _i in range(0, dictionary["entity_nodes"].size()):
			duplicate_node.entity_instance_list.push_back(map_definition_const.EntityInstance.new())
			
		print("Caching map resources...")
		for i in range(0, dictionary["entity_nodes"].size()):
			var entity: Node = dictionary["entity_nodes"][i]
			# Find the parent
			var entity_parent_index: int = dictionary["entity_nodes"].find(entity.get_parent())
			
			# Assign the entity instances
			duplicate_node.entity_instance_list[i].parent_id = entity_parent_index
			duplicate_node.entity_instance_list[i].transform = entity.get_transform()
			var valid_filenames: Array = get_valid_filenames(entity.get_filename(), validator, [])
			var entity_index:int = find_entity_id_from_filenames(valid_filenames)
			duplicate_node.entity_instance_list[i].entity_id = entity_index
			
			var properties:Dictionary = {}
			var nodepath: NodePath = entity.get("simulation_logic_node_path")
			var simulation_logic_node: Node = entity.get_node_or_null(nodepath)
			if simulation_logic_node:
				var property_list: Array = entity_node_const.get_logic_node_properties(simulation_logic_node)
				for property in property_list:
					var prop = simulation_logic_node.get(property["name"])
					if prop is Resource:
						if entity_resource_array.find(prop) == -1:
							entity_resource_array.push_back(prop)
					entity.set(property["name"], prop)
					properties[property["name"]] = prop
			
			duplicate_node.entity_instance_properties_list.push_back(properties)
			duplicate_node.entity_instance_list[i].properties_id = i

		print("Packing map...")
		
		duplicate_node.set_name(p_node.get_name()) # Reset name
		if packed_scene_export.pack(duplicate_node) == OK:
			err = map_callback_const.MAP_OK
	
	if duplicate_node:
		duplicate_node.free()

	return {"packed_scene":packed_scene_export, "err":err}
		
func export_map(p_root: Node, p_node: Node, p_path: String) -> int:
	print("Exporting map...")
	
	var packed_scene_dict: Dictionary = create_packed_scene_for_map(p_root, p_node)
	
	var err: int  = packed_scene_dict["err"]
	
	if err == OK:
		print("Saving map...")
		err = save_user_content_resource(p_path, packed_scene_dict["packed_scene"])
		
		if err == OK:
			print("---Map exported successfully!---")
		else:
			print("---Map exported failed!---")
	else:
		print("---Map exported failed!---")
		
	return err

"""
Online submission
"""

func _user_content_submission_requested(p_upload_data: Dictionary, p_callbacks: Dictionary) -> void:
	print("vsk_exporter::_user_content_submission_requested")
	
	# Clear the cancel flag
	user_content_submission_cancelled = false
	
	var export_data_callback = p_upload_data["export_data_callback"]
	var export_data: Dictionary = export_data_callback.call_func()

	var root: Node = export_data["root"]
	var node: Node = export_data["node"]
		
	var packed_scene: PackedScene = null
	
	match p_upload_data["user_content_type"]:
		vsk_types_const.UserContentType.Avatar:
			var packed_scene_dict: Dictionary = create_packed_scene_for_avatar(root,\
			node)
			
			var err: int = packed_scene_dict["err"]
			
			if err == avatar_callback_const.AVATAR_OK:
				packed_scene = packed_scene_dict["packed_scene"]
				
				p_callbacks["packed_scene_created"].call_func()
			else:
				p_callbacks["packed_scene_creation_failed"].call_func("Avatar export failed!")
		vsk_types_const.UserContentType.Map:
			var packed_scene_dict: Dictionary = create_packed_scene_for_map(root,\
			node)
			
			var err: int = packed_scene_dict["err"]
			
			if err == map_callback_const.MAP_OK:
				packed_scene = packed_scene_dict["packed_scene"]
				
				p_callbacks["packed_scene_created"].call_func()
			else:
				p_callbacks["packed_scene_creation_failed"].call_func("Avatar export failed!")
	
	if !user_content_submission_cancelled and packed_scene:
		var pre_uploading_callback: FuncRef = p_callbacks["packed_scene_pre_uploading"]
		if pre_uploading_callback.is_valid():
			p_callbacks["packed_scene_pre_uploading"].call_func(packed_scene, p_upload_data, p_callbacks)
		else:
			p_callbacks["packed_scene_creation_failed"].call_func("Pre-upload callback failed!")

func _user_content_submission_cancelled() -> void:
	user_content_submission_cancelled = true

func create_temp_folder() -> int:
	var directory: Directory = Directory.new()
	var err: int = OK
	
	if !directory.dir_exists("user://temp"):
		err = directory.make_dir("user://temp")
		if err != OK:
			printerr("Could not create temp directory. Error code %s" % str(err))
		else:
			print("Created temp directory!")
			
	return err
	
func get_export_addon_interface() -> Reference:
	return vsk_exporter_addon_interface

"""
Linking
"""
	
func _link_vsk_editor(p_node: Node) -> void:
	print("_link_vsk_editor")
	vsk_editor = p_node

	if vsk_editor:
		if vsk_editor.connect("user_content_submission_requested", self, "_user_content_submission_requested", [], CONNECT_DEFERRED) != OK:
			printerr("Could not connect signal 'user_content_submission_requested'")
		if vsk_editor.connect("user_content_submission_cancelled", self, "_user_content_submission_cancelled", [], CONNECT_DEFERRED) != OK:
			printerr("Could not connect signal 'user_content_submission_cancelled'")
	
func _unlink_vsk_editor() -> void:
	print("_unlink_vsk_editor")
	
	vsk_editor.disconnect("user_content_submission_requested", self, "_user_content_submission_requested")
	vsk_editor.disconnect("user_content_submission_cancelled", self, "_user_content_submission_cancelled")
	
	vsk_editor = null
	
func _node_added(p_node: Node) -> void:
	var parent_node: Node = p_node.get_parent()
	if parent_node:
		if !parent_node.get_parent():
			if p_node.get_name() == "VSKEditor":
				_link_vsk_editor(p_node)
			
func _node_removed(p_node: Node) -> void:
	if p_node == vsk_editor:
		_unlink_vsk_editor()
		
"""

"""

func _ready():
	if Engine.is_editor_hint():
		assert(get_tree().connect("node_added", self, "_node_added") == OK)
		assert(get_tree().connect("node_removed", self, "_node_removed") == OK)
		
		_link_vsk_editor(get_node_or_null("/root/VSKEditor"))
		
		if create_temp_folder() != OK:
			printerr("Could not create temp folder")
	

func setup() -> void:
	pass
