## 학교 평면 데이터 (5층).
## 근거: 층별 피난안내도 (방 배치와 비율), 건축물현황도 배치도 (외곽 치수), 건축물대장 (층별 면적).
## 피난안내도는 축척이 없어서, 4층 안내도에서 본관 외곽(59.7 × 61.8 m)에 대한 비율로 줄과 복도 폭을 읽었다.
## 방 하나하나의 크기는 그 비율과 기둥 간격(8.1 m)으로 맞춘 추정이다.
##
## 좌표: x = 동쪽(+), z = 남쪽(+), 단위 m. 원점은 본관 북서쪽 바깥 모서리.
##   x:  WO 0..7.7 | 서복도 7.7..10.3 | WI 10.3..16.6 | 중정 16.6..41.8 | EI 41.8..48.6 | 동복도 48.6..52.1 | EO 52.1..59.7
##   z:  북쪽 줄 0..10.4 | 북복도 10.4..14.0 | 가운데 14.0..58.5 | 남쪽 연결복도 58.5..61.8 (3~5층만)
##   1·2층에는 남쪽 연결복도가 없어 중정이 남쪽으로 열려 있다. 1층은 북쪽 줄 가운데(x 25.6..32.4)가 바깥 통로라
##   서쪽(A동)과 동쪽(B동)이 1층에서는 따로 떨어져 있다.
##   별관 32.4 × 26.4 m: x -57.9..-25.5, z 0..26.4. 1층은 2층 바닥 아래의 바깥 주차장(기둥만),
##   2층 식당·조리실, 3층 다목적강당·음악실. 위는 옥상이지만 4층에서 들어갈 수 없다.
##   본관과 별관은 북복도 높이의 연결복도(x -25.5..0)로 잇는다.
##
## 방 종류(kind):
##   class  교실 (복도 쪽 문 둘, 책상)       room  방 (문 하나)        hall  큰 방 (문 둘, 책상 없음)
##   toilet 화장실   open  복도와 벽 없이 트인 공간 (미디어스페이스 등)   closed  문 없는 방
##   stair 계단   ev 엘리베이터   eps 설비실   corr 복도   void 위가 트인 빈 공간   court 1층 중정 바닥
##   terrace 옥외 테라스   path 지붕 아래 바깥 통로
class_name SchoolLayout
extends RefCounted

const FLOOR_H := 3.6           # 층 높이 (대장 높이 19.4 m = 3.6 × 5 + 옥상)
const CEIL_H := 3.0            # 반자 높이
const FLOORS := 5
const CLASS_LEN := 8.2         # 교실 한 칸 (기둥 간격)

const X_WO := Vector2(0.0, 8.0)
const X_WC := Vector2(8.0, 11.0)
const X_WI := Vector2(11.0, 16.6)
const X_V := Vector2(16.6, 42.4)
const X_EI := Vector2(42.4, 50.4)
const X_EC := Vector2(50.4, 53.5)
const X_EO := Vector2(53.5, 59.7)
const Z_NO := Vector2(0.0, 9.7)
const Z_NC := Vector2(9.7, 13.9)
const Z_MID := Vector2(13.9, 57.6)
const Z_SC := Vector2(57.6, 61.8)
const W := 59.7
const D := 61.8
const ANNEX := Rect2(-57.9, 0.0, 32.4, 26.4)
const ANNEX_EAST := -33.9        # 별관 동쪽 칸 (x -33.9..-25.5)
const LINK := Rect2(-25.5, 9.7, 25.5, 4.2)
const GAP_1F := Vector2(25.6, 32.4)   # 1층 북쪽 줄 가운데 바깥 통로

# 계단: rect, 긴 축, 층계참(바닥 높이) 쪽 끝, 문 방향
const STAIRS := [
	{"name": "계단 A북", "rect": Rect2(11.9, 0.0, 3.5, 9.7), "axis": "z", "near": "S", "door": "S"},
	{"name": "계단 A남", "rect": Rect2(0.0, 55.8, 8.0, 6.0), "axis": "x", "near": "E", "door": "E"},
	{"name": "계단 B북", "rect": Rect2(53.5, 9.7, 6.2, 6.0), "axis": "x", "near": "W", "door": "W"},
	{"name": "계단 B남", "rect": Rect2(53.5, 55.8, 6.2, 6.0), "axis": "x", "near": "W", "door": "W"},
]


