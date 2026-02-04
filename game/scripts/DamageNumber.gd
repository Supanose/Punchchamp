extends Node3D
class_name DamageNumber

@onready var label: Label3D = $Label3D
@onready var timer: Timer = $Timer

var float_height: float = 2.0
var float_duration: float = 1.5
var fade_duration: float = 0.5

func _ready():
	timer.wait_time = float_duration + fade_duration
	timer.timeout.connect(_on_timer_timeout)

func show_damage(damage: int, position: Vector3, is_critical: bool = false):
	global_position = position + Vector3.UP * 0.5
	
	# Setup label
	label.text = str(damage)
	label.modulate = Color.RED if not is_critical else Color.YELLOW
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Start animation
	_float_and_fade()

func _float_and_fade():
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float upward
	tween.tween_property(self, "global_position:y", global_position.y + float_height, float_duration)
	
	# Fade out after float duration
	tween.tween_property(label, "modulate:a", 0.0, fade_duration).set_delay(float_duration)
	
	# Start timer
	timer.start()

func _on_timer_timeout():
	queue_free()
