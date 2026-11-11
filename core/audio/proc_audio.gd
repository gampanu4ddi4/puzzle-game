## 임시 소리: 녹음한 소리가 생기기 전까지 코드로 만든 소리를 쓴다.
## 모두 22050 Hz 모노 16비트.
class_name ProcAudio
extends RefCounted

const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## 형광등 안정기의 웅웅거림 (3초 반복. 주파수가 3초에 정수 주기라 이음새가 없다).
static func hum() -> AudioStreamWAV:
	var n := RATE * 3
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.5 * sin(TAU * 120.0 * t) + 0.22 * sin(TAU * 240.0 * t) + 0.12 * sin(TAU * 360.0 * t + 0.7) + 0.05 * sin(TAU * 1200.0 * t)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		s[i] = (v * 0.55 + lp * 0.35) * 0.35
	return _wav(s, true)


## 물방울 하나.
static func drip(seed: int = 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var f0 := rng.randf_range(1300.0, 1900.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * (0.55 + 0.45 * exp(-t * 30.0))
		phase += TAU * f / RATE
		var env := exp(-t * 18.0) * minf(1.0, t * 800.0)
		s[i] = sin(phase) * env * 0.6
	return _wav(s)


## 발소리 (콘크리트). 변형마다 seed를 다르게.
static func footstep(seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var cutoff := rng.randf_range(0.12, 0.2)
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * cutoff
		lp2 += (lp - lp2) * 0.35
		var env := exp(-t * rng.randf_range(38.0, 50.0)) * minf(1.0, t * 1500.0)
		var thump := sin(TAU * 85.0 * t) * exp(-t * 55.0) * 0.6
		s[i] = (lp2 * 1.8 + thump) * env * 0.7
	return _wav(s)


## 방화셔터가 내려와 닫히는 소리: 낮은 굉음 + 끝의 쇳소리.
static func shutter() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := int(RATE * 1.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var clang_at := 1.25
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.05
		var rattle := lp * (0.6 + 0.4 * sin(TAU * 18.0 * t)) * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(1.1, 1.3, t))
		var c := 0.0
		if t > clang_at:
			var tc := t - clang_at
			c = (sin(TAU * 310.0 * tc) * 0.5 + sin(TAU * 523.0 * tc) * 0.3 + sin(TAU * 871.0 * tc) * 0.2) * exp(-tc * 6.0)
			c += rng.randf_range(-1.0, 1.0) * exp(-tc * 40.0) * 0.6
		s[i] = (rattle * 1.4 + c) * 0.6
	return _wav(s)


## 차단기 팔이 내려오는 소리: 모터 소리 + 멈출 때 덜컥.
static func barrier() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := int(RATE * 1.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var run := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(1.35, 1.45, t))
		phase += TAU * (95.0 + 25.0 * t) / RATE
		var motor := (fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.25 + sin(phase * 3.0) * 0.1
		var thud := 0.0
		if t > 1.42:
			var tc := t - 1.42
			thud = sin(TAU * 140.0 * tc) * exp(-tc * 25.0) * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-tc * 60.0) * 0.4
		s[i] = (motor * run + thud) * 0.6
	return _wav(s)


## 종이를 집는 소리.
static func paper() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var hp := noise - prev   # 높은 소리만 남긴다
		prev = noise
		var env := (sin(t * 38.0) * 0.5 + 0.5) * exp(-t * 7.0) * minf(1.0, t * 200.0)
		s[i] = hp * env * 0.25
	return _wav(s)


## 바깥 밤거리: 멀리서 들리는 도시의 낮은 웅웅거림 (4초 반복).
static func city() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var n := RATE * 4
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		s[i] = (lp2 * 6.0 + sin(TAU * 55.0 * t) * 0.03) * (0.8 + 0.2 * sin(TAU * 0.25 * t))
	return _wav(s, true)


## 매달린 쇠막대에 부딪힌 소리: 둔탁한 쇳소리 + 체인 짤랑임.
static func clank() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var n := int(RATE * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var hit := (sin(TAU * 220.0 * t) * 0.5 + sin(TAU * 587.0 * t) * 0.3 + sin(TAU * 1130.0 * t) * 0.2) * exp(-t * 9.0)
		var chain := 0.0
		for k in 4:
			var tk := t - 0.08 - 0.13 * k
			if tk > 0.0:
				chain += sin(TAU * (2400.0 + 300.0 * k) * tk) * exp(-tk * 60.0) * 0.25
		s[i] = (hit + chain + rng.randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.3) * 0.5
	return _wav(s)


## 문 여는 소리: 걸쇠 딸깍 + 경첩 끼익.
static func door_open() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var n := int(RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var latch := (sin(TAU * 1800.0 * t) * 0.5 + rng.randf_range(-1.0, 1.0) * 0.5) * exp(-t * 90.0)
		var tc := maxf(t - 0.08, 0.0)
		phase += TAU * (380.0 + 220.0 * tc) / RATE
		var creak := sin(phase) * sin(TAU * 31.0 * tc) * smoothstep(0.08, 0.15, t) * (1.0 - smoothstep(0.35, 0.55, t)) * 0.12
		s[i] = (latch * 0.7 + creak) * 0.7
	return _wav(s)


## 문 닫히는 소리: 묵직한 쿵 + 걸쇠.
static func door_close() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	var n := int(RATE * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var thud := sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.9 + sin(TAU * 190.0 * t) * exp(-t * 30.0) * 0.4
		var slam := rng.randf_range(-1.0, 1.0) * exp(-t * 55.0) * 0.5
		var tc := t - 0.09
		var latch := 0.0
		if tc > 0.0:
			latch = sin(TAU * 2100.0 * tc) * exp(-tc * 110.0) * 0.3
		s[i] = (thud + slam + latch) * 0.6
	return _wav(s)


## 잠긴 문을 흔드는 소리.
static func door_rattle() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var n := int(RATE * 0.4)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in 3:
			var tk := t - 0.09 * k
			if tk > 0.0:
				v += (sin(TAU * (900.0 + 250.0 * k) * tk) * 0.5 + rng.randf_range(-1.0, 1.0) * 0.5) * exp(-tk * 70.0)
		s[i] = v * 0.45
	return _wav(s)


## 계단실에서 울리는 낮은 바람 소리 (3초 반복).
static func stair_wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54
	var n := RATE * 3
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.03
		lp2 += (lp - lp2) * 0.06
		s[i] = lp2 * 5.0 * (0.6 + 0.4 * sin(TAU * t / 3.0))
	return _wav(s, true)


## 작은 딸깍 소리 (표지판이 바뀔 때 등).
static func click() -> AudioStreamWAV:
	var n := int(RATE * 0.06)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 2200.0 * t) * exp(-t * 120.0) * 0.4
	return _wav(s)


## 공간 울림을 넣은 효과음 버스를 만든다 (이미 있으면 그대로 쓴다).
static func ensure_reverb_bus(name: String, room_size: float, wet: float) -> String:
	if AudioServer.get_bus_index(name) != -1:
		return name
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = room_size
	rev.damping = 0.35
	rev.spread = 0.8
	rev.wet = wet
	rev.dry = 0.85
	rev.predelay_msec = 40.0
	AudioServer.add_bus_effect(idx, rev)
	return name
