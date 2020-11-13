extends KinematicBody2D

signal tongue_start
signal tongue_stop

# Constants relating to horizontal movement
export (float) var walk_horiz_accel = 1200
export (float) var walk_speed_limit = 225
export (float) var going_too_fast_slowdown_accel = walk_speed_limit / 0.25
export (float) var friction_coeff = 1.5
export (float) var ground_turn_coefficient = friction_coeff * 1.5
export (float) var air_horiz_accel = walk_horiz_accel * 0.6
export (float) var air_speed_limit = walk_speed_limit * 1.0
export (float) var air_turn_coefficient = 1.2

export (float) var jump_leniency_time = 5 / 60.0
export (float) var jump_speed = 500
export (float) var jump_length = 10 / 60.0
export (float) var shorthop_speed = jump_speed * 0.6
export (float) var shorthop_length = 6 / 60.0
export (float) var gravity = 1200
export (float) var terminal_velocity = 400
export (float) var swing_user_anglespeed_per_s = 1
export (float) var swing_user_radius_per_s = 40
# How long to delay between hop sound effects
export (float) var hop_sound_timer_period = 0.2
# Used to add some randomness to hop sounds - see its use
# in the code below for more detail
export (float) var hop_sound_timer_period_variance = 0.1

# Variables relating to "jumping" out of tongue
# Search for "velocity_after_swing" for more information.
# The swing velocity will be multiplied by this when jumping out
# of the swing.
export (float) var tongue_exit_jump_multiplier_in_dirn = 1.1
# This is the constant velocity that will be added in the direction
# of the swing when jumping out of the swing.
export (float) var tongue_exit_jump_bonus_speed_in_dirn = 20
# This is a constant velocity that will be added in the "up" direction
# when jumping out of the swing.
export (float) var tongue_exit_jump_bonus_speed_up = 200


onready var animation_tree = get_node("AnimationTree")
onready var animation_mode = animation_tree.get("parameters/playback")

var velocity = Vector2.ZERO
var jump_frame_countdown = 0
var jump_shorthop_countdown = 0
var jump_button_press_leniency_timer = 0
var jump_on_ground_leniency_timer = 0
var facing = Vector2.RIGHT
var on_floor_last_frame = false

var user_direction = Vector2.ZERO
var jump_pressed = false
var tongue_pressed = false
var jump_held = false
var tongue_held = false

var swing_angular_speed = 0
var swing_radius = 0
var swing_angle = 0
var swing_pivot_position = Vector2.ZERO

# Timer used to add delay between hop sound effects
# This is temporary - in the future, hop sound will be synchronized
# with the hop animation
var hop_sound_timer = 0

# This counter keeps track of the number of star pieces collected.
# This may be temporary, depending on if we want to track the number of star pieces
# collected in-between levels or in-between deaths.
var star_piece_count = 0

var health = 3

func fequal(x, y):
	# Function to check if two floating point numbers are approximately equal.
	return abs(x - y) < 0.01

func start_swing():
	# Calculate initial angle and radius
	var swing_vec = update_swing_radius_angle()
	var swing_dir_vec = swing_vec.rotated(PI/2)
	var dotprod = swing_dir_vec.dot(velocity)
	swing_angular_speed = sign(dotprod) * pow(abs(dotprod), 0.5) / max(1, swing_radius)

func stop_swing():
	# Convert swinging angular momentum into player velocity
	velocity = Vector2.DOWN.rotated(swing_angle) * swing_angular_speed * swing_radius
	print_debug('Stop swing: Velocity=',velocity)
	emit_signal("tongue_stop")

func update_swing_radius_angle():
	# Calculate current angle and radius
	var frog_pos = get_global_transform().xform(Vector2.ZERO)
	var swing_vec = frog_pos - swing_pivot_position
	swing_radius = swing_vec.length()
	swing_angle = swing_vec.angle() # Angle from positive X-axis to swing vector
	return swing_vec

