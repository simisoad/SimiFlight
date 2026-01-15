class_name TabContainerExtended extends TabContainer

# Ein Flag, um zu verhindern, dass wir während eines Updates
# erneut ein Update triggern (Reentrancy Guard)
var _is_updating: bool = false

func _ready() -> void:
	custom_minimum_size.y = 40
	child_order_changed.connect(_on_tabs_changed)
	_on_tabs_changed()

func _on_tabs_changed():
	# Wenn wir schon updaten oder das Tool gerade beendet wird, nichts tun
	if _is_updating or not is_inside_tree():
		return

	# Wir schieben die eigentliche Logik auf den nächsten Frame,
	# um den Signal-Loop zu durchbrechen
	_actual_update_deferred.call_deferred()

func _actual_update_deferred():
	if not is_inside_tree() or _is_updating:
		return

	_is_updating = true # Sperre setzen

	var children = get_children()
	var real_children_count = 0
	var placeholder_node: Node = null

	# Zählen, was wirklich da ist (keine Nodes, die gerade gelöscht werden)
	for child in children:
		if child.name == " [ Drop Here ] ":
			placeholder_node = child
		elif not child.is_queued_for_deletion():
			real_children_count += 1

	if real_children_count == 0:
		if placeholder_node == null:
			#print("rüdi")
			var placeholder = Control.new()
			placeholder.name = " [ Drop Here ] "
			add_child(placeholder)
			set_tab_disabled(0, true)
	else:
		if placeholder_node != null:
			#print("schoggibärli")
			placeholder_node.queue_free()

	_is_updating = false # Sperre aufheben
