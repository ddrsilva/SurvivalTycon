# ============================================================
# Game Configuration — All constants and enums
# Autoloaded as "GameConfig"
# ============================================================
extends Node

# ── Map ──────────────────────────────────────────────────────
const TILE_SIZE := 32
const MAP_WIDTH := 220      # tiles
const MAP_HEIGHT := 220     # tiles
const CLEAR_RADIUS := 8    # initial cleared circle radius in tiles

# Archipelago world generation
const MAIN_ISLAND_RADIUS := 62.0
const SECONDARY_ISLAND_MIN := 5
const SECONDARY_ISLAND_MAX := 8

# Distance fog settings
const FOG_DARKNESS := 0.72

# ── Villagers ────────────────────────────────────────────────
const INITIAL_VILLAGERS := 10
const VILLAGER_SPEED := 60.0    # pixels per second
const GATHER_TIME := 2.0        # seconds
const CARRY_CAPACITY := 1

# Villager role expertise
const EXPERTISE_XP_PER_LEVEL := 8.0
const EXPERTISE_MAX_LEVEL := 10
const EXPERTISE_GATHER_SPEED_PER_LEVEL := 0.08
const EXPERTISE_DEFENDER_HP_PER_LEVEL := 0.12
const EXPERTISE_GATHER_XP := 1.0
const EXPERTISE_DEFENDER_HIT_XP := 0.8

# Resources per gather
const WOOD_PER_CHOP := 2
const STONE_PER_MINE := 2
const GOLD_PER_MINE := 1

# ── Evolution thresholds (manual — player decides when) ──────
const EVOLUTION := {
	"wooden_cabin": { "wood": 30, "stone": 10, "gold": 0, "clear_radius": 12 },
	"stone_hall":   { "wood": 60, "stone": 50, "gold": 20, "clear_radius": 18 },
}

# ── Placeable buildings ──────────────────────────────────────
const BUILDINGS := {
	"carpentry":    { "cost": { "wood": 20, "stone": 5,  "gold": 0  }, "villagers": 3, "role": "LUMBERJACK", "name": "Carpentry" },
	"mining_house": { "cost": { "wood": 15, "stone": 15, "gold": 0  }, "villagers": 3, "role": "MINER",      "name": "Mining House" },
	"army_base":    { "cost": { "wood": 15, "stone": 10, "gold": 5  }, "villagers": 2, "role": "DEFENDER",   "name": "Army Base" },
	"healing_hut":  { "cost": { "wood": 10, "stone": 10, "gold": 5  }, "villagers": 0, "role": "",           "name": "Healing Hut" },
	"forester_lodge": { "cost": { "wood": 22, "stone": 10, "gold": 0 }, "villagers": 2, "role": "FORESTER", "name": "Forester's Lodge", "min_stage": 1 },
	"training_grounds": { "cost": { "wood": 25, "stone": 15, "gold": 8 }, "villagers": 0, "role": "", "name": "Training Grounds", "min_stage": 1 },
	"armory": { "cost": { "wood": 20, "stone": 25, "gold": 12 }, "villagers": 0, "role": "", "name": "Armory", "min_stage": 1 },
	"trap":         { "cost": { "wood": 8,  "stone": 6,  "gold": 0  }, "villagers": 0, "role": "",           "name": "Spike Trap" },
	"barricade":    { "cost": { "wood": 6,  "stone": 2,  "gold": 0  }, "villagers": 0, "role": "",           "name": "Barricade" },
	"mine":         { "cost": { "wood": 40, "stone": 30, "gold": 15 }, "villagers": 3, "role": "MINER",      "name": "Mine", "min_stage": 1 },
	"watch_tower":  { "cost": { "wood": 25, "stone": 20, "gold": 10 }, "villagers": 0, "role": "",           "name": "Watch Tower", "min_stage": 1 },
	"ballista_tower": { "cost": { "wood": 55, "stone": 65, "gold": 35 }, "villagers": 0, "role": "", "name": "Ballista Tower", "min_stage": 2 },
}

const BUILD_TIME := {
	"carpentry": 9.0,
	"mining_house": 10.0,
	"army_base": 12.0,
	"healing_hut": 8.0,
	"forester_lodge": 12.0,
	"training_grounds": 13.0,
	"armory": 13.0,
	"trap": 6.0,
	"barricade": 4.0,
	"mine": 14.0,
	"watch_tower": 15.0,
	"ballista_tower": 20.0,
}

