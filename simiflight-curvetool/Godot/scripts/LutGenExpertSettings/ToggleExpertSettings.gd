extends Button
@onready var expert_settings_scroll_container: ScrollContainer = %ExpertSettingsScrollContainer

func _ready() -> void:
	self.toggled.connect(_on_expret_settings_toggled)

func _on_expret_settings_toggled(_toggled: bool) -> void:
	expert_settings_scroll_container.visible = _toggled
