# 기술 설계서 (Godot 4)

> 규칙의 정의는 [GDD.md](GDD.md) 4장. 이 문서는 그 정의를 어떻게 구현하는지 적는다.
> 코드는 방향을 보여주는 스케치다. 실제 구현 때 엔진 버전에 맞춰 확인한다.

## 1. 기본 결정

| 항목 | 결정 | 이유 |
|---|---|---|
| 엔진 | Godot 4 최신 안정 버전. 프로젝트 시작 때 버전을 고정하고, 큰 버전은 마일스톤 사이에만 올린다 | 중간에 올리면 조명 굽기 결과와 물리 동작이 달라질 수 있다 |
| 언어 | GDScript | 2인 팀이 함께 읽고 고치기 쉽다 |
| 렌더러 | Forward+ | 구운 조명, 안개, 반사를 모두 쓴다 |
| 물리 | 기본 3D 물리 (플레이어는 CharacterBody3D) | 물리 퍼즐이 없어 단순한 것으로 충분하다 |
| 조명 | 고정된 것은 굽고(LightmapGI), 깜빡이는 등 몇 개만 실시간 | 성능과 리미널 스페이스 특유의 평평한 빛 |
| 버전 관리 | Git + Git LFS (모델, 텍스처, 소리) | |
| 목표 성능 | 1080p 60프레임 (GTX 1060급), 내장 그래픽에서 낮음 품질 30프레임 | |

## 2. 프로젝트 구조

```
res://
├─ core/                 # 어디서나 쓰는 것
│  ├─ player/            # player.tscn, player.gd, 카메라, 발소리
│  ├─ game_state.gd      # (자동 로드) 풀린 퍼즐, 흔적, 현재 위치
│  ├─ save_manager.gd    # (자동 로드) 저장과 불러오기
│  ├─ hint_director.gd   # (자동 로드) 머문 시간 재기, 힌트 단계
│  ├─ stream_manager.gd  # (자동 로드) 구역 불러오기와 내리기
│  └─ audio_director.gd  # (자동 로드) 환경음 섞기
├─ systems/
│  ├─ loop/              # R1: loop_gate.gd, floor_state.gd
│  ├─ water/             # R2: water_body.gd, tile_zone.gd, water_link.gd
│  ├─ gaze/              # R3: gaze_tracker.gd, mutable.gd, observer_camera.gd
│  └─ interact/          # door.gd, valve.gd, button.gd, interactable.gd
├─ levels/
│  ├─ ch0_prologue/
│  ├─ ch1_parking/       # 퍼즐마다 장면 하나: p1_1.tscn …
│  ├─ bridge_a/
│  ├─ ch2_pool/
│  ├─ bridge_b/
│  ├─ ch3_school/
│  ├─ ch4_return/
│  └─ kits/              # 장소별 조립 부품 (벽, 기둥, 풀, 교실)
├─ assets/               # models/, textures/, materials/, audio/
├─ ui/                   # 메뉴, 설정, 흔적 화면
├─ debug/                # 개발용 도구 (출시 빌드에서 제외)
└─ docs/
```

**장면 나누기 원칙**
- **퍼즐 하나 = 장면 파일 하나.** 두 사람이 같은 장면 파일을 동시에 고치지 않는다 (장면 파일은 합치기가 어렵다).
- 퍼즐 장면의 맨 위 노드에는 `puzzle_room.gd`를 붙인다. 퍼즐 번호, 입구 위치, 처음 상태로 되돌리기, 힌트 3단계를 여기서 관리한다.

## 3. 핵심 시스템

### 3.1 R1: 반복 관문 (loop)

**원리:** 똑같이 생긴 구간을 여러 벌 놓고, 관문을 지나는 순간 플레이어를 다른 벌의 같은 자리로 옮긴다. 위치, 방향, 속도를 그대로 유지하면 옮긴 티가 나지 않는다.

**노드:** `LoopGate` (Node3D)
- 내보내는 값: `forward_target`(정방향 통과 시 도착 관문), `reverse_target`(역방향 통과 시 도착 관문), 관문의 폭과 높이.
- 관문의 앞 방향(−Z)이 화살표 방향이다. 편집기에서 화살표 기즈모로 보이게 한다.