const TECHNOLOGIES := {
	"masonry": {
		"name": "Masonry",
		"cost": 14,
		"requires": [],
		"desc": "Unlocks Mine construction.",
	},
	"ballistics": {
		"name": "Ballistics",
		"cost": 20,
		"requires": ["masonry"],
		"desc": "Unlocks Watch Tower construction.",
	},
	"architecture": {
		"name": "Architecture",
		"cost": 18,
		"requires": ["masonry"],
		"desc": "Builders construct and repair faster.",
	},
	"scholarship": {
		"name": "Scholarship",
		"cost": 16,
		"requires": [],
		"desc": "Scholars generate research faster.",
	},
	"firebreaks": {
		"name": "Firebreaks",
		"cost": 12,
		"requires": [],
		"desc": "Reduces fire spread chance.",
	},
}

const BUILDING_TECH_REQUIREMENTS := {
	"watch_tower": "ballistics",
}

# ── Building HP ──────────────────────────────────────────────
const BUILDING_HP := {
	"carpentry": 60,
	"mining_house": 60,
	"army_base": 80,
	"healing_hut": 50,
	"forester_lodge": 70,
	"training_grounds": 90,
	"armory": 95,
	"trap": 35,
	"barricade": 65,
	"mine": 70,
	"watch_tower": 100,
	"ballista_tower": 140,
}

# ── Building Leveling ───────────────────────────────────────
const BUILDING_UPGRADE_COST_SCALE := 0.7
const BUILDING_UPGRADE_HP_PER_LEVEL := 0.25
const BUILDING_SUPPORT_BONUS_PER_LEVEL := 0.10
const BUILDING_DEFENSE_DAMAGE_PER_LEVEL := 0.15
const BUILDING_DEFENSE_COOLDOWN_REDUCTION_PER_LEVEL := 0.08
const BUILDING_VISUAL_SCALE_PER_LEVEL := 0.06
const BUILDING_LEVEL_CAP_BY_STAGE := {
	0: 3,
	1: 5,
	2: 10,
}

# ── Mine bonus ───────────────────────────────────────────────
const MINE_GATHER_SPEED_BONUS := 1.5  # miners gather 50% faster when mine exists

# ── Watch Tower ──────────────────────────────────────────────
const TOWER_ATTACK_RANGE := 120.0   # pixels
const TOWER_ATTACK_DAMAGE := 8
const TOWER_ATTACK_COOLDOWN := 2.0  # seconds
const BALLISTA_ATTACK_RANGE := 170.0
const BALLISTA_ATTACK_DAMAGE := 42
const BALLISTA_ATTACK_COOLDOWN := 5.8
const BALLISTA_BEAR_BONUS_MULT := 1.7

# ── Trap / Barricade ────────────────────────────────────────
const TRAP_ATTACK_RANGE := 34.0
const TRAP_DAMAGE := 18
const TRAP_COOLDOWN := 1.3
const BARRICADE_BLOCK_RADIUS := 14.0
const BARRICADE_LINK_DISTANCE := 64.0
const BARRICADE_SNAP_STEP := 28.0

# ── Healing ──────────────────────────────────────────────────
const HEAL_RATE := 8           # HP restored per second at healing hut
const HEAL_SEEK_HP := 0.5      # villagers seek healing when HP below this ratio

# ── Tree Animations ──────────────────────────────────────────
const TREE_CHOP_FPS := 3.0         # chop animation frames per second
const TREE_FALL_FPS := 3.0         # fall animation frames per second
const LOG_COLLECT_TIME := 0.8      # seconds to collect log pile

# ── Defense ──────────────────────────────────────────────────
const PATROL_RADIUS := 5       # tiles from center
const ATTACK_RANGE := 48.0     # pixels
const ATTACK_DAMAGE := 10
const ATTACK_COOLDOWN := 1.0   # seconds

# ── Threats ──────────────────────────────────────────────────
const THREAT_SPAWN_INTERVAL := 60.0  # seconds between waves
const THREAT_HP := 30
const THREAT_SPEED := 30.0
const THREAT_DAMAGE := 5
const THREAT_CABIN_DAMAGE := 8        # damage to cabin on contact
const THREAT_KNOCKBACK := 60.0        # pixels pushed back on hit
const WAVE_BASE_COUNT := 3            # enemies in first wave
const WAVE_GROWTH := 1                # extra enemies per wave

