class_name FarmMeshes
extends RefCounted
## Crop fields of the countryside. Each mesh covers a 1x1 square centred on the
## origin; the building placer stretches it over its lot (x and z only), so
## the rows stay thin whatever the size of the field. Rows run along x.

const SOIL := Color("8a6a43")
const SOIL_DARK := Color("6f5233")


static func build_all(lib: ModelLibrary) -> void:
	lib.add_named("field_wheat", field(Color("c8a24e"), Color("e8c85a"), Color("f2dc7a"), 0.07, 14))
	lib.add_named("field_corn", field(SOIL, Color("3f8a3a"), Color("7fb83f"), 0.15, 11))
	lib.add_named("field_plowed", field(SOIL_DARK, Color("a07a4c"), Color("b58c58"), 0.035, 18))
	lib.add_named("field_green", field(SOIL, Color("5aa845"), Color("8fd05a"), 0.055, 16))


## Soil plate with `rows` ridges of height `h`; the top of each ridge is lighter.
static func field(soil: Color, ridge: Color, top: Color, h: float, rows: int) -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(-0.5, 0, -0.5), Vector3(1.0, 0.02, 1.0), soil)
	var pitch := 0.9 / float(rows)
	for i in rows:
		var z := -0.45 + (float(i) + 0.5) * pitch
		k.box(Vector3(-0.46, 0.02, z - pitch * 0.32), Vector3(0.92, h, pitch * 0.64), ridge, top)
	# A few darker gaps (tractor lanes) cross the field.
	k.box(Vector3(-0.5, 0.021, -0.02), Vector3(1.0, 0.004, 0.04), soil.darkened(0.15))
	return k.commit()