**통과 판정:** 영역에 들어왔는지가 아니라, **관문 면을 넘어간 순간의 방향**을 본다.

```gdscript
# loop_gate.gd (스케치)
extends Node3D

@export var forward_target: LoopGate
@export var reverse_target: LoopGate
@export var half_width := 3.0

var _last_side := 0.0

func _physics_process(_dt: float) -> void:
    var player := GameState.player
    var local := to_local(player.global_position)
    if absf(local.x) > half_width:      # 관문 폭 밖이면 무시
        _last_side = 0.0
        return
    var side := signf(local.z)           # 관문 면의 어느 쪽에 있는가
    if _last_side != 0.0 and side != 0.0 and side != _last_side:
        var went_forward := side < 0.0   # +Z에서 -Z로 넘어감 = 화살표 방향
        var target := forward_target if went_forward else reverse_target
        if target:
            _move_player(player, target)
            side = 0.0                   # 옮긴 직후 다시 판정되는 것을 막는다
    _last_side = side

func _move_player(player: CharacterBody3D, target: LoopGate) -> void:
    # 이 관문 기준의 상대 위치와 방향을 도착 관문 기준으로 그대로 옮긴다
    var delta := target.global_transform * global_transform.affine_inverse()
    player.global_transform = delta * player.global_transform
    player.velocity = delta.basis * player.velocity
    target._last_side = 0.0
```

**주의할 점**
- 옮기는 순간 화면에 보이는 것이 양쪽에서 같아야 한다. 관문은 **양쪽 풍경이 똑같은 지점**에 둔다 (경사로 중간, 긴 통로 중간).
- 구운 조명도 두 벌이 같아야 한다. 같은 장면을 인스턴스로 두 번 놓고 조명 굽기 결과를 공유한다.
- 소리가 끊기지 않게, 환경음은 위치가 아니라 구역 단위로 재생한다.
- 앵커 물건(커피컵 등)은 벌마다 조금씩 다르게 둘 수 있다 (1-1의 얼룩).

**1-1을 만들며 확인한 것 (2026-11-11)**
- **관문 양쪽의 앞뒤 풍경이 모두 같아야 한다.** 관문에서 경사로 위아래 끝이 다 보이므로, 진짜 층(F0) 하나에 위층 자리(F_up)와 아래층 자리(F_down) 복제본을 붙여 세 벌로 만든다. 복제본은 보이기만 하고 들어갈 수 없다.
- **텍스처는 층 원점 기준으로 입힌다.** 월드 좌표로 입히면 복제본마다 물웅덩이와 얼룩 위치가 달라진다. 셰이더의 `world_offset`에 층 원점을 넣는다 (`ParkingMats.for_floor`).
- **SDFGI는 쓰지 않는다.** 카메라를 따라 계산이 쌓이는 방식이라 순간이동 직후 밝기가 출렁인다. 대신 미리 구운 VoxelGI를 쓰고, 같은 모양의 층은 구운 결과 하나를 나눠 쓴다 (첫 실행 때 약 1초 걸려 자동으로 굽는다).
- **안개의 시간 누적(temporal reprojection)을 끈다.** 같은 이유.
- **순간이동 직후 몇 프레임은 직전 화면으로 덮는다 (`FrameHold`).** 처음 보이는 층으로 옮기면, 플레이어 **뒤쪽**에 있는 조명이 렌더러 안에서 1~2프레임 늦게 적용되어 화면이 어둡게 깜빡였다. 이미 보이던 층으로 갈 때는 1프레임, 처음 보는 층(B3, B4)으로 갈 때는 3프레임(1/20초)을 덮는다.
  - 원인 찾기에서 확인한 것: 그림자, 조명 거리 페이드, SSIL·SSAO·SSR·볼류메트릭 안개·TAA를 하나씩 꺼도 사라지지 않았다. 도착지를 보조 카메라(SubViewport)로 미리 그려도 효과가 없었다. 도착지 층의 조명 수가 늘수록 어두운 프레임이 길어졌다.
