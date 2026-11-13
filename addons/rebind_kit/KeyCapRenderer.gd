## KeyCapRenderer: the drawing of any key, with no file per letter. A frame per shape (the keyboard keycap, the
## gamepad dodecagon) with the name inside, taken from the font's outlines (TextServer) and written as a path in a white
## SVG: the color is up to whoever uses it. A special drawing in the files folder (Tab, Enter, mouse, sticks, d-pad...)
## wins over the generated one. Drawings are cached.
class_name KeyCapRenderer
extends RefCounted

const SHAPE_KEY := &"key"
const SHAPE_BUTTON := &"button"
## SVG measures, the same as the hand-made special drawings.
const H := 24.0
const TEXT := 11.0
const OUTER := 1.5
const INNER := 1.0
## The font is read at this size and scaled: the outlines stay precise.
const SAMPLE := 64
## Where generated drawings live in the resource cache: whoever wants them by path (a rich text [img]) finds them there
## as long as the renderer lives.
const GENERATED_DIR := "res://__rebind_kit_keycaps__/"

var _font: Font
var _specials_dir: String
var _cache: Dictionary = {}

func _init(font: Font, specials_dir: String) -> void:
	_font = font
	_specials_dir = specials_dir

## The file name of `id`: lowercase ASCII letters and digits, everything else in hex.
static func slug(id: String) -> String:
	var out := ""
	for i in id.length():
		var c := id.unicode_at(i)
		var ascii_alnum := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
		out += id[i].to_lower() if ascii_alnum else "u%04x" % c
	return out

## The drawing of `id` (the same id as the special files, e.g. "key:J"), with `label` written inside a `shape`.
## `scale` rasterizes it larger (sharp, not upscaled afterwards): those at scale 1 also get a path (path_of).
func texture(id: String, label: String, shape: StringName, scale: float = 1.0) -> Texture2D:
	var cache_key := "%s@%.2f" % [id, scale]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var special := _special_path(id)
	var tex: Texture2D = null
	if ResourceLoader.exists(special) and is_equal_approx(scale, 1.0):
		tex = load(special)
	else:
		var source := FileAccess.get_file_as_string(special) if ResourceLoader.exists(special) else svg(label, shape)
		var image := Image.new()
		image.load_svg_from_string(source, scale)
		tex = ImageTexture.create_from_image(image)
		if is_equal_approx(scale, 1.0):
			tex.take_over_path(GENERATED_DIR + slug(id) + ".svg")
	_cache[cache_key] = tex
	return tex

## The path of `id`'s drawing: the special file, or the cached one of a drawing already made with texture().
func path_of(id: String) -> String:
	var special := _special_path(id)
	return special if ResourceLoader.exists(special) else GENERATED_DIR + slug(id) + ".svg"

func _special_path(id: String) -> String:
	return _specials_dir.path_join(slug(id) + ".svg")

## Letters on keys are always uppercase, whatever name comes in.
func svg(label: String, shape: StringName) -> String:
	var shown := label.to_upper()
	var body := _button(shown) if shape == SHAPE_BUTTON else _key(shown)
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%.2f" height="%.2f" viewBox="0 0 %.2f %.2f">%s</svg>'
		% [body[0], H, body[0], H, body[1]])

## Keycap: the rim and the raised face, with the name centered on the face.
func _key(label: String) -> Array:
	var w := maxf(H, _text_width(label, TEXT) + 12.0)
	var face := Rect2(3.5, 2.0, w - 7.0, H - 8.5)
	var lips := "M%.2f,%.2f L%.2f,%.2f M%.2f,%.2f L%.2f,%.2f" % [1.2, H - 2, face.position.x, face.end.y,
		w - 1.2, H - 2, w - face.position.x, face.end.y]
	var body := (_stroke(_rounded_rect(Rect2(OUTER / 2, OUTER / 2, w - OUTER, H - OUTER), 4.0), OUTER)
		+ _stroke(_rounded_rect(face, 2.5), INNER) + _stroke(lips, INNER)
		+ _text(label, TEXT, Vector2(w / 2, face.get_center().y)))
	return [w, body]

## Gamepad button: a dodecagon (stretched for long names), with the raised face and the name on top.
func _button(label: String) -> Array:
	var size := TEXT if label.length() < 3 else TEXT * 0.85
	var w := maxf(H, _text_width(label, size) + (12.0 if label.length() < 3 else 22.0))
	var radius := Vector2(w / 2 - OUTER / 2, H / 2 - OUTER / 2)
	var outer := _polygon(Vector2(w / 2, H / 2), radius)
	var inner := _polygon(Vector2(w / 2, H / 2 - 2), radius - Vector2(3.5, 4))
	return [w, _stroke(outer, OUTER) + _stroke(inner, INNER) + _text(label, size, Vector2(w / 2, H / 2 - 2))]

