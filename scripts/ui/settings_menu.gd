class_name SettingsMenu
extends CanvasLayer

signal performance_mode_changed(mode: String)

@onready var panel: Panel = $Panel
@onready var mode_label: Label = $Panel/Mode
@onready var battery_button: Button = $Panel/Battery30
@onready var smooth_button: Button = $Panel/Smooth60
@onready var close_button: Button = $Panel/Close

var current_mode := "smooth60"

func _ready() -> void:
	panel.visible = false
	battery_button.pressed.connect(func(): _choose("battery30"))
	smooth_button.pressed.connect(func(): _choose("smooth60"))
	close_button.pressed.connect(close)
	_refresh()

func open(mode: String) -> void:
	current_mode = mode
	_refresh()
	panel.visible = true

func close() -> void:
	panel.visible = false

func _choose(mode: String) -> void:
	current_mode = mode
	_refresh()
	performance_mode_changed.emit(mode)

func _refresh() -> void:
	mode_label.text = "PERFORMANCE: 30 FPS / BATTERY" if current_mode == "battery30" else "PERFORMANCE: 60 FPS / SMOOTH"
	battery_button.disabled = current_mode == "battery30"
	smooth_button.disabled = current_mode == "smooth60"