- **관문에서 보이는 위아래 끝은 모두 실제 층이어야 한다.** 처음에는 B3로 올라가는 경사로의 아래쪽을 벽으로 막았더니, 뒷걸음질로 올라가면 넘어가는 순간 아래층이 벽으로 바뀌는 게 보였다. 지금은 B3 아래에 보이기만 하는 B4 층을 두고, 그 경사로에서 다시 내려가면 B2로 돌아가게 했다.
- **검증 방법:** `--test=down|up`이 순간이동 직전·직후 화면의 픽셀 차이를 출력한다. 기준은 같은 속도로 한 프레임 걸었을 때의 차이(약 0.008)다. 1-1의 측정값은 순간이동 프레임 0(덮음), 다음 실제 화면 약 0.025(두 프레임 이동분)였다.

**층 변수 (1-6용):** 층 모형 한 벌을 재사용한다. `floor_state.gd`가 현재 층 번호를 갖고, 층이 바뀔 때(플레이어가 경사로 안에 있어 층이 안 보일 때) 번호판, 차 배치, 조명, 차단물 유무를 그 번호에 맞게 바꾼다.

### 3.2 R2: 물의 연결 (water)

**노드**
- `WaterBody` (Area3D): 물의 부피. 수위(0~1), 깊이.
- `TileZone` (Area3D, WaterBody의 자식): 바닥의 타일 구역. 타일 번호(`tile_id`)와 떠오르는 지점(`surface_point`)을 가진다.
- `WaterLink` (자동 로드): 타일 번호 → 구역 둘의 짝을 관리한다.

**흐름**
1. 플레이어의 머리 위치가 WaterBody 안에 있고 수위에 따른 깊이가 1.0 m 이상이면 "잠수 중".
2. 잠수 중인 시간이 1초가 되면, 발밑 TileZone의 `tile_id`로 짝을 찾는다.
3. 짝이 있고 그 물의 깊이가 1.0 m 이상이면: 화면을 물빛으로 흐리게(0.4초) → 플레이어를 짝의 `surface_point`로 옮김 → 흐림을 걷는다(0.6초).
4. 짝이 없거나 비어 있으면 아무 일 없이 제자리에서 떠오른다.

```gdscript
# water_link.gd (스케치)
extends Node

var _zones := {}   # tile_id -> Array[TileZone]

func register(zone: TileZone) -> void:
    _zones.get_or_add(zone.tile_id, []).append(zone)
    assert(_zones[zone.tile_id].size() <= 2, "같은 타일의 물은 두 곳까지만: %s" % zone.tile_id)

func partner_of(zone: TileZone) -> TileZone:
    for other in _zones.get(zone.tile_id, []):
        if other != zone and other.body.depth_now() >= 1.0:
            return other
    return null
```

- `assert`로 "같은 타일은 정확히 두 곳" 규칙을 편집 단계에서 잡는다.
- **밸브:** `valve.gd`가 연결된 WaterBody들의 목표 수위를 정한다. 수위 변화는 몇 초에 걸쳐 일어나고, 저장할 때는 목표 수위만 저장한다.
- **물의 겉모습:** 반투명 수면 + 간단한 물결 셰이더 + 수중일 때 화면 후처리(색 틴트, 흐림, 소리 저역 필터). 사실적인 물 시뮬레이션은 하지 않는다.
- 멀리 떨어진 방으로 옮길 때는 3.4의 구역 불러오기가 먼저 끝나 있어야 한다. 짝이 있는 방은 미리 불러 둔다.

### 3.3 R3: 시선 판정 (gaze)

**노드**
- `Mutable` (Node3D): 변이체. 상태 목록(자식 노드들 중 하나만 보이게 하는 방식 또는 애니메이션), 현재 상태 번호, 판정용 점들(`sample_points`, 대상의 모서리와 중심에 5~9개).
- `GazeTracker` (자동 로드): 매 물리 프레임마다 등록된 변이체가 "보는 중"인지 계산한다.
- `ObserverCamera` (Node3D): 거울, 유리, CCTV용 보조 시점.

**"보는 중" 판정** (하나라도 참이면 보는 중)
1. 판정용 점 중 하나가 **화면 안**(가장자리에서 바깥으로 8% 넓힌 범위)에 있고,
2. 카메라에서 그 점까지 쏜 광선이 다른 물체에 막히지 않는다.

