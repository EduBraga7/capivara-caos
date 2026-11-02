class_name Defs
## Static game data: weapons, passives, characters, shop, enemies, waves, events.
## Every user-facing string is a [PT, EN] pair resolved through G.L().

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const MAX_WEAPON_LEVEL := 8

# Keys that multiply when a level delta is applied; every other key adds.
const MULT_KEYS := ["dmg", "cd", "area", "spd", "dur", "kb"]

const STAT_NAMES := {
	"dmg": ["Dano", "Damage"],
	"cd": ["Recarga", "Cooldown"],
	"area": ["Área", "Area"],
	"spd": ["Velocidade", "Speed"],
	"dur": ["Duração", "Duration"],
	"kb": ["Empurrão", "Knockback"],
	"pierce": ["Perfuração", "Pierce"],
}

# ---------------------------------------------------------------- weapons
# base: starting stats. levels[i] is the delta applied when reaching level i+1.
const WEAPONS := {
	"orange": {
		"name": ["Laranja", "Orange"],
		"desc": ["Arremessa laranjas no bicho mais próximo.", "Hurls oranges at the nearest critter."],
		"icon": "ic_orange", "amt_name": ["Laranjas", "Oranges"],
		"base": {"dmg": 10.0, "cd": 0.85, "amt": 1, "spd": 560.0, "area": 1.0, "pierce": 0, "dur": 1.4, "kb": 140.0},
		"levels": [{}, {"amt": 1}, {"dmg": 1.3}, {"pierce": 1}, {"cd": 0.85}, {"amt": 1}, {"dmg": 1.3}, {"pierce": 2}],
		"evo": {"partner": "xerox", "id": "orange_evo",
			"name": ["Laranjal Explosivo", "Orange Grove"],
			"desc": ["Laranjas explodem em suco e sementes!", "Oranges burst into juicy chaos!"],
			"mods": {"dmg": 1.6, "amt": 2, "area": 1.3, "cd": 0.85}},
	},
	"flipflop": {
		"name": ["Chinelada", "Flip-Flop"],
		"desc": ["Chinelo-bumerangue. Mãe brasileira nunca erra.", "Boomerang flip-flop. Brazilian moms never miss."],
		"icon": "ic_flipflop", "amt_name": ["Chinelos", "Flip-flops"],
		"base": {"dmg": 15.0, "cd": 2.0, "amt": 1, "spd": 430.0, "area": 1.0, "pierce": 99, "dur": 1.1, "kb": 90.0},
		"levels": [{}, {"area": 1.25}, {"amt": 1}, {"dmg": 1.3}, {"cd": 0.85}, {"amt": 1}, {"area": 1.25}, {"dmg": 1.4}],
		"evo": {"partner": "tenis", "id": "flipflop_evo",
			"name": ["Chinelão Épico", "Epic Flip-Flop"],
			"desc": ["Gigante, em hélice e atordoa tudo!", "Giant, spinning, and stuns everything!"],
			"mods": {"dmg": 1.5, "area": 1.5, "amt": 1, "cd": 0.8}},
	},
	"cheese": {
		"name": ["Pão de Queijo", "Cheese Bread"],
		"desc": ["Pãezinhos orbitam e esmagam tudo no caminho.", "Cheesy buns orbit and smash everything."],
		"icon": "ic_cheese", "amt_name": ["Pães", "Buns"],
		"base": {"dmg": 10.5, "cd": 1.5, "amt": 2, "spd": 3.2, "area": 1.0, "pierce": 0, "dur": 4.0, "kb": 70.0},
		"levels": [{}, {"amt": 1}, {"dmg": 1.3}, {"amt": 1}, {"dur": 1.2, "spd": 1.15}, {"amt": 1}, {"dmg": 1.3}, {"area": 1.3}],
		"evo": {"partner": "cafe", "id": "cheese_evo",
			"name": ["Pão de Queijo Cósmico", "Cosmic Cheese Bread"],
			"desc": ["Dois anéis, sempre ativos, bem mais rápidos!", "Two rings, always on, much faster!"],
			"mods": {"dmg": 1.5, "amt": 3, "spd": 1.25, "cd": 0.0}},
	},
	"repellent": {
		"name": ["Repelente", "Bug Spray"],
		"desc": ["Nuvem tóxica ao redor. Mosquito sofre em dobro.", "Toxic cloud around you. Mosquitoes suffer double."],
		"icon": "ic_repellent", "amt_name": ["Nuvens", "Clouds"],
		"base": {"dmg": 6.5, "cd": 0.42, "amt": 1, "spd": 1.0, "area": 1.0, "pierce": 0, "dur": 1.0, "kb": 45.0},
		"levels": [{}, {"area": 1.2}, {"dmg": 1.3}, {"cd": 0.85}, {"area": 1.2}, {"dmg": 1.3}, {"cd": 0.85}, {"area": 1.25}],
		"evo": {"partner": "fermento", "id": "repellent_evo",
			"name": ["Fumacê", "Fogger"],
			"desc": ["O fumacê passou! Nuvem gigante que deixa tudo lento.", "The fogger truck passed! Giant cloud that slows foes."],
			"mods": {"dmg": 1.5, "area": 1.5, "cd": 0.8}},
	},
	"thunder": {
		"name": ["Raio do Pantanal", "Swamp Lightning"],
		"desc": ["Raios caem do céu em bichos aleatórios.", "Lightning strikes random critters."],
		"icon": "ic_thunder", "amt_name": ["Raios", "Bolts"],
		"base": {"dmg": 24.0, "cd": 2.4, "amt": 1, "spd": 1.0, "area": 1.0, "pierce": 0, "dur": 1.0, "kb": 160.0},
		"levels": [{}, {"amt": 1}, {"dmg": 1.3}, {"cd": 0.85}, {"amt": 1}, {"dmg": 1.3}, {"amt": 1}, {"cd": 0.8}],
		"evo": {"partner": "trevo", "id": "thunder_evo",
			"name": ["Tempestade Tropical", "Tropical Storm"],
			"desc": ["Raios em cadeia por toda a tela!", "Chain lightning across the screen!"],
			"mods": {"dmg": 1.5, "amt": 2, "area": 1.3, "cd": 0.8}},
	},
	"mud": {
		"name": ["Banho de Lama", "Mud Bath"],
		"desc": ["Poças de lama lentas e tóxicas. Capivara adora.", "Slowing, damaging mud puddles. Capybaras love it."],
		"icon": "ic_mud", "amt_name": ["Poças", "Puddles"],
		"base": {"dmg": 7.0, "cd": 3.0, "amt": 1, "spd": 1.0, "area": 1.0, "pierce": 0, "dur": 4.5, "kb": 0.0},
		"levels": [{}, {"area": 1.2}, {"amt": 1}, {"dmg": 1.3}, {"dur": 1.25}, {"amt": 1}, {"area": 1.2}, {"dmg": 1.4}],
		"evo": {"partner": "coco", "id": "mud_evo",
			"name": ["Spa de Lama", "Mud Spa"],
			"desc": ["Poças gigantes que também curam você!", "Giant puddles that also heal you!"],
			"mods": {"dmg": 1.5, "area": 1.4, "amt": 1, "cd": 0.85}},
	},
	"vuvuzela": {
		"name": ["Vuvuzela", "Vuvuzela"],
		"desc": ["Buzinaço em cone: empurra e atordoa.", "A cone blast that shoves and stuns."],
		"icon": "ic_vuvuzela", "amt_name": ["Buzinaços", "Blasts"],
		"base": {"dmg": 20.0, "cd": 2.6, "amt": 1, "spd": 1.0, "area": 1.0, "pierce": 0, "dur": 1.0, "kb": 420.0},
		"levels": [{}, {"area": 1.2}, {"dmg": 1.3}, {"cd": 0.85}, {"amt": 1}, {"area": 1.2}, {"dmg": 1.3}, {"cd": 0.85}],
		"evo": {"partner": "guarana", "id": "vuvuzela_evo",
			"name": ["Vuvuzela da Copa", "World Cup Vuvuzela"],
			"desc": ["Buzinaço em 360 graus. Hexa garantido!", "A 360-degree blast. Hexa guaranteed!"],
			"mods": {"dmg": 1.5, "area": 1.4, "cd": 0.85}},
	},
	"birds": {
		"name": ["Passarinhos", "Little Birds"],
		"desc": ["Passarinhos amigos bicam quem chegar perto.", "Friendly birds peck anyone nearby."],
		"icon": "ic_birds", "amt_name": ["Passarinhos", "Birds"],
		"base": {"dmg": 11.0, "cd": 1.1, "amt": 1, "spd": 460.0, "area": 1.0, "pierce": 0, "dur": 1.0, "kb": 60.0},
		"levels": [{}, {"amt": 1}, {"dmg": 1.3}, {"amt": 1}, {"cd": 0.85}, {"dmg": 1.3}, {"amt": 1}, {"spd": 1.2, "cd": 0.85}],
		"evo": {"partner": "cursinho", "id": "birds_evo",
			"name": ["Revoada", "Flock"],
			"desc": ["Bando enorme que explode em penas!", "A huge flock that bursts into feathers!"],
			"mods": {"dmg": 1.4, "amt": 3, "spd": 1.2}},
	},
}

