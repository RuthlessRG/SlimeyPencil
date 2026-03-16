extends CharacterBody2D

const SPEED = 75.0

func _physics_process(_delta):
    var dir = Vector2.ZERO
    if Input.is_action_pressed("move_up"):    dir.y -= 1
    if Input.is_action_pressed("move_down"):  dir.y += 1
    if Input.is_action_pressed("move_left"):  dir.x -= 1
    if Input.is_action_pressed("move_right"): dir.x += 1
    
    velocity = dir.normalized() * SPEED
    move_and_slide()
    
    var sprite = $AnimatedSprite2D
    if dir != Vector2.ZERO:
        if abs(dir.x) > abs(dir.y):
            sprite.play("run_e" if dir.x > 0 else "run_w")
        else:
            sprite.play("run_s" if dir.y > 0 else "run_n")
    else:
        sprite.play("idle_s")
