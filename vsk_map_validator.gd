@tool
extends "res://addons/vsk_importer_exporter/vsk_validator.gd" # vsk_validator.gd

const map_definition_const = preload("res://addons/vsk_map/vsk_map_definition.gd")
const map_definition_runtime_const = preload("res://addons/vsk_map/vsk_map_definition_runtime.gd")

const network_spawn_const = preload("res://addons/network_manager/network_spawn.gd")
const canvas_3d_anchor_const = preload("res://addons/canvas_plane/canvas_3d_anchor.gd")
const vsk_uro_pipeline_const = preload("res://addons/vsk_importer_exporter/vsk_uro_pipeline.gd")

# FIXME: dictionary cannot be const????
var valid_node_whitelist = {
	"AnimatedSprite3D": AnimatedSprite3D,
	"AnimationPlayer": AnimationPlayer,
	"Area3D": Area3D,
	"AudioStreamPlayer": AudioStreamPlayer,
	"AudioStreamPlayer3D": AudioStreamPlayer3D,
	"BoneAttachment3D": BoneAttachment3D,
	"LightmapGI": LightmapGI,
	"Camera3D": Camera3D,
	"CollisionObject3D": CollisionObject3D,
	"CollisionShape3D": CollisionShape3D,
	"ConeTwistJoint3D": ConeTwistJoint3D,
	"CPUParticles3D": CPUParticles3D,
	"DirectionalLight3D": DirectionalLight3D,
	"GridMap": GridMap,
	"GeometryInstance3D": GeometryInstance3D,
	"Generic6DOFJoint3D": Generic6DOFJoint3D,
	"VoxelGI": VoxelGI,
	"HingeJoint3D": HingeJoint3D,
	"Joint3D": Joint3D,
	"CharacterBody3D": CharacterBody3D,
	"Light3D": Light3D,
	"MeshInstance3D": MeshInstance3D,
	"MultiMeshInstance3D": MultiMeshInstance3D,
	"NavigationAgent3D": NavigationAgent3D,
	"NavigationRegion3D": NavigationRegion3D,
	"Node":Node,
	"OmniLight3D": OmniLight3D,
	"GPUParticles3D": GPUParticles3D,
	"Path3D": Path3D,
	"PathFollow3D": PathFollow3D,
	"PhysicsBody3D": PhysicsBody3D,
	"PinJoint3D": PinJoint3D,
	"Position3D": Position3D,
	"ProximityGroup3D": ProximityGroup3D,
	"RayCast3D": RayCast3D,
	"ReflectionProbe": ReflectionProbe,
	"RigidBody3D": RigidBody3D,
	"RemoteTransform3D": RemoteTransform3D,
	"SliderJoint3D": SliderJoint3D,
	"Skeleton3D": Skeleton3D,
	"Node3D": Node3D,
	"SpotLight3D": SpotLight3D,
	"SpringArm3D": SpringArm3D,
	"Sprite3D": Sprite3D,
	"SpriteBase3D": SpriteBase3D,
	"StaticBody3D": StaticBody3D,
	"VehicleWheel3D": VehicleWheel3D,
	"VisibleOnScreenEnabler3D": VisibleOnScreenEnabler3D,
	"VisibleOnScreenNotifier3D": VisibleOnScreenNotifier3D,
	"VisualInstance3D": VisualInstance3D,
	"WorldEnvironment": WorldEnvironment,
}

# TODO: please fill in the missing nodes
const canvas_3d_script : Script = preload("res://addons/canvas_plane/canvas_3d.gd")

# FIXME: dictionary cannot be const????
var valid_canvas_node_whitelist = {
	"Node":Node,
	"HBoxContainer": HBoxContainer,
	"VBoxContainer": VBoxContainer,
	"Control": Control,
	"Container":Container,
	"AspectRatioContainer":AspectRatioContainer,
	"TabContainer":TabContainer,
	"Label":Label,
	"RichTextLabel":RichTextLabel,
	"BaseButton":BaseButton,
	"Button":Button,
	"CheckBox":CheckBox,
}

