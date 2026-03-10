## StateMachine.gd
## Generic finite state machine. Attach as a child of any enemy node.
## Child nodes must extend State.
extends Node
class_name StateMachine

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal state_changed(old_state: String, new_state: String)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
@export var initial_state: String = "Idle"

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
var current_state: State = null
var _states: Dictionary = {}    # name → State node
var _enemy: CharacterBody2D = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_enemy = get_parent() as CharacterBody2D

	# Collect all State children
	for child in get_children():
		if child is State:
			_states[child.name] = child
			child.enemy = _enemy

	await owner.ready  # Ensure entire tree is ready
	transition_to(initial_state)

func _process(delta: float) -> void:
	if current_state == null:
		return
	var next := current_state.update(delta)
	if next != "" and next != current_state.name:
		transition_to(next)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

# ---------------------------------------------------------------------------
# Transition
# ---------------------------------------------------------------------------
func transition_to(state_name: String) -> void:
	if not _states.has(state_name):
		push_warning("[StateMachine] Unknown state: " + state_name)
		return

	var old_name := current_state.name if current_state else ""

	if current_state:
		current_state.exit()

	current_state = _states[state_name]
	current_state.enter()
	state_changed.emit(old_name, state_name)

func get_current_state_name() -> String:
	return current_state.name if current_state else ""
