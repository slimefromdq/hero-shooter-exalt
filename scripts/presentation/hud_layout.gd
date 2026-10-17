class_name HUDLayout
extends RefCounted
## Fit the authored HUD uniformly into any viewport, with its aim point at screen centre.
static func fit(view_size: Vector2, reference: Vector2) -> Transform2D:
	var factor: float = minf(view_size.x / reference.x, view_size.y / reference.y)
	return Transform2D(0, Vector2.ONE * factor, 0, (view_size - reference * factor) * .5)