func _polygon(center: Vector2, radius: Vector2) -> String:
	var points: Array[String] = []
	for i in 12:
		var angle := PI / 12 + TAU * i / 12
		points.append("%.2f,%.2f" % [center.x + radius.x * cos(angle), center.y + radius.y * sin(angle)])
	return "M" + " L".join(points) + " Z"

func _rounded_rect(r: Rect2, c: float) -> String:
	var x := r.position.x
	var y := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return ("M%.2f,%.2f H%.2f Q%.2f,%.2f %.2f,%.2f V%.2f Q%.2f,%.2f %.2f,%.2f H%.2f Q%.2f,%.2f %.2f,%.2f V%.2f Q%.2f,%.2f %.2f,%.2f Z"
		% [x + c, y, x1 - c, x1, y, x1, y + c, y1 - c, x1, y1, x1 - c, y1, x + c, x, y1, x, y1 - c, y + c, x, y, x + c, y])

func _stroke(d: String, width: float) -> String:
	return '<path d="%s" fill="none" stroke="#fff" stroke-width="%.2f" stroke-linejoin="round"/>' % [d, width]

## The name as a filled path, centered on `center` (from the real outlines, not the text line).
func _text(label: String, size: float, center: Vector2) -> String:
	var outline := _outline(label)
	if outline["d"].is_empty():
		return ""
	var bounds: Rect2 = outline["bounds"]
	var scale := size / SAMPLE
	var offset := center - bounds.get_center() * scale
	return '<path transform="translate(%.2f %.2f) scale(%.4f)" d="%s" fill="#fff"/>' % [offset.x, offset.y, scale, outline["d"]]

func _text_width(label: String, size: float) -> float:
	var outline := _outline(label)
	return (outline["bounds"] as Rect2).size.x * size / SAMPLE

## The outlines of `label` at SAMPLE size: the SVG path and the rectangle around it.
func _outline(label: String) -> Dictionary:
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = _font.get_rids()[0]
	var d := ""
	var bounds := Rect2()
	var first := true
	var pen_x := 0.0
	for i in label.length():
		var glyph := ts.font_get_glyph_index(rid, SAMPLE, label.unicode_at(i), 0)
		var contours := ts.font_get_glyph_contours(rid, SAMPLE, glyph)
		if not contours.is_empty():
			var points: PackedVector3Array = contours["points"]
			var ends: PackedInt32Array = contours["contours"]
			var start := 0
			for end in ends:
				d += _contour(points, start, end, pen_x)
				start = end + 1
			for p in points:
				var at := Vector2(p.x + pen_x, p.y)
				bounds = Rect2(at, Vector2.ZERO) if first else bounds.expand(at)
				first = false
		pen_x += ts.font_get_glyph_advance(rid, SAMPLE, glyph).x
	return {"d": d, "bounds": bounds}

## A TrueType contour as SVG: off-curve points belong to a quadratic, and between two consecutive ones there's an
## implied on-curve point halfway.
func _contour(points: PackedVector3Array, start: int, end: int, dx: float) -> String:
	var count := end - start + 1
	if count < 2:
		return ""
	var at := func(i: int) -> Vector3: return points[start + posmod(i, count)]
	var on := func(p: Vector3) -> bool: return int(p.z) == TextServer.CONTOUR_CURVE_TAG_ON
	var first := 0
	while first < count and not on.call(at.call(first)):
		first += 1
	var origin: Vector2
	if first == count:
		var a: Vector3 = at.call(0)
		var b: Vector3 = at.call(1)
		origin = Vector2((a.x + b.x) / 2, (a.y + b.y) / 2)
		first = 0
	else:
		var p0: Vector3 = at.call(first)
		origin = Vector2(p0.x, p0.y)
		first += 1
	var out := "M%.1f,%.1f" % [origin.x + dx, origin.y]
	var control: Variant = null
	for k in count:
		var p: Vector3 = at.call(first + k)
		var here := Vector2(p.x, p.y)
		if on.call(p):
			out += (" L%.1f,%.1f" % [here.x + dx, here.y] if control == null
				else " Q%.1f,%.1f %.1f,%.1f" % [(control as Vector2).x + dx, (control as Vector2).y, here.x + dx, here.y])
			control = null
		else:
			if control != null:
				var mid := ((control as Vector2) + here) / 2
				out += " Q%.1f,%.1f %.1f,%.1f" % [(control as Vector2).x + dx, (control as Vector2).y, mid.x + dx, mid.y]
			control = here
	if control != null:
		out += " Q%.1f,%.1f %.1f,%.1f" % [(control as Vector2).x + dx, (control as Vector2).y, origin.x + dx, origin.y]
	return out + " Z"
