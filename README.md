# puzzle-game

1인칭 리미널 스페이스 공간 퍼즐 게임 (가제: 새솔센터) · PC · Godot 4

문 닫은 복합센터. 주차장은 되돌아가야 나아가고, 수영장은 같은 타일끼리 이어지고, 학교는 보지 않을 때 바뀐다.

## 실행하기

```bash
git clone https://github.com/gampanu4ddi4/puzzle-game.git
```

| | Windows | Ubuntu (Linux) |
|---|---|---|
| 게임 실행 (퍼즐 1-1부터) | `play.bat` 더블클릭 | `./play.sh` |
| Godot 편집기로 열기 | `edit.bat` | `./edit.sh` |

설치할 것은 없다. 처음 실행하면 스크립트가 알아서 준비한다.
1. Godot 4.7.2가 `.tools/godot`에 없으면 공식 배포 파일(Windows 약 86 MB, Linux 약 78 MB)을 내려받아 푼다.
   Ubuntu에서는 내려받기에 `curl` 또는 `wget`이 필요하다 (보통 기본으로 있다).
2. 에셋을 처음 한 번 가져온다 (약 1분).
3. 게임 첫 실행 때 간접광을 굽는다 (약 1초).

`.tools`와 `.godot` 폴더는 PC마다 따로 만들어지며 저장소에 올라가지 않는다.

Ubuntu 참고:
- Vulkan을 지원하는 그래픽 드라이버가 필요하다 (최근 Ubuntu의 기본 Mesa 드라이버나 NVIDIA 드라이버면 된다).
- 한글 간판은 `Noto Sans CJK KR` 글꼴로 나온다. 한글이 네모로 보이면 `sudo apt install fonts-noto-cjk`.

## 기획 문서

| 문서 | 내용 |
|---|---|
| [docs/GDD.md](docs/GDD.md) | 게임 기획서: 방향, 규칙 정의, 전체 구성, UX |
| [docs/levels/](docs/levels/) | 장별 퍼즐 명세 (퍼즐 39개) |
| [docs/TECH.md](docs/TECH.md) | 기술 설계 (Godot 4) |
| [docs/ART_SOUND.md](docs/ART_SOUND.md) | 아트 · 사운드 가이드 |
| [docs/PRODUCTION.md](docs/PRODUCTION.md) | 제작 계획 (2인 개발) |

## 프롤로그 + 퍼즐 1-1 "끝없는 경사로"

실행하면 메인 화면(새로 시작 · 설정 · 크레딧 · 게임 종료)이 뜨고, 뒤로 프롤로그 거리 장면이 보인다. "새로 시작"을 누르면 그 자리(건너편 인도)에서 바로 시작한다 (`levels/ch1_parking/p1_1.tscn`).
설정은 `user://settings.cfg`에 저장된다 (Windows: `%APPDATA%\Godot\app_userdata\새솔센터`).
연석을 넘고, 정산소 창문을 열어 주차권을 줍고, 셔터 밑을 웅크려 지나 B1을 거쳐 B2로 내려간다.
B2에서는 서쪽 나선을 내려가면 다시 B2가 나오고, 내려온 동쪽 나선을 거슬러 올라가면 B3에 도착한다.

- 조작: WASD 걷기, 마우스 둘러보기, Space 점프, Ctrl 웅크리기, E 상호작용, Shift 달리기, Esc 일시정지, F2 디버그 표시
- B2에서 바로 시작: `godot --path . -- --start=b2` (1-2 시작은 `--start=b3`, 1-3 시작은 `--start=b4`)
- 자동 테스트: `godot --path . res://levels/ch1_parking/p1_1.tscn -- --test=prologue|menu|down|downback|up|tour|hints|p12|p13 --out=<폴더>`
  - `prologue`: 프롤로그를 처음부터 B2까지 자동으로 걷는다
  - `menu`: 메인 화면, 설정, 크레딧, 일시정지 화면을 찍고 설정이 적용되는지 확인한다
  - `down`, `downback`: 자동으로 걸어 관문을 지나게 하고, 순간이동 직전·직후 화면의 차이를 출력한다
  - `--hint-scale=100`: 힌트 시간을 100배 빠르게

## 룩 테스트: 지하 주차장 B2 한 층

실사 느낌을 확인하기 위한 시험 장면 (`levels/lookdev/parking_b2.tscn`). 편집기에서 이 장면을 열고 F6으로 실행한다.

- 조작: WASD 걷기, Shift 달리기, Ctrl 웅크리기, 마우스 둘러보기, Esc 마우스 풀기, F12 스크린샷
- 장면: `levels/lookdev/parking_b2.tscn` (조립 스크립트 `parking_builder.gd`)

### 에셋 다시 만들기

모델과 텍스처는 Blender 스크립트로 만든다. 스크립트를 고친 뒤 아래를 실행하고 Godot에서 다시 가져온다.

```bash
blender --background --factory-startup --python tools/blender/gen_textures.py -- assets/textures/parking
blender --background --factory-startup --python tools/blender/parking_kit.py -- assets/models/parking
blender --background --factory-startup --python tools/blender/gen_street_textures.py -- assets/textures/street
blender --background --factory-startup --python tools/blender/street_kit.py -- assets/models/street
```

### 스크린샷 자동 촬영

```bash
godot --path . --windowed --resolution 1600x900 res://levels/lookdev/parking_b2.tscn -- --shots=<저장할 폴더>
```
