# Unit Card Display Design

## Goal

Extend the existing `CardDisplay` component to support rendering guests, bosses, and mythical beasts — collectively "units". This gives units the same visual treatment as stall/spell/relic cards, for use in View Deck and discover overlays.

## Context

- `CardDisplay` is 160×220px, used everywhere (hand, shop, discover, tier preview)
- No runtime state needed — purely definition-driven display
- Units have: sprite, name, needs (food/joy/interact), money, skills, rarity, type flags

## Layout

Same 160×220px card shell as stall cards. Top to bottom:

| Area | ~Height | Content |
|------|---------|---------|
| Sprite | 50px | Icon from `guest_def.icon_path` |
| Name | 20px | `guest_def.get_display_name()`, center-aligned |
| Separator | 1px | Thin line (existing) |
| Needs row | 20px | Icon+number pairs for each need type, horizontally centered |
| Description | flex | Auto-generated skill text, auto-scaled if >3 lines |
| Type badge | 16px | "guest" / "boss" / "beast" |

### Needs Row

- Small icons (~14px) for each need type: food, joy, interact
- Number displayed next to each icon
- Money shown with coin icon
- Horizontal layout, centered, small gaps between pairs

## Approach: Extend CardDisplay

Add `setup_unit(guest_def: GuestDefinition)` to `CardDisplay` rather than creating a separate component. Rationale:

- The card shell is identical (icon, name, separator, description, badge, rarity colors)
- Only the stats area differs: stalls show operation stats, units show needs icons
- Avoids duplicating rarity color logic, description auto-scaling, sizing code

### Type Badge Logic

- `guest_def.is_boss` → "boss"
- `guest_def.is_mythical_beast` → "beast"
- Otherwise → "guest"

### Description

Use same skill description concatenation as cards: join all skill descriptions from `skill_data`. If explicit `description` exists on definition, use that instead.

## Files Changed

- `src/ui/components/card_display.gd` — Add `setup_unit()`, needs row building logic
- `src/ui/components/card_display.tscn` — Add needs row container (HBoxContainer), hidden by default
- `src/ui/overlays/discover_overlay.gd` — Detect `GuestDefinition` in option data, render via `CardDisplay.setup_unit()`
- Need icons — Small 14px icons for food, joy, interact, coin (placeholders or existing assets)
