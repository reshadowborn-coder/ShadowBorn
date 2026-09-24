class_name StoryToast
extends CanvasLayer

@onready var panel:Panel=$Panel
@onready var label:Label=$Panel/Text
var ticket:=0

func _ready()->void:
	panel.visible=false

func show_message(message:String,duration:float=3.4)->void:
	ticket+=1
	var current:=ticket
	label.text=message
	panel.visible=true
	await get_tree().create_timer(duration).timeout
	if current==ticket:
		panel.visible=false

func hide_message()->void:
	ticket+=1
	panel.visible=false