const WEAPON_ORDER := ["orange", "flipflop", "cheese", "repellent", "thunder", "mud", "vuvuzela", "birds"]

# --------------------------------------------------------------- passives
# stat is accumulated as sum(per * level) by Run.recalc_stats().
const PASSIVES := {
	"guarana": {"name": ["Guaraná", "Guarana"], "desc": ["+12% de dano.", "+12% damage."], "icon": "ic_guarana", "max": 5, "stat": "might", "per": 0.12},
	"cafe": {"name": ["Cafezinho", "Coffee Shot"], "desc": ["-8% de recarga.", "-8% cooldown."], "icon": "ic_cafe", "max": 5, "stat": "cdr", "per": 0.08},
	"tenis": {"name": ["Tênis Novo", "New Sneakers"], "desc": ["+10% de velocidade.", "+10% move speed."], "icon": "ic_tenis", "max": 5, "stat": "speed", "per": 0.10},
	"marmita": {"name": ["Marmita da Vovó", "Grandma's Lunch"], "desc": ["+20 de vida máxima.", "+20 max HP."], "icon": "ic_marmita", "max": 5, "stat": "maxhp", "per": 20.0},
	"capa": {"name": ["Capa de Chuva", "Raincoat"], "desc": ["-1 de dano recebido.", "-1 damage taken."], "icon": "ic_capa", "max": 5, "stat": "armor", "per": 1.0},
	"coco": {"name": ["Água de Coco", "Coconut Water"], "desc": ["+0,4 de vida por segundo.", "+0.4 HP per second."], "icon": "ic_coco", "max": 5, "stat": "regen", "per": 0.4},
	"ima": {"name": ["Ímã de Geladeira", "Fridge Magnet"], "desc": ["+30% de alcance de coleta.", "+30% pickup range."], "icon": "ic_ima", "max": 5, "stat": "magnet", "per": 0.30},
	"fermento": {"name": ["Fermento", "Yeast"], "desc": ["+12% de área.", "+12% area."], "icon": "ic_fermento", "max": 5, "stat": "area", "per": 0.12},
	"xerox": {"name": ["Xerox", "Photocopier"], "desc": ["+1 projétil em todas as armas.", "+1 projectile on every weapon."], "icon": "ic_xerox", "max": 2, "stat": "amount", "per": 1.0},
	"cursinho": {"name": ["Cursinho", "Night School"], "desc": ["+10% de XP.", "+10% XP gain."], "icon": "ic_cursinho", "max": 5, "stat": "growth", "per": 0.10},
	"trevo": {"name": ["Trevo de 4 Folhas", "4-Leaf Clover"], "desc": ["+10% de sorte (críticos e drops).", "+10% luck (crits and drops)."], "icon": "ic_trevo", "max": 5, "stat": "luck", "per": 0.10},
	"cofrinho": {"name": ["Cofrinho", "Piggy Bank"], "desc": ["+15% de moedas.", "+15% coins."], "icon": "ic_cofrinho", "max": 5, "stat": "greed", "per": 0.15},
}