# ── Tool Upgrades ────────────────────────────────────────────
const TOOL_UPGRADES := {
	"axe": [
		{ "name": "Stone Axe",    "cost": { "wood": 0,  "stone": 0,  "gold": 0  }, "speed_mult": 1.0, "yield_bonus": 0 },
		{ "name": "Iron Axe",     "cost": { "wood": 15, "stone": 10, "gold": 0  }, "speed_mult": 1.4, "yield_bonus": 1 },
		{ "name": "Steel Axe",    "cost": { "wood": 25, "stone": 20, "gold": 10 }, "speed_mult": 1.8, "yield_bonus": 2 },
		{ "name": "Mithril Axe",  "cost": { "wood": 40, "stone": 30, "gold": 25 }, "speed_mult": 2.4, "yield_bonus": 3 },
	],
	"pickaxe": [
		{ "name": "Stone Pick",   "cost": { "wood": 0,  "stone": 0,  "gold": 0  }, "speed_mult": 1.0, "yield_bonus": 0 },
		{ "name": "Iron Pick",    "cost": { "wood": 10, "stone": 15, "gold": 0  }, "speed_mult": 1.4, "yield_bonus": 1 },
		{ "name": "Steel Pick",   "cost": { "wood": 20, "stone": 25, "gold": 10 }, "speed_mult": 1.8, "yield_bonus": 1 },
		{ "name": "Mithril Pick", "cost": { "wood": 30, "stone": 40, "gold": 25 }, "speed_mult": 2.4, "yield_bonus": 2 },
	],
	"sword": [
		{ "name": "Wooden Sword",  "cost": { "wood": 0,  "stone": 0,  "gold": 0  }, "dmg_mult": 1.0, "cd_mult": 1.0 },
		{ "name": "Iron Sword",    "cost": { "wood": 10, "stone": 15, "gold": 5  }, "dmg_mult": 1.5, "cd_mult": 0.85 },
		{ "name": "Steel Sword",   "cost": { "wood": 15, "stone": 25, "gold": 15 }, "dmg_mult": 2.0, "cd_mult": 0.7 },
		{ "name": "Mithril Sword", "cost": { "wood": 25, "stone": 35, "gold": 30 }, "dmg_mult": 2.8, "cd_mult": 0.55 },
	],
}

# ── Evolution Difficulty Scaling ─────────────────────────────
const EVOLUTION_SCALING := {
	0: { "hp_mult": 1.0, "speed_mult": 1.0, "dmg_mult": 1.0, "wave_extra": 0 },
	1: { "hp_mult": 1.5, "speed_mult": 1.15, "dmg_mult": 1.3, "wave_extra": 2 },
	2: { "hp_mult": 2.2, "speed_mult": 1.3, "dmg_mult": 1.7, "wave_extra": 5 },
}

# ── Health ───────────────────────────────────────────────────
const CABIN_MAX_HP := 200
const VILLAGER_MAX_HP := 40
const THREAT_ATTACK_RANGE := 40.0     # range for threat to damage cabin/villagers
const THREAT_ATTACK_COOLDOWN := 2.0

# ── Enemy types ──────────────────────────────────────────────
enum EnemyType { SLIME, WOLF, BEAR }
const ENEMY_STATS := {
	EnemyType.SLIME: { "hp": 25, "speed": 25.0, "damage": 4, "name": "Forest Slime" },
	EnemyType.WOLF:  { "hp": 40, "speed": 45.0, "damage": 7, "name": "Wolf" },
	EnemyType.BEAR:  { "hp": 80, "speed": 20.0, "damage": 15, "name": "Bear" },
}

# ── Tile type enum ───────────────────────────────────────────
enum TileType {
	GRASS = 0,
	DIRT = 1,
	TREE_PINE = 2,
	TREE_OAK = 3,
	ROCK = 4,
	ORE = 5,
	LOG_PILE = 6,
	WATER = 7,
	SAND = 8,
}

# ── Building evolution stages ────────────────────────────────
enum BuildingStage {
	TENT = 0,
	WOODEN_CABIN = 1,
	STONE_HALL = 2,
}

const CABIN_STAGE_HP := {
	BuildingStage.TENT: 200,
	BuildingStage.WOODEN_CABIN: 320,
	BuildingStage.STONE_HALL: 500,
}

# ── Villager states ──────────────────────────────────────────
enum VillagerState {
	IDLE,
	MOVING_TO_RESOURCE,
	GATHERING,
	RETURNING,
	PATROLLING,
	ATTACKING,
	FELLING,
	COLLECTING_LOGS,
	MOVING_TO_HEAL,
	HEALING,
}

# ── Villager roles ───────────────────────────────────────────
enum Role {
	IDLE,
	LUMBERJACK,
	MINER,
	DEFENDER,
	BUILDER,
	SCHOLAR,
	FORESTER,
}

## Utility: get role string key from enum
static func role_to_key(role: Role) -> String:
	match role:
		Role.IDLE: return "idle"
		Role.LUMBERJACK: return "lumberjack"
		Role.MINER: return "miner"
		Role.DEFENDER: return "defender"
		Role.BUILDER: return "builder"
		Role.SCHOLAR: return "scholar"
		Role.FORESTER: return "forester"
	return "idle"


## Convert building key to the Role enum value
static func building_role(building_key: String) -> Role:
	var info: Dictionary = BUILDINGS.get(building_key, {})
	var r: String = info.get("role", "")
	match r:
		"LUMBERJACK": return Role.LUMBERJACK
		"MINER": return Role.MINER
		"DEFENDER": return Role.DEFENDER
		"FORESTER": return Role.FORESTER
	return Role.IDLE
