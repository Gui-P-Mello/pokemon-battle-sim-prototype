class_name Pokemon
extends CharacterBody2D

@export_category("Stats")
@export var health: int = 100
@export var stamina: float = 100
@export var posture: float = 100
@export var power: int = 20
@export var trust: float
@export var stress: float
@export var walk_speed: float = 5000
@export var run_speed: float = 10000
@export var melee_range: float = 50
@export var dodge_distance: float = 100

@export_category("Trainer")
enum trainer_command {APPROACH, RUN_IN, ATTACK, SHOOT, RUN_OUT, DISTANCE, DODGE, STOP, NONE}
@export var is_trainer_cpu: bool = true
var last_trainer_command: trainer_command = trainer_command.NONE

@export_category("Oponent")
@export var oponent: Pokemon
@onready var oponent_position: Vector2 = oponent.position

@onready var nav_agent:= $NavigationAgent2D as NavigationAgent2D
@onready var melee_area: Area2D = $MeleeArea
@onready var melee_collision_shape: CollisionShape2D = $MeleeArea/CollisionShape2D
@onready var test = get_tree().get_root().get_node("Test")
@onready var projectile = load("res://effects/projectile.tscn")

var stop: bool = true
var faint: bool = false
var is_dodging: bool = false
var oponent_distance: float
var target_position: Vector2
var has_dodge_target: bool =  false
var can_set_dodge_target: bool = true
var direction: Vector2

@onready var sprite = $Sprite2D
@export var front_texture: Texture2D
@export var right_texture: Texture2D
@export var back_texture: Texture2D
@export var left_texture: Texture2D
var melee_effect:PackedScene

func _ready():
	melee_effect = preload("res://effects/melee_effect.tscn")

func _process(delta):	
	
	pass

func _physics_process(delta):
	
	var next_path_position = nav_agent.get_next_path_position()
	direction = global_position.direction_to(next_path_position)
	update_sprite(direction)
	
	oponent_position = oponent.global_position
	make_path()
	oponent_distance = self.position.distance_to(oponent.global_position)
	
	if !is_trainer_cpu:
		set_last_trainer_command()
		if last_trainer_command == trainer_command.APPROACH:
			approach(delta)
		if last_trainer_command == trainer_command.STOP:
			last_trainer_command = trainer_command.NONE
			velocity = Vector2.ZERO
		if last_trainer_command == trainer_command.ATTACK:
			attack(delta)
		if last_trainer_command == trainer_command.SHOOT:
			shoot_projectile()
		if last_trainer_command == trainer_command.RUN_IN:
			run_in(delta)
		if last_trainer_command == trainer_command.DISTANCE:
			distance(delta)
		if last_trainer_command == trainer_command.DODGE:
			dodge(delta)
	
func make_path():
	await get_tree().physics_frame
	if target_position:
		nav_agent.target_position = target_position
	
func approach(delta:float):
	if oponent_distance >= melee_range:
		target_position = oponent_position
		move(walk_speed, delta)
	else:
		velocity =  Vector2.ZERO
		last_trainer_command = trainer_command.NONE

func run_in(delta: float):
	if oponent_distance >= melee_range:
		target_position = oponent_position
		move(run_speed, delta)
	else:
		velocity =  Vector2.ZERO
		last_trainer_command = trainer_command.NONE

func attack(delta: float):
	if oponent_distance >= melee_range:
		run_in(delta)
	else:
		var bodies = melee_area.get_overlapping_bodies()
		for body in bodies:
			if body is Pokemon && body != self:
				var target = body
				var melee_effect_instance = melee_effect.instantiate()
				
				if sprite.texture == right_texture || sprite.texture == left_texture:
					melee_effect_instance.position = position + (target.global_position - global_position).normalized()	*50	+ Vector2(0, -20)
				else:
					melee_effect_instance.position = position + (target.global_position - global_position).normalized()	*50			
				get_parent().add_child(melee_effect_instance)
				deal_damage(target)
		last_trainer_command = trainer_command.NONE
		velocity = Vector2.ZERO
		
