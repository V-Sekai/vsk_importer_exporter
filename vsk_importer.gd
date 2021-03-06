tool
extends Node

const validator_const = preload("vsk_validator.gd")
const validator_avatar_const = preload("vsk_avatar_validator.gd")
const validator_map_const = preload("vsk_map_validator.gd")

const NO_PARENT_SAVED = 0x7FFFFFFF
const NAME_INDEX_BITS = 18

const FLAG_ID_IS_PATH = (1 << 30)
const TYPE_INSTANCE = 0x7fffffff
const FLAG_INSTANCE_IS_PLACEHOLDER = (1 << 30)
const FLAG_MASK = (1 << 24) - 1

enum ImporterResult {
	OK,
	FAILED,
	NULL_PACKED_SCENE,
	READ_FAIL,
	HAS_NODE_GROUPS,
	FAILED_TO_CREATE_TREE,
	INVALID_ENTITY_PATH,
	UNSAFE_NODEPATH,
	SCRIPT_ON_INSTANCE_NODE,
	INVALID_ROOT_SCRIPT,
	INVALID_CHILD_SCRIPT,
	RECURSIVE_CANVAS,
	INVALID_NODE_CLASS,
	INVALID_ANIMATION_PLAYER_ROOT,
	INVALID_METHOD_TRACK,
	INVALID_VALUE_TRACK,
	INVALID_TRACK_PATH,
}

class RefNode:
	extends Reference
	var id: int = -1
	var name: String = ""
	var properties: Array = []
	var class_str: String = ""
	var instance_path: String = ""
	var parent: RefNode = null
	var children: Array = []


class NodeData:
	extends Reference
	var parent_id: int = -1
	var owner_id: int = -1
	var type_id: int = -1
	var name_id: int = -1
	var index_id: int = -1
	var instance_id: int = -1
	var properties: Array = []
	var groups: Array = []

# This function attempts to walk the RefTree to make sure a nodepath is not
# breaking out of the sandbox
static func get_ref_node_from_relative_path(p_node: RefNode, p_path: NodePath) -> RefNode:
	var nodepath: NodePath = p_path
	
	if nodepath.is_empty() or nodepath.is_absolute():
		return null
		
	var current: RefNode = p_node
	var root: RefNode = null
	
	for i in range(0, nodepath.get_name_count()):
		var name: String = nodepath.get_name(i)
		var next: RefNode = null
		
		if name == ".":
			next = current
		elif name == "..":
			if current == null or !current.parent:
				return null
				
			next = current.parent
		elif (current == null):
			
			if (name == root.get_name()):
				next = root
		else:
			next = null
			
			for child in current.children:
				if child.name == name:
					next = child
					break
			if next == null:
				return null
		current = next

	return current

enum RefNodeType {
	OTHER,
	ANIMATION_PLAYER,
	MESH_INSTANCE,
}

