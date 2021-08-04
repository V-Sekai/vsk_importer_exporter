@tool
extends RefCounted

func preprocess_scene(p_node: Node, p_validator: RefCounted) -> Node:
	return p_node

func get_name() -> String:
	return "UnnamedAddon"
