# Session Notes

---

## Session: Terrain Elevation + Path 2 Hybrid (complete)

### Completed

- **Terrain elevation system fully completed and verified.** Heightmap-driven terrain, slope clamp, and unit terrain-following all working.
- **Slope clamp rewritten** as a single unified relaxation pass (intersection-of-neighbour-constraints, midpoint on conflict). Converges correctly — max adjacent delta reaches SLOPE_MAX_DELTA limit. Earlier two-sweep version was broken (sweeps cancelled each other).
- **Terrain mesh tessellation** now derived from heightmap resolution; subdivisions scale with map size. Fixes flat-triangle corner-cutting on slopes.
- **Terrain shader UV fixed:** samples height in world space, Z-flipped to match CPU Image row convention, half-texel aligned to `get_visual_height_at()`. Visible mesh now matches the collider and unit heights.
- **`custom_aabb` set on GroundMesh** so shadow/culling bounds include the displaced hills (flat PlaneMesh AABB was insufficient).
- **P2.1** (terrain collider), **P2.2** (right-click raycast targeting), **P2.3** (drag-box selection using units' visual screen positions) — all complete. Path 2 Hybrid is finished: real terrain collision for input, flat navmesh for pathfinding.
- **All temporary diagnostic logging removed:** `[CLAMP]`, `[CLAMP-TRACE]`, `[UV-DIAG]`, `[DIAG]`, `[DIAG-FRAME]` and the `_diag` scaffolding in `Unit.gd`.

### Deferred / Known Items

- **Real-time shadows disabled** (`shadow_enabled = false` on the match `DirectionalLight3D`). Displaced-terrain shadow projection was unresolved (shadow AABB, pancaking, bias interactions); revisit post-MVP.
- **Cliffs** (impassable terrain type + navmesh exclusion) — not built, planned later.
- **Hill movement/combat penalty layer** — not built, part of the situational modifier system later.
- A possible **unit jitter / stuck-in-place** issue was seen in diagnostics but never confirmed as a real bug; not investigated. Watch for it during normal play.

### Current State

- Project compiles and runs clean, no parse errors.
- Terrain / Path 2 chapter is complete.
- Next: back on the main roadmap.

---

## Deferred: Capital-destruction win condition

The Capital-destruction win condition was implemented in Wave 2 (commit `68ff0e1`) as a secondary trigger: `MatchEndHandler._connect_win_condition_if_needed` connected `_on_win_condition_building_destroyed` to each Capital's `tree_exited` signal via `.bind(player)`.

**Problem:** Destroying a Capital produces no end-game response and no debugger error. The callback appears to be correctly connected (the logic and signal ordering were verified by code analysis), but the win panel never shows. Root cause was not identified — the silent failure mode is undiagnosed.

**Current state:** The Capital-destruction trigger has been **DISABLED** by commenting out the connection inside `_connect_win_condition_if_needed` (MatchEndHandler.gd). The code — `_on_win_condition_building_destroyed`, `_connect_win_condition_if_needed`, `is_win_condition_building` flag — is preserved in place.

**Active win condition:** Reverted to the template's original owns-nothing logic (`_on_unit_tree_exited`), which fires whenever any unit/structure exits the tree and then checks whether any player is left with zero entries in the "units" group. All structures (Capital, Command Post, mills, etc.) are in the "units" group via `_setup_unit_groups`, so destruction of all a player's buildings and units correctly triggers defeat.

**Fog reveal:** Added to `_show()` so all end-game paths (owns-nothing and future Capital-destruction) reveal the full map on match end.

**To re-enable Capital-destruction:** Uncomment the two commented lines in `_connect_win_condition_if_needed`. Add `GameLogger.debug` calls at the top of `_on_win_condition_building_destroyed` to confirm the callback fires. Best diagnosed once siege units exist so Capital destruction happens naturally in gameplay.

---

## Session: Mercenary, Dismiss, Archer + Suppress rework, Movement modifier system

### Units Added

**Mercenary** — elite combat unit trained in batches of 5 from any Capital.
- Cost: 250 gold per batch, ~10 seconds batch time, queue-able.
- High food + gold upkeep. Intended to be strong: one mercenary beats roughly 5 infantry.
- Production queue extended with a generic `batch_count` concept: one queue entry spawns N units simultaneously. Mercenary is the only user of batch spawning so far.
- Note on cost enforcement: `PRODUCTION_COSTS` is enforced only for the Mercenary (charged in the Capital menu). Other units are free to train. Structures cost resources. Cost enforcement for siege units will be added with siege work.

**Dismiss ability** — all mobile units gain a "DIS" command (toggle).
- 15-second dismiss countdown with a white depleting bar; the unit stays controllable and pays upkeep during the countdown.
- Cancelling dismiss starts a 60-second cooldown.
- On completion the unit becomes an uncontrollable `civilian` (laborer-type prop) that wanders ~10s then despawns.
- Respects the Tab-filter selection subset. Buildings excluded.

### Archer Rework

- **Attack model rewritten**: no hit/miss roll — every arrow scatters within a target-centered circle whose radius scales with range (3 tiers: ≤5, ≤8, >8 units). Nearest unit to the arrow's landing point takes damage (friendly fire on).
- All four attack entry points (idle, right-click, attack-move, patrol) unified to use the scatter behavior.
- Scatter radii reduced (archers were missing too much); base attack speed increased; archers in a group fire staggered (random phase offset per archer) rather than synchronized volleys.

### Suppress Ability (archer) — complete

A pure on/off toggle (old duration / grace / auto-renew removed).

**Rooting:**
- Toggle-on immediately roots the archer — immovable by any method (right-click, attack-move, patrol, formation, rally, minimap).
- Enforced centrally in `Unit._set_action()`: suppressing/suppress_armed units reject all incoming actions. `suppress_armed` allows only `ArcherAutoAttacking` through (so a player-ordered in-range target correctly triggers the suppress activation chain).
- `ArcherAutoAttacking._attack_or_move_closer()` also guards against creating `FollowingToReachDistance` while suppress is active (defense-in-depth).

**Re-targeting while rooted:**
- A suppressing archer CAN be re-targeted to any enemy already within its (boosted) range — handled via `SuppressedAttacking.retarget()`.
- Out-of-range targets are silently rejected. Attack-move on a suppressing archer retargets the nearest in-range enemy and never moves.
- `SuppressedAttacking` stores itself in the unit's meta (`"suppress_action"`) for O(1) lookup by controllers.

**Bonuses:** +2 attack range, +50% fire rate while active.

**Wood cost (recurring):**
- 1 wood per suppressing archer charged on activation, then 1 wood per archer every 10 seconds.
- If the player cannot pay at any tick, those archers are immediately dropped from suppress (5-second cooldown applies).
- Shown in the resource HUD as –6 wood/min per suppressing archer (expenditure label + hover breakdown tooltip).

**Suppress zone:**
- Suppress projects a slow zone centered on the target, sized to the scatter circle radius. All units inside (friend and foe) are slowed by 1% per overlapping zone, capped at 10%. Implemented via `SuppressZoneManager` (auto-created under Match on first suppress).

**Cooldown / UX:**
- 5-second cooldown after toggling off (stored as `suppress_cooldown_until_ms` meta on the archer).
- Hovering the Suppress button shows a grey boosted-range preview circle around each selected archer; circles track archers in real time if they move.

**Design note:** Suppress is intentionally the defensive archer stance — holds ground, denies an area, high sustained DPS in place.

### Movement Modifier System

`Movement.gd` now owns a central effective-speed computation: base speed with all slow contributors applied additively (25% minimum speed floor). Terrain slow and suppress-zone slow both register through `set_speed_slow(source, fraction)` / `clear_speed_slow(source)`. The additive/multiplicative choice is isolated to one function (`_compute_effective_speed`) for easy future adjustment. Future systems (weather, debuffs, etc.) should feed into this same API.

### Design Decisions / Deferred

**Win condition:** Active condition is the template's "player owns no units or structures" logic. The Capital-destruction win condition is built but disabled (commented out in `MatchEndHandler`) — does not fire reliably; best diagnosed once siege units make Capital destruction testable in normal play.

**Phase 5 Economy design decision (recorded for future):** When the full economy system is built, simulate continuously (per-second / per-tick), not in per-minute lump ticks. Income accrues and upkeep drains smoothly; discrete events (supply wagon arrivals) stay discrete. This unifies upkeep, suppress cost, and supply timing into one time base. The HUD should still display per-minute rates for readability.

**Still deferred:**
- Siege units (Battering Ram, Trebuchet, Ballista, Siege Tower) and the Siege Workshop
- Keep, Tower, and Walls buildings
- Units-before-structures targeting priority
- Veteran per-kill XP / stat bonus
- Skirmish battle-zone system
- Morale-based surrender prompt
- Real-time shadows (disabled — shadow AABB / bias issues with displaced terrain)
- Cliffs (impassable terrain + navmesh exclusion)
- Hill movement / combat penalty layer

### Current State

- Project compiles and runs clean.
- Archer and Suppress are complete and stable.
- Waves 1–2 of the building update (Capital, Command Post, win condition) are done.
- **Next: Wave 3 — Siege Workshop and the four siege units.**

---

## Session: Wave 3a — Siege Workshop + Battering Ram (complete)

### Units / Buildings Added

**Siege Workshop** — production building, built by the Engineer.
- Costs resources to build (standard construction flow).
- Has a production queue; produces siege units one at a time.
- Currently produces the Battering Ram.

**Battering Ram** — anti-structure siege unit, produced by the Siege Workshop.
- Attacks buildings, walls, and other siege units only — never regular units.
- Melee range, edge-based attack (see Targeting below).
- No upkeep cost.
- Auto-acquires nearby valid targets while idle; returns to target-scanning state after any move or attack completes.

### Inside-Crew System (CrewManager + CrewDots — reusable)

Units (infantry / archers) board a siege unit by selecting them and right-clicking it. They walk to it and are absorbed (hidden inside).

- **Capacity / minimum:** Ram capacity 12; minimum 4 crew to move or attack.
- **Population / upkeep:** crew still count toward pop cap and pay upkeep while inside.
- **Protection:** crew are invulnerable inside — they die only if the siege unit is destroyed (all crew hp set to 0 on death).
- **Unman:** releases all crew at full HP beside the unit.

**Ownership (neutral/claimable):**
- Un-crewed = neutral — no owner, no player control, not visible in fog, neither player can order it.
- Loading the first crew member claims the siege unit for that player (scene-tree reparent, group updates, colour refresh).
- Unmanning releases it back to neutral. Either player can claim a neutral siege unit.
- Implemented as symmetric claim/release in `CrewManager` with reparenting.

**Crew Dots (CrewDots — reusable visual component):**
- Row of dots above the unit, billboarded to the camera (always faces camera regardless of unit rotation).
- Grey dot = empty capacity slot; white dot = filled crew slot; fills left-to-right.
- Positioned above the unit's name label at a fixed world-space height offset.

### Edge-Based Targeting

A siege unit's attack reach and auto-detect range are both measured to the **edge** of the target, not its center:

- `attack_range + target.MovementObstacle.radius` (for structured targets with a navmesh carve).
- `sight_range + target.MovementObstacle.radius` (for auto-detect scan).
- Targets without a navmesh carve (mobile siege units) contribute radius 0 — plain melee range.

This allows the Ram to attack and detect buildings of any size, including the Capital (obstacle radius 2.5), without inflating the base attack_range with a magic constant. Base `attack_range = 1.2` (true melee contact).

The Ram's RamAutoAttacking, RamAttackingWhileInRange, and RamWaitingForTargets all use this edge-based calculation.

### Idle / Re-scan Behaviour

After any action completes (move finishes, attack completes, building destroyed), the Ram's action becomes `null`. A hook on the `action_changed` signal in `battering_ram.gd` reinstates `RamWaitingForTargets` whenever action becomes null and crew ≥ 4. This means a crewed Ram continuously scans for valid targets after moving or finishing an attack.

### Debug / Testing

- Each player currently starts with **2 000 of every resource** — a DEBUG testing value (`DEBUG_STARTING_RESOURCES` in `Match.gd`). Set to normal values before shipping.

### Deferred Design Work (specified, to build later)

**Wave 3 remaining siege units:**
- **3b — Siege Tower:** pure troop transport; 2 000 HP; capacity 24; reuses inside-crew system.
- **3c — Ballista:** ranged siege unit operated by external crew (siege-engineer external-crew system); requires Siege Engineer unit.
- **3d — Trebuchet:** heavy ranged siege, 15-second pack/unpack animation between move and fire states.
- **3e — Ballista dig-in ability.**

**Formation system (full design pass done — build post-siege):**
- **Ranks:** ordered fighting line; travels as a column; deploys to rows 3 tiles from the march point. Unit type order front-to-back: cavalry → infantry → archers → siege. Faces direction of travel; does not auto-reorient when flanked.
- **Square:** defensive box; melee on perimeter, archers inside, siege in the center; toughest type on the perimeter when no melee present. Faces direction of travel.
- A **deployment zone** within 3 tiles gives reduced ally collision + a movement-speed boost for repositioning.
- **Spread** is a toggle modifier on either formation: wider spacing, −5% move speed.
- Formations are purely positional (no combat bonuses).
- Build stages F1–F4 specified.

**Command panel restructure (planned, depends on formations):**
- Two-panel command UI: a shared "Orders" panel (movement + formation commands every selection obeys) and an "Abilities" panel (unit-unique commands for the tabbed unit type).

**Phase 5 Economy (continuous simulation, when built):**
- Simulate per-second/per-tick rather than per-minute lumps. Discrete events (supply wagon arrivals) stay discrete. HUD continues to display per-minute rates.

**Combat modifier / bonus decisions (Phase 6 tuning):**
- Cap on stacked combat bonuses (~+50% discussed), veteran per-kill bonus, terrain/high-ground bonus, additive stacking — not yet finalised; tune once combat and targeting mature.

**Morale:**
- Discussed as a behavioural system (routing, hesitation, surrender, recovery). Governs unit will, not damage; emergent; has inertia; spreads locally. Not yet designed in detail.

**Smaller deferred items:**
- Building placement revisit.
- FormationController placement math needs a quality pass.
- Units-before-structures targeting priority.
- Real-time shadows (disabled — shadow AABB / bias issues with displaced terrain).
- Cliffs / hill movement–combat penalty.

### Current State

- Project compiles and runs clean.
- Wave 3a (Siege Workshop, Battering Ram, inside-crew system, neutral/claimable ownership, crew dots, edge-based targeting, idle re-scan) is **complete**.
- **Next: Wave 3b — Siege Tower.**

---

## Session: Wave 3b — Siege Tower + Ownership Fixes (complete)

### Units Added

**Siege Tower** — pure troop transport, produced by the Siege Workshop (second button "TWR" [W], alongside Ram "RAM" [Q]).
- HP: 2000, move speed: 0.5 (siege-class slow), no attack.
- Crew capacity 24 (infantry/archers), minimum 4 to move.
- Neutral/claimable ownership — same system as the Battering Ram (CrewManager, scene-tree reparent on claim/release).
- Crew released at full HP on Unman. Crew killed on tower death.
- Placeholder geometry: tall box (0.8 × 2.0 × 0.8).
- Upkeep: 5 wood + 5 gold/min.
- Production cost: Wood 150, Stone 100, Gold 50; 50 seconds.

### CrewDots Enhancements

- **Multi-row layout** — up to 12 dots per row; rows centred vertically. Ram = 1 row of 12; Tower = 2 rows of 12.
- **`@export var crew_count_public: bool = true`** — when `false`, dots visible only to the owning player. Ram and Tower both set `crew_count_public = false`.
- **`@export var dot_height: float = 1.15`** — configurable height offset above the unit. Tower sets `dot_height = 2.3`.
- **Owner-visibility check** — in `_process`, when not public: neutral → dots hidden; owned → `_parent_unit.player == _get_local_player()` (lazy-cached `Human` instance lookup). Uses scene-tree parent as the authoritative owner (see ownership fix below).

### Siege Ownership System — Symmetric Claim/Release

`CrewManager._release_ownership()` now mirrors `_claim_ownership()` exactly:
- On claim: reparents siege unit to the crewing player → `unit.player` = real Player.
- On release: reparents siege unit to `$Players` (Match's Players Node3D container) → `unit.player` = `$Players`, clearly not a Player.

Before this fix, release did not reparent — a neutral (unmanned) siege unit's `unit.player` still pointed at the former owner, making it unreliable. Now a neutral siege unit has consistent parentage whether it was never-crewed or unmanned.

**Neutral siege unit state:** parent = `$Players`, groups = "units" + "neutral_siege", NOT in "controlled_units" or "adversary_units". `unit.player is Player` → false without any extra group check needed. Claiming always reparents (since `$Players` ≠ any player), making re-claim and cross-player capture both correct.

### Crash Fix (unman crash, post-ownership-fix)

After the ownership fix, `unit.player` for neutral units = `$Players` Node3D. Code that read `unit.player.color` crashed.

Two fixes:
- **`Minimap.gd._sync_unit`** — guards with `unit.is_in_group("neutral_siege")` → uses `Color.WHITE` for neutral units instead of `unit.player.color`.
- **`Unit.gd.color` getter** — guards with `is_in_group("neutral_siege")` → returns `Color.WHITE` when neutral, preventing crashes from any future caller.

`Highlight.gd`, `Selection.gd`, `Targetability.gd` were already safe — they use group-based color constants (`controlled_units` → GREEN, `adversary_units` → RED, else WHITE).

### UID Fixes

- `CrewDots.tscn`: removed fake `uid="uid://crewdots00001"` from `[gd_scene]` header; ext_resource uid references in `battering_ram.tscn` and `siege_tower.tscn` cleaned up to path-only resolution.
- `UnitMenus.tscn`: updated SiegeTowerMenu ext_resource uid from stale hand-written value to the real Godot-assigned uid (`uid://dd2f1jxee2iyy`).
- `siege_tower.tscn`, `SiegeTowerMenu.tscn`: Godot auto-corrected hand-written UIDs to real ones on first import.

### Current State

- Project compiles and runs clean.
- Waves 3a and 3b complete. Siege Workshop produces Ram and Tower. Both support the full crew cycle (crew → unman → re-crew by either player) without crashes.
- **Next: Wave 3c — Ballista (external crew / siege-engineer system).**

---

## SCHEDULED DESIGN WORK (not yet built)

Items fully designed, to be implemented as their own tasks after the siege wave completes.

### Relationship System (Ally / Enemy / Neutral)

A proper tri-state relationship system. Currently every system (targeting, vision, selection, minimap, AI) does its own ad hoc check ("is this unit's player == my player?"). Neutral un-crewed siege units are a real third state that these checks handle inconsistently — causing the crash and workaround patches above.

**Goal:** one canonical function that answers "what is unit X's relationship to player Y" → Ally, Enemy, or Neutral. All systems use it instead of their own ad hoc logic.

**Design constraints:**
- Must accommodate future neutral unit types (not just siege machines).
- Must accommodate **multiplayer alliances**: in team games the answer is per-player-pair (player A is allied with B but at war with C). Do not hardcode a rigid 3-way global assumption.
- Neutral units: uncontrollable, provide no vision, cannot be auto-attacked or targeted by normal means (only manually — see below).

**Dependency:** Relationship System is a prerequisite for the Manual Attack command and for clean targeting across all units.

### Manual Single-Target Attack Command

A StarCraft-style explicit "Attack" command: the player deliberately orders a unit to attack a specific target, bypassing the Relationship System's auto-acquire filter. This allows intentional attacks on neutral or even friendly units — auto-acquire never does this, but a manual order can.

- Universal command, belongs in the planned Orders panel of the two-panel command grid restructure.
- **Depends on the Relationship System** (it must exist before this can bypass it correctly). Build after it.

### Siege Dismissal + Salvage Crate

Siege units can be dismissed, similar to regular unit dismissal:

**Dismissal flow:**
- Engaging dismiss immediately ejects all crew; they return as their original units at full HP (soldiers are NOT destroyed).
- A 15-second countdown runs and is cancellable.
- During the countdown the machine is un-crewed (neutral); cancelling stops the despawn.
- On completion the empty siege machine despawns (no civilian/prop left behind).

**Salvage Crate:**
- On dismissal completion only (NOT on combat destruction), a salvage crate (simple brown box) spawns at the location.
- Any player's engineer can collect it; collection is a 15-second action, interruptible (if interrupted, the crate remains collectible by anyone).
- On successful collection: 50% of the siege unit's build cost is credited to the collecting player.
- Crate despawns after 5 minutes if uncollected.

### Sequencing Note

Several scheduled items intersect through the planned **two-panel command grid** (Orders panel + Abilities panel): manual Attack, formation commands, and siege dismissal all surface there. The Relationship System is a dependency for manual Attack and for clean targeting. Before building any of these, do a dependency-ordering pass to sequence them correctly.

---

## Session: Wave 3c — Ballista external-crew system (complete)

### Completed

The Ballista external-crew system is complete and verified. Key fixes from this work:

**Friendly-fire-on-own-crew bug (commit `94b2c7f`):** The `Unit.gd` `player` getter (just `get_parent()`) returned the Ballista for a crewed engineer, because `ExternalCrewManager` reparents engineers to the Ballista. Target scans use `player != player` to identify enemies, so friendly engineers read as enemies and were auto-attacked. Fixed at source: the `player` getter now resolves a crewed engineer (one with `crew_siege_unit` meta) to its siege unit's owner.

**Abandon crash + crew-list corruption (commits `bc7412d`, `6dc875c`, `3db7bb9`):** Root cause found in `3db7bb9`: `load_unit` connected the engineer `tree_exited` death-signal and appended to `_crew` *before* calling `_claim_ownership`. `_claim_ownership` reparents the neutral Ballista to the player, and reparenting fires `tree_exited` on **all children** — including the just-attached engineer — which triggered `_on_engineer_died` mid-claim, dropping that engineer from `_crew`. Result: a "ghost" engineer — physically present in the Ballista subtree, has `crew_siege_unit` meta, in the `"units"` group, but **not** in `_crew`. This caused the "4 crew loaded but only 3 dots" desync, a slot-index collision (two engineers at slot 0), and the abandon crash (the ghost was skipped by teardown, kept its meta, and crashed `_sync_unit` once the Ballista went neutral). Fix: `_claim_ownership` now runs *before* connecting `tree_exited` and appending to `_crew`, so the reparent's `tree_exited` fires harmlessly with no connection established.

The abandon teardown itself was also reworked (`6dc875c`) to a three-phase deterministic order: (1) strip meta, disconnect signal, remove from `"units"` group for all tracked engineers; (2) release Ballista ownership; (3) spawn fresh infantry replacements and `queue_free` engineer nodes. This ordering guarantees `_sync_unit` cannot see a live engineer with a stale meta pointing to a now-neutral Ballista.

### Key Lessons

- **Reparenting a node in Godot fires `tree_exited` on all its children.** Connecting lifecycle signals to a child *before* a parent reparent can trigger those handlers spuriously. Order signal connections carefully around any reparenting operation.
- **Diagnose upstream.** The abandon crash was patched three times at the teardown site before the real cause was found in the *loading* path. A seemingly minor symptom — crew dot count being off by one — was the clue that located the root cause upstream.

### Current State

- Project compiles and runs clean.
- Wave 3c (Ballista, external-crew / siege-engineer system, neutral/claimable ownership, `ExternalCrewManager`, `CrewDots` with public count, abandon teardown) is **complete**.
- **Next: Wave 3d — Trebuchet.**
