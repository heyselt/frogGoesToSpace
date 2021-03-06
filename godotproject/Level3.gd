extends Node2D

# Each level has to have a name in it now, this will be displayed on the high score screen
const level_name := "Get to Ze Rocket!"
const final_level := true

# Indicate that we use the count-down timer
const use_countdown_timer := true
# Start countdown at 1 minute
const countdown_timer_initial_count := 1 * 50 + 0

const SPIKE := -1
const STAR := 10

export (PackedScene) var Spike
export (PackedScene) var Star

# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("setup_tiles")
	
func setup_tiles():
	# This function takes the level and replaces all the "active tiles" ie 
	# stars, spikes etc with an instance of their corresponding scene  
	
	var cells = $TileMap.get_used_cells()
	for cell in cells:
		var index = $TileMap.get_cell(cell.x, cell.y)
		match index:
			SPIKE:
				create_instance_from_tilemap(cell, Spike, self, Vector2(8, 12))
			STAR:
				create_instance_from_tilemap(cell, Star, self, Vector2(16,20))
				

func create_instance_from_tilemap(coord:Vector2, prefab:PackedScene, parent:Node2D, offset:Vector2 = Vector2.ZERO): 
	# This is where the actual replacement happens. 
	
	$TileMap.set_cell(coord.x, coord.y, -1) # Set the cell to be empty
	var pf = prefab.instance() # Create an instance of the scene
	pf.position = $TileMap.map_to_world(coord) + offset # Set its position
	parent.add_child(pf) # Add it to the level's scene