```gdscript
# gaze_tracker.gd (스케치)
const MARGIN := 0.08          # 화면보다 조금 넓게: 플레이어에게 유리하게
const UNSEEN_DELAY := 0.5     # 이 시간 이상 안 보여야 "안 보는 중"

func _point_seen(cam: Camera3D, p: Vector3, exclude: Array[RID]) -> bool:
    if cam.is_position_behind(p):
        return false
    var vp := cam.get_viewport().get_visible_rect().size
    var s := cam.unproject_position(p)
    var m := vp * MARGIN
    if s.x < -m.x or s.y < -m.y or s.x > vp.x + m.x or s.y > vp.y + m.y:
        return false
    var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, OCCLUDER_MASK, exclude)
    return cam.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
```

**상태 넘기기**
- 변이체마다 "안 보인 시간"을 잰다. 0.5초를 넘는 순간 한 번만 다음 상태로 넘긴다. 다시 보이면 타이머를 0으로.
- 한 번도 보인 적 없는 변이체는 넘기지 않는다.
- 플레이어가 변이체의 `no_change_area` 안에 있으면 넘기지 않는다 (끼임 방지).
- 넘길 때 `changed` 신호를 낸다 → 소리 재생, 접근성 물결 표시.

**간접 시선 (유리, 거울, 모니터)**
- `ObserverCamera`는 "어떤 면을 통해 무엇을 보는가"를 나타낸다: 반사면(또는 모니터 화면)의 판정용 점들 + 보조 시점의 위치와 방향.
- 판정: 플레이어가 **그 면을 보는 중**이고, 보조 시점에서 변이체가 보이면 → 보는 중.
- 거울과 유리의 보조 시점은 플레이어 카메라를 그 면에 대칭시킨 위치로 매 프레임 계산한다. 모니터는 CCTV 카메라 위치로 고정.
- **녹화:** CCTV 카메라의 `recording`이 켜져 있으면 플레이어와 무관하게, 카메라 시야 안의 변이체는 항상 보는 중.
- 화면에 실제로 비치는 반사 그림은 가짜여도 된다 (평면 반사용 보조 뷰포트 또는 단순한 반사 프로브). **판정과 그림을 분리**해서, 그림 품질을 낮춰도 퍼즐은 정확하게 동작하게 한다.

**3-3의 늘어나는 복도:** 복도 끝부분(문 포함)을 하나의 노드로 묶고, 비상구 등이 안 보이는 동안 그 노드를 뒤로 밀어 원래 길이로 되돌린다. 사이는 같은 복도 조각을 이어 붙여 채운다.

### 3.4 구역 불러오기 (stream)

게임 전체가 로딩 화면 없이 이어진다.
- 세계를 **구역**(대략 퍼즐 2~3개 묶음)으로 나눈다. 구역마다 장면 파일 하나.
- `StreamManager`가 현재 구역, 이웃 구역, 물이나 관문으로 이어진 구역을 메모리에 유지한다.
- 구역 경계에는 **꺾인 복도나 문**을 둔다. 여기에 들어서면 다음 구역을 배경에서 불러오고(`ResourceLoader.load_threaded_request`), 지나온 구역을 내린다.
- 서로 떨어진 구역은 좌표상 멀리 배치해도 된다 (수영장 방들은 걸어서 이어지지 않으므로).
- 불러오기가 끝나지 않았으면 문이 "뻑뻑하게" 조금 늦게 열린다 (로딩을 연출로 가린다).

### 3.5 상호작용

- `Interactable` 기반 클래스: `interact()`, `can_interact()`, 안내 점 위치.
- 플레이어 카메라 중앙에서 2 m 광선을 쏴서 맞은 대상에 점을 표시한다.
- 종류: 문(여닫이, 미닫이, 스프링), 밸브(2단, 3단), 버튼, 스위치, 서랍, 흔적.

### 3.6 힌트