const PASSIVE_ORDER := ["guarana", "cafe", "tenis", "marmita", "capa", "coco", "ima", "fermento", "xerox", "cursinho", "trevo", "cofrinho"]

# ------------------------------------------------------------- characters
const CHAR_ORDER := ["cap", "ninja", "chef", "doutora", "rei"]
const CHARACTERS := {
	"cap": {
		"name": ["Capi", "Capi"], "weapon": "orange", "price": 0, "hat": "none", "body": Color("b5824f"),
		"trait": ["Relaxada: recupera 0,3 de vida por segundo.", "Chill: recovers 0.3 HP per second."],
		"mods": {"regen": 0.3},
	},
	"ninja": {
		"name": ["Capi Ninja", "Ninja Capi"], "weapon": "flipflop", "price": 400, "hat": "ninja", "body": Color("9a6b42"),
		"trait": ["Veloz: +12% de velocidade e esquiva recarrega mais rápido.", "Fast: +12% speed and quicker dodge cooldown."],
		"mods": {"speed": 0.12, "dashcd": -0.25},
	},
	"chef": {
		"name": ["Capi Chef", "Chef Capi"], "weapon": "cheese", "price": 1200, "hat": "chef", "body": Color("c08f5c"),
		"trait": ["Mão na massa: +15% de área e +10% de XP.", "Hands-on: +15% area and +10% XP."],
		"mods": {"area": 0.15, "growth": 0.10},
	},
	"doutora": {
		"name": ["Dra. Capi", "Dr. Capi"], "weapon": "repellent", "price": 2500, "hat": "goggles", "body": Color("a97848"),
		"trait": ["Cientista: -10% de recarga e +1 de armadura.", "Scientist: -10% cooldown and +1 armor."],
		"mods": {"cdr": 0.10, "armor": 1.0},
	},
	"rei": {
		"name": ["Rei Capi", "King Capi"], "weapon": "thunder", "price": 5000, "hat": "crown", "body": Color("b98b52"),
		"trait": ["Realeza: +25% de moedas, +10% de sorte, +20 de vida.", "Royalty: +25% coins, +10% luck, +20 HP."],
		"mods": {"greed": 0.25, "luck": 0.10, "maxhp": 20.0},
	},
}

