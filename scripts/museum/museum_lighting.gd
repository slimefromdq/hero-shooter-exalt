class_name MuseumLighting
extends Node3D
## Museum-only lighting, selected per session. No geometry or combat state changes.
signal preset_changed(id: String)
const IDS: Array[String] = ["dawn","afternoon","night"]
const TITLES: Array[String] = ["COOL DAWN","ROSY AFTERNOON","STARRY NIGHT"]
const PREFERENCE_PATH: String = "user://museum_lighting.cfg"
static var selected_preset: String = "afternoon"
static var preference_loaded: bool = false
const PRESETS := {
 "dawn":{"zenith":"263e77","horizon":"a4bedb","ground":"55667b","cloud":"becce7","sun":"c8dcff","ambient":"9db9e1","ambient_energy":0.6,"key_energy":1.05,"pitch":-14.0,"yaw":-62.0,"lamps":0.65,"emission":1.2,"fog":0.0012,"stars":0.0},
 "afternoon":{"zenith":"677ab4","horizon":"f5aec8","ground":"8b7388","cloud":"ffd6d8","sun":"ffc0bb","ambient":"d3b9d8","ambient_energy":0.62,"key_energy":1.65,"pitch":-38.0,"yaw":-32.0,"lamps":0.25,"emission":0.8,"fog":0.0006,"stars":0.0},
 "night":{"zenith":"050b23","horizon":"28385f","ground":"10172b","cloud":"243451","sun":"bed6ff","ambient":"6c8bbb","ambient_energy":0.32,"key_energy":0.24,"pitch":-35.0,"yaw":34.0,"lamps":4.5,"emission":3.0,"fog":0.0007,"stars":1.0}
}
var definition: MuseumMapDefinition
var current_preset: String = ""
var world_environment: WorldEnvironment
var environment: Environment
var sky_material: ShaderMaterial
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
var fixture_material: StandardMaterial3D

static func load_preference() -> String:
 if not preference_loaded:
  preference_loaded = true
  var config := ConfigFile.new()
  if config.load(PREFERENCE_PATH) == OK:
   var saved: String = str(config.get_value("museum","lighting","afternoon"))
   if saved in IDS: selected_preset = saved
 return selected_preset

static func choose(id: String, save: bool = true) -> bool:
 if id not in IDS: return false
 preference_loaded = true
 selected_preset = id
 if save:
  var config := ConfigFile.new()
  config.set_value("museum","lighting",id)
  var error: Error = config.save(PREFERENCE_PATH)
  if error != OK: push_warning("Museum lighting preference: "+error_string(error))
 return true

static func entry_preset() -> String:
 var result: String = load_preference()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--museum-lighting="):
   var id: String = arg.trim_prefix("--museum-lighting=").to_lower()
   if id in IDS: result = id
 return result

func _ready() -> void:
 name = "MuseumLighting"
 world_environment = WorldEnvironment.new()
 environment = Environment.new()
 environment.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 sky_material = ShaderMaterial.new()
 sky_material.shader = preload("res://shaders/museum_sky.gdshader")
 sky.sky_material = sky_material
 environment.sky = sky
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.glow_enabled = true
 environment.glow_intensity = 0.65
 environment.glow_bloom = 0.08
 environment.fog_enabled = true
 environment.fog_sky_affect = 0.0
 world_environment.environment = environment
 add_child(world_environment)
 key_light = DirectionalLight3D.new()
 key_light.name = "SunOrMoon"
 key_light.shadow_enabled = true
 key_light.directional_shadow_max_distance = 160
 add_child(key_light)
 fill_light = DirectionalLight3D.new()
 fill_light.rotation_degrees = Vector3(-28,145,0)
 fill_light.light_color = Color("8eaef3")
 fill_light.light_energy = 0.12
 add_child(fill_light)
 _build_fixtures()
 apply_preset(entry_preset())

func _build_fixtures() -> void:
 fixture_material = StandardMaterial3D.new()
 fixture_material.albedo_color = Color("ffe1ad")
 fixture_material.emission_enabled = true
 fixture_material.emission = Color("ffcc8b")
 for at: Vector3 in [Vector3(-38,3.05,12),Vector3(-16,4.5,32),Vector3(-28,5.8,25),Vector3(-29,9,-27),Vector3(-23,8,-5),Vector3(-11,4.4,-12),Vector3(17,3.3,-15),Vector3(19,5.2,-2),Vector3(39,2.8,-24),Vector3(39,2.8,-12),Vector3(25,4.5,18),Vector3(32,4.5,36),Vector3(37,7,23),Vector3(22,5,36),Vector3(15,6.5,26)]:
  _fixture(at)
 for at: Vector3 in definition.attacker_rooms: _fixture(at+Vector3.UP*3.7)
 for at: Vector3 in definition.defender_rooms: _fixture(at+Vector3.UP*3.7)

func _fixture(at: Vector3) -> void:
 var fixture := MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = Vector3(1.8,0.09,0.35)
 fixture.mesh = mesh
 fixture.material_override = fixture_material
 fixture.position = at
 add_child(fixture)
 var lamp := OmniLight3D.new()
 lamp.position = at-Vector3.UP*.25
 lamp.light_color = Color("ffd4a0")
 lamp.omni_range = 12
 lamp.omni_attenuation = 1.3
 lamp.shadow_enabled = false
 add_child(lamp)
 lamps.append(lamp)

func apply_preset(id: String) -> bool:
 if id not in IDS: return false
 var data: Dictionary = PRESETS[id]
 current_preset = id
 key_light.rotation_degrees = Vector3(data.pitch,data.yaw,0)
 key_light.light_color = Color(data.sun)
 key_light.light_energy = data.key_energy
 fill_light.light_energy = 0.08
 environment.ambient_light_color = Color(data.ambient)
 environment.ambient_light_energy = data.ambient_energy
 environment.fog_light_color = Color(data.horizon)
 environment.fog_density = data.fog
 for entry: Array in [["zenith","zenith"],["horizon","horizon"],["ground_color","ground"],["cloud_color","cloud"],["disc_color","sun"]]:
  sky_material.set_shader_parameter(entry[0],Color(data[entry[1]]))
 sky_material.set_shader_parameter("disc_direction",key_light.basis.z)
 sky_material.set_shader_parameter("stars_strength",data.stars)
 sky_material.set_shader_parameter("cloud_opacity",0.18 if id == "night" else 0.48)
 sky_material.set_shader_parameter("disc_radius",0.017 if id == "night" else 0.012)
 fixture_material.emission_energy_multiplier = data.emission
 for lamp: OmniLight3D in lamps: lamp.light_energy = data.lamps
 preset_changed.emit(id)
 return true
