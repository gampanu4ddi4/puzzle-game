# puzzle-game

1인칭 리미널 스페이스 공간 퍼즐 게임 (가제: 새솔센터) · PC · Godot 4

문 닫은 복합센터. 주차장은 되돌아가야 나아가고, 수영장은 같은 타일끼리 이어지고, 학교는 보지 않을 때 바뀐다.

## 기획 문서

| 문서 | 내용 |
|---|---|
| [docs/GDD.md](docs/GDD.md) | 게임 기획서: 방향, 규칙 정의, 전체 구성, UX |
| [docs/levels/](docs/levels/) | 장별 퍼즐 명세 (퍼즐 39개) |
| [docs/TECH.md](docs/TECH.md) | 기술 설계 (Godot 4) |
| [docs/ART_SOUND.md](docs/ART_SOUND.md) | 아트 · 사운드 가이드 |
| [docs/PRODUCTION.md](docs/PRODUCTION.md) | 제작 계획 (2인 개발) |

## 퍼즐 1-1 "끝없는 경사로"

Godot 4.7로 프로젝트를 열고 실행(F5)하면 1-1이 시작된다 (`levels/ch1_parking/p1_1.tscn`).
B2에서 시작한다. 서쪽 경사로를 내려가면 다시 B2가 나오고, 동쪽 경사로를 거슬러 올라가면 B3에 도착한다.

- F2: 디버그 표시 (반복 횟수, 힌트 단계, 위치, FPS)
- 자동 테스트: `godot --path . res://levels/ch1_parking/p1_1.tscn -- --test=down|up|tour|hints --out=<폴더>`
  - `down`, `up`: 자동으로 걸어 관문을 지나게 하고, 순간이동 직전·직후 화면의 차이를 출력한다
  - `--hint-scale=100`: 힌트 시간을 100배 빠르게

## 룩 테스트: 지하 주차장 B2 한 층

실사 느낌을 확인하기 위한 시험 장면 (`levels/lookdev/parking_b2.tscn`). 편집기에서 이 장면을 열고 F6으로 실행한다.

- 조작: WASD 걷기, Shift 천천히, Ctrl 웅크리기, 마우스 둘러보기, Esc 마우스 풀기, F12 스크린샷
- 장면: `levels/lookdev/parking_b2.tscn` (조립 스크립트 `parking_builder.gd`)

### 에셋 다시 만들기

모델과 텍스처는 Blender 스크립트로 만든다. 스크립트를 고친 뒤 아래를 실행하고 Godot에서 다시 가져온다.

```bash
blender --background --factory-startup --python tools/blender/gen_textures.py -- assets/textures/parking
blender --background --factory-startup --python tools/blender/parking_kit.py -- assets/models/parking
```

### 스크린샷 자동 촬영

```bash
godot --path . --windowed --resolution 1600x900 res://levels/lookdev/parking_b2.tscn -- --shots=<저장할 폴더>
```
