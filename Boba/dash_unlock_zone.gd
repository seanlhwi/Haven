# dash_unlock_zone.gd (Area2D)
extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		GameState.unlock("dash")
		queue_free() # remove the zone so it only fires once
