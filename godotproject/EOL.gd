extends Area2D

# Let our scene instantiation tell us what level to go to next
export (String, FILE, "*.tscn") var next_path

# Make it so that we can't send multiple end_of_level events to the high score screen
var triggered = false

func _on_EOL_body_entered(body):
	# Change the current scene to the next level
	if body.name == "Player" and not triggered:
		triggered = true
		var level_name = Global.get_current_scene_property('level_name')
		Global.HighScoreScreen.end_of_level(level_name, body.star_piece_count, $"/root/CountUpDownTimer".time, Global.level_uses_countdown_timer(), next_path)