# FIXME: dictionary cannot be const????
var valid_resource_whitelist = {
	"AnimatedTexture": AnimatedTexture,
	"Animation": Animation,
	"ArrayMesh": ArrayMesh,
	"AtlasTexture": AtlasTexture,
	"AudioStreamSample": AudioStreamSample,
	"AudioStreamOGGVorbis": AudioStreamOGGVorbis,
	"LightmapGIData": LightmapGIData,
	"BoxShape3D": BoxShape3D,
	"CapsuleMesh": CapsuleMesh,
	"CapsuleShape3D": CapsuleShape3D,
	"ConcavePolygonShape3D": ConcavePolygonShape3D,
	"ConvexPolygonShape3D": ConvexPolygonShape3D,
	"BoxMesh": BoxMesh,
	"Curve": Curve,
	"Curve2D": Curve2D,
	"Curve3D": Curve3D,
	"CurveTexture": CurveTexture,
	"CylinderMesh": CylinderMesh,
	"CylinderShape3D": CylinderShape3D,
	"Environment": Environment,
	"VoxelGIData": VoxelGIData,
	"GradientTexture": GradientTexture,
	"HeightMapShape3D": HeightMapShape3D,
	"ImageTexture": ImageTexture,
	### "LargeTexture": LargeTexture, # Obsolete, removed in 4.x
	"Mesh": Mesh,
	"MeshLibrary": MeshLibrary,
	"MeshTexture": MeshTexture,
	"NoiseTexture": NoiseTexture,
	"PackedScene": PackedScene,
	"PhysicalSkyMaterial": PhysicalSkyMaterial,
	"PanoramaSkyMaterial": PanoramaSkyMaterial,
	"ProceduralSkyMaterial": ProceduralSkyMaterial,
	"PhysicsMaterial": PhysicsMaterial,
	"PlaneMesh": PlaneMesh,
	"WorldMarginShape": WorldMarginShape3D,
	"PointMesh": PointMesh,
	"PrimitiveMesh": PrimitiveMesh,
	"PrismMesh": PrismMesh,
	"ProxyTexture": ProxyTexture,
	"RayShape3D": RayShape3D,
	"QuadMesh": QuadMesh,
	"Resource": Resource,
	"Shader": Shader,
	"ShaderMaterial": ShaderMaterial,
	"Shape3D": Shape3D,
	"Skin": Skin,
	"Sky": Sky,
	"StandardMaterial3D": StandardMaterial3D,
	"SphereMesh": SphereMesh,
	"SphereShape3D": SphereShape3D,
	"StreamTexture2D": StreamTexture2D,
	"Texture2D": Texture2D,
	"Texture3D": Texture3D,
	"Texture2DArray": Texture2DArray,
	"TextureLayered": TextureLayered,
	"ViewportTexture": ViewportTexture
}

################
# Map Entities #
################

const entity_script : Script = preload("res://addons/entity_manager/entity.gd")
const valid_entity_whitelist = [
	"res://addons/vsk_entities/vsk_interactable_prop.tscn"
	]
	
	
const valid_root_script_whitelist = [map_definition_const, map_definition_runtime_const]
const valid_children_script_whitelist = [network_spawn_const, vsk_uro_pipeline_const]

const valid_resource_script_whitelist = []

static func check_if_script_type_is_valid(p_script: Script, p_node_class: String) -> bool:
	# FIXME: dictionary cannot be const????
	var script_type_table = {
		network_spawn_const: ["Position3D", "Node3D"],
		map_definition_const: ["Position3D", "Node3D"],
		map_definition_runtime_const: ["Position3D", "Node3D"],
		vsk_uro_pipeline_const: ["Node"]
	}
	if script_type_table.get(p_script) != null:
		var valid_classes: Array = script_type_table.get(p_script)
		for class_str in valid_classes:
			if class_str == p_node_class:
				return true
				
	return false

func is_script_valid_for_root(p_script: Script, p_node_class: String):
	if p_script == null:
		return true
	
	if valid_root_script_whitelist.find(p_script) != -1:
		return check_if_script_type_is_valid(p_script, p_node_class)
				
	return false

func is_script_valid_for_children(p_script: Script, p_node_class: String):
	if p_script == null:
		return true
	
	if valid_children_script_whitelist.find(p_script) != -1:
		return check_if_script_type_is_valid(p_script, p_node_class)
				
	return false

func is_script_valid_for_resource(p_script: Script):
	if p_script == null:
		return true
	
	if valid_resource_script_whitelist.find(p_script) != -1:
		return true
	else:
		return false

func is_node_type_valid(p_node: Node, p_child_of_canvas: bool) -> bool:
	if valid_node_whitelist.has(p_node.get_class()):
		if !is_editor_only(p_node):
			return true
	return false
	
func is_node_type_string_valid(p_class_str: String, p_child_of_canvas: bool) -> bool:
	if p_child_of_canvas:
		return valid_canvas_node_whitelist.has(p_class_str)
	else:
		return valid_node_whitelist.has(p_class_str)
	return false

func is_resource_type_valid(p_resource: Resource) -> bool:
	if valid_resource_whitelist.has(p_resource.get_class()):
		return true
	return false

func is_path_an_entity(p_packed_scene_path: String) -> bool:
	if valid_entity_whitelist.find(p_packed_scene_path) != -1:
		return true
	else:
		return false

func is_valid_entity_script(p_script: Script) -> bool:
	if p_script == entity_script:
		return true
		
	return false
	
func is_valid_canvas_3d(p_script: Script, p_node_class: String) -> bool:
	if p_script == canvas_3d_script and p_node_class == "Node3D":
		return true
		
	return false
	
func is_valid_canvas_3d_anchor(p_script: Script, p_node_class: String) -> bool:
	if p_script == canvas_3d_anchor_const and p_node_class == "Node3D":
		return true
		
	return false
		
func validate_value_track(p_subnames: String, p_node_class: String):
	match p_node_class:
		"MeshInstance3D":
			return check_basic_node_3d_value_targets(p_subnames)
		"Node3D":
			return check_basic_node_3d_value_targets(p_subnames)
		"DirectionalLight":
			return check_basic_node_3d_value_targets(p_subnames)
		"OmniLight":
			return check_basic_node_3d_value_targets(p_subnames)
		"SpotLight":
			return check_basic_node_3d_value_targets(p_subnames)
		"Camera3D":
			return check_basic_node_3d_value_targets(p_subnames)
		"GPUParticles3D":
			return check_basic_node_3d_value_targets(p_subnames)
		"CPUParticles":
			return check_basic_node_3d_value_targets(p_subnames)
		_:
			return false

func get_name() -> String:
	return "MapValidator"
