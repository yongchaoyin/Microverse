# Microverse – P0 Requirements Snapshot (2025-10-19)

> Consolidated from `docs/01_项目愿景与核心设定.md`, `docs/02_核心系统设计.md`,
> and the `docs/design` deep-dive specifications (notably 09.5 / 15.5 series).
> This note exists to keep the engineering backlog aligned with the authored design set.

## Simulation Bedrock
- **TimeSystem (Autoload)**  
  - 24h cycle with configurable `REAL_SECONDS_PER_GAME_MINUTE`, seasonal progression (28-day seasons, 4 seasons per year).  
  - Emits `time_changed`, `hour_changed`, `day_changed`, `season_changed`, `year_changed` plus day-part signals (morning/noon/evening/night).  
  - Supplies utility helpers: timestamps, weekend checks, `add_days`, formatted strings; drives scene lighting & weather cadence.
- **WeatherSystem (Autoload)**  
  - Season-aware probability tables, transient weather states (sunny, rain, storm, snow, fog).  
  - Broadcasts transitions, applies visual/audio layers, mood modifiers, and location availability impacts.
- **EventBus / ConfigManager / DebugConsole (Autoload)**  
  - Global messaging, runtime configuration, developer tooling as per `15.5` doc.

## AI Core Stack
- **CareerSystem + ScheduleManager**  
  - Career definitions per character (work hours, weekly shifts, growth ladder).  
  - Generates daily schedules (workblocks, breaks, social slots) mapped to locations via `LocationManager`.  
  - Reacts to `TimeSystem` signals to push activity changes to agents.
- **TaskSystem (Autoload)**  
  - Four task domains: Work, Daily, Social, Growth.  
  - Lifecycle: create → assign → in-progress → completed/failed (with LLM grading hooks).  
  - Priority queue (urgent/important matrix), deadlines, automatic refresh, and history storage (weekly performance snapshot for Economy).  
  - Provides `get_weekly_performance(ai_id)` required by EconomyManager.
- **RelationshipManager**  
  - Multi-channel relationship graph (friendship, romance, rivalry, professional).  
  - Manages trust thresholds, decay/reinforcement, event-triggered adjustments, exposes APIs for ConflictSystem & Schedule.
- **MemoryManager Enhancements**  
  - Long/short-term memory buckets with time-based pruning (7/15/30 day policies).  
  - Categorized memories (task, social, conflict, finance) used by dialog + AI reasoning.
- **ConflictSystem**  
  - Detects triggers (loan failures, schedule collisions, personality friction).  
  - State machine per conflict (`IDLE`, `TENSION`, `ESCALATED`, `RESOLVED`).  
  - Integrates with RelationshipManager for trust deltas, logs events to EventBus, imposes cooldowns.
- **PersonalityEngine**  
  - Surfaces traits/persona definitions already authored in `CharacterPersonality.gd` to other systems (mood modifiers, task handling bias, conflict thresholds).

## Economy & Progression
- **EconomyManager (Autoload)**  
  - Tracks individual balances, payroll, purchases, and town-wide aggregates.  
  - Weekly payroll pipeline (salary + bonuses from TaskSystem performance, penalties for lateness).  
  - Supports inflation, vendor item catalogs, and transaction receipts (hook to EventBus/UI).
- **SaveManager + DatabaseManager**  
  - Versioned save schema, daily/weekly auto-save slots, delta compression.  
  - SQLite/JSON hybrid per design, migration hooks, integrity validation.

## World & UI Layer
- **LocationManager** (existing)  
  - Must own authoritative registry (id, type, capacity, occupancy) and respond to schedule/location queries.  
  - Exposes navigation helper APIs consumed by `AIMovementController`.
- **ObservationUIManager**  
  - Consolidated HUD for observer role: timeline, relationship graphs, task boards, economy dashboards.  
- **GodUI / Settings**  
  - Extend to surface time controls (pause/fast-forward), weather, and economy snapshots.

## Implemented Baseline (2025-10-19 Snapshot)
- Character controllers, movement (manual + AI), seating logic, and RoomManager utilities.
- Dialog stack (DialogManager + DialogService + APIManager) supporting LLM-driven conversations.
- MemoryManager (base version), ChatHistory, and GodUI task panel with manual task management.
- Basic saving via `GameSaveManager.gd`, map scenes (`scene/maps/Office.tscn`), and UI shell.
- Navigation helpers (`LocationManager`, `AIMovementController`) and tooling scripts for marker setup.

## Integration Contracts
- TimeSystem drives: WeatherSystem, ScheduleManager, TaskSystem, EconomyManager, MemoryManager, RelationshipManager.
- TaskSystem ⇄ EconomyManager (`get_weekly_performance`, wage adjustments), ⇄ ScheduleManager (daily task generation), ⇄ MemoryManager (task memories).
- ConflictSystem relies on RelationshipManager for trust data and records resolutions back into MemoryManager.
- SaveManager serializes state from TimeSystem, WeatherSystem, Economy/Economy transactions, AI state (tasks, relations, memories).

## Immediate Gaps (Code vs. Design)
1. Autoload roster currently missing: TimeSystem, WeatherSystem, EconomyManager, RelationshipManager, TaskSystem, ConflictSystem, SaveManager/DatabaseManager, EventBus, ConfigManager, DebugConsole, ObservationUIManager, PersonalityEngine, CareerSystem, ScheduleManager.  
2. No implementation for documented systems (time, economy, relationship, conflict, advanced task workflows).  
3. GameSaveManager must be superseded by spec-compliant SaveManager architecture.  
4. UI lacks observer dashboards, time controls, weather & economy visibility mandated by docs.  
5. MemoryManager / AIAgent require integration touchpoints for new signals (time-of-day shifts, task updates, conflict outcomes).  

These notes act as the living north-star checklist while we bring the Godot project up to the design baseline.
