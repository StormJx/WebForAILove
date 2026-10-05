class_name MapMath
extends RefCounted

## Gameplay coordinates live in the World node's local space.
## World may be scaled to fit the safe area; do not use global_position for range checks.

static func of(node: Node2D) -> Vector2:
	var parent := node.get_parent() as Node2D
	if parent == null or parent.name == "World":
		return node.position
	return parent.position + node.position