## 층(1..5)의 방 목록. 각 방: {name, rect: Rect2(x, z, w, d), kind, door: "N"/"S"/"E"/"W"}
## 뒤에 넣은 방이 앞의 방을 덮는다.
static func rooms(floor: int) -> Array:
	var out: Array = []
	var south := floor >= 3
	# 복도 (서·동복도는 건물 남쪽 끝까지)
	out.append(_r("북복도", Rect2(0.0, Z_NC.x, W, Z_NC.y - Z_NC.x), "corr", ""))
	out.append(_r("서복도", Rect2(X_WC.x, Z_NC.y, X_WC.y - X_WC.x, D - Z_NC.y), "corr", ""))
	out.append(_r("동복도", Rect2(X_EC.x, Z_NC.y, X_EC.y - X_EC.x, D - Z_NC.y), "corr", ""))
	if south:
		out.append(_r("남쪽 연결복도", Rect2(X_WC.y, Z_SC.x, X_EC.x - X_WC.y, D - Z_SC.x), "corr", ""))
	# 중정 (1·2층은 남쪽 끝까지 트임)
	var court_end := D if not south else Z_MID.y
	out.append(_r("중정", Rect2(X_V.x, Z_MID.x, X_V.y - X_V.x, court_end - Z_MID.x), "court" if floor == 1 else "void", ""))
	if not south:
		out.append(_r("중정 남쪽", Rect2(X_WI.x, Z_MID.y, X_EI.y - X_WI.x, D - Z_MID.y), "court" if floor == 1 else "void", ""))
	# 북쪽 줄: 서쪽 칸, 계단 동쪽
	out.append_array(_stack(Rect2(0.0, 0.0, 11.9, Z_NO.y), "x", "S", _no_left(floor)))
	out.append_array(_stack(Rect2(15.4, 0.0, W - 15.4, Z_NO.y), "x", "S", _no_right(floor)))
	# 서쪽 바깥 줄 WO (북복도 아래 ~ A남 계단 위)
	out.append_array(_stack(Rect2(X_WO.x, Z_MID.x, X_WO.y, 55.8 - Z_MID.x), "z", "E", _wo(floor)))
	# 서쪽 안쪽 WI, 동쪽 안쪽 EI
	out.append_array(_stack(Rect2(X_WI.x, Z_MID.x, X_WI.y - X_WI.x, Z_MID.y - Z_MID.x), "z", "W", _wi(floor)))
	out.append_array(_stack(Rect2(X_EI.x, Z_MID.x, X_EI.y - X_EI.x, Z_MID.y - Z_MID.x), "z", "E", _ei(floor)))
	# 동쪽 바깥 줄 EO (B북 계단 아래 ~ B남 계단 위)
	out.append_array(_stack(Rect2(X_EO.x, 15.7, X_EO.y - X_EO.x, 55.8 - 15.7), "z", "W", _eo(floor)))
	if floor >= 2:
		# 동쪽 화장실: 앞 공간에서 화장실마다 작은 들머리(문 앞 칸)로 들어가 문을 연다. 들머리와 칸 줄 사이, 앞 공간과 화장실 사이는 벽.
		# 앞 공간 가운데에 음수대 칸, 그 동쪽으로 앞 공간을 둘로 나누는 벽
		out.append(_r("화장실 앞", Rect2(X_EO.x, 19.7, 2.0, 1.9), "corr", ""))
		out.append(_r("화장실 앞", Rect2(X_EO.x, 26.7, 2.0, 1.9), "corr", ""))
		out.append(_r("음수대", Rect2(X_EO.x, 23.2, 3.6, 1.9), "closed", ""))
		out.append(_r("칸막이벽", Rect2(X_EO.x + 3.6, 24.05, X_EO.y - X_EO.x - 3.6, 0.5), "closed", ""))
		out.append(_r("세척실", Rect2(X_EO.x, 30.9, 2.5, 1.6), "room", "W", 0.5))
	# 계단 (방 줄 위에 덮는다)
	for s in STAIRS:
		out.append(_r(s["name"], s["rect"], "stair", s["door"]))
	# 1층 북쪽 가운데 바깥 통로
	if floor == 1:
		out.append(_r("바깥 통로", Rect2(GAP_1F.x, 0.0, GAP_1F.y - GAP_1F.x, Z_NC.y), "path", ""))
	# 연결복도와 별관
	var west := Rect2(ANNEX.position.x, 0.0, ANNEX_EAST - ANNEX.position.x, ANNEX.size.y)
	var east_col := Rect2(ANNEX_EAST, 0.0, ANNEX.end.x - ANNEX_EAST, ANNEX.size.y)
	match floor:
		1:
			# 별관 1층은 바깥 주차장. 북쪽 끝에 수거실·창고만 있다 (주차장 쪽으로 문)
			out.append_array(_stack(Rect2(ANNEX.position.x, 0.0, ANNEX.size.x, 6.0), "x", "S", [["음식물수거실", 1.0, "room"], ["창고", 1.0, "room"], ["화장실", 1.0, "toilet"], ["재활용창고", 1.0, "room"]]))
			out.append(_r("주차장", Rect2(ANNEX.position.x, 6.0, ANNEX.size.x, ANNEX.size.y - 6.0), "path", ""))
		2:
			out.append(_r("연결복도", LINK, "corr", ""))
			out.append_array(_stack(Rect2(west.position.x, 0.0, west.size.x, 9.0), "x", "S", [["세척실", 1.0, "room"], ["보일러실", 1.0, "room"], ["조리실", 1.6, "room"], ["영양사실", 0.8, "room"], ["휴게실", 0.8, "room"], ["전처리실", 1.0, "room"]]))
			out.append(_r("식당", Rect2(west.position.x, 9.0, west.size.x, west.size.y - 9.0), "hall", "E"))
			out.append_array(_stack(east_col, "z", "W", [["기술/가정실", -10.4, "class", "S"], ["별관 2층 홀", -3.6, "corr"], ["준비실", -4.0, "room", "N"], ["데크", 1.0, "terrace", "N"]]))
		3:
			out.append(_r("연결복도", LINK, "corr", ""))
			out.append(_r("다목적강당", Rect2(west.position.x, 0.0, west.size.x, west.size.y - 4.0), "hall", "E"))
			out.append_array(_stack(Rect2(west.position.x, west.size.y - 4.0, west.size.x, 4.0), "x", "N", [["기구창고", 1.0, "room"], ["탈의실(남)", 1.0, "room"], ["탈의실(여)", 1.0, "room"], ["교사실", 1.0, "room"], ["창고", 1.0, "room"]]))
			out.append_array(_stack(east_col, "z", "W", [["음악실", -10.4, "class", "S"], ["별관 3층 홀", -3.6, "corr"], ["개인연습실", -4.0, "room", "N"], ["데크", 1.0, "terrace", "N"]]))
	return out


