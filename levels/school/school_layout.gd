## 학교 평면 데이터 (5층). 방 순서·이웃은 받은 층별 평면도, 건물 외곽 치수는 건축물현황도(배치도)의 기둥 간격 치수,
## 층별 면적은 건축물대장으로 맞췄다 (본관 한 층 약 2,530㎡ ↔ 대장 4층 2,425㎡).
## 방 하나하나의 크기는 배치도에서 읽을 수 없어 기둥 간격(8.1 m)과 표준 치수로 나눴다.
##
## 좌표: x = 동쪽(+), z = 남쪽(+), 단위 m. 원점은 본관 북서쪽 바깥 모서리.
##   본관 59.7 × 61.8 m (배치도 X0..X9 = 59,700 / Y0..Y9 = 61,800)
##   x:  WO 0..9.6 | 서복도 9.6..12.6 | WI 12.6..17.1 | 중정 17.1..41.9 | EI 41.9..51.5 | 동복도 51.5..54.5 | EO 54.5..59.7
##   z:  북쪽 줄 0..9.0 | 북복도 9.0..12.0 | 가운데 12.0..58.8 (WO·EO는 61.8까지) | 남쪽 연결복도 58.8..61.8
##   별관(식당·다목적강당) 32.4 × 26.4 m: x -57.9..-25.5, z 0..26.4 (배치도 A0..A4, B0..B4)
##   본관과 별관 사이: 북복도를 서쪽으로 이은 연결복도 (x -25.5..0, z 9..12), 그 북쪽에 특별교실 동 (x -12..0, z 0..9, 3층)
##
## 방 종류(kind):
##   class  교실 (복도 쪽 문 둘, 책상)       room  방 (문 하나)        hall  큰 방 (문 둘, 책상 없음)
##   toilet 화장실   open  복도와 벽 없이 트인 공간 (미디어스페이스 등)   closed  문 없는 방 (폐쇄 출입구 등)
##   stair 계단   ev 엘리베이터   eps 설비실   corr 복도   void 중정 위 빈 공간   court 1층 중정 바닥   terrace 옥외 테라스
class_name SchoolLayout
extends RefCounted

const FLOOR_H := 3.6           # 층 높이 (대장 높이 19.4 m = 3.6 × 5 + 옥상)
const CEIL_H := 3.0            # 반자 높이
const FLOORS := 5
const CLASS_LEN := 8.1         # 교실 한 칸 (기둥 간격)

const X_WO := Vector2(0.0, 9.6)
const X_WC := Vector2(9.6, 12.6)
const X_WI := Vector2(12.6, 17.1)
const X_V := Vector2(17.1, 41.9)
const X_EI := Vector2(41.9, 51.5)
const X_EC := Vector2(51.5, 54.5)
const X_EO := Vector2(54.5, 59.7)
const Z_NO := Vector2(0.0, 9.0)
const Z_NC := Vector2(9.0, 12.0)
const Z_MID := Vector2(12.0, 58.8)
const Z_SC := Vector2(58.8, 61.8)
const W := 59.7
const D := 61.8
const ANNEX := Rect2(-57.9, 0.0, 32.4, 26.4)
const LINK := Rect2(-25.5, 9.0, 25.5, 3.0)
const SPECIAL := Rect2(-12.0, 0.0, 12.0, 9.0)

# 계단: rect, 긴 축, 층계참(바닥 높이) 쪽 끝, 문 방향
const STAIRS := [
	{"name": "계단 A북", "rect": Rect2(9.6, 0.0, 3.5, 9.0), "axis": "z", "near": "S", "door": "S"},
	{"name": "계단 A남", "rect": Rect2(0.0, 55.8, 9.6, 6.0), "axis": "x", "near": "E", "door": "E"},
	{"name": "계단 B북", "rect": Rect2(54.5, 12.0, 5.2, 7.5), "axis": "z", "near": "N", "door": "W"},
	{"name": "계단 B남", "rect": Rect2(54.5, 54.3, 5.2, 7.5), "axis": "z", "near": "S", "door": "W"},
]


