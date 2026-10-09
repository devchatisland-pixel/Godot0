class_name MeshKit
extends RefCounted
## Tiny helper to build flat-shaded, vertex-coloured meshes in the Kenney style
## (boxes, cylinders, prisms). Used for buildings the kits do not provide.

var _st := SurfaceTool.new()

static var _material: StandardMaterial3D


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Shared material: vertex colours, no texture, works on every renderer.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.9
	return _material


func commit() -> ArrayMesh:
	_st.set_material(material())
	return _st.commit()


# --- Primitives ---------------------------------------------------------------------
## Axis aligned box from its min corner. `top` colours the roof face if given.
func box(min_c: Vector3, size: Vector3, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var c := min_c + size * 0.5
	var h := size * 0.5
	var roof := top if top.a > 0.0 else color
	_face(c + Vector3(0, h.y, 0), Vector3.UP, Vector3(h.x, 0, 0), Vector3(0, 0, -h.z), roof)
	_face(c + Vector3(0, 0, h.z), Vector3.BACK, Vector3(h.x, 0, 0), Vector3(0, h.y, 0), color)
	_face(c - Vector3(0, 0, h.z), Vector3.FORWARD, Vector3(-h.x, 0, 0), Vector3(0, h.y, 0), color)
	_face(c + Vector3(h.x, 0, 0), Vector3.RIGHT, Vector3(0, 0, -h.z), Vector3(0, h.y, 0), color)
	_face(c - Vector3(h.x, 0, 0), Vector3.LEFT, Vector3(0, 0, h.z), Vector3(0, h.y, 0), color)


## Box centred on x/z with its base at y.
func block(center: Vector3, size: Vector3, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	box(center - Vector3(size.x * 0.5, 0, size.z * 0.5), size, color, top)


## Vertical cylinder (or cone when r_top != r_bottom) with a flat cap.
func cylinder(base: Vector3, r_bottom: float, r_top: float, height: float,
		segments: int, color: Color, cap: Color = Color(0, 0, 0, 0)) -> void:
	var cap_c := cap if cap.a > 0.0 else color
	var top := base + Vector3(0, height, 0)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		_quad(base + d0 * r_bottom, base + d1 * r_bottom, top + d1 * r_top, top + d0 * r_top, n, color)
		if r_top > 0.0:
			_tri(top, top + d0 * r_top, top + d1 * r_top, Vector3.UP, cap_c)


## Ring band of stands: from an inner low ellipse up to an outer high ellipse.
func elliptic_ring(center: Vector3, inner: Vector2, outer: Vector2, low: float, high: float,
		segments: int, colors: Array[Color], wall: Color) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var i0 := center + Vector3(cos(a0) * inner.x, low, sin(a0) * inner.y)
		var i1 := center + Vector3(cos(a1) * inner.x, low, sin(a1) * inner.y)
		var o0 := center + Vector3(cos(a0) * outer.x, high, sin(a0) * outer.y)
		var o1 := center + Vector3(cos(a1) * outer.x, high, sin(a1) * outer.y)
		var slope_n := (o0 - i0).cross(i1 - i0).normalized()
		if slope_n.y < 0.0:
			slope_n = -slope_n
		_quad(i0, i1, o1, o0, slope_n, colors[i % colors.size()])
		var g0 := Vector3(o0.x, center.y, o0.z)
		var g1 := Vector3(o1.x, center.y, o1.z)
		var out_n := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		_quad(g0, g1, o1, o0, out_n, wall)


## Flat ellipse lying at height y (fields, water, helipads).
func disc(center: Vector3, radius: Vector2, segments: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		_tri(center, center + Vector3(cos(a0) * radius.x, 0, sin(a0) * radius.y),
				center + Vector3(cos(a1) * radius.x, 0, sin(a1) * radius.y), Vector3.UP, color)


## Triangular roof (gable) along X, base at `min_c.y`.
func gable(min_c: Vector3, size: Vector3, color: Color, gable_color: Color) -> void:
	var x0 := min_c.x
	var x1 := min_c.x + size.x
	var y0 := min_c.y
	var y1 := min_c.y + size.y
	var z0 := min_c.z
	var z1 := min_c.z + size.z
	var zm := (z0 + z1) * 0.5
	var n_front := Vector3(0, size.z * 0.5, size.y).normalized()
	var n_back := Vector3(0, size.z * 0.5, -size.y).normalized()
	_quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, zm), Vector3(x0, y1, zm), n_front, color)
	_quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, zm), Vector3(x1, y1, zm), n_back, color)
	_tri(Vector3(x1, y0, z0), Vector3(x1, y1, zm), Vector3(x1, y0, z1), Vector3.RIGHT, gable_color)
	_tri(Vector3(x0, y0, z1), Vector3(x0, y1, zm), Vector3(x0, y0, z0), Vector3.LEFT, gable_color)


## Rows of dark windows on the four facades of a box (thin boxes 0.01 out).
func windows(min_c: Vector3, size: Vector3, floors: int, per_side: int, color: Color,
		from_floor: int = 0) -> void:
	var fh := size.y / floors
	var depth := 0.012
	for f in range(from_floor, floors):
		var y := min_c.y + fh * f + fh * 0.3
		var wh := fh * 0.45
		for k in per_side:
			var tx := (k + 0.5) / per_side
			var wx := size.x / per_side * 0.6
			var wz := size.z / per_side * 0.6
			var px := min_c.x + size.x * tx
			var pz := min_c.z + size.z * tx
			box(Vector3(px - wx * 0.5, y, min_c.z + size.z), Vector3(wx, wh, depth), color)
			box(Vector3(px - wx * 0.5, y, min_c.z - depth), Vector3(wx, wh, depth), color)
			box(Vector3(min_c.x + size.x, y, pz - wz * 0.5), Vector3(depth, wh, wz), color)
			box(Vector3(min_c.x - depth, y, pz - wz * 0.5), Vector3(depth, wh, wz), color)


# --- Low level -------------------------------------------------------------------------
## Face centred at `c` spanning +-u and +-v, facing `n`.
func _face(c: Vector3, n: Vector3, u: Vector3, v: Vector3, color: Color) -> void:
	_quad(c - u - v, c + u - v, c + u + v, c - u + v, n, color)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	_tri(a, b, c, n, color)
	_tri(a, c, d, n, color)


## Emits a triangle so that its front side looks along `n` (Godot: clockwise = front).
func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	_st.set_color(color)
	_st.set_normal(n)
	if (b - a).cross(c - a).dot(n) > 0.0:
		_st.add_vertex(a)
		_st.add_vertex(c)
		_st.add_vertex(b)
	else:
		_st.add_vertex(a)
		_st.add_vertex(b)
		_st.add_vertex(c)
