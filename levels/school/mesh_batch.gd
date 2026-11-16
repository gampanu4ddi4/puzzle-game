## 상자 수천 개를 재질별 메시 하나로 합친다 (그리기 호출을 줄인다). 재질은 월드 좌표 삼면 투영이라 UV가 필요 없다.
class_name MeshBatch
extends RefCounted

const CHUNK := 16.0       # 이 크기 구역마다 메시를 따로 만든다 (화면 밖 구역은 그리지 않게)

var _tools := {}          # 구역 → {Material → SurfaceTool}
var _counts := {}


func add_box(mat: Material, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	if size.x <= 0.0001 or size.y <= 0.0001 or size.z <= 0.0001:
		return
	var ck := Vector2i(int(floor(center.x / CHUNK)), int(floor(center.z / CHUNK)))
	if not _tools.has(ck):
		_tools[ck] = {}
	var per: Dictionary = _tools[ck]
	if not per.has(mat):
		var nst := SurfaceTool.new()
		nst.begin(Mesh.PRIMITIVE_TRIANGLES)
		per[mat] = nst
	if not _counts.has(mat):
		_counts[mat] = 0
	var st: SurfaceTool = per[mat]
	var h := size / 2.0
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var up: Vector3 = f[1]
		var right: Vector3 = up.cross(n)   # 앞에서 봤을 때 오른쪽 → 시계 방향 = Godot의 앞면
		var c := n * h
		var u := up * h
		var r := right * h
		var p0 := center + basis * (c - u - r)
		var p1 := center + basis * (c - u + r)
		var p2 := center + basis * (c + u + r)
		var p3 := center + basis * (c + u - r)
		var nn := (basis * n).normalized()
		for p in [p0, p2, p1, p0, p3, p2]:
			st.set_normal(nn)
			st.add_vertex(p)
	_counts[mat] += 1


func box_count() -> int:
	var t := 0
	for k in _counts:
		t += _counts[k]
	return t


## 구역마다 메시 하나 (재질마다 표면 하나).
func commit(parent: Node3D, node_name: String, cast_shadows := true) -> void:
	for ck in _tools:
		var per: Dictionary = _tools[ck]
		var mesh := ArrayMesh.new()
		for mat in per:
			var st: SurfaceTool = per[mat]
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d_%d" % [node_name, ck.x, ck.y]
		mi.mesh = mesh
		if not cast_shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