func get_input():
	var l = Input.is_action_pressed("walk_left")
	var r = Input.is_action_pressed("walk_right")
	var u = Input.is_action_pressed("look_up")
	var d = Input.is_action_pressed("look_down")
	user_direction.x = 0
	if l:
		user_direction.x -= 1
	if r:
		user_direction.x += 1
	user_direction.y = 0
	if u:
		user_direction.y -= 1
	if d:
		user_direction.y += 1
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	tongue_pressed = Input.is_action_just_pressed("tongue")
	tongue_held = Input.is_action_pressed("tongue")


func handle_normal_horizontal_movement(delta):
	# We break movement up into two main categories: ground and air
	###############################################################################################
	# If the frog is on the ground, then there are a few possible movement options:
	#   - user is not inputting a direction:
	#     => frog experiences friction (walk_horiz_accel * friction_coeff) slowing them down
	#        until they are stopped
	# 
	#   - user is inputting direction that the frog is going, and frog is going slower than the max speed:
	#     => frog experiences constant acceleration (walk_horiz_accel) in input direction until they
	#        reach their max speed (walk_speed_limit), beyond which the speed doesn't increase
	# 
	#   - user is inputting direction OPPOSITE the dir'n the frog is going, and is going slower than the max speed:
	#     => frog experiences boosted constant acceleration (walk_horiz_accel * ground_turn_coefficient)
	#        in the inputted direction (still obeying the maximum speed limit)
	# 
	#   - user is inputting direction that the frog is going, and frog is going faster than the max speed:
	#     => frog experiences constant deceleration (going_too_fast_slowdown_accel)
	#        until they reach their max speed, beyond which the speed doesn't decrease
	# 
	# The ground_turn_coefficient exists so that the frog can turn around quicker, which should
	# make the movement feel "tighter."
	# 
	# The "going_too_fast_slowdown_accel" exists so that the frog can't go ridiculously fast along
	# the ground, since it wouldn't make sense if all of a sudden they were able to run faster
	# for an extended period of time just because they went fast once.
	# 
	###############################################################################################
	# If the frog is in the air, the movement is simpler:
	#   - user is not inputting a direction:
	#     => no effect, they keep all momentum (no ground to have friction against)
	# 
	#   - user is inputting direction that the frog is going:
	#     => frog experiences constant acceleration (air_horiz_accel) in input direction until they
	#        reach their max speed (air_speed_limit), beyond which the speed doesn't increase
	# 
	#   - user is inputting direction OPPOSITE the dir'n the frog is going:
	#     => frog experiences boosted constant acceleration (air_horiz_accel * air_turn_coefficient)
	#        in the inputted direction (still obeying the maximum speed limit)
	# 
	# When a direction is not input while in the air, momentum is kept the same since that logically
	# makes sense and seems to play OK.
	# 
	# There is a horizontal speed cap while in the air, but this only affects the user's inputs.
	# This means they can't exceed this speed cap by inputting left/right, but when they eject
	# out of a swing, they will be allowed to be above the speed cap. If they push in the dir'n
	# they are going, then they won't lose speed. If they push in the dir'n opposite their
	# velocity, then they will slow down using the same "air_turn_coefficient" as normal.
	# 
	# This conservation of momentum above the speed cap basically allows the user to keep their
	# momentum for as long as they are in the air, slowing down when they touch ground.
	# They can keep the full momentum if they can jump as soon as they touch the ground.
	# 
	###############################################################################################
	
	if on_floor_last_frame:
		# Handle ground movement
		if fequal(user_direction.x, 0):
			# If the user isn't inputting a direction, slow them down toward stopped
			var vs = sign(velocity.x)
			velocity.x += -vs * walk_horiz_accel * delta * friction_coeff
			if sign(velocity.x) * vs < 0:
				# User is going in opposite dir'n then they were originally.
				# Make them come to a stop.
				velocity.x = 0
		else:
			# Make the user move in the direction they're pointing if they're not already
			# at the speed cap
			if sign(user_direction.x) * velocity.x < walk_speed_limit:
				var turning_bonus = 1
				# Add additional speed if the user is turning around
				# (dir'n of user_direction.x doesn't match dir'n of velocity.x)
				if sign(user_direction.x) * sign(velocity.x) < 0:
					turning_bonus = ground_turn_coefficient
				velocity.x += user_direction.x * walk_horiz_accel * delta * turning_bonus
				# Limit horiz. speed to speed cap
				velocity.x = sign(velocity.x) * min(abs(velocity.x), walk_speed_limit)
			else:
				# If they are at or above the speed cap, gradually slow them down towards
				# speed cap (to stop them from going too fast)
				velocity.x -= user_direction.x * going_too_fast_slowdown_accel * delta
				# Don't decrease speed past the speed cap!
				velocity.x = sign(velocity.x) * max(abs(velocity.x), walk_speed_limit)
	else:
		# Handle air movement
		# If the user isn't inputting a direction, don't adjust their velocity
		# Otherwise...
		if !fequal(user_direction.x, 0):
			# Make the user move in the direction they're pointing if they're not already
			# at the speed cap
			if sign(user_direction.x) * velocity.x < air_speed_limit:
				var turning_bonus = 1
				# Add additional speed if the user is turning around
				# (dir'n of user_direction.x doesn't match dir'n of velocity.x)
				if sign(user_direction.x) * sign(velocity.x) < 0:
					turning_bonus = air_turn_coefficient
				velocity.x += user_direction.x * air_horiz_accel * delta * turning_bonus
				# Limit horiz. speed to speed cap
				velocity.x = sign(velocity.x) * min(abs(velocity.x), air_speed_limit)