## 층마다 바깥으로 나가는 문: [면 또는 "x=값"/"z=값", 위치(면을 따라), 폭]
static func exterior_doors(floor: int) -> Array:
	if floor == 1:
		return [
			["x=%f" % X_WI.y, 56.3, 2.4],          # 정문: A동 홀에서 중정 남쪽으로
			["x=%f" % X_EI.x, 56.3, 2.0],          # B동 출입구
			["W", (Z_NC.x + Z_NC.y) / 2.0, 2.0],   # 북복도 서쪽 끝 (주차장 쪽)
			["x=%f" % GAP_1F.x, 12.2, 2.0],        # 북쪽 바깥 통로 양쪽
			["x=%f" % GAP_1F.y, 12.2, 2.0],
		]
	return []


## frac: 문 위치 (문이 난 벽에서 방의 북쪽/서쪽 끝 0 ~ 남쪽/동쪽 끝 1). 음수면 벽 가운데.
## fix: 화장실 설비 배치 "N:칸|S:세면칸" 처럼 (N/S/W/E = 그 끝벽, 칸 = 대변기 칸 줄, 세면칸 = 세면대 + 칸, 소변 = 소변기 줄)
static func _r(name: String, rect: Rect2, kind: String, door: String, frac := -1.0, fix := "") -> Dictionary:
	return {"name": name, "rect": rect, "kind": kind, "door": door, "frac": frac, "fix": fix}


