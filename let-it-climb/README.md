# Let it Climb - Game Design Document

## Overview
**Let it Climb** is a 2D action RPG that combines the progression mechanics of *Let it Die* with the combat system of *Vampire Survivors*. Players must climb a magical tower, fighting monsters and bosses while gathering experience, blueprints, and resources to upgrade their character and equipment.

## Core Gameplay Loop
1. **Base Preparation**: Upgrade character stats, research weapons/accessories, select loadout
2. **Tower Climbing**: Fight through floors, collect resources and blueprints
3. **Risk/Reward Decision**: Continue climbing for better rewards or return to base to secure progress
4. **Permanent Progression**: Use gathered resources for R&D and character upgrades
5. **Repeat**: Climb higher with improved gear and stats

## Character System

### Base Stats
All characters have five core stats that define their capabilities:
- **VIT (Vitality)**: Determines HP (10 HP per stat point)
- **STR (Strength)**: Affects melee weapon damage and requirements
- **DEX (Dexterity)**: Affects ranged weapon damage and requirements  
- **SPD (Speed)**: Affects movement speed and attack speed
- **LUK (Luck)**: Affects resource drops and blueprint discovery rates

### Character Classes
Characters are unlocked by reaching specific tower floors:

#### All Rounder (Starting Class)
- **Description**: Balanced fighter suitable for any playstyle
- **Stat Growth per Level**: VIT +3, STR +3, DEX +3, SPD +3, LUK +2
- **Starting Tier**: 1st Tier

#### Striker (Unlocked at Floor 5)
- **Description**: Melee specialist with devastating close-combat power
- **Stat Growth per Level**: VIT +3, STR +5, DEX +1, SPD +3, LUK +2
- **Focus**: High STR for powerful melee attacks, low DEX

#### Shooter (Unlocked at Floor 10)
- **Description**: Ranged specialist excelling at distance combat
- **Stat Growth per Level**: VIT +3, STR +1, DEX +5, SPD +3, LUK +2
- **Focus**: High DEX for ranged damage, low STR

#### Collector (Unlocked at Floor 15)
- **Description**: Resource gatherer with enhanced speed and luck
- **Stat Growth per Level**: VIT +2, STR +2, DEX +2, SPD +5, LUK +5
- **Focus**: High SPD/LUK for efficient resource gathering
- **Special**: Increased bag capacity at all tiers

#### Attacker (Unlocked at Floor 20)
- **Description**: Glass cannon with extreme offensive capabilities
- **Stat Growth per Level**: VIT +2, STR +5, DEX +5, SPD +3, LUK +2
- **Focus**: High STR/DEX but low survivability

### Character Tiers
Characters can be upgraded through tiers using EXP points:

| Tier | Max Level | Accessories | Bag Slots | Collector Bag |
|------|-----------|-------------|-----------|---------------|
| 1st  | 10        | 1           | 3         | 5             |
| 2nd  | 20        | 2           | 5         | 7             |
| 3rd  | 30        | 3           | 7         | 10            |
| 4th  | 50        | 5           | 10        | 15            |
| 5th  | 75        | 7           | 15        | 20            |

## Weapon System

### Weapon Categories

#### Melee Weapons (Scale with STR)
**Sword**
- **Base Stats**: Moderate damage, medium speed, close range
- **Tier 3 Upgrade**: Fire element (burn status)
- **Tier 4 Upgrade**: Full circle attack pattern
- **Tier 5 Upgrade**: Flame wave special attack

**Axe**
- **Base Stats**: High damage, slow speed, close range
- **Tier 3 Upgrade**: Lightning element (area damage)
- **Tier 4 Upgrade**: Full circle attack pattern
- **Tier 5 Upgrade**: Lightning storm special attack

**Bat**
- **Base Stats**: Very high damage, very slow speed, close range
- **Tier 3 Upgrade**: Ice element (freeze status)
- **Tier 4 Upgrade**: Full circle attack pattern
- **Tier 5 Upgrade**: Area slam special attack

#### Ranged Weapons (Scale with DEX)
**Bow**
- **Base Stats**: Moderate damage, medium speed, long range
- **Tier Upgrades**: 1/2/3/5/8 shots per attack
- **Tier 3 Addition**: Fire arrows (burn status)
- **Tier 5 Upgrade**: Arrow rain special attack

**Staff**
- **Base Stats**: High damage, slow speed, very long range
- **Tier Upgrades**: 1/2/3/5/8 shots per attack
- **Tier 3 Addition**: Lightning bolts (area damage)
- **Tier 5 Upgrade**: Magic burst special attack

**Knives**
- **Base Stats**: Low damage, very fast speed, medium range
- **Tier Upgrades**: 1/2/3/5/8 shots per attack
- **Tier 3 Addition**: Ice knives (freeze status)
- **Tier 5 Upgrade**: Ice shards special attack

### Weapon Stats
- **Fire Rate/Speed**: How quickly the weapon attacks
- **Range**: Attack distance/area coverage
- **Base Attack**: Raw damage output
- **Element Effect**: Special status effects (unlocked at higher tiers)

### Weapon Progression
- **Blueprints**: Found in tower chests, unlock new weapons
- **Tiers**: 5 tiers total, each adding new capabilities
- **Levels**: 4 levels per tier, improving base stats
- **Requirements**: Higher tiers/levels require specific STR/DEX values
- **R&D Cost**: Resources needed for each upgrade