func _draw():
	# THIS IS JUST DEBUG
	# TODO: Remove
	# Draw swinging velocity vector
	#if $PlayerTongue.shooting:
	#	#frog_pos = get_global_transform().xform(Vector2.ZERO)
	#	draw_line($Sprite.position, $Sprite.position + $PlayerTongue.globalposition, Color(1,0,0))
	
	if $PlayerTongue.swinging:
		#var frog_pos = get_global_transform().xform(Vector2.ZERO)
		draw_line(Vector2(0,0), Vector2(0,0) - swing_pivot_position, Color(1,0,0))
		
		#print(swing_pivot_position)
		#var tgt = Vector2.DOWN.rotated(swing_angle) * swing_angular_speed * 100
		#draw_line(Vector2(0,0), tgt, Color(1,0,0))


func do_movement(delta):
	if $PlayerTongue.swinging:
		# Adjust swinging speed based on user's influence
		swing_angular_speed += swing_user_anglespeed_per_s * -user_direction.x * delta
		# TODO: Fix this and uncomment
		# # We don't directly compute the position. We need to use move_and_collide
		# var change_in_swing_radius = swing_user_radius_per_s * user_direction.y * delta
		# if abs(change_in_swing_radius) > 0.01:
		# 	var proposed_movement = Vector2.RIGHT.rotated(swing_angle) * change_in_swing_radius
		# 	collision_info = move_and_collide(proposed_movement)

		# 	# Update swing radius based on what's shown on-screen
		# 	update_swing_radius()
		# 	var frog_pos = get_global_transform().xform(Vector2.ZERO)
		# 	var swing_vec = frog_pos - swing_pivot_position
		# 	swing_radius = swing_vec.length()
		

		swing_angular_speed += 1 / swing_radius * gravity * cos(swing_angle) * delta

		# Add some dampening to the swinging. Equivalent to speed being halved every second.
		swing_angular_speed *= pow(0.5, delta)

		# Adjust swing angle based on swing speed
		swing_angle += swing_angular_speed * delta

		# === Uh oh. "When moving a KinematicBody2D, you should not set its position property directly."
		# Instead of the direct position calculation, we can set velocity, and use move_and_collide
		velocity = Vector2.DOWN.rotated(swing_angle) * swing_angular_speed * swing_radius
		var collision_info = move_and_collide(velocity * delta)
		
		if collision_info:
			# We decided that the frog should exit swinging state when they hit a wall or the ground
			# Let's just make them stop swinging no matter what they collided with
			stop_swing()

		animation_tree.set('parameters/swing/blend_position', velocity.normalized())
		animation_mode.travel("swing")

	else:
		# Adjust X velocity based on user input
		handle_normal_horizontal_movement(delta)
		
		# Adjust Y velocity based on gravity and jump
		velocity.y += gravity * delta

		# If we're still in the shorthop section of our jump
		if jump_shorthop_countdown > 0:
			jump_shorthop_countdown -= delta
			# If we're still shorthopping and the user has let go of jump, then abort out of
			# the main jump by clearing its timer, and use the shorthop speed instead.
			if jump_shorthop_countdown <= 0 and not jump_held:
				jump_frame_countdown = 0
				velocity.y = -shorthop_speed
		# If we're still jumping, set the user's Y velocity to -jump_speed (-Y is up)
		if jump_frame_countdown > 0:
			jump_frame_countdown -= delta
			velocity.y = -jump_speed
		# Prevent the player from falling faster than their terminal velocity
		velocity.y = min(velocity.y, terminal_velocity)

		# Actually move the player along the velocity vector.
		velocity = move_and_slide(velocity, Vector2.UP)
		# Update our stored floor state.
		on_floor_last_frame = is_on_floor()

		# Count down the hop sound timer, ensuring it never goes below 0.
		hop_sound_timer = max(hop_sound_timer - delta, 0)
		# Play sound effect when timer has expired and frog is walking on floor
		# (only if user is pointing in the same direction that frog is going)
		if hop_sound_timer <= 0 && on_floor_last_frame && !fequal(user_direction.x, 0) && sign(velocity.x) == sign(user_direction.x):
			# Calculate new timer value, based on period as well as random variance.
			# This slight variance will hopefully make it sound more natural.
			# Let P and V be the period and variance, the minimum timer value will be P and the max will be P*(1+V)
			# In practice, with (P,V) = (0.2,0.1), the min will be 0.2 and the max will be 0.22
			hop_sound_timer = hop_sound_timer_period * (1 + rand_range(0, hop_sound_timer_period_variance))
			# Play sound effect.
			$HopSoundPlayer.play(0)
		
		if jump_pressed or jump_held:
			if velocity.x < 0:
				animation_tree.set('parameters/Land/blend_position', velocity.normalized())
				animation_tree.set('parameters/Idle/blend_position', velocity.normalized())
				animation_mode.travel("Land")
			if velocity.x > 0:	
				animation_tree.set('parameters/Launch/blend_position', velocity.normalized())
				animation_tree.set('parameters/Idle/blend_position', velocity.normalized())
				animation_mode.travel("Launch")
				
		elif velocity.y == 0:
			animation_tree.set('parameters/Hop/blend_position', velocity.normalized())
			animation_tree.set('parameters/Idle/blend_position', velocity.normalized())
			animation_mode.travel("Hop")
		elif velocity.y != 0:
			animation_mode.travel("Idle")
			
	if tongue_pressed or tongue_held:
		if $PlayerTongue.swinging:
			animation_tree.set('parameters/tongue_retract/blend_position', velocity.normalized())
			animation_mode.travel("tongue_retract")
		else:
			animation_tree.set('parameters/tongue_launch/blend_position', velocity.normalized())
			animation_mode.travel("tongue_launch")#emit_signal("tongue_start", get_tongue_direction())		