## 층(1..5)의 방 목록. 각 방: {name, rect: Rect2(x, z, w, d), kind, door: "N"/"S"/"E"/"W"}
static func rooms(floor: int) -> Array:
	var out: Array = []
	# 복도
	out.append(_r("북복도", Rect2(0.0, Z_NC.x, W, 3.0), "corr", ""))
	out.append(_r("서복도", Rect2(X_WC.x, Z_MID.x, 3.0, Z_MID.y - Z_MID.x), "corr", ""))
	out.append(_r("동복도", Rect2(X_EC.x, Z_MID.x, 3.0, Z_MID.y - Z_MID.x), "corr", ""))
	out.append(_r("남쪽 연결복도", Rect2(X_WC.x, Z_SC.x, X_EC.y - X_WC.x, 3.0), "corr", ""))
	# 계단
	for s in STAIRS:
		out.append(_r(s["name"], s["rect"], "stair", s["door"]))
	# 중정
	out.append(_r("중정", Rect2(X_V.x, Z_MID.x, X_V.y - X_V.x, Z_MID.y - Z_MID.x), "court" if floor == 1 else "void", ""))
	# 북쪽 줄: 서쪽 칸(x 0..9.6)과 계단 동쪽(x 13.1..59.7)
	out.append_array(_stack(Rect2(0.0, Z_NO.x, X_WO.y, Z_NO.y), "x", "S", _no_left(floor)))
	out.append_array(_stack(Rect2(13.1, Z_NO.x, W - 13.1, Z_NO.y), "x", "S", _no_right(floor)))
	# 서쪽 바깥 줄 WO (북복도 아래 ~ A남 계단 위)
	out.append_array(_stack(Rect2(X_WO.x, Z_MID.x, X_WO.y - X_WO.x, 55.8 - Z_MID.x), "z", "E", _wo(floor)))
	# 서쪽 안쪽 WI
	out.append_array(_stack(Rect2(X_WI.x, Z_MID.x, X_WI.y - X_WI.x, Z_MID.y - Z_MID.x), "z", "W", _wi(floor)))
	# 동쪽 안쪽 EI
	out.append_array(_stack(Rect2(X_EI.x, Z_MID.x, X_EI.y - X_EI.x, Z_MID.y - Z_MID.x), "z", "E", _ei(floor)))
	# 동쪽 바깥 줄 EO (B북 계단 아래 ~ B남 계단 위)
	out.append_array(_stack(Rect2(X_EO.x, 19.5, X_EO.y - X_EO.x, 54.3 - 19.5), "z", "W", _eo(floor)))
	# 서쪽: 연결복도, 특별교실 동, 별관
	match floor:
		1:
			out.append(_r("연결복도", LINK, "corr", ""))
			out.append(_r("특별교실동 1층", SPECIAL, "room", "S"))
		2:
			out.append(_r("연결복도", LINK, "corr", ""))
			out.append(_r("특별교실동 2층", SPECIAL, "room", "S"))
			out.append_array(_stack(ANNEX, "x", "E", [["조리실", -8.0, "room", "E"], ["식당", 1.0, "hall", "E"]]))
		3:
			out.append(_r("연결복도", LINK, "corr", ""))
			out.append(_r("음악실", SPECIAL, "class", "S"))
			out.append_array(_stack(ANNEX, "x", "E", [["다목적강당", 1.0, "hall", "E"]]))
		4:
			out.append(_r("연결 테라스", LINK, "terrace", "E"))
			out.append(_r("테라스", ANNEX, "terrace", "E"))
		5:
			out.append(_r("테라스", Rect2(-6.0, 9.0, 6.0, 3.0), "terrace", "E"))
	return out


## 별관 구역: 연결복도의 서쪽 끝이 별관 동쪽 벽에 닿는다
static func annex_link_z() -> float:
	return LINK.position.y + LINK.size.y / 2.0


