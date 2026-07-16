return {
    -- Main-player selection applied at every run start: 0 = none (mod
    -- inactive), 1-4 = always P1-P4. Changeable in real time from Mod Config
    -- Menu or hotkey, but never persisted across runs.
    mainSlot = 0,

    -- Name of a palette entry below. Overridable (and persisted) from Mod Config Menu.
    color = "White",

    -- What gets highlighted. Overridable (and persisted) from Mod Config Menu.
    highlight = {
        player = true,
        familiars = true,
        tears = true,
    },

    -- Available highlight colors ({ name, r, g, b }, 0-1 floats).
    palette = {
        { name = "White", 1.0, 1.0, 1.0 },
        { name = "Yellow", 1.0, 0.9, 0.2 },
        { name = "Orange", 1.0, 0.5, 0.1 },
        { name = "Red", 1.0, 0.2, 0.2 },
        { name = "Magenta", 1.0, 0.3, 1.0 },
        { name = "Cyan", 0.3, 1.0, 1.0 },
        { name = "Green", 0.3, 1.0, 0.3 },
    },

    -- Default keys, overridable in real time from Mod Config Menu.
    hotkeys = {
        -- Cycle the main player (none/P1-P4) without opening the menu.
        cycleMainPlayer = Keyboard.KEY_I,
        -- Cycle the highlight color through the palette.
        cycleColor = Keyboard.KEY_O,
    },
}