# ------------------------------------------------------------------ shop
const SHOP_ORDER := ["might", "health", "armor", "speed", "growth", "greed", "luck", "magnet", "cooldown", "area", "reroll", "revival"]
const SHOP := {
	"might": {"name": ["Força", "Might"], "desc": ["+5% de dano por nível.", "+5% damage per level."], "icon": "ic_guarana", "max": 5, "cost": [120, 260, 520, 1000, 1900], "stat": "might", "per": 0.05},
	"health": {"name": ["Vitalidade", "Vitality"], "desc": ["+10 de vida máxima por nível.", "+10 max HP per level."], "icon": "ic_marmita", "max": 5, "cost": [100, 220, 450, 900, 1700], "stat": "maxhp", "per": 10.0},
	"armor": {"name": ["Casca Grossa", "Thick Skin"], "desc": ["-1 de dano recebido por nível.", "-1 damage taken per level."], "icon": "ic_capa", "max": 3, "cost": [350, 900, 2200], "stat": "armor", "per": 1.0},
	"speed": {"name": ["Pés Ligeiros", "Quick Feet"], "desc": ["+4% de velocidade por nível.", "+4% move speed per level."], "icon": "ic_tenis", "max": 5, "cost": [100, 220, 450, 900, 1700], "stat": "speed", "per": 0.04},
	"growth": {"name": ["Esperteza", "Smarts"], "desc": ["+8% de XP por nível.", "+8% XP per level."], "icon": "ic_cursinho", "max": 5, "cost": [150, 320, 650, 1250, 2300], "stat": "growth", "per": 0.08},
	"greed": {"name": ["Ganância", "Greed"], "desc": ["+10% de moedas por nível.", "+10% coins per level."], "icon": "ic_cofrinho", "max": 5, "cost": [150, 320, 650, 1250, 2300], "stat": "greed", "per": 0.10},
	"luck": {"name": ["Sorte Grande", "Big Luck"], "desc": ["+8% de sorte por nível.", "+8% luck per level."], "icon": "ic_trevo", "max": 5, "cost": [150, 320, 650, 1250, 2300], "stat": "luck", "per": 0.08},
	"magnet": {"name": ["Ímã Potente", "Strong Magnet"], "desc": ["+15% de coleta por nível.", "+15% pickup range per level."], "icon": "ic_ima", "max": 4, "cost": [100, 250, 550, 1100], "stat": "magnet", "per": 0.15},
	"cooldown": {"name": ["Pressa", "Haste"], "desc": ["-3% de recarga por nível.", "-3% cooldown per level."], "icon": "ic_cafe", "max": 5, "cost": [200, 450, 900, 1700, 3000], "stat": "cdr", "per": 0.03},
	"area": {"name": ["Alcance", "Reach"], "desc": ["+5% de área por nível.", "+5% area per level."], "icon": "ic_fermento", "max": 5, "cost": [200, 450, 900, 1700, 3000], "stat": "area", "per": 0.05},
	"reroll": {"name": ["Troca-Troca", "Reroll"], "desc": ["+1 troca de opções por partida.", "+1 reroll per run."], "icon": "ic_reroll", "max": 3, "cost": [250, 700, 1600], "stat": "reroll", "per": 1.0},
	"revival": {"name": ["Segunda Chance", "Second Chance"], "desc": ["Renasce uma vez por partida.", "Revive once per run."], "icon": "ic_heart", "max": 2, "cost": [900, 3500], "stat": "revival", "per": 1.0},
}

