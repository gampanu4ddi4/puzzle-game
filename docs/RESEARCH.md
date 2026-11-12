# 공포·퍼즐 재기획 조사 보고서

> 조사·열람일: 2026-11-12 · 대상: 요청한 7개 게임
> **장문 비평·체험기 15개, Steam 추천 35개·비추천 35개, 개발진 자료 2개를 검토한 정성 조사입니다. 전체 리뷰를 전수 조사했다는 뜻이 아닙니다.**
> 여기의 메커니즘 평가는 출처 작성자의 경험·해석이며 게임의 현재 버전을 직접 실행해 검증한 사실이 아닙니다. 새솔센터도 실행·빌드·테스트하지 않았습니다.

## 1. 선결론

위협의 외형보다 **플레이어가 무엇을 믿고, 무엇을 시험하고, 그 결과 무엇을 할 수 있는가**를 가져옵니다. 다만 적·사망·협동을 뺀 새솔센터에서 같은 공포 효과가 생긴다는 보장은 없습니다. 따라서 ‘괴물 없는 리썰 컴퍼니’를 복제하지 않고, 공간의 수·연결·거리·기록에 대한 판단을 게임의 주된 상호작용으로 만듭니다.

가장 큰 설계 위험은 규칙을 알면 남은 구간이 단순 반복으로 변하는 것입니다. 반대로 모든 정보를 불확실하게 만들면 실험도 의미를 잃습니다. **행동 결과는 정직하게, 공간이 이렇게 존재하는 이유는 불확실하게** 남깁니다. 특정 방향 이동·잠수·고개 돌리기를 공통 해법으로 정하지 않습니다.

## 2. 조사 방법과 한계

- 장문 자료는 작품별 두 개를 기준으로 선정했습니다. 파피 플레이타임은 버전별 차이를 구분하기 위해 보완 비평 하나를 더 읽었습니다.
- Steam 공개 페이지에서 추천·비추천을 따로 열람하고, 다음 페이지의 공개 링크를 따라 자료를 확보했습니다. JSON 리뷰 API는 HTML 응답으로 바뀌어 사용하지 못했습니다. 로그인·쿠키·개인 계정은 사용하지 않았습니다.
- 우선 30단어 이상의 후기를 후보로 삼은 뒤 원문을 읽어 무관한 복사문·방송 대본·레시피·미술문자·단순 한 줄 농담을 제외했습니다. 구체적인 입력·결과가 있는 짧은 사건 서술과 공략형 추천은 유형을 구분해 포함했습니다.
- 추천/비추천은 Steam의 작성자 선택입니다. 추천 안의 비판, 비추천 안의 칭찬도 그대로 반영합니다. 이를 긍정/부정 감정이 순수하게 분리된 표본이라고 해석하지 않습니다.
- 표본은 유용성 정렬에 영향을 받는 의도 표집이며 통계적으로 대표적이지 않습니다. 퍼센트·매출·바이럴 인과·현재 버그 존재 여부를 이 표본으로 계산하지 않습니다.
- 개별 후기 링크·원문에 표시된 작성일·짧은 의역만 남깁니다. 연도가 생략된 날짜는 임의로 보충하지 않습니다. 정확한 빌드 번호는 대부분 공개 본문에 없어 ‘미표시’입니다. Early Access 표시는 출시 시점·업데이트 이전 경험이라는 한계와 함께 읽습니다.
- **자료의 질 부족:** 후즈 앳 더 도어의 Gaming.net 글은 데모 대상이고, Game Critix는 구체적인 플레이 환경·버전·직접 플레이 근거가 부족합니다. 장문 링크 두 개를 확보했어도 두 개의 동등하게 강한 검증 자료는 아닙니다. 해당 작품은 구체적인 사용자 후기와 교차해 판단합니다.
- **주제의 편향:** 파피의 비추천 상위 표본은 과거 가격·분할 판매·부가 상품에 대한 거부감 비중이 큽니다. 이것을 퍼즐 품질이 낮다는 증거로 바꾸지 않습니다. 미확인 개발사 비위·봇·AI 기술 주장 등은 사실로 전재하지 않습니다.

### 장문 자료 목록

