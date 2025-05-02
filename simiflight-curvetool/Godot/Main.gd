@tool
extends Control

func _ready():
	if Engine.is_editor_hint():
		if not has_node("VBox"):
			var vbox = VBoxContainer.new()
			vbox.name = "VBox"
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.anchor_right = 1.0
			vbox.anchor_bottom = 1.0
			vbox.margin_left = 300
			vbox.margin_top = 200
			vbox.margin_right = -300
			vbox.margin_bottom = -200
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			add_child(vbox)

			for label in ["Kurve erstellen", "Kurve laden", "Kurve speichern"]:
				var btn = Button.new()
				btn.text = label
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vbox.add_child(btn)