## 한 줄(rect)을 axis 방향으로 나눈다. item: [이름, 크기, 종류] — 크기가 음수면 고정 길이(-크기), 양수면 비율.
## 이름에 "|"가 있으면 가로로 둘로 나눈다 (예: "EPS|E/V"). 문 방향을 바꾸려면 item[3], 문 위치는 item[4] (frac).
static func _stack(area: Rect2, axis: String, door: String, items: Array) -> Array:
	var total := area.size.x if axis == "x" else area.size.y
	var fixed := 0.0
	var weights := 0.0
	for it in items:
		var s: float = it[1]
		if s < 0.0:
			fixed += -s
		else:
			weights += s
	var per := (total - fixed) / weights if weights > 0.0 else 0.0
	var out: Array = []
	var at := area.position.x if axis == "x" else area.position.y
	for it in items:
		var s: float = it[1]
		var seg := -s if s < 0.0 else s * per
		var r := Rect2(at, area.position.y, seg, area.size.y) if axis == "x" else Rect2(area.position.x, at, area.size.x, seg)
		var d: String = it[3] if it.size() > 3 and it[3] != "" else door
		var frac: float = it[4] if it.size() > 4 else -1.0
		var fix: String = it[5] if it.size() > 5 else ""
		var name: String = it[0]
		if "|" in name:
			var parts := name.split("|")
			var kinds := (it[2] as String).split("|")
			if axis == "z":
				var w1 := r.size.x * 0.45
				var first_west := door == "W"
				var r1 := Rect2(r.position.x if first_west else r.end.x - w1, r.position.y, w1, r.size.y)
				var r2 := Rect2(r.position.x + w1 if first_west else r.position.x, r.position.y, r.size.x - w1, r.size.y)
				out.append(_r(parts[0], r1, kinds[0], door))
				out.append(_r(parts[1], r2, kinds[1], "N"))
			else:
				var d1 := r.size.y * 0.5
				out.append(_r(parts[0], Rect2(r.position.x, r.end.y - d1, r.size.x, d1), kinds[0], door))
				out.append(_r(parts[1], Rect2(r.position.x, r.position.y, r.size.x, r.size.y - d1), kinds[1], "W"))
		else:
			out.append(_r(name, r, it[2], d, frac, fix))
		at += seg
	return out


# ================================================================ 층별 방 (피난안내도 순서)

const C := -CLASS_LEN

## 북쪽 줄 서쪽 (A북 계단 서쪽, x 0..11.9)
static func _no_left(f: int) -> Array:
	var small := ["교사실", 1.0, "room", "S", 0.2]
	return [[["특수교실", -7.7, "room", "S", 0.8], small], [["1-1", -7.7, "class"], small], [["교실", -7.7, "class"], small], [["교실", -7.7, "class"], small], [["교실", -7.7, "class"], small]][f - 1]


## 북쪽 줄 동쪽 (x 15.4..59.7, 44.3 m). 맨 앞은 승강기
static func _no_right(f: int) -> Array:
	match f:
		1:
			return [["E/V", -2.5, "ev"], ["고사실", -4.0, "room"], ["자료실", -3.7, "room"], ["(통로)", -6.8, "room"], ["준비실", -4.0, "room"], ["시청각실", -18.0, "hall"], ["전기실", -5.3, "room"]]
		2:
			return [["E/V", -2.5, "ev"], ["화장실(교사)", -3.0, "toilet"], ["멀티미디어실", 1.0, "room"], ["도서실", 2.6, "hall"]]
		3:
			return [["E/V", -2.5, "ev"], ["화장실(교사)", -3.0, "toilet"], ["컴퓨터실", 1.0, "class"], ["다목적1실", 1.0, "class"], ["다목적2실", 1.0, "class"]]
		4:
			return [["E/V", -2.5, "ev"], ["화장실(교사)", -3.0, "toilet"], ["과학1실", 1.0, "class"], ["준비실", 0.45, "room", "S", 0.2], ["과학2실", 1.0, "class"], ["과학3실", 1.0, "class"], ["준비실", 0.45, "room", "S", 0.15]]
		_:
			return [["E/V", -2.5, "ev"], ["화장실(교사)", -3.0, "toilet"], ["공용교실-1", 1.0, "class"], ["공용교실-2", 1.0, "class"], ["스마트과학실", 1.0, "class"], ["준비실", 0.4, "room", "S", 0.15]]


static func _wo(f: int) -> Array:
	match f:
		1:
			return [["상담실", 4.0, "room", "", 0.15], ["고정실", 3.0, "room", "", 0.8], ["교장실", 6.0, "room", "", 0.15], ["탕비실", 2.0, "room", "", 0.5], ["문서고", 2.0, "room", "", 0.5], ["행정실", 7.0, "room", "", 0.85], ["방송실", 4.0, "room", "", 0.8], ["스튜디오", 4.0, "room", "", 0.8], ["하부 창고", 2.0, "room", "", 0.5]]
		2:
			return [["1학년실", -7.4, "room", "", 0.85], ["1-2", C, "class"], ["1-3", C, "class"], ["1-4", C, "class"], ["1-5", C, "class"], ["세미나실", 1.0, "room", "", 0.2]]
		3:
			return [["교무실", -7.4, "room", "", 0.85], ["1-10", C, "class"], ["1-11", C, "class"], ["1-12", C, "class"], ["교실", C, "class"], ["휴게실(여)", 1.0, "room", "", 0.2]]
		4:
			return [["교사연구실", -7.4, "room", "", 0.85], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["휴게실(남)", 1.0, "room", "", 0.2]]
		_:
			return [["교사연구실", -7.4, "room", "", 0.85], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["세미나실", 1.0, "room", "", 0.2]]


