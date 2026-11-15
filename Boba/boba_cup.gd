extends Node2D

@onready var area_2d: Area2D = $Area2D
@onready var label: Label = $CanvasLayer/Label

func _ready() -> void:
	area_2d.body_entered.connect(_on_goal_zone_body_entered)

func _on_goal_zone_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		label.visible = true
