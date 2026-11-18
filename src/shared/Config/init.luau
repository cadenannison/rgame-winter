--!strict
-- Config: merges the domain modules in this folder into one table. Public API: Config.<Section>.<Key>.
-- Domain modules (edit the one that owns the section): see docs/INDEX.md.

local Core = require("@self/Core")
local Debug = require("@self/Debug")
local Survival = require("@self/Survival")
local World = require("@self/World")
local Items = require("@self/Items")
local Loot = require("@self/Loot")
local Mobs = require("@self/Mobs")
local Horror = require("@self/Horror")
local Lighting = require("@self/Lighting")
local Perf = require("@self/Perf")
local Meta = require("@self/Meta")
local Ui = require("@self/Ui")
local Art = require("@self/Art")

export type DebugConfig = Debug.DebugConfig
export type TimeConfig = Survival.TimeConfig
export type MeterConfig = Survival.MeterConfig
export type FireCost = Survival.FireCost
export type FireTier = Survival.FireTier
export type FireRingConfig = Survival.FireRingConfig
export type FireConfig = Survival.FireConfig
export type FireMeterConfig = Survival.FireMeterConfig
export type ScalingConfig = Mobs.ScalingConfig
export type WorldConfig = World.WorldConfig
export type SlotTags = World.SlotTags
export type InventoryConfig = Items.InventoryConfig
export type ToolTierConfig = Items.ToolTierConfig
export type GatherConfig = Items.GatherConfig
export type FoodConfig = Survival.FoodConfig
export type CraftStation = Items.CraftStation
export type CraftConfig = Items.CraftConfig
export type BuildConfig = Items.BuildConfig
export type WarmSpotConfig = Survival.WarmSpotConfig
export type GhostConfig = Items.GhostConfig
export type MobStats = Mobs.MobStats
export type MobConfig = Mobs.MobConfig
export type CombatConfig = Mobs.CombatConfig
export type DownedConfig = Survival.DownedConfig
export type HeldVisual = Ui.HeldVisual
export type HeldConfig = Ui.HeldConfig
export type FeedbackConfig = Ui.FeedbackConfig
export type NightConfig = Mobs.NightConfig
export type LightingConfig = Lighting.LightingConfig
export type NetConfig = Perf.NetConfig
export type LobbyConfig = Meta.LobbyConfig
export type RunConfig = Meta.RunConfig
export type TeleportConfig = Meta.TeleportConfig
export type MetaConfig = Meta.MetaConfig
export type PerfConfig = Perf.PerfConfig
export type SettingsConfig = Ui.SettingsConfig
export type HintsConfig = Ui.HintsConfig
export type BiomeConfig = World.BiomeConfig
export type BiomeTuning = World.BiomeTuning
export type StructuresConfig = World.StructuresConfig
export type TreeClass = World.TreeClass
export type ForestConfig = World.ForestConfig
export type BiomeTerrain = World.BiomeTerrain
export type TerrainConfig = World.TerrainConfig
export type LootConfig = Loot.LootConfig
export type ChestCountRule = Loot.ChestCountRule
export type ChestBeamConfig = Loot.ChestBeamConfig
export type MassiveBudget = World.MassiveBudget
export type MassiveStructure = World.MassiveStructure
export type MassiveConfig = World.MassiveConfig
export type TreesConfig = World.TreesConfig
export type FireRulesConfig = Survival.FireRulesConfig
export type WolfScalingConfig = Mobs.WolfScalingConfig
export type ShelterConfig = Survival.ShelterConfig
export type ShadowConfig = World.ShadowConfig
export type ClothingConfig = Survival.ClothingConfig
export type EventsConfig = Horror.EventsConfig
export type DreadConfig = Horror.DreadConfig
export type IsolationConfig = Horror.IsolationConfig
export type StalkerConfig = Horror.StalkerConfig
export type LurkerConfig = Horror.LurkerConfig
export type ScaresConfig = Horror.ScaresConfig
export type CueConfig = Horror.CueConfig
export type HorrorCueConfig = Horror.HorrorCueConfig
export type BossConfig = Mobs.BossConfig
export type BlizzardConfig = Horror.BlizzardConfig
export type SprintConfig = Survival.SprintConfig
export type ForageConfig = Items.ForageConfig
export type ProjectileConfig = Mobs.ProjectileConfig
export type StorageConfig = Items.StorageConfig
export type ItemEntry = Items.ItemEntry
export type ItemsConfig = Items.ItemsConfig
export type EquipmentConfig = Items.EquipmentConfig
export type SiteGroundConfig = World.SiteGroundConfig
export type MapConfig = World.MapConfig
export type PingConfig = Items.PingConfig
export type RepairConfig = Items.RepairConfig
export type CookingConfig = Items.CookingConfig
export type BuffConfig = Survival.BuffConfig
export type DurabilityConfig = Survival.DurabilityConfig
export type HubArtConfig = Art.HubArtConfig
export type WorldBiomeArt = Art.WorldBiomeArt
export type WorldArtConfig = Art.WorldArtConfig
export type ArtConfig = Art.ArtConfig

export type Config =
	Core.Sections
	& Debug.Sections
	& Survival.Sections
	& World.Sections
	& Items.Sections
	& Loot.Sections
	& Mobs.Sections
	& Horror.Sections
	& Lighting.Sections
	& Perf.Sections
	& Meta.Sections
	& Ui.Sections
	& Art.Sections

local modules: { any } =
	{ Core, Debug, Survival, World, Items, Loot, Mobs, Horror, Lighting, Perf, Meta, Ui, Art }
local merged = {}
for _, module in modules do
	for key, value in module do
		assert(merged[key] == nil, `Config key {key} defined in more than one module`)
		merged[key] = value
	end
end

return merged :: Config