func handle_jump_starting():
	# Adjust jump start related timers used to permit users to jump a short bit
	# after they technically left the ground or pressed the jump key.
	# This is done in many games to prevent the user from feeling like their jump was
	# "stolen" when they actually pressed the button after leaving the ground.
	# Also allows them to press the jump button just before hitting the ground and
	# not have their jump eaten. Technically this allows for the user to buffer a
	# frame-perfect jump which preserves all their horizontal speed, but we can block
	# this if users prove to be able to perform these jumps very easily.
	if jump_pressed:
		$JumpButtonPressLeniencyTimer.start(jump_leniency_time)
	if on_floor_last_frame:
		$JumpOnGroundLeniencyTimer.start(jump_leniency_time)
	
	# Check if we should jump - if we hit the jump button and were on solid ground recently
	if $JumpButtonPressLeniencyTimer.time_left > 0 && $JumpOnGroundLeniencyTimer.time_left > 0:
		# Reset both timers so we don't jump again next update.
		$JumpButtonPressLeniencyTimer.stop()
		$JumpOnGroundLeniencyTimer.stop()
		# Set jump timers to cause frog to jump. The actual jumping motion is handled in do_movement
		# on the next _physics_process call.
		jump_frame_countdown = jump_length
		jump_shorthop_countdown = shorthop_length
		$JumpSoundPlayer.play(0)