- `PuzzleRoom`이 플레이어가 방 안에 머문 시간을 잰다 (일시정지 제외).
- 설정에 따른 시간(기본 7 / 12 / 18분)에 `hint_stage_1/2/3` 함수를 부른다. 퍼즐 장면마다 이 함수에 조명 깜빡임, 소리, 변화를 연결한다.
- 퍼즐이 풀리면 타이머를 멈춘다.

### 3.7 저장

```json
{
  "version": 1,
  "zone": "ch2_pool_b",
  "room": "p2_6",
  "solved": ["p1_1", "p1_2"],
  "room_state": {
    "p2_2": { "valve": 1 },
    "p3_6": { "door_a": 2, "shutter_b": 1 }
  },
  "traces": [1, 2, 5],
  "play_seconds": 5421
}
```

- 위치: `user://save_1.json` ~ `save_3.json`. 설정은 `user://settings.cfg`.
- 각 퍼즐 방은 `get_state()`와 `set_state()`를 구현한다.
- `version`을 두어, 개발 중 저장 형식이 바뀌어도 옛 저장을 읽거나 버릴 수 있게 한다.

## 4. 개발용 도구 (debug/)

초기에 만들어 두면 계속 시간을 아낀다.

| 도구 | 기능 |
|---|---|
| 퍼즐 이동 메뉴 (F1) | 원하는 퍼즐 방 입구로 바로 이동 |
| 규칙 보기 (F2) | 관문 면과 방향, 타일 번호, 변이체 상태와 "보는 중" 여부를 화면에 표시 |
| 자유 카메라 (F3) | 플레이어와 떨어져 장면을 둘러본다 |
| 시간 배속 (F4) | 힌트 타이머 시험용 |
| 플레이 기록 | 퍼즐별 걸린 시간, 힌트 단계, 방 다시 시작 횟수를 파일로 남긴다 (테스트 분석용. PRODUCTION.md 참고) |

## 5. 성능 지침

- 조명은 굽는다. 실시간 조명은 화면에 동시에 4개 이하.
- 반복 구간의 여러 벌은 메시와 재질을 공유한다 (인스턴스).
- 가림 처리(오클루전 컬링)를 켠다. 주차장과 학교는 벽이 많아 효과가 크다.
- 반사: 수영장은 화면 공간 반사 + 반사 프로브. 평면 반사용 보조 뷰포트는 3-7 한 곳에서만 쓰고 해상도를 절반으로.
- 시선 판정 광선: 변이체당 점 5~9개 × 근처 변이체만. 플레이어에게서 40 m 넘게 떨어진 변이체는 "안 보는 중"이 아니라 **판정 중지**로 둔다 (멀리서 멋대로 바뀌지 않게).

## 6. 구현 순서

| 순서 | 내용 | 대응 마일스톤 |
|---|---|---|
| 1 | 플레이어 조작, 상호작용, 문 | M0 |
| 2 | LoopGate, 디버그 도구 F1~F3 | M1 |
| 3 | PuzzleRoom, 힌트, 저장 | M1~M2 |
| 4 | 구역 불러오기 | M2 |
| 5 | 물 시스템, 밸브 | M3 |
| 6 | 시선 판정, 간접 시선, 녹화 | M4 |
| 7 | 세 시스템 겹침 시험 | M5 |
| 8 | 메뉴, 설정, 접근성, 컨트롤러 | M6 |
| 9 | 최적화, Steam 연동(도전 과제, 클라우드 저장) | M7~M8 |

## 7. 기술 위험

| 위험 | 대비 |
|---|---|
| 관문을 지날 때 화면이 튀거나 끊김 | M1 첫 주에 1-1만 가지고 완성도를 본다. 안 되면 관문 위치를 어두운 구간으로 옮긴다 |
| 시선 판정이 불공정하게 느껴짐 | 여유 범위(8%)와 지연(0.5초)을 설정값으로 빼 두고 테스트로 맞춘다 |
| 거울 반사 그림의 비용 | 판정과 그림을 분리했으므로 그림은 낮은 품질로 대체 가능 |
| 조명 굽기 시간이 길어짐 | 구역 단위로 굽는다. 그레이박스 단계에서는 굽지 않는다 |
| 장면 파일 충돌 | 퍼즐 하나 = 장면 하나, 작업 전 누가 맡는지 정한다 |