static func _wi(f: int) -> Array:
	var top := ["EPS|E/V", -4.0, "eps|ev"]
	var wc := [["화장실(여)", -4.5, "toilet", "S", 0.12, "N:칸|S:세면칸"], ["화장실 앞", -3.0, "corr"], ["화장실(남)", -4.5, "toilet", "N", 0.12, "N:세면칸|S:소변"]]
	match f:
		1:
			return [top, ["창고", -4.0, "room", "", 0.8], wc[0], wc[1], wc[2], ["포켓쉼터", 3.0, "open"], ["운영위원회의실", 3.0, "room", "", 0.15], ["전산실", 2.0, "room", "", 0.85], ["발간실", 2.0, "room", "", 0.1], ["홀", 4.0, "open"]]
		2:
			return [top, wc[0], wc[1], wc[2], ["포켓쉼터", 3.0, "open"], ["Media Space", 3.0, "open"], ["탈의실(남)", 1.5, "room", "", 0.2], ["체력단련실", 1.5, "room", "", 0.5]]
		3:
			return [top, wc[0], wc[1], wc[2], ["포켓쉼터", 3.0, "open"], ["Media Space", 3.0, "open"], ["탈의실(여)", 2.0, "room", "N", 0.8]]
		4:
			return [top, wc[0], wc[1], wc[2], ["포켓쉼터", 3.0, "open"], ["Media Space", 3.0, "open"], ["탈의실(남)", 2.0, "room", "N", 0.8]]
		_:
			return [top, wc[0], wc[1], wc[2], ["포켓쉼터", 3.0, "open"], ["Media Space", 3.0, "open"], ["탈의실(여)", 2.0, "room", "N", 0.8]]


static func _ei(f: int) -> Array:
	match f:
		1:
			return [["보건교육실", 5.0, "room", "", 0.1], ["위클래스실", 6.0, "room", "", 0.85], ["준비실", 3.0, "room", "", 0.85], ["미술실", 10.0, "class"], ["출입구", 3.0, "open"]]
		2:
			return [["%s", -7.4, "room", "", 0.85], ["1-6", C, "class"], ["1-7", C, "class"], ["1-8", C, "class"], ["1-9", C, "class"], ["학생회의실", 1.0, "room", "", 0.3]]
		3:
			return [["%s", -7.4, "room", "", 0.85], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["동아리실", 1.0, "room", "S", 0.15]]
		4:
			return [["%s", -7.4, "room", "", 0.85], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["동아리실", 1.0, "room", "S", 0.15]]
		_:
			return [["%s", -7.4, "room", "", 0.85], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["교실", C, "class"], ["교실", 1.0, "class"]]


static func _eo(f: int) -> Array:
	var wc := [["화장실(남)", -4.0, "toilet", "", 0.2], ["화장실(여)", -4.0, "toilet", "", 0.2]]
	var wc2 := [["화장실(남)", -5.9, "toilet", "S", 0.12, "N:칸|S:세면칸"], ["화장실 앞", -5.1, "corr"], ["화장실(여)", -5.8, "toilet", "S", 0.12, "N:세면칸|S:소변"]]
	match f:
		1:
			return [["창고", 2.0, "room", "", 0.5], wc[0], wc[1], ["진로교육 전용공간", 3.0, "room", "", 0.85], ["포켓쉼터", 2.0, "open"], ["기술/가정 이론교실", 5.0, "class"], ["준비실", 2.0, "room", "", 0.2], ["창고", 2.0, "room", "", 0.2]]
		2:
			return [wc2[0], wc2[1], wc2[2], ["Media Space", 2.0, "open"], ["탈의실(여)", 1.0, "room", "", 0.1]]
		3:
			return [wc2[0], wc2[1], wc2[2], ["Media Space", 2.0, "open"], ["탈의실(남)", 1.0, "room", "", 0.1]]
		4:
			return [wc2[0], wc2[1], wc2[2], ["Media Space", 2.0, "open"], ["탈의실(여)", 1.0, "room", "", 0.1]]
		_:
			return [wc2[0], wc2[1], wc2[2], ["Media Space", 2.0, "open"], ["탈의실(남)", 1.0, "room", "", 0.1]]