func shoot_projectile():
	var instance:Node2D = projectile.instantiate()
	instance.dir = global_position.direction_to(oponent.position)
	var oponent_direction: Vector2 = global_position.direction_to(oponent.position).normalized()
	var instance_offset: Vector2 = oponent_direction * 50
	instance.caster = self
	instance.position = position + instance_offset
	get_parent().add_child(instance)
	last_trainer_command = trainer_command.NONE
	pass

func distance(delta: float):
	var dir = (oponent_position - position).normalized() * -1
	velocity = dir * walk_speed * delta
	move_and_slide()

func run_out():
	pass
	
func dodge(delta: float):
	var dir = (oponent_position - global_position).normalized()
	var left_dir = Vector2(dir.y, -dir.x) * dodge_distance
	var right_dir = Vector2(-dir.y, dir.x) * dodge_distance
	
	var dodge_dir = Vector2.ZERO

	if !has_dodge_target:
		# Escolhe uma direção de desvio aleatória entre esquerda e direita
		if randi() % 2 == 0:
			dodge_dir = left_dir
			print("Esquivando para a esquerda")
		else:
			dodge_dir = right_dir
			print("Esquivando para a direita")

		target_position = position + dodge_dir
		has_dodge_target = true
		can_set_dodge_target = false

	# Move-se diretamente para o `target_position` em alta velocidade (sem usar NavigationAgent)
	if global_position.distance_to(target_position) > 10:  # Verifica se ainda não chegou no destino
		var move_direction = global_position.direction_to(target_position)
		velocity = move_direction * run_speed * 3 * delta
		move_and_slide()
		is_dodging = true
	else:
		print("Chegou ao destino de esquiva")
		is_dodging = false
		has_dodge_target = false
		can_set_dodge_target = true
		last_trainer_command = trainer_command.NONE

	# Modulação de cor para indicar a esquiva
	modulate = Color.BLUE
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func behaviour():
	pass

func set_last_trainer_command():
	if Input.is_action_just_pressed("Approach"):
		last_trainer_command = trainer_command.APPROACH
	if Input.is_action_just_pressed("Stop"):
		last_trainer_command = trainer_command.STOP			
	if Input.is_action_just_pressed("Attack"):
		last_trainer_command = trainer_command.ATTACK
	if Input.is_action_just_pressed("Run_In"):
		last_trainer_command = trainer_command.RUN_IN
	if Input.is_action_just_pressed("Distance"):
		last_trainer_command = trainer_command.DISTANCE
	if Input.is_action_just_pressed("Dodge"):
		last_trainer_command = trainer_command.DODGE
	if Input.is_action_just_pressed("Shoot"):
		last_trainer_command = trainer_command.SHOOT
	
func deal_damage(oponent:Pokemon):	
	if oponent:
		print("Your pokémon is hitting its oponent!")
		oponent.take_damage(power)

func take_damage(amount: int):
	if health <= 0: return
	health -= amount
	
	modulate = Color.RED
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	print("CPU Trainer pokémon got hit! Its HP has dropped to: ", health)
	
func spend_stamina(amount: int):
	stamina -= amount
	
func move(speed: float, delta: float):
	if nav_agent.is_navigation_finished(): return
	var current_agent_position = global_position
	var next_path_position = nav_agent.get_next_path_position()
	
	velocity = current_agent_position.direction_to(next_path_position) * speed * delta
	move_and_slide()
	
func update_sprite(direction: Vector2):
	if abs(direction.x) > abs(direction.y): # Movendo mais no eixo X (esquerda ou direita)
		if direction.x > 0:
			sprite.texture = right_texture  # Direita
		else:
			sprite.texture = left_texture   # Esquerda
	else: # Movendo mais no eixo Y (frente ou costas)
		if direction.y > 0:
			sprite.texture = front_texture   # Para trás
		else:
			sprite.texture =  back_texture # Para frente