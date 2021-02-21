tool
extends Node

"""

const NO_PARENT_SAVED = 0x7FFFFFFF
const NAME_INDEX_BITS = 18

const FLAG_ID_IS_PATH = (1 << 30)
const TYPE_INSTANCE = 0x7fffffff
const FLAG_INSTANCE_IS_PLACEHOLDER = (1 << 30)
const FLAG_MASK = (1 << 24) - 1

class RefNode:
	extends Reference
	var id: int = -1
	var name: String = ""
	var class_str: String = ""
	var instance_path: String = ""
	var parent: RefNode = null
	var children: Array = []


class NodeData:
	extends Reference
	var parent_id = -1
	var owner_id = -1
	var type_id = -1
	var name_id = -1
	var index_id = -1
	var instance_id = -1
	var properties = []
	var groups = []

static func get_ref_node_from_relative_path(p_node: RefNode, p_path: String) -> RefNode:
	var nodepath: NodePath = NodePath(p_path)
	
	if (nodepath.is_empty() or nodepath.is_absolute()):
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
				if (child.name == name):
					next = child
					break
			if (next == null):
				return null
		current = next;

	return current;

# Build a node tree of RefNodes and return the root
static func build_ref_node_tree(
	p_node_data_array: Array,
	p_names: PoolStringArray,
	p_node_paths: PoolStringArray,
	p_editable_instances: Array
):
	var root_ref_node: RefNode = null
	var ref_nodes: Array = []
	
	#var has_root: bool = false
	
	for snode in p_node_data_array:
		var ref_node = RefNode.new()
		if p_names.size() > snode.name_id - 1:
			ref_node.name = p_names[snode.name_id]
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
						parent_node.children.push_back(ref_nodes)
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
			var editable_instance = p_editable_instances[snode.instance_id]
			ref_node.instance_path = p_names[snode.instance_id]
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

static func sanitise_packed_scene_for_map(p_packed_scene: PackedScene, _strip_all_entities: bool) -> PackedScene:
	print("Sanitising map...")
	if p_packed_scene == null:
		return null

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
				return null

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.owner_id = snode_reader.result
			else:
				return null

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.type_id = snode_reader.result
			else:
				return null

			var name_index: int = -1
			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				name_index = snode_reader.result
				nd.name_id = name_index & ((1 << NAME_INDEX_BITS) - 1)
				nd.index_id = (name_index >> NAME_INDEX_BITS) - 1
			else:
				return null

			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				nd.instance_id = snode_reader.result
			else:
				return null

			var property_count = 0
			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				property_count = snode_reader.result
			else:
				return null

			for _j in range(0, property_count):
				var name: int = -1
				snode_reader = reader_snode(snodes, snode_reader)
				if snode_reader.idx != -1:
					name = snode_reader.result
				else:
					return null

				var value: int = -1
				snode_reader = reader_snode(snodes, snode_reader)
				if snode_reader.idx != -1:
					value = snode_reader.result
				else:
					return null

				nd.properties.append({"name": name, "value": value})

			
			var group_count = 0
			snode_reader = reader_snode(snodes, snode_reader)
			if snode_reader.idx != -1:
				group_count = snode_reader.result
			else:
				return null
			
			
			# Parse groups but don't use them
			for _j in range(0, group_count):
				var group: int = -1
				snode_reader = reader_snode(snodes, snode_reader)
				if snode_reader.idx != -1:
					group = snode_reader.result
				else:
					return null
			
			node_data_array.push_back(nd)
	
	#var ref_root_node : RefNode = build_ref_node_tree(node_data_array, packed_scene_bundle["names"], packed_scene_bundle["node_paths"], packed_scene_bundle["editable_instances"])
	#if ref_root_node == null:
	#	return null

	return p_packed_scene

"""

func setup() -> void:
	pass
