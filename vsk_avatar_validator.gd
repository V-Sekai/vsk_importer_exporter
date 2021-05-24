tool
extends "vsk_validator.gd"

const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")
const avatar_definition_const = preload("res://addons/vsk_avatar/vsk_avatar_definition.gd")
const avatar_definition_runtime_const = preload("res://addons/vsk_avatar/vsk_avatar_definition_runtime.gd")

# Support for VRM physics
const avatar_physics_const = preload("res://addons/vsk_avatar/avatar_physics.gd")
const avatar_collidergroup_const = preload("res://addons/vsk_avatar/physics/avatar_collidergroup.gd")
const avatar_springbone_const = preload("res://addons/vsk_avatar/physics/avatar_springbone.gd")

const vsk_pipeline_const = preload("res://addons/vsk_importer_exporter/vsk_pipeline.gd")

const valid_node_whitelist = {
	"AnimatedSprite3D": AnimatedSprite3D,
	"Area": Area,
	"AudioStreamPlayer": AudioStreamPlayer,
	"AudioStreamPlayer3D": AudioStreamPlayer3D,
	"BoneAttachment": BoneAttachment,
	"Camera": Camera,
	"CollisionObject": CollisionObject,
	"CollisionShape": CollisionShape,
	"ConeTwistJoint": ConeTwistJoint,
	"CPUParticles": CPUParticles,
	"GridMap": GridMap,
	"GeometryInstance": GeometryInstance,
	"Generic6DOFJoint": Generic6DOFJoint,
	"HingeJoint": HingeJoint,
	"Joint": Joint,
	"KinematicBody": KinematicBody,
	"Light": Light,
	"MeshInstance": MeshInstance,
	"MultiMeshInstance": MultiMeshInstance,
	"Navigation": Navigation,
	"NavigationMeshInstance": NavigationMeshInstance,
	"Node":Node,
	"OmniLight": OmniLight,
	"Particles": Particles,
	"Path": Path,
	"PathFollow": PathFollow,
	"PhysicsBody": PhysicsBody,
	"PinJoint": PinJoint,
	"Position3D": Position3D,
	"ProximityGroup": ProximityGroup,
	"RayCast": RayCast,
	"RigidBody": RigidBody,
	"RemoteTransform": RemoteTransform,
	"SliderJoint": SliderJoint,
	"Skeleton": Skeleton,
	"Spatial": Spatial,
	"SpotLight": SpotLight,
	"SpringArm": SpringArm,
	"Sprite3D": Sprite3D,
	"SpriteBase3D": SpriteBase3D,
	"StaticBody": StaticBody,
	"VisualInstance": VisualInstance,
	"WorldEnvironment": WorldEnvironment,
}

const valid_resource_whitelist = {
	"AnimatedTexture": AnimatedTexture,
	"ArrayMesh": ArrayMesh,
	"AtlasTexture": AtlasTexture,
	"BoxShape": BoxShape,
	"CapsuleMesh": CapsuleMesh,
	"CapsuleShape": CapsuleShape,
	"ConcavePolygonShape": ConcavePolygonShape,
	"ConvexPolygonShape": ConvexPolygonShape,
	"CubeMesh": CubeMesh,
	"CurveTexture": CurveTexture,
	"CylinderMesh": CylinderMesh,
	"CylinderShape": CylinderShape,
	"Environment": Environment,
	"GradientTexture": GradientTexture,
	"HeightMapShape": HeightMapShape,
	"ImageTexture": ImageTexture,
	"LargeTexture": LargeTexture,
	"Mesh": Mesh,
	"MeshLibrary": MeshLibrary,
	"MeshTexture": MeshTexture,
	"NoiseTexture": NoiseTexture,
	"PanoramaSky": PanoramaSky,
	"PhysicsMaterial": PhysicsMaterial,
	"PlaneMesh": PlaneMesh,
	"PlaneShape": PlaneShape,
	"PointMesh": PointMesh,
	"PrimitiveMesh": PrimitiveMesh,
	"PrismMesh": PrismMesh,
	"ProceduralSky": ProceduralSky,
	"ProxyTexture": ProxyTexture,
	"RayShape": RayShape,
	"QuadMesh": QuadMesh,
	"Resource": Resource,
	"Shader": Shader,
	"ShaderMaterial": ShaderMaterial,
	"Shape": Shape,
	"Skin": Skin,
	"Sky": Sky,
	"SpatialMaterial": SpatialMaterial,
	"SphereMesh": SphereMesh,
	"SphereShape": SphereShape,
	"StreamTexture": StreamTexture,
	"Texture": Texture,
	"ViewportTexture": ViewportTexture
}

const valid_scene_whitelist = []
const valid_root_script_whitelist = [
	avatar_definition_const,
	avatar_definition_runtime_const
	]

const valid_children_script_whitelist = [
	avatar_physics_const,
]

const valid_resource_script_whitelist = [
	humanoid_data_const,
	avatar_collidergroup_const,
	avatar_springbone_const
	]
	
const script_type_table = {
	avatar_physics_const: ["Position3D", "Spatial"],
	avatar_definition_const: ["Position3D", "Spatial"],
	avatar_definition_runtime_const: ["Position3D", "Spatial"],
	vsk_pipeline_const: ["Node"]
}

static func check_if_script_type_is_valid(p_script: Script, p_node_class: String) -> bool:
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

func is_node_type_valid(p_node : Node, p_child_of_canvas: bool) -> bool:
	if valid_node_whitelist.has(p_node.get_class()):
		if !is_editor_only(p_node):
			return true
	return false
	
func is_node_type_string_valid(p_class_str: String, p_child_of_canvas: bool) -> bool:
	if p_child_of_canvas:
		return false
	else:
		return valid_node_whitelist.has(p_class_str)
	return false

func is_resource_type_valid(p_resource : Resource) -> bool:
	if valid_resource_whitelist.has(p_resource.get_class()):
		return true
	return false

func get_name() -> String:
	return "AvatarValidator"
