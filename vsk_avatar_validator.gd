tool
extends "vsk_validator.gd"

const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")
const avatar_definition_const = preload("res://addons/vsk_avatar/vsk_avatar_definition.gd")
const avatar_definition_runtime_const = preload("res://addons/vsk_avatar/vsk_avatar_definition_runtime.gd")

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
const valid_root_script_whitelist = [avatar_definition_const, avatar_definition_runtime_const]
const valid_children_script_whitelist = []
const valid_resource_script_whitelist = [humanoid_data_const]

func is_script_valid_for_root(p_script: Script):
	if p_script == null:
		return true
	
	if valid_root_script_whitelist.find(p_script) != -1:
		return true
	else:
		return false

func is_script_valid_for_children(p_script: Script):
	if p_script == null:
		return true
	
	if valid_children_script_whitelist.find(p_script) != -1:
		return true
	else:
		return false

func is_script_valid_for_resource(p_script: Script):
	if p_script == null:
		return true
	
	if valid_resource_script_whitelist.find(p_script) != -1:
		return true
	else:
		return false

func is_node_type_valid(p_node : Node) -> bool:
	if valid_node_whitelist.has(p_node.get_class()):
		return true
	return false

func is_resource_type_valid(p_resource : Resource) -> bool:
	if valid_resource_whitelist.has(p_resource.get_class()):
		return true
	return false
