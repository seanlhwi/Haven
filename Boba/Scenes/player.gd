extends CharacterBody2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Horizontal Movement ---
const SPEED     = 130
const ACCEL     = 1300   # ground: how fast you speed up
const FRIC      = 1600   # ground: how fast you slow down
const AIR_ACCEL = 900    # weaker steering during airtime (lower than ground acceleration)
const AIR_FRIC  = 350    # how quickly you slow down (lower number retains more velocity)

# --- Jumping ---
const JUMP_VELOCITIES = [-260.0, -310.0, -360.0] # jumps 1, 2, 3
const COMBO_TIMER = 0.10 # time for combo jump after hittin floor

var jump_stage := 0   # counts jump stage
var combo_timer := 0.0

# --- adds acceleration and smooth stop ---
func _handle_horizontal(delta):
	if wall_jump_lock > 0.0 or is_dashing:
		return # stops code if after wall jump
		
	var direction := Input.get_axis("move_left", "move_right") # -1 if left, 0 if still, +1 if right
	if direction != 0.0: # if direction key if pressed
		var accel := ACCEL if is_on_floor() else AIR_ACCEL # picks ground or air ACCEL constant
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta) # (current, target, how much you can change)
	else:
		var fric := FRIC if is_on_floor() else AIR_FRIC
		velocity.x = move_toward(velocity.x, 0.0, fric * delta) # (current, speed to 0.0, groudn or air friction)
		

# --- Coyote Time/ Jump Buffer/ Variable Jump Height/ Combo Timer ---
const COYOTE_TIME = 0.10 # jumping after ledge
const JUMP_BUFFER = 0.10 # press jump before landing
const JUMP_CUT = 0.45 # fraction of the rising speed kept on an early release

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

func _handle_jump(delta):
	# --- Coyote timer + combo timer ---
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		combo_timer = max(combo_timer - delta, 0.0) # only counts down while on the ground
		if combo_timer == 0.0:
			jump_stage = 0 # waited too long, chain resets
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
	
	# --- Jump Buffer Timer ---
	if Input.is_action_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER # if action just pressed make jump buffer timer 0.10
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0) # start buffer timer if button pressed in past frame, otherwise make timer = 0.0
		
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITIES[jump_stage]            # pick this jump's speed
		#jump_stage = (jump_stage + 1) % JUMP_VELOCITIES.size() # move to the next jump, wrap after the last
		jump_stage = min(jump_stage + 1, JUMP_VELOCITIES.size() - 1) # advance, but stay on the last (highest) jump
		combo_timer = COMBO_TIMER                         # restart the window
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		
 	# --- Variable Jump Height ---
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and not is_clinging:
		velocity.y *= JUMP_CUT # after one frame after press, when rising up (positive velocty), cut upward speed to 45%
		

# --- Assymetric Gravity, Hangtime ---
const RISE_GRAV_MULT    = 0.9   # floaty rise
const FALL_GRAV_MULT    = 1.5   # snappy fall
const APEX_SPEED_THRES  = 45.0  # between -45 and +45 speed is considered as the "apex"
const APEX_GRAV_MULT    = 0.55  # less gravity at peak for hangtime
const MAX_FALL_SPEED    = 400.0 # max speed when falling for control

var base_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") # brings default gravity number to scale with const, float is decimal number

func _apply_gravity(delta):
	if is_clinging or is_dashing:
		return
	if not is_on_floor():
		var mult := RISE_GRAV_MULT if velocity.y < 0.0 else FALL_GRAV_MULT # when not on floor, multiply rise and fall gravity based on + or - velocity
		if absf(velocity.y) < APEX_SPEED_THRES: # "absf" is absolute value
			mult *= APEX_GRAV_MULT # when at apex, multiply time by apex_grav_mult
		velocity.y += base_gravity * mult * delta # takes base, multiply it by chosen scale, and adds it to downward velocity
		velocity.y = min(velocity.y, MAX_FALL_SPEED) # picks smaller number, caps speed to max_fall_speed

# --- Wall Jump/ Cling ---
const WALL_JUMP_PUSH: float = 100.0
const WALL_CLIMB_SPEED = 130.0   # max speed up/down the wall
const WALL_CLIMB_ACCEL = 3000.0  # wall accel
const WALL_CLIMB_FRIC  = 3300.0  # wall friction
const WALL_SLIDE_SPEED = 30.0    # slow slide downwards
const WALL_GLIDE_SPEED = -300    # main glide speed

var wall_contact_coyote: float = 0.0 # set coyote time to 0
const WALL_CONT_COYOTE_TIME: float = 0.2 # set coyote time to 0.2
 
var wall_jump_lock: float = 0.0 # set jump lock timer to 0
const WALL_JUMP_LOCK_TIME = 0.05 # set jump lock timer to 0.05