# --------------------------------------------------------------- enemies
# ai: chase | weave | dash | swoop | hop | shoot | charge | leap | snake
const ENEMIES := {
	"mosquito": {"name": ["Mosquito", "Mosquito"], "hp": 5.0, "spd": 108.0, "dmg": 5.0, "r": 9.0, "xp": 1.0, "ai": "weave", "spr": "mosquito", "size": 0.8, "frames": 2, "fps": 18.0},
	"barata": {"name": ["Barata", "Cockroach"], "hp": 14.0, "spd": 74.0, "dmg": 7.0, "r": 13.0, "xp": 1.0, "ai": "chase", "spr": "barata", "size": 0.85, "frames": 2, "fps": 12.0},
	"rato": {"name": ["Rato", "Rat"], "hp": 11.0, "spd": 122.0, "dmg": 6.0, "r": 12.0, "xp": 2.0, "ai": "chase", "spr": "rato", "size": 0.85, "frames": 2, "fps": 14.0},
	"pombo": {"name": ["Pombo", "Pigeon"], "hp": 16.0, "spd": 215.0, "dmg": 8.0, "r": 14.0, "xp": 3.0, "ai": "swoop", "spr": "pombo", "size": 0.85, "frames": 2, "fps": 10.0},
	"sapo": {"name": ["Sapo", "Toad"], "hp": 46.0, "spd": 52.0, "dmg": 12.0, "r": 20.0, "xp": 5.0, "ai": "hop", "spr": "sapo", "size": 0.9, "frames": 2, "fps": 6.0},
	"gamba": {"name": ["Gambá", "Skunk"], "hp": 32.0, "spd": 62.0, "dmg": 8.0, "r": 17.0, "xp": 4.0, "ai": "shoot", "spr": "gamba", "size": 0.85, "frames": 2, "fps": 8.0},
	"voadora": {"name": ["Barata Voadora", "Flying Cockroach"], "hp": 28.0, "spd": 88.0, "dmg": 11.0, "r": 15.0, "xp": 4.0, "ai": "dash", "spr": "voadora", "size": 0.9, "frames": 2, "fps": 16.0},
	"jacare": {"name": ["Jacaré Rabugento", "Grumpy Caiman"], "hp": 1500.0, "spd": 70.0, "dmg": 18.0, "r": 62.0, "xp": 70.0, "ai": "charge", "spr": "jacare", "size": 0.95, "frames": 2, "fps": 3.0, "big": true},
	"onca": {"name": ["Onça-Pintada", "Jaguar"], "hp": 2400.0, "spd": 130.0, "dmg": 20.0, "r": 52.0, "xp": 110.0, "ai": "leap", "spr": "onca", "size": 0.95, "frames": 2, "fps": 8.0, "big": true},
	"sucuri": {"name": ["Sucuri Gigante", "Giant Anaconda"], "hp": 14000.0, "spd": 150.0, "dmg": 24.0, "r": 40.0, "xp": 160.0, "ai": "snake", "spr": "sucuri", "size": 1.0, "frames": 1, "fps": 1.0, "big": true},
}

# Which enemies may appear in the random pool at a given time (sorted by t).
const WAVES := [
	{"t": 0, "pool": [["mosquito", 10]]},
	{"t": 22, "pool": [["mosquito", 8], ["barata", 4]]},
	{"t": 70, "pool": [["mosquito", 6], ["barata", 6], ["rato", 4]]},
	{"t": 140, "pool": [["barata", 5], ["rato", 6], ["mosquito", 3], ["pombo", 2]]},
	{"t": 210, "pool": [["rato", 5], ["sapo", 3], ["pombo", 3], ["barata", 3], ["gamba", 2]]},
	{"t": 300, "pool": [["voadora", 3], ["sapo", 4], ["gamba", 3], ["rato", 4], ["pombo", 3]]},
	{"t": 420, "pool": [["voadora", 5], ["sapo", 5], ["gamba", 4], ["rato", 4], ["barata", 3], ["pombo", 3]]},
]

