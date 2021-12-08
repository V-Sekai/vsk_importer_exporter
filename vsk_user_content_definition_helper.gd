@tool

enum UserContentFormat {
	PORTABLE, # Non-native textures, compatible everywhere
	PC, # PC class hardware, DXT compression
	MOBILE # Mobile class hardware, PVR compression, S3TC/ETC/2
}

static func common_set(p_node: Node, p_property, p_value) -> bool:
	return false
	
static func common_get(p_node: Node, p_property):
	return null