### Elemental Effects
- **Fire**: Burn status - deals 10% of weapon's base attack as damage over time
- **Ice**: Freeze status - immobilizes enemy for 1-2 seconds (random)
- **Lightning**: Area damage - creates damage zone at impact point based on weapon level

## Accessory System

### Accessory Types
**Stat Rings**
- VIT Ring: +X% Vitality
- STR Ring: +X% Strength  
- DEX Ring: +X% Dexterity
- SPD Ring: +X% Speed
- LUK Ring: +X% Luck

**Weapon Stat Rings**
- Fire Rate Ring: +X% attack speed
- Range Ring: +X% attack range

**Element Rings**
- Fire Ring: +X% fire damage
- Lightning Ring: +X% lightning damage
- Ice Ring: +X% ice damage

**Special Rings**
- Second Wind Ring: Revives player X times with X% HP
- Greed Ring: Retain X% of resources/blueprints when dying

### Accessory Progression
- Same tier/level system as weapons (5 tiers, 4 levels each)
- Found as blueprints in tower chests
- Upgraded using resources through R&D

## Resource System

### Resource Types
**Wood Materials**
- Simple Wood (Common)
- Red Wood (Uncommon)  
- Dark Wood (Rare)

**Metal Materials**
- Iron (Common)
- Steel (Uncommon)
- Dark Steel (Rare)

**Elemental Stones**
- Fire Stone
- Ice Stone
- Lightning Stone

### Resource Management
- **Stacking**: Up to 9 resources per stack
- **Bag Limits**: Determined by character tier and class
- **Blueprint Storage**: Blueprints don't stack, take individual slots
- **Loss on Death**: All carried resources/blueprints lost unless using Greed Ring

## Enemy System

### Enemy Stats
- **Speed**: Movement and attack speed
- **Damage**: Contact damage dealt to player
- **HP**: Health points
- **Elemental Weakness/Strength**: Damage modifiers for different elements
- **EXP Reward**: Experience points given when defeated

### Enemy Scaling
- Enemy stats increase based on current tower floor
- Higher floors feature stronger, more diverse enemy types
- Sub-bosses appear every 5 floors
- Final boss at the top floor

### Enemy Behavior
- **Base Pattern**: Move toward player, deal damage on contact
- **Vampire Survivors Style**: Swarm-based combat with many enemies
- **Floor Progression**: New enemy types introduced at higher floors

## Base/Hub System

### NPCs and Locations

**Mage**
- **Function**: Character stat upgrades using EXP points
- **Services**: Level up characters, unlock new tiers

**Blacksmith**
- **Function**: Weapon and accessory R&D
- **Services**: Upgrade weapon/accessory tiers and levels using resources

**Tavern**
- **Function**: Character selection and management
- **Services**: Switch between unlocked character classes

**Storage**
- **Function**: Resource management
- **Services**: View stored resources, manage inventory

**Quest Board** (Future Feature)
- **Function**: Special objectives and challenges
- **Services**: Additional progression goals

### Base Navigation
**Stairs**: Access to Tower Floor 1 (always available)
**Portal**: Direct access to unlocked special floors (5, 10, 15, etc.)

## Game Progression

### Starting Conditions
- **Character**: All Rounder, Tier 1, Level 1
- **Weapon**: Sword, Tier 1, Level 1
- **Accessories**: None
- **Resources**: None

### Run Structure
1. **Loadout Selection**: Choose character, weapon, and accessories before entering tower
2. **Floor Progression**: Clear enemies to advance to next floor
3. **Decision Points**: After each floor, choose to continue climbing or return to base
4. **Resource Collection**: Gather materials and blueprints from chests and enemy drops
5. **Risk Management**: Weigh potential rewards against risk of losing everything

### Death and Consequences
- **Immediate Loss**: All carried resources and blueprints are lost
- **Permanent Retention**: Character levels, unlocked weapons/accessories, completed R&D
- **Greed Ring Exception**: Retains percentage of resources based on ring level

### Permanent Progression
- **Character Development**: EXP-based stat increases and tier upgrades
- **Equipment R&D**: Permanent weapon and accessory improvements
- **Class Unlocks**: New character classes available based on highest floor reached
- **Floor Portals**: Direct access to milestone floors (every 5 floors)

## Victory Conditions
- **Primary Goal**: Reach and defeat the final boss at the tower's peak
- **Secondary Goals**: Unlock all character classes, max out all equipment, complete all R&D

## Technical Implementation Notes
- Built in Godot Engine
- 2D top-down perspective
- Vampire Survivors-style automatic combat system
- Persistent save system for permanent progression
- Scalable difficulty based on floor number

## Recent Updates

### Weapon System Changes
- **Weapon Tiers**: Expanded from 4 to 5 tiers for all weapons
- **New Weapons**: 
  - **Bat**: Replaces Hammer - Very high damage melee weapon with ice element
  - **Staff**: Replaces Crossbow - High damage ranged weapon with lightning element
- **Sprite Assets**: Added high-quality weapon sprites for all 5 tiers of each weapon type
- **Asset Organization**: Weapons now organized in dedicated asset directories under `assets/weapons/`

---

*This document serves as the foundation for Let it Climb's development and will be updated as features are implemented and refined.*
