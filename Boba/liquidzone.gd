# liquid_zone.gd (attach to the Area2D)
extends Area2D

func _ready():
	print("Liquid zone working")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("Liquid entered by: ", body.name, " | in group: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		body.enter_liquid()

func _on_body_exited(body):
	if body.is_in_group("player"):
		body.exit_liquid()