var look_dir_x: int = 1 #wall to left is -1, wall to right is +1, and default setting is +1
var is_clinging := false # starts with character not clinging to wall

func _update_cling() -> void: # returns to nothing
	var toward := Input.get_axis("move_left", "move_right") # what direction the player presses, left=-1, right=+1, neurtral=0
	var wall_dir := -signf(get_wall_normal().x) if is_on_wall() else 0.0 # player direction on wall is -normal, signf simnplifies to 1, -1, 0, if not on wall, 0
	is_clinging = ( # condition of wall cling
		not is_on_floor()
		and is_on_wall()
		and wall_jump_lock <= 0.0 # short lockout is positive
		and toward != 0.0 # a direction key is pressed
		and toward == wall_dir # button pressed matches wall directino
	)

func _wall_jump(delta: float) -> void:
	if is_clinging:
		look_dir_x = int(-signf(get_wall_normal().x))  # direction of the wall
		wall_contact_coyote = WALL_CONT_COYOTE_TIME
		
		var v_input := Input.get_axis("move_up", "move_down")  # up is negative
		var target_y := v_input * WALL_CLIMB_SPEED if v_input != 0.0 else WALL_SLIDE_SPEED
		var rate := WALL_CLIMB_ACCEL if v_input != 0.0 else WALL_CLIMB_FRIC
		velocity.y = move_toward(velocity.y, target_y, rate * delta)
		
		velocity.x = look_dir_x * 20.0  # small push keeps is_on_wall true
	else:
		wall_contact_coyote = max(wall_contact_coyote - delta, 0.0)
	
	if wall_jump_lock > 0.0:
		wall_jump_lock = max(wall_jump_lock - delta, 0.0)
	
	if not is_on_floor() and wall_contact_coyote > 0.0 and Input.is_action_just_pressed("jump"):
		velocity.y = WALL_GLIDE_SPEED
		velocity.x = -look_dir_x * WALL_JUMP_PUSH
		wall_jump_lock = WALL_JUMP_LOCK_TIME
		wall_contact_coyote = 0.0
		
# --- Dash ---
const DASH_SPEED: float = 600.0
const DASH_TIME: float = 0.15
var can_dash: bool = true
var dash_timer: float = 0.0
var is_dashing: bool = false
var facing_x: int = 1

func _dash_check(delta: float) -> void:
	var x_input: float = Input.get_axis("move_left", "move_right")
	if x_input != 0.0:
		facing_x = int(x_input)
	
	if is_on_floor() and dash_timer == 0.0:
		can_dash = true

# --- dash logic ---
func _dash_logic(delta: float) -> void:
	if can_dash and Input.is_action_just_pressed("dash"):
		can_dash = false
		dash_timer = DASH_TIME
		velocity.x = DASH_SPEED * facing_x
		velocity.y = 0.0
	
	if dash_timer > 0.0:
		dash_timer = max(0.0, dash_timer - delta)
		if is_on_wall():
			dash_timer = 0.0
		if dash_timer == 0.0:
			velocity.x = facing_x * SPEED  # leave the dash at normal speed
	
	is_dashing = dash_timer > 0.0
			
# --- animations ---
enum Phase { NONE, ON, HOLD, OFF }
var phase := Phase.NONE
var current_move := ""   # remembers past move, and "" if none

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished) # plays animation once, and sends to next function, _ready plays once

func _desired_move() -> String:
	if is_clinging:
		return "left_wall" if look_dir_x < 0 else "right_wall"
	if is_dashing:
		return "dash_left" if facing_x < 0 else "dash_right"
	return "" # finds current desired move

func _handle_anim() -> void:
	var desired := _desired_move()
	
	if desired != "" and (desired != current_move or phase == Phase.OFF):
		current_move = desired
		if animated_sprite.sprite_frames.has_animation(current_move):
			phase = Phase.ON
			animated_sprite.play(current_move)            # transition in
		else:
			phase = Phase.HOLD
			animated_sprite.play(current_move + "_on")    # hold
	
	elif desired == "" and current_move != "" and phase != Phase.OFF:
		var off_name := current_move + "_off"
		if animated_sprite.sprite_frames.has_animation(off_name):
			phase = Phase.OFF
			animated_sprite.play(off_name)
		else:
			phase = Phase.NONE
			current_move = ""
	
	if phase == Phase.OFF and not animated_sprite.is_playing():
		phase = Phase.NONE
		current_move = ""
	
	if phase == Phase.NONE:
		animated_sprite.play("idle")

func _on_animation_finished() -> void:
	match phase:
		Phase.ON:
			phase = Phase.HOLD
			animated_sprite.play(current_move + "_on")    # hold
		Phase.OFF:
			phase = Phase.NONE
			current_move = ""

func _physics_process(delta):
	_update_cling()
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_horizontal(delta)
	_wall_jump(delta)
	_dash_check(delta)
	_dash_logic(delta)
	_handle_anim()
	move_and_slide()
