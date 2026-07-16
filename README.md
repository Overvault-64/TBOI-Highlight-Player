# Highlight Player

Visual accessibility mod for *The Binding of Isaac: Repentance+*. Requires [**Mod Config Menu**](https://steamcommunity.com/sharedfiles/filedetails/?id=3701683951).

<img width="600" height="320" alt="ezgif-5c46e75716994e85" src="https://github.com/user-attachments/assets/adff37c0-cd71-49f8-8a11-1ffba2000593" />

## Features
- Highlights the selected player with a perspective crescent under their feet, and their familiars and tears with an outline.
- Purely visual and client-side: safe in online sessions, each player can use their own settings without desyncing the run.
- Highlight color selectable from a palette; player, familiars and tears can each be toggled individually.
- Treats characters sharing the same controller, such as Jacob and Esau, as part of the same player.

## Configuration

All options are in the **Mod Config Menu**, adjustable in real time without restarting the run:

- **Main player**: which party slot (P1-P4) to highlight (in online sessions, main player is not detected automatically due to API limitations);
- **Player switch key**: hotkey to cycle to the next main player (None→P1→P2→P3→P4→None) without opening the menu, `I` by default;
- **Color**: highlight color, picked from the palette defined in `highlight_player/config.lua`;
- **Color switch key**: hotkey to cycle to the next palette color without opening the menu, `O` by default;
- **Highlight player / familiars / tears**: individual toggles for each highlight target.

Default values are in `highlight_player/config.lua`.

## Installation

1. Download the [latest release](https://github.com/Overvault-64/TBOI-Highlight-Player/releases/latest).
2. Extract the content into the Repentance+ mods directory.
3. Enable **Highlight Player** from the Mods menu.
