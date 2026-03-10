## State.gd
## Base class for all FSM states. Override enter/update/physics_update/exit.
## `owner` is set by StateMachine to the enemy node.
extends Node
class_name State

# Reference to the enemy that owns this state machine
var enemy: CharacterBody2D = null

## Called when the state becomes active.
func enter() -> void:
	pass

## Called every _process frame while active. Return state name to transition.
func update(_delta: float) -> String:
	return ""

## Called every _physics_process frame while active.
func physics_update(_delta: float) -> void:
	pass

## Called when leaving this state.
func exit() -> void:
	pass