static func scan_ref_node_tree(p_ref_branch: RefNode, p_canvas: bool, p_validator: validator_const) -> int:
	# Special-case handling code for animation players
	var ref_node_type: int = RefNodeType.OTHER
	var skip_type_check: bool = false
	var is_instance: bool = false
	var children_belong_to_canvas: bool = p_canvas
	
	var animations: Array = []
	var animation_player_ref_node: RefNode = null
	
	if p_ref_branch.class_str == "Instanced":
		if p_validator.is_path_an_entity(p_ref_branch.instance_path):
			skip_type_check = true
			is_instance = true
		else:
			return ImporterResult.INVALID_ENTITY_PATH
	
	match p_ref_branch.class_str:
		"AnimationPlayer":
			ref_node_type = RefNodeType.ANIMATION_PLAYER
			animation_player_ref_node = p_ref_branch.parent
	
	for property in p_ref_branch.properties:
		var name = property["name"]
		var value = property["value"]
			
		# We must make sure that any node path variants in this node only
		# reference nodes within this scene
		if value is NodePath:
			var ref_node_path_target: RefNode = get_ref_node_from_relative_path(p_ref_branch, value)
			if ref_node_path_target == null:
				return ImporterResult.UNSAFE_NODEPATH
				
			if ref_node_type == RefNodeType.ANIMATION_PLAYER:
				if name == "root_node":
					animation_player_ref_node = ref_node_path_target
		elif value is Script:
			if name == "script":
				if is_instance:
					return ImporterResult.SCRIPT_ON_INSTANCE_NODE
				
				if p_ref_branch.parent == null:
					# Check if the script is valid for the root node
					if !p_validator.is_script_valid_for_root(value, p_ref_branch.class_str):
						return ImporterResult.INVALID_ROOT_SCRIPT
					else:
						skip_type_check = true
				else:
					# Check if this object is a canvas anchor
					if p_validator.is_valid_canvas_3d_anchor(value, p_ref_branch.class_str):
						children_belong_to_canvas = false
						skip_type_check = true
					# Check if this object is a canvas
					elif p_validator.is_valid_canvas_3d(value, p_ref_branch.class_str):
						if p_canvas:
							return ImporterResult.RECURSIVE_CANVAS
						else:
							children_belong_to_canvas = true
							skip_type_check = true
					else:
						# Check if it's another valid script for a child node
						if !p_validator.is_script_valid_for_children(value, p_ref_branch.class_str):
							return ImporterResult.INVALID_CHILD_SCRIPT
						else:
							skip_type_check = true
						
		elif value is Animation:
			# Save all animation for later validation
			animations.push_back(value)
			
	# Okay, with that information, make sure the node type itself is valid
	if !skip_type_check:
		if !p_validator.is_node_type_string_valid(p_ref_branch.class_str, p_canvas):
			return ImporterResult.INVALID_NODE_CLASS
			
	for animation in animations:
		# If the animation player root node is null, it is not a secure path
		if !animation_player_ref_node:
			return ImporterResult.INVALID_ANIMATION_PLAYER_ROOT
			
		# Now, loop through all the tracks
		var track_count: int = animation.get_track_count()
		for i in range(0, track_count):
			# Make sure all track paths reference the nodes in this scene
			var track_path: NodePath = animation.track_get_path(i)
			
			var track_ref_node: RefNode = get_ref_node_from_relative_path(animation_player_ref_node, track_path)
			if !track_ref_node:
				return ImporterResult.INVALID_TRACK_PATH
			
			var track_type_int: int = animation.track_get_type(i)
			
			# Method and value tracks are currently banned until they can
			# be properly validated for safety
			if track_type_int == Animation.TYPE_METHOD:
				return ImporterResult.INVALID_METHOD_TRACK
			elif track_type_int == Animation.TYPE_VALUE:
				if !p_validator.validate_value_track(
					track_path.get_concatenated_subnames(),
					track_ref_node.class_str):
					return ImporterResult.INVALID_VALUE_TRACK
			
	for child_ref_node in p_ref_branch.children:
		var result: int = scan_ref_node_tree(
			child_ref_node,
			children_belong_to_canvas,
			p_validator)
		if result != ImporterResult.OK:
			return result
		
	return ImporterResult.OK

# Build a node tree of RefNodes and return the root
static func build_ref_node_tree(
	p_node_data_array: Array,
	p_names: PoolStringArray,
	p_variants: Array,
	p_node_paths: PoolStringArray,
	p_editable_instances: Array
) -> RefNode:
	var root_ref_node: RefNode = null
	var ref_nodes: Array = []
	
	#var has_root: bool = false
	
	for snode in p_node_data_array:
		var ref_node = RefNode.new()
		if p_names.size() > snode.name_id - 1:
			ref_node.name = p_names[snode.name_id]
			for property in snode.properties:
				var property_name: String = p_names[property["name"]]
				var property_value = p_variants[property["value"]]
				
				ref_node.properties.push_back(
					{"name":property_name, "value":property_value}
				)
				
		else:
			return null
			
		var type: int = snode.type_id
		var parent_id: int = snode.parent_id
		
		if parent_id < 0 or parent_id == NO_PARENT_SAVED:
			if root_ref_node == null:
				root_ref_node = ref_node
			else:
				return null
		else:
			if root_ref_node == null:
				return null
				
			if parent_id & FLAG_ID_IS_PATH:
				var idx: int = parent_id & FLAG_MASK
				if p_node_paths.size() > idx - 1:
					var node_path: String = p_node_paths[idx]
					var parent_node: RefNode = get_ref_node_from_relative_path(root_ref_node, node_path)
					if parent_node:
						ref_node.parent = parent_node
						parent_node.children.push_back(ref_node)
						# TODO: check circular dependency
					else:
						return null
			else:
				var idx: int = parent_id & FLAG_MASK
				if ref_nodes.size() > idx - 1:
					ref_node.parent = ref_nodes[parent_id & FLAG_MASK]
					ref_nodes[parent_id & FLAG_MASK].children.push_back(ref_node)
					# TODO: check circular dependency
					
		if type == TYPE_INSTANCE:
			ref_node.class_str = "Instanced"
			var instance_id: int = snode.instance_id
			#var editable_instance = p_editable_instances[instance_id]
			ref_node.instance_path = p_variants[instance_id].resource_path
		else:
			if p_names.size() > snode.type_id - 1:
				ref_node.class_str = p_names[snode.type_id]
		
		ref_node.id = ref_nodes.size()
		ref_nodes.push_back(ref_node)
		
	return root_ref_node