# Scripted moments. kind: ring | line | flock | boss | calm
const EVENTS := [
	{"t": 40.0, "kind": "ring", "id": "mosquito", "n": 18, "msg": ["Enxame de mosquitos!", "Mosquito swarm!"]},
	{"t": 100.0, "kind": "line", "id": "rato", "n": 14, "msg": ["Ratos na pista!", "Rat stampede!"]},
	{"t": 150.0, "kind": "flock", "id": "pombo", "n": 9, "msg": ["Chuva de pombos!", "Pigeon storm!"]},
	{"t": 180.0, "kind": "boss", "id": "jacare", "msg": ["JACARÉ RABUGENTO!", "GRUMPY CAIMAN!"], "sub": ["Ele nunca acorda de bom humor.", "He never wakes up in a good mood."]},
	{"t": 235.0, "kind": "ring", "id": "barata", "n": 24, "msg": ["Baratada!", "Roach rush!"]},
	{"t": 275.0, "kind": "ring", "id": "voadora", "n": 6, "msg": ["BARATA VOADORA!!", "FLYING COCKROACH!!"]},
	{"t": 330.0, "kind": "ring", "id": "sapo", "n": 12, "msg": ["Os sapos pulam!", "The toads are hopping!"]},
	{"t": 360.0, "kind": "boss", "id": "onca", "msg": ["ONÇA-PINTADA!", "JAGUAR!"], "sub": ["Rápida, silenciosa e faminta.", "Fast, silent and hungry."]},
	{"t": 415.0, "kind": "line", "id": "gamba", "n": 10, "msg": ["Gambás fedidos!", "Stinky skunks!"]},
	{"t": 460.0, "kind": "ring", "id": "mosquito", "n": 64, "msg": ["ENXAME GIGANTE!", "GIANT SWARM!"]},
	{"t": 520.0, "kind": "ring", "id": "voadora", "n": 12, "msg": ["REVOADA DE BARATAS VOADORAS!", "FLYING COCKROACH FLOCK!"]},
	{"t": 565.0, "kind": "calm", "msg": ["A calma antes da tempestade...", "The calm before the storm..."]},
	{"t": 600.0, "kind": "boss", "id": "sucuri", "msg": ["SUCURI GIGANTE!", "GIANT ANACONDA!"], "sub": ["A rainha do Pantanal acordou.", "The queen of the Pantanal has awoken."]},
]

const ELITE_TIMES := [110.0, 195.0, 265.0, 340.0, 405.0, 480.0, 545.0]

# ---------------------------------------------------------------- helpers
static func xp_need(level: int) -> float:
	var l := float(level - 1)
	return round(5.0 + 5.0 * l + 0.45 * l * l)

static func weapon_name(id: String) -> String:
	if WEAPONS.has(id):
		return G.L(WEAPONS[id]["name"])
	for wid in WEAPONS:
		var evo: Dictionary = WEAPONS[wid]["evo"]
		if evo["id"] == id:
			return G.L(evo["name"])
	return id

static func weapon_def(id: String) -> Dictionary:
	if WEAPONS.has(id):
		return WEAPONS[id]
	for wid in WEAPONS:
		if WEAPONS[wid]["evo"]["id"] == id:
			return WEAPONS[wid]
	return {}

static func level_text(wid: String, level: int) -> String:
	## Text describing what reaching `level` of weapon `wid` gives.
	var d: Dictionary = WEAPONS[wid]
	if level <= 1:
		return G.L(d["desc"])
	var delta: Dictionary = d["levels"][level - 1]
	var parts: Array[String] = []
	for k in delta:
		var v = delta[k]
		if k == "amt":
			parts.append("+%d %s" % [int(v), G.L(d["amt_name"])])
		elif k == "pierce":
			parts.append("+%d %s" % [int(v), G.L(STAT_NAMES["pierce"])])
		else:
			var pct := int(round((float(v) - 1.0) * 100.0))
			parts.append("%s%d%% %s" % ["+" if pct >= 0 else "-", absi(pct), G.L(STAT_NAMES[k])])
	return ", ".join(parts)

static func wave_pool(t: float) -> Array:
	var pool: Array = WAVES[0]["pool"]
	for w in WAVES:
		if t >= float(w["t"]):
			pool = w["pool"]
	return pool

static func pick_weighted(pool: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for p in pool:
		total += float(p[1])
	var r := rng.randf() * total
	for p in pool:
		r -= float(p[1])
		if r <= 0.0:
			return p[0]
	return pool[0][0]
