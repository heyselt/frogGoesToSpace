extends Area2D

func _on_DeathPlane_body_entered(body):
	if Global.is_player(body):
		body.hit_death_plane()
