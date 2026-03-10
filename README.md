# AI-Driven Tactical Survival Arena
### A production-quality Godot 4 top-down survival game

---

## How to Run

1. **Install Godot 4.2+** from https://godotengine.org/download
2. Open Godot → **Import** → select this folder (`godot project/`)
3. Press **F5** (or the Play button) to run
4. The main scene is `scenes/world/Arena.tscn`

> **Note:** On first run Godot may show warnings about missing navigation mesh.
> This is normal — the mesh is baked at runtime via `Arena.gd`.

---

## Controls

| Action        | Key / Button          |
|---------------|-----------------------|
| Move          | WASD / Arrow Keys     |
| Dash          | Space (invincible!)   |
| Shoot         | Left Mouse Button     |
| Aim           | Mouse cursor          |
| Pause         | Escape                |

---

## Gameplay Loop

```
Main Menu → Arena (Wave 1) → Kill all enemies
         → Wave Complete → Choose 1 of 3 upgrades
         → Next Wave (harder) → … → BOSS every 5 waves
         → Player dies → Game Over (score saved)
```

---

## Architecture Overview

### Directory Structure

```
godot project/
├── project.godot               ← Autoloads, input map, window settings
├── scenes/
│   ├── world/Arena.tscn        ← ROOT scene (start here)
│   ├── player/Player.tscn
│   ├── enemies/                ← ChaserEnemy, ShooterEnemy, TankEnemy, BossEnemy
│   ├── projectiles/            ← Bullet, EnemyBullet
│   └── ui/                     ← HUD, UpgradeScreen, GameOverScreen, MainMenu
├── scripts/
│   ├── systems/                ← All autoload singletons + Arena.gd
│   ├── player/Player.gd
│   ├── ai/                     ← StateMachine, State base, all states
│   │   └── states/             ← Idle, Patrol, Chase, Attack, Retreat
│   ├── weapons/Bullet.gd
│   └── ui/                     ← HUD, screens, DamageNumber, MiniMap, Camera
└── assets/
```

### Autoloaded Singletons

| Singleton        | Responsibility                                      |
|------------------|-----------------------------------------------------|
| `GameManager`    | Game state FSM, score, player behaviour tracking    |
| `WaveManager`    | Wave progression, difficulty scaling, spawn timing  |
| `EnemyManager`   | Active enemy registry, spatial queries              |
| `UpgradeManager` | Upgrade definitions, selection, stat application    |
| `SaveManager`    | JSON save/load via `FileAccess`                     |
| `ObjectPool`     | Scene instance pooling (bullets)                    |

### Signal Flow

```
Player shoots → Bullet spawned from pool
             → Bullet Area2D enters enemy Hurtbox
             → BaseEnemy.take_damage()
             → EnemyManager tracks death
             → all_enemies_dead signal
             → WaveManager.wave_completed
             → GameManager.trigger_wave_complete()
             → UpgradeScreen shown
             → Player picks upgrade
             → UpgradeManager.apply_upgrade() → Player.apply_upgrade()
             → GameManager.finish_upgrade_phase()
             → WaveManager.start_next_wave()
```

---

## AI Behavior System

### Finite State Machine

Each enemy has a `StateMachine` node with 5 states as children:

```
Idle ──────────→ Patrol ──→ (loops)
  │                 │
  └─── player ──────┘
       detected
           │
           ▼
         Chase ◄──────────────────┐
           │                      │
           ├── in range ──→ Attack │ (out of range)
           │                  │   │
           └── low health ────┼───┘
                              ▼
                           Retreat
                              │
                              └── health recovers ──→ Chase
```

### Adaptive Difficulty

`GameManager.get_player_aggression()` returns a 0–1 ratio based on:
- `damage_dealt / (damage_dealt + damage_taken)`

High aggression → enemies in `AttackState` fire faster (bonus tick).

### Enemy Types

| Type    | HP  | Speed | Range | Behavior                            |
|---------|-----|-------|-------|-------------------------------------|
| Chaser  | 50  | Fast  | Melee | Charges directly, brave retreater   |
| Shooter | 40  | Med   | Long  | Kites at preferred distance, retreats early |
| Tank    | 200 | Slow  | Melee | Charge attack, near-never retreats  |
| Boss    | 800 | Med   | Long  | 3 phases: spread/spiral/summon      |

### Boss Phases

- **Phase 1** (>66% HP): Spread shot (5 bullets)
- **Phase 2** (33–66%): Spread + spiral (12 bullets) + summons 2 chasers every 8s
- **Phase 3** (<33%): Double spiral, summons 3 chasers, moves faster, fires faster

---

## Upgrade System

10 upgrades; 3 random options presented after each wave:

| Upgrade          | Effect                         |
|------------------|--------------------------------|
| Swift Feet       | Speed +15%                     |
| Sharp Rounds     | Damage +20%                    |
| Rapid Fire       | Fire rate +25%                 |
| Iron Body        | Max HP +30                     |
| Nimble           | Dash cooldown -20%             |
| Split Shot       | +1 extra bullet per shot       |
| Explosive Rounds | Bullets deal AoE on impact     |
| Velocity Rounds  | Bullet speed +30%              |
| Eagle Eye        | Crit chance +15%               |
| Ricochet         | Bullets bounce off walls once  |

Upgrades are additive/multiplicative and stack across waves.

---

## Performance Systems

- **Object Pool** (`ObjectPool.gd`): Bullets are never `queue_free()`d — returned
  to pool and reactivated, eliminating GC pressure.
- **Signal-driven**: No `get_node()` polling in `_process`. All cross-system
  communication via signals.
- **NavigationAgent2D**: Enemy pathfinding uses Godot's built-in navigation mesh,
  baked at scene start from the procedurally placed obstacles.
- **Spatial queries** in `EnemyManager`: O(n) enemy lookup with distance² (no sqrt).

---

## Procedural Map

Every arena session generates:
- **8–14 random obstacles** (random size, color, position)
- Obstacles avoid the center spawn point (player safe zone)
- Obstacles avoid overlapping each other (rejection sampling)
- Navigation mesh is baked after placement for pathfinding

---

## Save System

Saves to `user://save_data.json` (platform-specific user directory):

```json
{
    "high_score": 4200,
    "waves_survived": 7,
    "unlocked_upgrades": ["speed_up", "damage_up"],
    "timestamp": "2026-03-09 14:22:01"
}
```

---

## Future Improvements

- **Full art pass**: Replace Polygon2D shapes with sprites/spritesheets
- **Sound design**: Add `AudioStreamPlayer2D` to bullets, enemies, UI
- **More enemy types**: Sniper, Swarmer, Healer
- **Weapon variety**: Shotgun, Laser, Rocket Launcher (separate scenes)
- **Leaderboard**: Online via Godot's HTTPRequest + backend
- **Controller support**: Remap actions for gamepad
- **Arena variants**: Different map shapes (circular, maze-like)
- **Difficulty selector**: Easy / Normal / Hard presets
- **Achievement system**: Track stats over multiple runs
- **More boss patterns**: Each boss wave could use a unique boss type
