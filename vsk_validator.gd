tool
extends Reference

func is_scene_valid_for_root(p_script: Script):
	if p_script == null:
		return true
	else:
		return false

func is_script_valid_for_root(p_script: Script):
	if p_script == null:
		return true
	else:
		return false

func is_script_valid_for_children(p_script: Script):
	if p_script == null:
		return true
	else:
		return false

func is_script_valid_for_resource(p_script: Script):
	if p_script == null:
		return true
	else:
		return false

func is_node_type_valid(p_node : Node) -> bool:
	return false

func is_resource_type_valid(p_resource : Resource) -> bool:
	return false

func is_path_an_entity(p_packed_scene_path : String) -> bool:
	return false
	
func is_valid_entity_script(p_script : Script) -> bool:
	return false

func sanitise_node(p_node: Node) -> Node:
	var node_name: String = p_node.get_name()
	var new_node: Node = null
	if p_node is Spatial:
		new_node = Spatial.new()
	else:
		new_node = Node.new()
		
	new_node.set_name(node_name)
	p_node.replace_by(new_node)
	p_node = new_node
	
	return p_node
