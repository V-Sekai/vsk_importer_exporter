@tool

enum UserContentFormat {
	PORTABLE, # Non-native textures, compatible everywhere
	PC, # PC class hardware, DXT compression
	MOBILE # Mobile class hardware, PVR compression, S3TC/ETC/2
}

class VSKEditorProperties extends RefCounted:
	var vskeditor_preview_type: String = "Camera"
	var vskeditor_preview_camera_path: NodePath = NodePath()
	var vskeditor_preview_texture: Texture2D = null
	var vskeditor_pipeline_paths: Array = []

static func common_set(p_node: Node, p_property, p_value) -> bool:
	if !p_node.editor_properties:
		p_node.editor_properties = VSKEditorProperties.new()
	
	match p_property:
		# Backwards compatibility #
		"preview_camera_path":
			p_node.editor_properties.vskeditor_preview_camera_path = p_value
			return true
		"pipeline_paths":
			p_node.editor_properties.vskeditor_pipeline_paths = p_value
			return true
		###
		"vskeditor_preview_type":
			p_node.editor_properties.vskeditor_preview_type = p_value
			p_node.property_list_changed_notify()
			return true
		"vskeditor_preview_camera_path":
			p_node.editor_properties.vskeditor_preview_camera_path = p_value
			return true
		"vskeditor_preview_texture":
			p_node.editor_properties.vskeditor_preview_texture = p_value
			return true
		"vskeditor_pipeline_paths":
			p_node.editor_properties.vskeditor_pipeline_paths = p_value
			return true
		
	return false
	
static func common_get(p_node: Node, p_property):
	if !p_node.editor_properties:
		p_node.editor_properties = VSKEditorProperties.new()
	
	match p_property:
		"vskeditor_preview_type":
			return p_node.editor_properties.vskeditor_preview_type
		"vskeditor_preview_camera_path":
			return p_node.editor_properties.vskeditor_preview_camera_path
		"vskeditor_preview_texture":
			return p_node.editor_properties.vskeditor_preview_texture
		"vskeditor_pipeline_paths":
			return p_node.editor_properties.vskeditor_pipeline_paths
		
	return null

static func get_common_property_list(p_preview_type) -> Array:
	var properties = [
		{
			name = "database_id", # Backwards compatibility
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "SDK Properties",
			type = TYPE_NIL,
			hint_string = "vskeditor_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "vskeditor_preview_type",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Camera,Texture"
		},
		{
			name = "vskeditor_preview_texture",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_DEFAULT if p_preview_type == "Texture"\
			else PROPERTY_USAGE_STORAGE,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Texture"
		},
		{
			name = "vskeditor_preview_camera_path",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT if p_preview_type == "Camera"\
			else PROPERTY_USAGE_STORAGE
		},
		{
			name = "vskeditor_pipeline_paths",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT,
			hint = PROPERTY_HINT_NONE,
			hint_string = str(TYPE_NODE_PATH) + ":"
		}]
	return properties
