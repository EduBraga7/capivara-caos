class_name Enemy extends RefCounted
## Plain data container for one enemy (normal, elite, mini-boss or boss).

enum AI { CHASE, WEAVE, DASH, SWOOP, HOP, SHOOT, CHARGE, LEAP, SNAKE }

static var next_uid: int = 1

var uid: int = 0
var id: String = ""
var ai: int = AI.CHASE
var pos := Vector2.ZERO
var kb := Vector2.ZERO          # knockback velocity (decays)
var hp: float = 1.0
var max_hp: float = 1.0
var spd: float = 50.0
var dmg: float = 5.0
var r: float = 10.0
var xp: float = 1.0
var scale_f: float = 1.0        # sprite scale
var frames: int = 2
var fps: float = 8.0
var anim: float = 0.0
var face: float = 1.0
var flash: float = 0.0
var slow: float = 0.0
var stun: float = 0.0
var elite: bool = false
var big: bool = false           # lives in the "bigs" list (not in the grid)
var boss: bool = false          # the final boss
var dead: bool = false
var st: int = 0                 # ai state
var t1: float = 0.0
var t2: float = 0.0
var dir := Vector2.ZERO
var phase: float = 0.0
var age: float = 0.0
var src: Array = []             # Array[Rect2] animation frames (atlas pixels)
var wsize := Vector2.ZERO       # drawn size (px) of a frame at scale 1
var parts: PackedVector2Array = PackedVector2Array()   # snake body positions
var part_r: PackedFloat32Array = PackedFloat32Array()
var trail: PackedVector2Array = PackedVector2Array()
var head_ang: float = 0.0
var name_pair: Array = []
var enraged: bool = false

func _init() -> void:
	uid = next_uid
	next_uid += 1

static func ai_from(s: String) -> int:
	match s:
		"weave": return AI.WEAVE
		"dash": return AI.DASH
		"swoop": return AI.SWOOP
		"hop": return AI.HOP
		"shoot": return AI.SHOOT
		"charge": return AI.CHARGE
		"leap": return AI.LEAP
		"snake": return AI.SNAKE
	return AI.CHASE

## Does a circle (p, rad) touch this enemy? Snake bosses test every body part.
func overlaps(p: Vector2, rad: float) -> bool:
	if parts.size() > 0:
		for i in parts.size():
			var rr: float = part_r[i] + rad
			if parts[i].distance_squared_to(p) <= rr * rr:
				return true
		return false
	var rr2 := r + rad
	return pos.distance_squared_to(p) <= rr2 * rr2

## Closest point of the enemy to p (for knockback direction / contact).
func closest_part(p: Vector2) -> Vector2:
	if parts.size() == 0:
		return pos
	var best := parts[0]
	var bd := 1e12
	for q in parts:
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	return best
