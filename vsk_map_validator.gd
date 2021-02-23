tool
extends "vsk_validator.gd"

const map_definition_const = preload("res://addons/vsk_map/vsk_map_definition.gd")
const map_definition_runtime_const = preload("res://addons/vsk_map/vsk_map_definition_runtime.gd")

const network_spawn_const = preload("res://addons/network_manager/network_spawn.gd")

const valid_node_whitelist = {
	"AnimatedSprite3D": AnimatedSprite3D,
	"AnimationPlayer": AnimationPlayer,
	"Area": Area,
	"AudioStreamPlayer": AudioStreamPlayer,
	"AudioStreamPlayer3D": AudioStreamPlayer3D,
	"BoneAttachment": BoneAttachment,
	"BakedLightmap": BakedLightmap,
	"Camera": Camera,
	"CollisionObject": CollisionObject,
	"CollisionShape": CollisionShape,
	"ConeTwistJoint": ConeTwistJoint,
	"CPUParticles": CPUParticles,
	"DirectionalLight": DirectionalLight,
	"GridMap": GridMap,
	"GeometryInstance": GeometryInstance,
	"Generic6DOFJoint": Generic6DOFJoint,
	"GIProbe": GIProbe,
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
	"ReflectionProbe": ReflectionProbe,
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
	"VehicleWheel": VehicleWheel,
	"VisibilityEnabler": VisibilityEnabler,
	"VisibilityNotifier": VisibilityNotifier,
	"VisualInstance": VisualInstance,
	"WorldEnvironment": WorldEnvironment,
}

const valid_resource_whitelist = {
	"AnimatedTexture": AnimatedTexture,
	"Animation": Animation,
	"ArrayMesh": ArrayMesh,
	"AtlasTexture": AtlasTexture,
	"AudioStreamSample": AudioStreamSample,
	"AudioStreamOGGVorbis": AudioStreamOGGVorbis,
	"BakedLightmapData": BakedLightmapData,
	"BoxShape": BoxShape,
	"CapsuleMesh": CapsuleMesh,
	"CapsuleShape": CapsuleShape,
	"ConcavePolygonShape": ConcavePolygonShape,
	"ConvexPolygonShape": ConvexPolygonShape,
	"CubeMesh": CubeMesh,
	"Curve": Curve,
	"Curve2D": Curve2D,
	"Curve3D": Curve3D,
	"CurveTexture": CurveTexture,
	"CylinderMesh": CylinderMesh,
	"CylinderShape": CylinderShape,
	"Environment": Environment,
	"GIProbeData": GIProbeData,
	"GradientTexture": GradientTexture,
	"HeightMapShape": HeightMapShape,
	"ImageTexture": ImageTexture,
	"LargeTexture": LargeTexture,
	"Mesh": Mesh,
	"MeshLibrary": MeshLibrary,
	"MeshTexture": MeshTexture,
	"NoiseTexture": NoiseTexture,
	"PackedScene": PackedScene,
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
	"Texture3D": Texture3D,
	"TextureArray": TextureArray,
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
const valid_children_script_whitelist = [network_spawn_const]

const valid_resource_script_whitelist = []

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

func is_path_an_entity(p_packed_scene_path : String) -> bool:
	if valid_entity_whitelist.find(p_packed_scene_path) != -1:
		return true
	else:
		return false

func is_valid_entity_script(p_script : Script) -> bool:
	if p_script == entity_script:
		return true
		
	return false