func update_anim():
	# If the frog is shooting out the tongue, don't allow them to change
	# which direction they're facing.
	var facing_lock = $PlayerTongue.shooting
	if !facing_lock:
		# If the user is inputting left or right on the stick, face in that
		# direction - otherwise, we will remain facing the direction that
		# we were before.
		if !fequal(user_direction.x, 0):
			facing.x = user_direction.x
		# At the moment, we only face left or right, no up/down/diagonals.
		facing.y = 0
		# If we're facing left, flip the frog.
		$Sprite.flip_h = facing.x < 0

# This function is used when the player shoots out their tongue
# to determine what direction it should travel in.
func get_tongue_direction():
	var tdir = user_direction
	# Block out tongueing down (positive Y dir'n)
	# If we're currently going to tongue down by any amount...
	if tdir.y > 0:
		# Remove the tongue's vertical component so it goes either
		# left or right
		tdir.y = 0
	if tdir.length_squared() < 0.01:
		tdir = facing
	if tdir.length_squared() < 0.01:
		tdir = Vector2.RIGHT
	
	return tdir.normalized()

func _physics_process(delta):
	# Update our input-related variables
	get_input()

	# Move the frog based on current state and inputs
	do_movement(delta)

	# Handle various non-directional-movement things (tongue, jump)
	if $PlayerTongue.swinging:
		if jump_pressed:
			# When we exit swinging using the jump button, give an additional speed boost
			# in the direction they were swinging.
			stop_swing()
			var velocity_after_swing = velocity * tongue_exit_jump_multiplier_in_dirn
			velocity_after_swing += velocity.normalized() * tongue_exit_jump_bonus_speed_in_dirn
			velocity_after_swing += Vector2.UP * tongue_exit_jump_bonus_speed_up
			velocity = velocity_after_swing
		elif tongue_pressed:
			# When we exit swinging using the tongue button, just drop them out of swinging
			stop_swing()
	else:
		# If we aren't swinging, then we may be able to jump.
		# Check if we should jump
		handle_jump_starting()

		# Check if we should tongue
		if tongue_pressed:
			# Fire out the tongue by signalling the PlayerTongue object
			emit_signal("tongue_start", get_tongue_direction())

	update_anim()

func takeDamage(damageTaken):
	if $InvulnerableTimer.is_stopped():
		health -= damageTaken
		if health <= 0:
			die()
			
		#After the player gets hit set the player to invulnerable to damage for 1 second
		$InvulnerableTimer.start()

func die():
	print_debug("ded")
	# The "var _unused" is needed to remove a warning about the return value being unused
	var _unused = get_tree().reload_current_scene()

func collect_star_piece(star_piece):
	# Increment star piece counter
	star_piece_count += 1
	print("Star piece count: ", star_piece_count)
	# Play sound
	$CollectStarPieceSoundPlayer.play(0)
	# Delete star piece
	star_piece.queue_free()

func _on_PlayerTongue_tongue_swing(global_tongue_position):
	swing_pivot_position = global_tongue_position
	start_swing()
	pass # Replace with function body.

# Keep this for now as a reminder the signal exists
func _on_InvulnerableTimer_timeout():
	pass
