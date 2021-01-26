extends Control

onready var lb_life = $LeftPanel/HBoxContainer/LifeContainer/LifeCountLabel
onready var lb_star = $LeftPanel/HBoxContainer/StarContainer/StarCountLabel
onready var lb_time = $RightPanel/TimeCountLabel
onready var menu = $"/root/Global/InGameMenuLayer/InGameMenu"

var player = null
var countup_timer = null

func _hud_is_hidden():
	# Hide HUD if:
	# - current scene says No HUD (title screen)
	# - menu is open and current menu screen hides HUD
	return \
		Global.current_scene_has_property_set('inhibit_hud') || \
		menu.should_hide_hud()

func _process(_delta):
	# Check if we should hide the HUD
	if _hud_is_hidden():
		hide()
		return
	else:
		show()

	# Check if we should show or hide the transparent backing to the HUD elements
	# based on if the pause menu is open
	if menu.active():
		$StyleAnimationPlayer.play("inmenu")
	else:
		$StyleAnimationPlayer.play("ingame")
	if !player:
		# Get player
		var scene = get_tree().current_scene
		if !scene:
			return
		player = scene.find_node("Player", false, true)
	if player:
		var health = player.health
		lb_life.text = str(health)
		var star = player.star_piece_count
		lb_star.text = str(star)
	if !countup_timer:
		countup_timer = $"/root/CountupTimer"
	if countup_timer:
		var time = countup_timer.time
		var minutes = int(time / 60)
		var seconds = int(time) % 60
		var subseconds = int(time * 60) % 60
		lb_time.text = "%01d:%02d:%02d" % [minutes, seconds, subseconds]