## 층마다 바깥으로 나가는 문: [면 또는 "x=값"/"z=값", 위치(면을 따라), 폭]
static func exterior_doors(floor: int) -> Array:
	if floor == 1:
		# 정문(남쪽 연결복도 가운데, 서쪽 안쪽 줄 앞), 연결복도 서쪽 끝(별관·운동장 쪽)
		return [["S", (X_WI.x + X_WI.y) / 2.0, 2.4], ["x=-25.5", annex_link_z(), 1.8]]
	return []


static func _r(name: String, rect: Rect2, kind: String, door: String) -> Dictionary:
	return {"name": name, "rect": rect, "kind": kind, "door": door}


## 한 줄(rect)을 axis 방향으로 나눈다. item: [이름, 크기, 종류] — 크기가 음수면 고정 길이(-크기), 양수면 비율.
## 이름에 "|"가 있으면 가로로 둘로 나눈다 (예: "EPS|E/V"). 문 방향을 바꾸려면 item[3].
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
		var d: String = it[3] if it.size() > 3 else door
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
			out.append(_r(name, r, it[2], d))
		at += seg
	return out


# ================================================================ 층별 방 (평면도 순서)

const C := -CLASS_LEN

static func _no_left(f: int) -> Array:
	return [[["특수교실", 1.0, "room"]], [["공용교실", 1.0, "class"]], [["공용교실", 1.0, "class"]], [["2-10", 1.0, "class"]], [["3-12", 1.0, "class"]]][f - 1]


static func _no_right(f: int) -> Array:
	match f:
		1:
			return [["숙직실", 4.0, "room"], ["무대", 5.0, "room"], ["시청각실", 24.0, "hall"], ["자료실", 6.0, "room"]]
		2:
			return [["화장실(여교사)", -3.0, "toilet"], ["화장실(남교사)", -3.0, "toilet"], ["도서관", 1.0, "hall"]]
		3:
			return [["화장실(여교사)", -3.0, "toilet"], ["화장실(남교사)", -3.0, "toilet"], ["컴퓨터실", 9.0, "class"], ["1학년교무실", 9.0, "room"], ["2학년교무실", 9.0, "room"], ["동아리실", 6.0, "room"]]
		4:
			return [["화장실(여교사)", -3.0, "toilet"], ["화장실(남교사)", -3.0, "toilet"], ["1과학실", 9.0, "class"], ["준비실", 3.5, "room"], ["2과학실", 9.0, "class"], ["3과학실", 9.0, "class"], ["준비실", 3.5, "room"]]
		_:
			return [["화장실(여교사)", -3.0, "toilet"], ["화장실(남교사)", -3.0, "toilet"], ["제1학습실", 9.0, "class"], ["제2학습실", 9.0, "class"], ["3학년교무실", 9.0, "room"], ["준비실", 5.0, "room"]]


static func _wo(f: int) -> Array:
	match f:
		1:
			return [["보건실", 6.0, "room"], ["평가관리실", 4.5, "room"], ["교장실", 7.5, "room"], ["탕비실", 3.0, "room"], ["서고", 3.0, "room"], ["행정실", 9.0, "room"], ["학교운영위원회 회의실", 7.5, "room"], ["방송실", 6.0, "room"]]
		2:
			return [["진로/정보교무실", 6.0, "room"], ["1-4", C, "class"], ["1-3", C, "class"], ["1-2", C, "class"], ["1-1", C, "class"], ["교감실", 5.4, "room"]]
		3:
			return [["본교무실", 6.0, "room"], ["2-5", C, "class"], ["2-4", C, "class"], ["2-3", C, "class"], ["2-2", C, "class"], ["휴게실(여)", 5.4, "room"]]
		4:
			return [["교육과정교무실", 6.0, "room"], ["2-9", C, "class"], ["2-8", C, "class"], ["2-7", C, "class"], ["2-6", C, "class"], ["휴게실(남)", 5.4, "room"]]
		_:
			return [["학생회의실", 6.0, "room"], ["3-11", C, "class"], ["3-10", C, "class"], ["3-9", C, "class"], ["3-8", C, "class"], ["탈의실(여)", 2.7, "room"], ["세미나실", 2.7, "room"]]


