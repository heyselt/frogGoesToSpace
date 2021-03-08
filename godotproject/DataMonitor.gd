extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

enum MONITOR {
	TIME_FPS ,
	TIME_PROCESS ,
	TIME_PHYSICS_PROCESS ,
	MEMORY_STATIC ,
	MEMORY_DYNAMIC ,
	MEMORY_STATIC_MAX ,
	MEMORY_DYNAMIC_MAX ,
	MEMORY_MESSAGE_BUFFER_MAX ,
	OBJECT_COUNT ,
	OBJECT_RESOURCE_COUNT ,
	OBJECT_NODE_COUNT ,
	OBJECT_ORPHAN_NODE_COUNT ,
	RENDER_OBJECTS_IN_FRAME ,
	RENDER_VERTICES_IN_FRAME ,
	RENDER_MATERIAL_CHANGES_IN_FRAME ,
	RENDER_SHADER_CHANGES_IN_FRAME ,
	RENDER_SURFACE_CHANGES_IN_FRAME ,
	RENDER_DRAW_CALLS_IN_FRAME ,
	RENDER_2D_ITEMS_IN_FRAME ,
	RENDER_2D_DRAW_CALLS_IN_FRAME ,
	RENDER_VIDEO_MEM_USED ,
	RENDER_TEXTURE_MEM_USED ,
	RENDER_VERTEX_MEM_USED ,
	RENDER_USAGE_VIDEO_MEM_TOTAL ,
	PHYSICS_2D_ACTIVE_OBJECTS ,
	PHYSICS_2D_COLLISION_PAIRS ,
	PHYSICS_2D_ISLAND_COUNT ,
	PHYSICS_3D_ACTIVE_OBJECTS ,
	PHYSICS_3D_COLLISION_PAIRS ,
	PHYSICS_3D_ISLAND_COUNT ,
	AUDIO_OUTPUT_LATENCY ,
	MONITOR_MAX ,
}

var MONITOR_NAMES = [
	"TIME_FPS",
	"TIME_PROCESS",
	"TIME_PHYSICS_PROCESS",
	"MEMORY_STATIC",
	"MEMORY_DYNAMIC",
	"MEMORY_STATIC_MAX",
	"MEMORY_DYNAMIC_MAX",
	"MEMORY_MESSAGE_BUFFER_MAX",
	"OBJECT_COUNT",
	"OBJECT_RESOURCE_COUNT",
	"OBJECT_NODE_COUNT",
	"OBJECT_ORPHAN_NODE_COUNT",
	"RENDER_OBJECTS_IN_FRAME",
	"RENDER_VERTICES_IN_FRAME",
	"RENDER_MATERIAL_CHANGES_IN_FRAME",
	"RENDER_SHADER_CHANGES_IN_FRAME",
	"RENDER_SURFACE_CHANGES_IN_FRAME",
	"RENDER_DRAW_CALLS_IN_FRAME",
	"RENDER_2D_ITEMS_IN_FRAME",
	"RENDER_2D_DRAW_CALLS_IN_FRAME",
	"RENDER_VIDEO_MEM_USED",
	"RENDER_TEXTURE_MEM_USED",
	"RENDER_VERTEX_MEM_USED",
	"RENDER_USAGE_VIDEO_MEM_TOTAL",
	"PHYSICS_2D_ACTIVE_OBJECTS",
	"PHYSICS_2D_COLLISION_PAIRS",
	"PHYSICS_2D_ISLAND_COUNT",
	"PHYSICS_3D_ACTIVE_OBJECTS",
	"PHYSICS_3D_COLLISION_PAIRS",
	"PHYSICS_3D_ISLAND_COUNT",
	"AUDIO_OUTPUT_LATENCY",
	"MONITOR_MAX",
]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	for monitor in range(MONITOR.MONITOR_MAX):
		var format_string = MONITOR_NAMES[monitor] + ", %d"
		print(format_string % Performance.get_monitor(monitor))

	
