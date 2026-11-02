class_name Proj extends RefCounted
## One player-side projectile / zone / bolt. Behaviour lives in Projs.

enum K { BULLET, BOOM, ORBIT, BIRD, ZONE, BOLT, WAVE, MUDBALL }

var kind: int = K.BULLET
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var dmg: float = 1.0
var r: float = 8.0
var life: float = 1.0
var max_life: float = 1.0
var age: float = 0.0
var pierce: int = 0
var kb: float = 0.0
var rot: float = 0.0
var spin: float = 0.0
var scale_f: float = 1.0
var ang: float = 0.0
var rad: float = 0.0
var tick: float = 0.0
var tick_rate: float = 0.4
var hits: Dictionary = {}
var w: Weapon = null
var tex: String = ""
var a: float = 0.0
var b: float = 0.0
var c: float = 0.0
var st: int = 0
var color := Color.WHITE
var flags: int = 0
var dead: bool = false
var src := Rect2()
var tvec := Vector2.ZERO
var chain: int = 0
var evo: bool = false