# Read the next integer in the array and increment the internal IDX
static func reader_snode(p_snodes: PoolIntArray, p_reader: Dictionary) -> Dictionary:
	if p_reader.idx < p_snodes.size() and p_reader.idx >= 0:
		p_reader.result = p_snodes[p_reader.idx]
		p_reader.idx += 1
	else:
		p_reader.result = null
		p_reader.idx = -1

	return p_reader
	

static func sanitise_packed_scene(
	p_packed_scene: PackedScene,
	p_validator: validator_const
	) -> Dictionary:

	if p_packed_scene == null:
		return {"packed_scene":null, "result":ImporterResult.NULL_PACKED_SCENE}

	var result: int = ImporterResult.OK

	var packed_scene_bundle: Dictionary = p_packed_scene._get_bundled_scene()
	var node_data_array: Array = []
	var node_count: int = packed_scene_bundle["node_count"]

	if node_count > 0:
		var snodes: PoolIntArray = packed_scene_bundle["nodes"]
		var snode_reader = {"idx": 0, "result": -1}
		for _i in range(0, node_count):
			var nd = NodeData.new()

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.parent_id = snode_reader.result
			else:
				result = ImporterResult.READ_FAIL
				break

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.owner_id = snode_reader.result
			else:
				result = ImporterResult.READ_FAIL
				break

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.type_id = snode_reader.result
			else:
				result = ImporterResult.READ_FAIL
				break

			var name_index: int = -1
			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				name_index = snode_reader.result
				nd.name_id = name_index & ((1 << NAME_INDEX_BITS) - 1)
				nd.index_id = (name_index >> NAME_INDEX_BITS) - 1
			else:
				result = ImporterResult.READ_FAIL
				break

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.instance_id = snode_reader.result
			else:
				result = ImporterResult.READ_FAIL
				break


			var property_count = 0
			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				property_count = snode_reader.result
			else:
				result = ImporterResult.READ_FAIL
				break


			for _j in range(0, property_count):
				var name: int = -1
				snode_reader = reader_snode(snodes, snode_reader)
				if snode_reader.idx != -1:
					name = snode_reader.result
				else:
					result = ImporterResult.READ_FAIL
					break
					
				var value: int = -1
				snode_reader = reader_snode(snodes, snode_reader)
				if snode_reader.idx != -1:
					value = snode_reader.result
				else:
					result = ImporterResult.READ_FAIL
					break
					
				nd.properties.append({"name": name, "value": value})
				
			if result != ImporterResult.OK:
				break
			
			var group_count = 0
			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				group_count = snode_reader.result
				if group_count > 0:
					result = ImporterResult.HAS_NODE_GROUPS
					break
			else:
				result = ImporterResult.READ_FAIL
				break
			
			
			# Parse groups but don't use them
			for _j in range(0, group_count):
				var group: int = -1
				snode_reader = reader_snode(snodes, snode_reader)
				if snode_reader.idx != -1:
					group = snode_reader.result
				else:
					result = ImporterResult.READ_FAIL
					break
			
			node_data_array.push_back(nd)
	
	if result == ImporterResult.OK:
		var ref_root_node : RefNode = build_ref_node_tree(
			node_data_array,
			packed_scene_bundle["names"],
			packed_scene_bundle["variants"],
			packed_scene_bundle["node_paths"],
			packed_scene_bundle["editable_instances"]
		)
		
		if ref_root_node == null:
			result = ImporterResult.FAILED_TO_CREATE_TREE
		else:
			result = scan_ref_node_tree(ref_root_node, false, p_validator)

	var resulting_packed_scene: PackedScene = null
	if result == ImporterResult.OK:
		resulting_packed_scene = p_packed_scene
		
	return {"packed_scene":resulting_packed_scene, "result":result}

static func sanitise_packed_scene_for_map(p_packed_scene: PackedScene) -> Dictionary:
	print("Sanitising map...")
	#var validator: validator_map_const = validator_map_const.new()
	#return sanitise_packed_scene(p_packed_scene, validator)
	
	return {"packed_scene":p_packed_scene, "result":ImporterResult.OK}

func sanitise_packed_scene_for_avatar(p_packed_scene: PackedScene) -> Dictionary:
	print("Sanitising avatar...")
	var validator: validator_avatar_const = validator_avatar_const.new()
	return sanitise_packed_scene(p_packed_scene, validator)
	
	return {"packed_scene":p_packed_scene, "result":ImporterResult.OK}
	
func setup() -> void:
	pass
