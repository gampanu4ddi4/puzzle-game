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