static func _wi(f: int) -> Array:
	var top := ["EPS|E/V", -3.0, "eps|ev"]
	match f:
		1:
			return [top, ["화장실(여)", -5.0, "toilet"], ["화장실(남)", -5.0, "toilet"], ["옥외화장실(여)", -3.0, "toilet"], ["옥외화장실(남)", -3.0, "toilet"], ["일시적관찰실", 6.0, "room"], ["전산실", 4.0, "room"], ["발간실", 4.0, "room"], ["주출입구", 9.0, "open"]]
		2:
			return [top, ["화장실(남)", -6.0, "toilet"], ["화장실(남)", -6.0, "toilet"], ["미디어스페이스", 20.0, "open"], ["환경담당자실", 5.0, "room"], ["진로상담실", 5.0, "room"]]
		3:
			return [top, ["화장실(남)", -6.0, "toilet"], ["화장실(남)", -6.0, "toilet"], ["미디어스페이스", 30.0, "open"], ["수능 물품실", 9.0, "room"]]
		4:
			return [top, ["화장실(남)", -6.0, "toilet"], ["화장실(남)", -6.0, "toilet"], ["미디어스페이스", 30.0, "open"], ["사회교과실2", 9.0, "room"]]
		_:
			return [top, ["화장실(남)", -6.0, "toilet"], ["화장실(남)", -6.0, "toilet"], ["홈베이스", 21.0, "open"], ["제7상담실", 6.0, "room"], ["사회교과실1", 9.0, "room"]]


static func _ei(f: int) -> Array:
	match f:
		1:
			return [["출입구(폐쇄)", 3.0, "closed"], ["화단", 3.0, "closed"], ["서고", 6.0, "room"], ["위클래스(상담실)", 9.0, "room"], ["준비실", 4.0, "room"], ["미술실", 12.0, "class"], ["출입구(폐쇄)", 4.0, "closed"]]
		2:
			return [["예체능/인문교무실", 1.0, "room"], ["1-9", C, "class"], ["1-8", C, "class"], ["1-7", C, "class"], ["1-6", C, "class"], ["1-5", C, "class"]]
		3:
			return [["학생인권부교무실", 1.0, "room"], ["2-1", C, "class"], ["1-12", C, "class"], ["1-11", C, "class"], ["1-10", C, "class"], ["여교사협의회실", 1.0, "room"]]
		4:
			return [["연구/과학교무실", 1.0, "room"], ["3-2", C, "class"], ["3-1", C, "class"], ["2-12", C, "class"], ["2-11", C, "class"], ["제1동아리실", 1.0, "room"]]
		_:
			return [["제3학습실", 1.0, "class"], ["3-7", C, "class"], ["3-6", C, "class"], ["3-5", C, "class"], ["3-4", C, "class"], ["3-3", C, "class"]]


static func _eo(f: int) -> Array:
	match f:
		1:
			return [["화장실(남)", 4.5, "toilet"], ["화장실(여)", 4.5, "toilet"], ["체력단련실", 9.0, "room"], ["포켓쉼터", 6.0, "open"], ["기술실", 9.0, "class"], ["준비실", 4.0, "room"], ["창고", 3.0, "room"]]
		2:
			return [["화장실(남)", -4.5, "toilet"], ["화장실(여)", -4.5, "toilet"], ["미디어스페이스", 2.0, "open"], ["영어교과실", 1.0, "room"]]
		3:
			return [["화장실(남)", -4.5, "toilet"], ["화장실(남)", -4.5, "toilet"], ["미디어스페이스", 2.0, "open"], ["제2외국어교과실", 1.0, "room"]]
		4:
			return [["화장실(남)", -4.5, "toilet"], ["화장실(남)", -4.5, "toilet"], ["미디어스페이스", 2.0, "open"], ["국어교과실", 1.0, "room"]]
		_:
			return [["화장실(남)", -4.5, "toilet"], ["화장실(남)", -4.5, "toilet"], ["미디어스페이스", 2.0, "open"], ["수학교과실", 1.0, "room"]]