| ID | 원문·작성자 | 날짜·대상 | 사용할 근거와 제한 |
|---|---|---|---|
| E01 | [PC Gamer · Omri Petitte](https://www.pcgamer.com/five-nights-at-freddys-review/) | 2014-08-25, FNAF 원작 PC | 예상되는 위험·제한 관찰, 패턴 학습 뒤 감소하는 긴장 |
| E02 | [Nintendo Life · Mitch Vogel](https://www.nintendolife.com/reviews/switch-eshop/five_nights_at_freddys) | 2019-12-02, 원작 Switch 이식 | 분위기·음향과 반복 피로, 이식 조작 문제는 PC 일반화 금지 |
| E03 | [Pure Xbox · Fraser Gilbert](https://www.purexbox.com/reviews/xbox-series-x/poppy-playtime-chapter-1) | 2024-07-15, Chapter 1 Xbox | 상호작용·퍼즐과 불안의 결합, 짧은 챕터라는 조건 |
| E04 | [Pocket Tactics · Kayleigh Partleton](https://www.pockettactics.com/poppy-playtime/chapter-1-mobile-review) | 2023-10-06 업데이트, Chapter 1 모바일 | 익숙한 장소의 뒤틀림·호기심, 카메라·성능 문제는 플랫폼 한정 |
| E05 | [Corrosion Hour · Voice in My Head](https://www.corrosionhour.com/lethal-company-review/) | 2024-01-15/22 표기, 초기 접근 | 차폐·거리·적 행동 학습, 같은 실내 구조의 반복 비판 |
| E06 | [UCLA ACM Studio · Andrew Douglas/그룹 토론](https://studio.uclaacm.com/league-of-analysts/loa-lethal-company) | 본문 January 회의, 정확한 게시일·빌드 미표시 | 혼자/함께의 차이, 정보 없이 치르는 지식 시험 비판 |
| E07 | [PC Gamer · Elie Gould](https://www.pcgamer.com/games/horror/r-e-p-o-is-my-new-favourite-co-op-horror-game-which-combines-lethal-companys-looting-loop-with-content-warnings-zany-monsters/) | 2025-03-07, 초기 체험기 | 운반 행동·손실·사건의 연결, 완성판 정식 리뷰와 구분 |
| E08 | [CultureSlate · Chris Streetman](https://www.cultureslate.com/gaming-reviews/repo-spoiler-free-review) | 본문 May 24, 연도·빌드 미표시 | 협동이 조작 불편을 상쇄한다는 평가, 싱글 이식 한계 |
| E09 | [Try Hard Guides · Erik Hodges](https://tryhardguides.com/mimesis-early-access-review/) | 2025-12-10, Early Access | 간파하기 쉬운 모방과 발견 보상 부족에 대한 비판 |
| E10 | [Opium Pulses · LilyR](https://www.opiumpulses.com/article/1009/mimesis-review) | 원문 09.08.2026, 2026-06 업데이트 이후 | 모방의 설득력 칭찬, 적 밀도·경제·반복에 대한 비판 |
| E11 | [Gaming.net · Jord Tury](https://www.gaming.net/reviews/whos-at-the-door-review-pc/) | 2025-06 초기 글/2026-04-02 업데이트 표기, 데모 | 좁은 공간·판단 불안에 대한 평가. 현재 완제품의 세부 계약 근거로 사용 금지 |
| E12 | [Game Critix · nspme](https://gamecritix.co.uk/whos-at-the-door-review/) | 2025-11-28, 버전·직접 플레이 근거 불명 | 절제·반복의 장단점이라는 비평 의견만 참고, 신뢰도 낮음 |
| E13 | [God is a Geek · Lyle Pendle](https://godisageek.com/reviews/the-exit-8-review/) | 2024-07-01, Switch | 기준 공간 학습·기억 의심·작고 큰 변화의 배합 |
| E14 | [Nintendo Life · Ollie Reynolds](https://www.nintendolife.com/reviews/nintendo-switch-2/the-exit-8-nintendo-switch-2-edition) | 2025-08-30, Switch 2 Edition | 미세한 차이 누락·진행 초기화의 답답함, 추가 이상 현상 버전 |
| E15 | [Gaming Respawn · Will Worrall](https://gamingrespawn.com/featured/64155/poppy-playtime-review-ch-1-4/) | 2026-02-08, Chapters 1–4 회고 | 보완 검토: 1장의 압축된 도입과 3장의 단서·버그 비판을 구분 |

## 3. 작품별 분석: 관찰과 새솔센터의 선택

### 프레디 피자가게 — 예상과 관찰의 비용

**관찰:** E01·E02는 적이 등장하는 순간뿐 아니라 확인하지 못한 상태에서 생기는 불안, 제한된 행동과 환경음의 효과를 설명합니다. 동시에 패턴을 안 뒤에는 같은 확인 순환과 놀람이 닳는다고 평가합니다. U-FNAF-P4의 공략도 행동이 정형 순환으로 압축될 수 있음을 보여 줍니다.

**설계 해석:** 관찰할 대상과 무엇을 확인할지 선택하는 일은 가져오되 배터리·죽음·시간 압박은 옮기지 않습니다. 새솔센터 P07은 정보의 출처를 시험하고 P08은 유지할 부분을 선택합니다. 단순 카메라 순회가 오래 남으면 실패입니다.

**제외:** 마스코트·점프 스케어·문 닫기 타이밍·동일 밤의 난도 상승. 안전을 알게 된 뒤에도 긴장이 지속된다고 가정하지 않고, 새 공간적 질문이 남는지 평가합니다.

### 파피 플레이타임 — 장소를 건드리는 행동과 호기심

**관찰:** E03·E04는 손으로 환경과 상호작용하는 퍼즐, 시설의 분위기, 이야기의 조각이 만드는 호기심을 높게 평가합니다. E04의 이동·카메라 불편은 추격에서 특히 큰 문제였고, E15는 후반 단서 판독과 버그를 별도로 비판합니다. 사용자 비추천에는 당시 판매 방식에 대한 거부도 있어 평가 이유를 분리해야 합니다.

**설계 해석:** 퍼즐을 벽에 붙은 암호가 아닌 실제 설비의 목표로 만듭니다. P02는 판으로 건넌 뒤 상태를 바꾸고, P06은 부력대를 보내 계단을 내립니다. 중요한 사실은 배경 글보다 조작 결과로 전달합니다.

**제외:** GrabPack 모방·장난감 괴물·추격·필수 영상 감상·짧은 체험을 억지로 늘리는 수집 과제. 몸 조작의 불편을 공포라고 부르지 않습니다.

### 리썰 컴퍼니 — 공간의 소리가 행동을 설명

**관찰:** E05·E06과 U-LETHAL-P1/P2/P4/P5에는 떨어진 사람의 소리, 차폐, 갑자기 바뀌는 상황이 경험의 핵심으로 등장합니다. E06은 살아남는 데 필요한 정보를 쉽게 얻지 못하는 실패도 지적합니다. 사용자 비판에는 장기 목표·공간 반복·참가 환경이 각각 나타납니다.

**설계 해석:** 사람의 비명 대신 같은 설비 소리의 거리·차폐·원인을 설계합니다. P05에서는 소리 주소와 실제 배수 노선을 비교할 수 있습니다. 입력에 반응하는 시각 증거가 있어야 잘못된 추론을 수정할 수 있습니다.

**제외:** 음성 채팅·친구의 죽음·할당량·랜덤 적 조합. 협동에서 생기는 웃음과 이야기 생산을 싱글에서 자동으로 얻는다고 가정하지 않습니다.

### R.E.P.O. — 행동이 사건을 만드는 힘과 마찰의 비용

**관찰:** E07·E08은 운반·충돌·대화가 사건을 만들지만, 혼자서는 같은 조작이 지루하거나 불편할 수 있다고 봅니다. 비추천 표본에는 난도, 색 구분, 멀미, 민감한 물리, 재시도 손실이 나타납니다. 추천 표본 일부는 게임 자체보다 첫인상을 해치는 배너를 이야기합니다.

**설계 해석:** P03·P06처럼 물체가 실제 공간 관계의 일부가 되게 하되, 고정 고리·레일·정지점으로 결과를 예측 가능하게 합니다. 실패의 원인을 손재주와 불안정한 물리로 돌리지 않습니다. 어두운 화면·흔들림으로 몰입을 강요하지 않습니다.

**제외:** 자유 물리 운반·가격 손실·팀원 장난·지속 난도 상승. 홍보에서도 익숙한 공포 이미지보다 실제 공간적 발견을 먼저 보여 줍니다.

### 미메시스 — 믿던 정보에 대한 재검증과 발견 보상

**관찰:** E09의 2025년 비평은 반복 문장과 행동으로 모방을 쉽게 간파한다고 보고, E10의 업데이트 후 평가는 더 설득력 있는 반응을 경험했다고 설명합니다. 사용자 표본도 양쪽 경험이 공존합니다. 이를 같은 빌드에 대한 모순으로 단정하지 않습니다. 알아챘는데도 대응할 수 없는 실패는 여러 비판에서 나타납니다.

**설계 해석:** 신뢰했던 자료를 다시 시험하게 만들되, 알아낸 사실이 해결 능력으로 이어져야 합니다. P07의 화면 검증, P09의 중복 회로, P11의 중복 사건은 판단 후 바로 행동을 바꿀 수 있습니다. 시스템 구현 방식에 대한 리뷰어의 AI 추측은 기술 사실로 사용하지 않습니다.

**제외:** 사람 모방·음성 수집·실시간 AI·사회적 의심·불투명한 적 학습. 판별 뒤에도 무조건 실패하는 장면은 만들지 않습니다.

### 후즈 앳 더 도어 — 익숙한 공간과 불명확한 판정의 경계

**관찰:** 데모 비평 E11은 좁은 공간에서 방문자·이상 여부를 판단하는 불안을 긍정적으로 봅니다. 그러나 U-DOOR-N3/N4/N5는 무엇을 이상으로 세는지와 반복 실행 이유가 불분명하다고 설명합니다. E12의 절제된 공포라는 평가는 일부 실제 사용자 경험과 어긋나므로 일반 사실로 사용하지 않습니다.

**설계 해석:** 공간을 먼저 익히게 하되 플레이어가 알아낸 변화의 인과를 유지합니다. P01은 입력으로 동일성을 검증하고, P11은 틀렸다면 어느 사건이 두 번 기록됐는지 남깁니다. 놀라운 장면과 정답에 필요한 단서를 혼동시키지 않습니다.

**제외:** 약 복용·질환·방문자 판단·미세한 장식 누락으로 전체 진행 초기화. 새로운 퍼즐 대신 같은 방 검사 순서가 남으면 축소합니다.

### 8번 출구 — 기준을 배운 뒤 생기는 자기 의심

**관찰:** E13과 사용자 추천은 정상 공간을 익힌 뒤 기억을 재검사하는 재미와 불안을 설명합니다. E14와 비추천은 사소한 누락·초기화·되풀이 검사가 분위기를 작업으로 바꾼다고 평가합니다. U-EXIT8-N3의 버그 주장은 직접 재현하지 않았으므로 버그 존재의 증거로 확정하지 않습니다.

**설계 해석:** 정상 기준과 크고 작은 차이의 대조만 가져옵니다. 차이를 발견하면 방향을 뒤집는 공식은 가져오지 않습니다. 새솔센터의 차이는 관찰·실험·공간 조작의 재료입니다. 정답을 알면 같은 복도를 여러 번 검사하지 않아도 됩니다.

**제외:** 이상이면 후진/없으면 전진·연속 성공 횟수·전면 리셋·작은 차이를 무제한 암기하는 검문. 의도된 모순과 버그처럼 보이는 현상을 구분할 증거가 필요합니다.

## 4. 퍼즐 보완 자료: 개발진이 말한 발견

| ID | 자료·실제 열람 범위 | 적용 |
|---|---|---|
| D01 | [GDC 2021 · Kelsey Beachum, curiosity-driven narrative](https://www.gdcvault.com/play/1027368/Independent-Games-Summit-Sparking-Curiosity) — 공개 세션 개요. 강연 영상을 시청했다고 주장하지 않음 | 외부 임무 지시보다 공간 안의 질문과 발견이 진행 이유가 되도록 함 |
| D02 | [Alex Beachum 인터뷰 · Cordial Kobold](https://medium.com/@cordialkobold/interview-with-alex-beachum-creative-director-of-outer-wilds-a01bb9631e20) — 인터뷰 2023-04-26, 공개 2025-06-26. 지식 기반 진행·단서 전달·오해 대응 부분 | 지식이 실제 행동 가능성을 바꾸고, 핵심 단서가 장식 서사로만 읽히지 않도록 함 |

D02에서 개발자는 장소를 하나씩 ‘청소’하기보다 질문을 따라 다른 곳의 정보를 연결하는 진행을 설명합니다. 또한 알아야 할 정보를 충분히 전달하지 못한 문제를 플레이어 잘못으로 돌리지 않습니다. 새솔센터는 이를 **가설·구별 실험·결과**라는 레벨 작성 형식으로 적용합니다. 원작의 세계 규모·시간 반복·텍스트 양을 모방하지 않습니다.

연구에서 도출한 설계 기준은 다음과 같습니다. 이는 새솔센터에서 아직 검증하지 않은 선택입니다.

1. 진행을 막는 것은 물건 수집 개수가 아니라 아직 이해하지 못한 관계여야 합니다.
2. 옳은 판단은 더 나은 선택으로 이어져야 합니다. 알아차려도 의미가 없으면 발견의 보상이 사라집니다.
3. 공포 장식과 기능 단서를 구분합니다. 혼란이 있어도 확인할 방법은 있어야 합니다.
4. 반복되는 조작이 아니라 서로 다른 사고를 비교합니다. 같은 입력을 쓴다고 같은 퍼즐은 아니지만, 같은 발견만 남으면 통합합니다.
5. 반복 검사·자유 물리의 불편·암전·불공정한 손실을 난도로 계산하지 않습니다.

## 5. 반론·전이 한계·검증 과제

**실제 위협이 없으면 덜 무서울 수 있습니다.** 맞습니다. 여기의 목표는 습격 예상이 아니라 공간과 기록의 모순을 직접 확인한 뒤에도 남는 불편함입니다. 불안·호기심·답답함·통제감을 따로 묻는 평가를 계획하며, 높은 불안 하나로 성공을 선언하지 않습니다.

**정해진 장치가 많으면 실험실 퍼즐처럼 보일 수 있습니다.** 모든 장치를 정답용 형광색으로 칠하지 않고 기존 시설의 유지보수 목적을 먼저 읽히게 합니다. 그러나 생활감 때문에 기능을 숨겨서는 안 됩니다. P05·P09가 단순 선택기 작업으로 남으면 짧은 연결 장면으로 축소합니다.

**클립이 잘 나오면 바이럴이 되나요?** 이 자료만으로 인과를 확정할 수 없습니다. 협동의 웃음·가격·기존 팬·스트리머 노출·업데이트 시기도 영향을 줍니다. 새솔센터는 정상 장면과 불가능한 결과를 한 장면 안에서 비교하기 쉽게 설계하되 조회수·판매량을 보장하지 않습니다.

**같은 문법을 쓰면 결국 또 반복 아닌가요?** 문법은 재사용하되 목표·상충 조건·확인 실험·예측할 관계가 달라야 합니다. [GDD의 비교표](GDD.md#4-전체-진행)와 [제작 계획](PRODUCTION.md)의 축소 기준으로 판단합니다. 현재 11개를 지키기 위해 재미없는 방을 남기지 않습니다.

## 6. Steam 후기 표본 원장

각 행은 해당 URL의 독립 후기 하나입니다. 아래 ‘요지’는 작성자의 의견을 짧게 의역한 것이며 현재 게임의 사실 확인이나 원문 인용이 아닙니다. 날짜는 원문 표시 그대로입니다. 긍정/부정이 아닌 **추천/비추천 버튼** 기준으로 분류합니다. 구체 빌드 미표시, 조회일은 모두 2026-11-12입니다.

### 프레디 피자가게

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-FNAF-P1 | 추천 | [Locust](https://steamcommunity.com/id/Lolcust/recommended/319510/) | August 19, 2014 | 제한된 관찰·자원과 음향이 불안을 만들고, 실수는 통제 가능한 행동의 결과라고 평가. |
| U-FNAF-P2 | 추천 | [Spirit](https://steamcommunity.com/id/spiritreviews/recommended/319510/) | August 22, 2014 | 야간 공간·작은 소리·적은 조작이 상상과 불안을 키운다는 장문 체험기. |
| U-FNAF-P3 | 추천 | [SourPatchAdult](https://steamcommunity.com/profiles/76561198045179935/recommended/319510/) | August 19, 2014 | 체험 서술 형식: 정상 근무가 작은 위치 변화와 전력 우려로 바뀌는 단계가 핵심. |
| U-FNAF-P4 | 추천 | [Corrupted_Empire](https://steamcommunity.com/profiles/76561198345751787/recommended/319510/) | December 29, 2025 | 공략형 추천: 확인 행동이 일정한 카메라·조명 순환으로 압축됨. 반복 위험의 자료. |
| U-FNAF-P5 | 추천 | [Murphy's Lawyer](https://steamcommunity.com/id/murphyslawyer87/recommended/319510/) | February 13, 2016 | 단순한 조작과 무력감이 짧은 공포 체험에는 효과적이지만 장기 깊이를 기대하지 않는 평가. |
| U-FNAF-N1 | 비추천 | [doobes](https://steamcommunity.com/profiles/76561198067699203/recommended/319510/) | August 25, 2015 | 카메라·문 반복과 익숙해진 놀람이 진행 방해로 변했다고 평가. |
| U-FNAF-N2 | 비추천 | [QuadyOfKippleEyes](https://steamcommunity.com/id/quadyofkippleeyes/recommended/319510/) | September 12, 2014 | 초기 참신함 뒤 반복 실패·자원 압박이 공포보다 피로를 만든다는 장문 비판. |
| U-FNAF-N3 | 비추천 | [Topwaffle](https://steamcommunity.com/id/yukkureimu/recommended/319510/) | July 3, 2015 | 개념에는 흥미가 있으나 실제 실행의 재미는 약하다는 의견. |
| U-FNAF-N4 | 비추천 | [RunnerJake](https://steamcommunity.com/profiles/76561198064598993/recommended/319510/) | October 19, 2014 | 초반의 낮은 자극과 후반의 급격한 난도 상승 사이 간격을 비판. |
| U-FNAF-N5 | 비추천 | [judan ♥](https://steamcommunity.com/id/judanwugnar/recommended/319510/) | March 25, 2016 | 세 번째 밤 뒤 반복감이 커졌다는 의견. 커뮤니티 평가는 설계 근거에서 제외. |

### 파피 플레이타임

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-POPPY-P1 | 추천 | [Mr.Mime](https://steamcommunity.com/profiles/76561198161374486/recommended/1721470/) | 3 November, 2021 | 어두운 길로 들어가기를 망설인 경험. 짧은 분량과 강한 불안이 공존. |
| U-POPPY-P2 | 추천 | [Krisss](https://steamcommunity.com/profiles/76561198967294234/recommended/1721470/) | 16 October, 2021 | 퍼즐과 공포의 결합을 추천하지만 유료 챕터 분량은 아쉽다고 평가. |
| U-POPPY-P3 | 추천 | [DevilBoss](https://steamcommunity.com/id/devilboss/recommended/1721470/) | June 13, 2024 | 습격 자체보다 안전하다고 믿는 순간과 쌓이는 긴장을 칭찬. |
| U-POPPY-P4 | 추천 | [Old Salt](https://steamcommunity.com/profiles/76561198303190605/recommended/1721470/) | March 2, 2024 | 시설 몰입과 퍼즐을 즐기지만 추격 자극이 강해 중단한 경험. |
| U-POPPY-P5 | 추천 | [Arithmya](https://steamcommunity.com/id/arianaher/recommended/1721470/) | October 13, 2021 | 환경 단서·직접 조작이 스스로 풀었다는 감각을 준다고 평가, 일부 버그도 언급. |
| U-POPPY-N1 | 비추천 | [ryderhimself](https://steamcommunity.com/id/ryderhimself/recommended/1721470/) | 25 December, 2021 | 작성자가 과거 첫 챕터·당시 판매 논란에 한정된 오래된 평가임을 직접 명시. |
| U-POPPY-N2 | 비추천 | [to_nate](https://steamcommunity.com/profiles/76561198111052154/recommended/1721470/) | 28 April, 2022 | 설정·퍼즐은 흥미롭지만 분할 판매와 홍보 중심의 인상에 거부감. |
| U-POPPY-N3 | 비추천 | [J-Man](https://steamcommunity.com/id/5_9_2006/recommended/1721470/) | 13 August, 2022 | 콘텐츠 자체보다 구매 후 무료 전환과 추가 결제에 대한 불만. |
| U-POPPY-N4 | 비추천 | [zog](https://steamcommunity.com/profiles/76561198154495679/recommended/1721470/) | 5 June, 2022 | 지불 금액과 짧은 분량·무료 전환의 관계에 대한 불만. |
| U-POPPY-N5 | 비추천 | [kit0.exe](https://steamcommunity.com/profiles/76561198409023675/recommended/1721470/) | 5 May, 2022 | 기본 구매가 전체 콘텐츠 구매가 아니라는 기대 불일치를 지적. |

### 리썰 컴퍼니

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-LETHAL-P1 | 추천 | [John Bloodborn](https://steamcommunity.com/id/jojomemes/recommended/1966720/) | 8 November, 2023 | 거리·차폐가 있는 음성으로 상황이 전달되는 점을 추천. 제안한 새 괴물은 현 기능으로 간주하지 않음. |
| U-LETHAL-P2 | 추천 | [jjhamm](https://steamcommunity.com/id/jjhamm/recommended/1966720/) | 15 November, 2023 | 직접 볼 수 없는 사건이 무전 소리만으로 전달되는 체험을 추천. |
| U-LETHAL-P3 | 추천 | [Caleb](https://steamcommunity.com/id/mescoosie/recommended/1966720/) | November 9, 2023 | 행동의 결과를 조합해 목표에 간신히 도달하는 사건 서술. 실제 규칙의 검증 근거는 아님. |
| U-LETHAL-P4 | 추천 | [BananaNinja124](https://steamcommunity.com/profiles/76561199179564904/recommended/1966720/) | November 25, 2023 | 안내받기·분리·소리·실패 뒤 웃음이 이어지는 협동 체험 서술. |
| U-LETHAL-P5 | 추천 | [RobloxUwU](https://steamcommunity.com/id/Ascendes/recommended/1966720/) | November 7, 2023 | 기억한 위험 정보와 실제 돌발 상황이 결합해 공유할 사건이 된다는 서술. |
| U-LETHAL-N1 | 비추천 | [Undy1ngWill](https://steamcommunity.com/profiles/76561198316294154/recommended/1966720/) | 17 November, 2023 | 순간 플레이는 즐겁지만 끝없는 목표 상승과 진행 상실에 불만. |
| U-LETHAL-N2 | 비추천 | [big floppa gaming](https://steamcommunity.com/profiles/76561198168249920/recommended/1966720/) | 6 November, 2023 | 비슷한 실내 공간 반복으로 장기 탐색 동기가 약하다고 평가. |
| U-LETHAL-N3 | 비추천 | [Fox](https://steamcommunity.com/profiles/76561198239727208/recommended/1966720/) | 27 February, 2024 | 친구 없는 공개 참가 과정의 불편을 비판. 싱글 설계로 직접 옮길 근거 아님. |
| U-LETHAL-N4 | 비추천 | [Derp](https://steamcommunity.com/profiles/76561198382753999/recommended/1966720/) | 6 December, 2025 | 학습 보상보다 어려움·무작위성 상승이 앞선다는 업데이트 시점의 의견. |
| U-LETHAL-N5 | 비추천 | [Girls](https://steamcommunity.com/id/FlannelKat/recommended/1966720/) | December 2, 2023 | 순간 행동은 좋지만 목표·장기 진행 이유가 약하다는 양가 평가. |

### R.E.P.O.

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-REPO-P1 | 추천 | [E. Huxley](https://steamcommunity.com/id/ehuxley/recommended/3241660/) | 4 March, 2025 | 실제 재미와 첫 배너가 주는 저품질 인상 사이의 차이를 지적. |
| U-REPO-P2 | 추천 | [thesmallestbee](https://steamcommunity.com/id/thesmallestbee/recommended/3241660/) | 28 February, 2025 | 작은 완성도와 게임은 칭찬하지만 첫 홍보 이미지가 체험을 방해한다고 평가. |
| U-REPO-P3 | 추천 | [TypicalGiggle](https://steamcommunity.com/profiles/76561199140807660/recommended/3241660/) | 5 April, 2025 | 물리 운반·동료 행동의 연쇄가 예기치 않은 사건을 만든다는 체험 서술. |
| U-REPO-P4 | 추천 | [MM5tar](https://steamcommunity.com/id/mingvin_/recommended/3241660/) | 6 March | 소리→당황→운반 실패→동료 반응으로 이어지는 짧은 행동 서술. |
| U-REPO-P5 | 추천 | [pubbo & sliddy](https://steamcommunity.com/id/tf2olive/recommended/3241660/) | 3 June, 2025 | 게임의 매력과 피드백 대응을 칭찬. 업데이트 사실의 독립 검증 자료는 아님. |
| U-REPO-N1 | 비추천 | [hailstormnightmare](https://steamcommunity.com/profiles/76561198091739293/recommended/3241660/) | 1 November, 2025 | 초반·싱글의 위협 배치가 대응 수단보다 앞선다는 난도 비판. |
| U-REPO-N2 | 비추천 | [Jouskaia](https://steamcommunity.com/id/iamthejouskaia/recommended/3241660/) | 28 February, 2025 | 어두운 색조에서 색 구분이 어려웠다는 접근성 경험. |
| U-REPO-N3 | 비추천 | [c0r3 錢](https://steamcommunity.com/id/spacec0r3/recommended/3241660/) | 15 October, 2025 | 카메라 흔들림·시야 설정이 멀미를 유발했다는 개인 경험. |
| U-REPO-N4 | 비추천 | [meelk](https://steamcommunity.com/profiles/76561198316650023/recommended/3241660/) | 3 March, 2025 | 예측 어려운 물리·적 행동·경제·급격한 상승·재시도 손실을 비판. |
| U-REPO-N5 | 비추천 | [The Fat Lady](https://steamcommunity.com/id/theenbyswitch/recommended/3241660/) | 21 June, 2025 | 대기·무작위 불리함·난도 상승이 재미와 보상을 앞선다고 평가. |

### 미메시스

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-MIMESIS-P1 | 추천 | [ShorkSeven/TTV](https://steamcommunity.com/id/765611980859318199/recommended/2827200/) | 1 November, 2025 | 대화가 쌓일수록 의심이 커진다고 평가하며, 판별 뒤 대응 가능성도 요구. |
| U-MIMESIS-P2 | 추천 | [stankhunt42](https://steamcommunity.com/profiles/76561198965603304/recommended/2827200/) | 24 December, 2025 | 확인 질문·조 편성 등 플레이어가 검증 전략을 만들게 된 경험. |
| U-MIMESIS-P3 | 추천 | [MaxGiacca](https://steamcommunity.com/profiles/76561197981859435/recommended/2827200/) | 25 November, 2025 | 동작으로 진위를 확인하려던 방법까지 따라 해 의심이 커진 체험. |
| U-MIMESIS-P4 | 추천 | [Leon3i](https://steamcommunity.com/profiles/76561199102375851/recommended/2827200/) | 5 November, 2025 | 재미는 인정하나 이동·입구 판독·충돌·탐색 보상을 비판하는 혼합 추천. |
| U-MIMESIS-P5 | 추천 | [ChopSuey](https://steamcommunity.com/profiles/76561198008480668/recommended/2827200/) | 22 December, 2025 | 소리 출처와 눈앞 동료의 모순 하나가 이후 모든 대화를 검증하게 만든 체험. |
| U-MIMESIS-N1 | 비추천 | [Kat With Cigarette](https://steamcommunity.com/id/yeyeasshaircut/recommended/2827200/) | 11 February | 반복 문장·이동이 쉽게 드러나 핵심 속임수가 곧 무력해졌다고 평가. |
| U-MIMESIS-N2 | 비추천 | [一条S胖斧](https://steamcommunity.com/profiles/76561199579982810/recommended/2827200/) | 12 November, 2025 | 진위를 알아차려도 대응 보상 없이 실패하는 점과 조작을 비판. |
| U-MIMESIS-N3 | 비추천 | [DetectiveHailey](https://steamcommunity.com/profiles/76561198884573910/recommended/2827200/) | 14 February | 초기 혼란 뒤 금세 반복되고 모방의 학습이 느리다고 평가. 기술·회사 의혹은 전재하지 않음. |
| U-MIMESIS-N4 | 비추천 | [Dee-Dee](https://steamcommunity.com/profiles/76561198213855328/recommended/2827200/) | 16 June | 업데이트 뒤 적 밀도·이동 여유가 체감 재미를 해쳤다는 시점 한정 의견. |
| U-MIMESIS-N5 | 비추천 | [Psychokiller](https://steamcommunity.com/profiles/76561198169163201/recommended/2827200/) | 8 November, 2025 | 길 안내가 실제 경로를 돕지 못하고 공간·목표가 반복된다는 비판. |

### 8번 출구

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-EXIT8-P1 | 추천 | [Rei](https://steamcommunity.com/id/GothGayCat/recommended/2653790/) | 16 March, 2024 | 최소한의 공간을 반복 확인하며 자기 기억을 의심하는 체험을 상세 설명. |
| U-EXIT8-P2 | 추천 | [MindPlays](https://steamcommunity.com/id/thewaliasahb/recommended/2653790/) | January 19, 2024 | 환경음·빈 공간·발견 만족을 추천하나 미세한 차이의 답답함도 인정. |
| U-EXIT8-P3 | 추천 | [Predator Magnet](https://steamcommunity.com/id/kudredin/recommended/2653790/) | December 3, 2023 | 큰 연출보다 일상 공간의 불편함을 즐겼다는 취향 평가. |
| U-EXIT8-P4 | 추천 | [Skanderous](https://steamcommunity.com/id/hunterosprey/recommended/2653790/) | December 4, 2023 | 단순 기준과 작은 차이가 재확인·의심을 만든다고 평가. |
| U-EXIT8-P5 | 추천 | [WizardLizard](https://steamcommunity.com/profiles/76561197968914206/recommended/2653790/) | December 10, 2023 | 작은 규칙과 재질·음향의 완성도가 짧은 체험에 맞는다고 평가. |
| U-EXIT8-N1 | 비추천 | [Mr Bing](https://steamcommunity.com/profiles/76561198084099911/recommended/2653790/) | 4 December, 2023 | 무엇을 찾아야 하는지 불명확해 반복 검사가 작업이 됐다고 평가. |
| U-EXIT8-N2 | 비추천 | [Noble](https://steamcommunity.com/profiles/76561198045388344/recommended/2653790/) | 6 December, 2023 | 큰 변화 뒤 남은 미세한 차이 검사가 분위기를 소진시킨다고 평가. |
| U-EXIT8-N3 | 비추천 | [Shoom](https://steamcommunity.com/profiles/76561198258199074/recommended/2653790/) | 10 December, 2023 | 변화 없는 방에서 초기화됐다는 버그 주장. 직접 재현하지 않아 사실로 확정하지 않음. |
| U-EXIT8-N4 | 비추천 | [RxMxG](https://steamcommunity.com/id/freestyler_rmg/recommended/2653790/) | 29 October, 2025 | 미세한 누락·진행 초기화·도움 부족이 만드는 답답함을 비판. |
| U-EXIT8-N5 | 비추천 | [Sara](https://steamcommunity.com/id/cummunism/recommended/2653790/) | November 23, 2025 | 위화감은 있지만 할 일이 적어 반복감이 남는다는 의견. |

### 후즈 앳 더 도어

| ID | 분류 | 작성자·원문 | 작성일(원문) | 요지 |
|---|---|---|---|---|
| U-DOOR-P1 | 추천 | [X](https://steamcommunity.com/profiles/76561198369499700/recommended/3690010/) | 20 July, 2025 | 분위기 조성과 보상의 배합을 추천하지만 분량은 짧다고 평가. |
| U-DOOR-P2 | 추천 | [DinnerTimeFun™](https://steamcommunity.com/profiles/76561197986233155/recommended/3690010/) | 31 July, 2025 | 추천 버튼이지만 내용은 조건부: 첫 완료 뒤 남는 변화와 장기 이유가 적다고 평가. |
| U-DOOR-P3 | 추천 | [gimp](https://steamcommunity.com/id/iamgimp/recommended/3690010/) | 2 October, 2025 | 이상 찾기 자체보다 기묘한 분위기와 연출을 추천. |
| U-DOOR-P4 | 추천 | [Sniffhow](https://steamcommunity.com/profiles/76561198040309535/recommended/3690010/) | 1 September, 2025 | 환경 탐색과 사건 구분을 칭찬하면서 시청각 자료의 인상에는 거부도 표함. |
| U-DOOR-P5 | 추천 | [MozyMyers](https://steamcommunity.com/profiles/76561199490025369/recommended/3690010/) | 5 October, 2025 | 현상 발견·이야기 탐색을 즐김. 기기별 달리기 입력 문제는 당시 경험에 한정. |
| U-DOOR-N1 | 비추천 | [lj2000](https://steamcommunity.com/profiles/76561198136554081/recommended/3690010/) | 24 July, 2025 | 시청각 자료의 인상과 저렴하게 느껴진 놀람에 거부. 봇 관련 추측은 제외. |
| U-DOOR-N2 | 비추천 | [TTV / Verauti](https://steamcommunity.com/id/verauti/recommended/3690010/) | 5 August, 2025 | 차이 찾기의 반복과 결말 보상이 약하다는 평가. 자료 제작 의혹은 사실화하지 않음. |
| U-DOOR-N3 | 비추천 | [Suzy~💗](https://steamcommunity.com/id/suzyk94/recommended/3690010/) | 19 July, 2025 | 기능 단서·일시적 연출·수집물을 혼동하게 하는 판정과 반복 검사 과정을 상세 비판. |
| U-DOOR-N4 | 비추천 | [Sanic](https://steamcommunity.com/id/realdarkovidiu/recommended/3690010/) | 27 October, 2025 | 작은 차이를 놓쳐 전체 진행을 잃는 벌이 과하다는 의견. |
| U-DOOR-N5 | 비추천 | [HGxPR0DIGYx](https://steamcommunity.com/profiles/76561199075736379/recommended/3690010/) | 16 October | 이벤트 조건을 알기 위해 외부 공략이 필요하다고 느낀 정보 전달 문제. |

## 7. 후속 산출물과 남은 확인

이 보고서의 선택은 [GDD](GDD.md), [장별 퍼즐 명세](levels/ch1_parking.md), [아트·사운드](ART_SOUND.md), [기술 계약](TECH.md)에 반영합니다. 실제 재미·공포·판독성·접근성·성능은 아직 확인하지 않았습니다. 후속 [사용자 평가 계획](PRODUCTION.md#5-사용자에게-요청할-검증-계획--아직-실행하지-않음)에 따라 별도 요청 후 확인합니다.

조사에서 다루지 않은 것은 게임별 전체 버전의 모든 리뷰, 모든 언어권의 반응, 직접 실행에 의한 메커니즘 재현, 매출·노출량을 통제한 바이럴 원인 분석입니다. 확보한 70개 사용자 후기를 전체 이용자의 합의처럼 표현하지 않습니다.
