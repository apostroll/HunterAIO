# HunterAIO

**HunterAIO** is an all-in-one quality-of-life suite designed specifically for Hunters in **World of Warcraft (Vanilla 1.12.1 / Interface: 11200)**. It consolidates pet management, in-combat trapping automation, visual ranged swing timing, and circular popup menus into a single lightweight, modular addon with an in-game graphical configuration panel.

---

## Features & Modules

### 1. PetCare (Smart Pet Lifecycle Management)
* **One-Button Pet Maintenance**:
  * **Dead Pet**: Casts `Revive Pet` (Hold `Alt` to revive if the corpse has despawned).
  * **Missing / Dismissed Pet**: Casts `Call Pet`.
  * **In Combat**: Casts `Mend Pet`.
  * **Out of Combat & Unhappy (Level 1 or 2)**: Checks if the pet is already eating (to prevent wasting food), then casts `Feed Pet` and uses the item in your configured bag/slot.
  * **Out of Combat & Happy (Level 3)**: Casts `Dismiss Pet`.
* **Bag/Slot Configuration**: Set and save your preferred food bag and slot permanently in-game.

### 2. SmartTrap (In-Combat Trapping & Cooldown Tracking)
* **Automatic Feign Death + Trap Automation**:
  * **Out of Combat**: Directly casts the requested trap.
  * **In Combat**: Automatically checks if Feign Death is learned, off cooldown, and has sufficient mana. Sets your pet to **Passive** and **Follow** (so pet combat won't pull you back into combat), casts **Feign Death**, and immediately lays the trap.
* **Standard Action Bar Cooldown Display**:
  * Hooks Blizzard's default action bars. Macros placed on your action bars will display real rotating cooldown spirals and digital countdown numbers (via `!OmniCC`).
  * **Auto-Icon Resolution**: If a macro uses the default `?` icon, it automatically displays the real spell icon from your spellbook.
  * **Full Tooltips**: Hovering over macro buttons displays the full spell tooltip.
  * **Combat Availability Dimming**: Dims the button when Feign Death is unavailable while in combat.

### 3. AutoShotTimer (Ranged Swing & Stutter-Step Bar)
* **Symmetrical Phase Visualization**:
  * **Shooting / Aim Phase (0.5s)**: Bar expands outward from the center to both edges in **Solid Red** (Hold still!).
  * **Reload Phase (`WeaponSpeed - 0.5s`)**: Bar starts full and shrinks inward from edges toward the center, smoothly transitioning from **Green $\rightarrow$ Yellow $\rightarrow$ Orange** (Stutter-step window—safe to move!).
* **Smooth Cadence & Movement Pausing**:
  * Continuously tracks weapon speed adjusted by quivers, Rapid Fire, and haste procs.
  * Pauses cleanly at the center and displays `Moving` if you are running when a shot wants to draw.
  * Automatically hides with zero delay upon leaving combat or target death.
* **Diagnostic Logging**: Optional event and combat log buffer with copy-paste window (`/haio ast log`).

### 4. RingMenu (Circular Popup Action Bars)
* **Radial Layout**:
  * 45px round action buttons symmetrically arranged around a minimalist 15px center dot.
  * Cropped icons and golden tracking ring borders.
* **Multiple Rings**:
  * **Ring 1**: Hunter Tracking (Track Beasts, Humanoids, Undead, Hidden, Elementals, Demons, Giants, Dragonkin).
  * **Ring 2**: Professions & Gathering (Find Herbs, Minerals, Treasure, Sense Undead/Demons).
  * **Ring 3**: Hunter Aspects (Hawk, Monkey, Cheetah, Pack, Wild, Beast).
* **Default Keybinding**: **`CTRL-D`** toggles Ring 1 at your mouse cursor.

### 5. In-Game Configuration Panel (`/haio`)
* Graphical control panel with tabs for **PetCare**, **SmartTrap**, **AutoShot**, and **RingMenu**.
* Sliders for bar size/scale, buttons to populate spell lists, food slot selector, and test preview toggles.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| **`/haio`** *(or `/hunteraio`)* | Open the graphical in-game Control Panel |
| **`/haio pet`** *(or `/petcare`)* | Execute the smart PetCare routine |
| **`/haio trap <name>`** | Cast smart trap (e.g. `/haio trap freezing`) |
| **`/haio ring <1-3>`** | Open a specific RingMenu |
| **`/haio ast test`** | Toggle AutoShotTimer preview bar |
| **`/haio ast log on` / `off`** | Enable/disable diagnostic event logging |
| **`/haio ast dump`** | Open copy-paste log window |

---

## Action Bar Macro Reference

Create standard macros with the `?` icon and place them anywhere on your action bars:

```lua
-- Smart Freezing Trap
/smarttrap freezing

-- Smart Frost Trap
/smarttrap frost

-- Smart Immolation Trap
/smarttrap immolation

-- Smart Explosive Trap
/smarttrap explosive

-- Smart Pet Maintenance
/petcare
```

---

## Key Bindings

Go to **Game Menu $\rightarrow$ Key Bindings $\rightarrow$ HunterAIO** to bind:
* **Open Ring 1 (Tracking)** *(Default: `CTRL-D`)*
* **Open Ring 2 (Professions & Gathering)**
* **Open Ring 3 (Aspects & Utility)**
* **Smart Traps** (Freezing, Frost, Immolation, Explosive)
