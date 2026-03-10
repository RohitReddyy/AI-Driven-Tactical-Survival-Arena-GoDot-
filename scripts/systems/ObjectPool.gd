## ObjectPool.gd
## Generic object pool for performance. Used primarily for bullets.
## Attach as an AutoLoad or as a child node of the scene root.
extends Node

# ---------------------------------------------------------------------------
# Internal pool storage: scene_path → [Node, ...]
# ---------------------------------------------------------------------------
var _pools: Dictionary = {}
var _scene_cache: Dictionary = {}  # scene_path → PackedScene

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Pre-warm a pool with `count` instances of the scene at `scene_path`.
func preload_pool(scene_path: String, count: int, parent: Node = null) -> void:
	_ensure_pool(scene_path)
	var ps := _get_packed_scene(scene_path)
	if not ps:
		return
	var target := parent if parent else self
	for i in count:
		var inst := ps.instantiate()
		inst.set_meta("pooled", true)
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		inst.hide()
		target.add_child(inst)
		_pools[scene_path].append(inst)

## Retrieve an instance from the pool (or instantiate if exhausted).
func get_instance(scene_path: String, parent: Node = null) -> Node:
	_ensure_pool(scene_path)
	var pool: Array = _pools[scene_path]

	for inst in pool:
		if not inst.visible and inst.process_mode == Node.PROCESS_MODE_DISABLED:
			_activate(inst)
			return inst

	# Pool exhausted – create a new one and add it
	var ps := _get_packed_scene(scene_path)
	if not ps:
		return null
	var inst := ps.instantiate()
	inst.set_meta("pooled", true)
	var target := parent if parent else self
	target.add_child(inst)
	pool.append(inst)
	_activate(inst)
	return inst

## Return an instance to the pool instead of queue_free.
func return_instance(inst: Node) -> void:
	if not inst.has_meta("pooled"):
		inst.queue_free()
		return
	_deactivate(inst)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------
func _ensure_pool(scene_path: String) -> void:
	if not _pools.has(scene_path):
		_pools[scene_path] = []

func _get_packed_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		var ps: PackedScene = load(path)
		if ps:
			_scene_cache[path] = ps
		else:
			push_error("[ObjectPool] Failed to load scene: " + path)
			return null
	return _scene_cache[path] as PackedScene

func _activate(inst: Node) -> void:
	inst.show()
	inst.process_mode = Node.PROCESS_MODE_INHERIT
	if inst.has_method("on_spawned"):
		inst.on_spawned()

func _deactivate(inst: Node) -> void:
	inst.hide()
	inst.process_mode = Node.PROCESS_MODE_DISABLED
	if inst.has_method("on_returned"):
		inst.on_returned()
