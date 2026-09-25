class_name IPhoneUILayout
extends Node

const COMBAT_WIDTH:=536.0
const ROOM5_WIDTH:=700.0
const TOAST_SIZE:=Vector2(1040,90)
const FALLBACK_TOUCH:=80.0

@onready var combat_panel:Control=get_parent().get_node("CombatHUD/Panel")
@onready var combat_a1:Button=get_parent().get_node("CombatHUD/Panel/A1")
@onready var combat_a2:Button=get_parent().get_node("CombatHUD/Panel/A2")
@onready var combat_player_meter:ProgressBar=get_parent().get_node_or_null("CombatHUD/Panel/PlayerTurnMeter") as ProgressBar
@onready var combat_enemy_meter:ProgressBar=get_parent().get_node_or_null("CombatHUD/Panel/EnemyTurnMeter") as ProgressBar
@onready var settings_button:Button=get_parent().get_node("CombatHUD/SettingsButton")
@onready var room5_panel:Control=get_parent().get_node("MultiTargetHUD/Panel")
@onready var room5_target_a:Button=get_parent().get_node("MultiTargetHUD/Panel/TargetA")
@onready var room5_target_b:Button=get_parent().get_node("MultiTargetHUD/Panel/TargetB")
@onready var room5_shadow_meter:ProgressBar=get_parent().get_node_or_null("MultiTargetHUD/Panel/ShadowTurnMeter") as ProgressBar
@onready var room5_target_a_meter:ProgressBar=get_parent().get_node_or_null("MultiTargetHUD/Panel/TargetATurnMeter") as ProgressBar
@onready var room5_target_b_meter:ProgressBar=get_parent().get_node_or_null("MultiTargetHUD/Panel/TargetBTurnMeter") as ProgressBar
@onready var room5_a1:Button=get_parent().get_node("MultiTargetHUD/Panel/A1")
@onready var room5_a2:Button=get_parent().get_node("MultiTargetHUD/Panel/A2")
@onready var toast_panel:Control=get_parent().get_node("StoryToast/Panel")
@onready var settings_panel:Control=get_parent().get_node("SettingsMenu/Panel")
@onready var settings_battery:Button=get_parent().get_node("SettingsMenu/Panel/Battery30")
@onready var settings_smooth:Button=get_parent().get_node("SettingsMenu/Panel/Smooth60")
@onready var settings_reduced:Button=get_parent().get_node("SettingsMenu/Panel/ReducedMotion")
@onready var settings_info:Label=get_parent().get_node("SettingsMenu/Panel/Info")
@onready var settings_close:Button=get_parent().get_node("SettingsMenu/Panel/Close")

func _ready()->void:
	get_viewport().size_changed.connect(apply_safe_area)
	call_deferred("apply_safe_area")

func apply_safe_area()->void:
	var m:=MobileSafeArea.current(get_viewport())
	var touch:=MobileSafeArea.minimum_touch_target(get_viewport(),44.0,FALLBACK_TOUCH)

	combat_a1.size.y=touch
	combat_a2.size.y=touch
	combat_a1.custom_minimum_size.y=touch
	combat_a2.custom_minimum_size.y=touch
	var combat_action_y:=125.0
	combat_a1.position.y=combat_action_y
	combat_a2.position.y=combat_action_y
	if combat_player_meter:
		combat_player_meter.position.y=68.0
	if combat_enemy_meter:
		combat_enemy_meter.position.y=68.0
	var combat_height:=combat_action_y+touch+26.0
	combat_panel.offset_right=-m.z
	combat_panel.offset_left=combat_panel.offset_right-COMBAT_WIDTH
	combat_panel.offset_bottom=-m.w
	combat_panel.offset_top=combat_panel.offset_bottom-combat_height

	settings_button.custom_minimum_size.y=touch
	settings_button.offset_right=-m.z
	settings_button.offset_left=settings_button.offset_right-196.0
	settings_button.offset_top=m.y
	settings_button.offset_bottom=settings_button.offset_top+touch

	room5_target_a.size.y=touch
	room5_target_b.size.y=touch
	room5_target_a.custom_minimum_size.y=touch
	room5_target_b.custom_minimum_size.y=touch
	var meter_y:=48.0+touch+5.0
	if room5_shadow_meter:
		room5_shadow_meter.position.y=meter_y
	if room5_target_a_meter:
		room5_target_a_meter.position.y=meter_y+14.0
	if room5_target_b_meter:
		room5_target_b_meter.position.y=meter_y+14.0
	var action_y:=meter_y+32.0
	room5_a1.position.y=action_y
	room5_a2.position.y=action_y
	room5_a1.size.y=touch
	room5_a2.size.y=touch
	room5_a1.custom_minimum_size.y=touch
	room5_a2.custom_minimum_size.y=touch
	var room5_height:=action_y+touch+26.0
	room5_panel.offset_left=-ROOM5_WIDTH*0.5
	room5_panel.offset_right=ROOM5_WIDTH*0.5
	room5_panel.offset_bottom=-m.w
	room5_panel.offset_top=room5_panel.offset_bottom-room5_height

	var settings_row_y:=150.0
	settings_battery.position.y=settings_row_y
	settings_smooth.position.y=settings_row_y
	settings_battery.size.y=touch
	settings_smooth.size.y=touch
	settings_battery.custom_minimum_size.y=touch
	settings_smooth.custom_minimum_size.y=touch

	var reduced_y:=settings_row_y+touch+20.0
	settings_reduced.position.y=reduced_y
	settings_reduced.size.y=touch
	settings_reduced.custom_minimum_size.y=touch

	var info_y:=reduced_y+touch+16.0
	settings_info.position=Vector2(40,info_y)
	settings_info.size=Vector2(600,78)

	var close_y:=info_y+90.0
	settings_close.position.y=close_y
	settings_close.size.y=touch
	settings_close.custom_minimum_size.y=touch
	var settings_height:=close_y+touch+30.0
	settings_panel.offset_top=-settings_height*0.5
	settings_panel.offset_bottom=settings_height*0.5

	toast_panel.offset_left=-TOAST_SIZE.x*0.5
	toast_panel.offset_right=TOAST_SIZE.x*0.5
	toast_panel.offset_bottom=-(m.w+20.0)
	toast_panel.offset_top=toast_panel.offset_bottom-TOAST_SIZE.y
