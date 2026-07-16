local mod = RegisterMod("Highlight Player", 1)
local config = include("highlight_player/config")
local game = Game()

local MCM_CATEGORY = "Highlight Player"
local MAX_OWNER_DEPTH = 6
local NOTICE_FRAMES = 90 -- render frames (60fps) the cycle notification stays on screen

local participants = { frame = -1 }
local mcmRegistered = false

local noticeFont = Font()
noticeFont:Load("font/pftempestasevencondensed.fnt")
local notice = { text = nil, framesLeft = 0 }

local OUTLINE_THICKNESS = 1 -- pixels
local OUTLINE_OFFSETS = {}
for dx = -OUTLINE_THICKNESS, OUTLINE_THICKNESS, OUTLINE_THICKNESS do
    for dy = -OUTLINE_THICKNESS, OUTLINE_THICKNESS, OUTLINE_THICKNESS do
        if dx ~= 0 or dy ~= 0 then
            OUTLINE_OFFSETS[#OUTLINE_OFFSETS + 1] = Vector(dx, dy)
        end
    end
end

local function mcmValue(attribute, default)
    if ModConfigMenu and ModConfigMenu.Config[MCM_CATEGORY] and ModConfigMenu.Config[MCM_CATEGORY][attribute] ~= nil then
        return ModConfigMenu.Config[MCM_CATEGORY][attribute]
    end
    return default
end

-- config.color is a palette name for readability and reorder-safety; resolve
-- it once to the numeric index MCM number settings store.
local defaultColorIndex = 1
for i, entry in ipairs(config.palette) do
    if entry.name == config.color then
        defaultColorIndex = i
        break
    end
end

-- Outline and ring Color objects for the selected palette entry, rebuilt only
-- when the selection changes.
local colors = { index = nil }

local function getColors()
    local index = mcmValue("color", defaultColorIndex)
    if config.palette[index] == nil then
        index = 1
    end

    if colors.index ~= index then
        local r, g, b = table.unpack(config.palette[index])
        colors = {
            index = index,
            -- Zeroed tint plus full offsets flatten every pixel to the chosen
            -- color; SetColorize would only yield a tinted grayscale copy,
            -- leaving the sprite's dark edges dark.
            outline = Color(0, 0, 0, 1, r, g, b),
            -- The ring spritesheet is white, so a plain tint recolors it.
            ring = Color(r, g, b, 1),
        }
    end
    return colors
end

local function getParticipants()
    local frame = game:GetFrameCount()
    if participants.frame == frame then
        return participants
    end

    local playerCount = game:GetNumPlayers()
    local controllers = {}
    local controllerOrder = {}

    for index = 0, playerCount - 1 do
        local controllerIndex = Isaac.GetPlayer(index).ControllerIndex
        if controllers[controllerIndex] == nil then
            controllers[controllerIndex] = true
            controllerOrder[#controllerOrder + 1] = controllerIndex
        end
    end

    -- Slot 0 disables the highlight; 1-n picks the matching player.
    local slot = math.min(math.max(math.floor(mcmValue("mainSlot", config.mainSlot)), 0), #controllerOrder)

    participants = {
        frame = frame,
        count = #controllerOrder,
        localController = slot > 0 and controllerOrder[slot] or nil,
    }
    return participants
end

local function getMainController()
    return getParticipants().localController
end

local function isMainParticipant(player)
    return player.ControllerIndex == getMainController()
end

local function findOwner(entity)
    local current = entity
    for _ = 1, MAX_OWNER_DEPTH do
        if not current then
            break
        end

        local player = current:ToPlayer()
        if player then
            return player
        end

        local familiar = current:ToFamiliar()
        if familiar and familiar.Player then
            return familiar.Player
        end

        current = current.SpawnerEntity or current.Parent
    end

    return nil
end

-- The reflection pass re-renders entities mirrored; WorldToScreen maps to the
-- unmirrored spot, so custom drawing must skip it.
local function isReflectionPass()
    return game:GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
end

-- Draws silhouette copies of the entity's sprite in 8 directions, then the
-- entity itself on top: only the outline ring around the shape stays visible.
-- Familiars and tears only — player costumes (items, transformations) are
-- separate sprites the engine composes on top, unreachable for recoloring
-- from the vanilla API, so their dark edges would break the outline.
local function renderOutline(entity)
    if isReflectionPass() then
        return
    end
    local screenPos = Isaac.WorldToScreen(entity.Position + entity.PositionOffset)

    local sprite = entity:GetSprite()
    -- Detached copy: sprite.Color is a live reference, so assigning the
    -- outline color below would mutate it and make the restore a no-op.
    local color = sprite.Color
    local originalColor = Color(color.R, color.G, color.B, color.A, color.RO, color.GO, color.BO)

    sprite.Color = getColors().outline
    for _, offset in ipairs(OUTLINE_OFFSETS) do
        sprite:Render(screenPos + offset)
    end

    sprite.Color = originalColor
    sprite:Render(screenPos)
end

-- Players get a crescent at the feet instead of an outline (see
-- renderOutline). It's a detached sprite drawn during the render pass, never
-- an entity: spawning one would alter the game state from local-only settings
-- and desync online sessions, where every client must simulate an identical
-- entity list. Post-player rendering can't draw behind the body, so the
-- crescent shape itself provides the occlusion a full ring would need.
local ringSprite = Sprite()
ringSprite:Load("gfx/highlight_ring.anm2", true)
ringSprite:Play("Idle", true)

local function renderRing(_, player)
    if not mcmValue("highlightPlayer", config.highlight.player)
        or not isMainParticipant(player)
        or isReflectionPass() then
        return
    end

    ringSprite.Color = getColors().ring
    -- PositionOffset tracks flight hover.
    ringSprite:Render(Isaac.WorldToScreen(player.Position + player.PositionOffset))
end

-- One renderer per entity kind, so each MCM toggle governs its own callback.
local function ownedEntityRenderer(attribute, default)
    return function(_, entity)
        if not mcmValue(attribute, default) then
            return
        end

        local owner = findOwner(entity)
        if owner and isMainParticipant(owner) then
            renderOutline(entity)
        end
    end
end

local function registerMCM()
    if mcmRegistered or not ModConfigMenu then
        return
    end
    mcmRegistered = true

    local slotDisplay = { [0] = "None", "P1", "P2", "P3", "P4" }
    local colorDisplay = {}
    for i, entry in ipairs(config.palette) do
        colorDisplay[i] = entry.name
    end

    ModConfigMenu.AddNumberSetting(
        MCM_CATEGORY, "Settings", "mainSlot",
        0, 4, 1, config.mainSlot,
        "Player",
        slotDisplay,
        { "The highlighted player.", "None: disabled." }
    )
    ModConfigMenu.AddKeyboardSetting(
        MCM_CATEGORY, "Settings", "cycleKey",
        config.hotkeys.cycleMainPlayer,
        "Cycle players hotkey",
        true,
        { "Cycle through none and the players without opening the menu." }
    )
    ModConfigMenu.AddNumberSetting(
        MCM_CATEGORY, "Settings", "color",
        1, #config.palette, 1, defaultColorIndex,
        "Color",
        colorDisplay,
        { "Highlight color for the crescent and the outlines." }
    )
    ModConfigMenu.AddKeyboardSetting(
        MCM_CATEGORY, "Settings", "cycleColorKey",
        config.hotkeys.cycleColor,
        "Cycle color hotkey",
        true,
        { "Cycle through the palette colors without opening the menu." }
    )
    ModConfigMenu.AddBooleanSetting(
        MCM_CATEGORY, "Settings", "highlightPlayer",
        config.highlight.player,
        "Highlight player",
        { [true] = "On", [false] = "Off" },
        { "Crescent under the main player." }
    )
    ModConfigMenu.AddBooleanSetting(
        MCM_CATEGORY, "Settings", "highlightFamiliars",
        config.highlight.familiars,
        "Highlight familiars",
        { [true] = "On", [false] = "Off" },
        { "Outline on the main player's familiars." }
    )
    ModConfigMenu.AddBooleanSetting(
        MCM_CATEGORY, "Settings", "highlightTears",
        config.highlight.tears,
        "Highlight tears",
        { [true] = "On", [false] = "Off" },
        { "Outline on the main player's tears." }
    )
end

local function onGameStarted()
    registerMCM()
    -- The main player is session state, not a saved preference: MCM persists
    -- its config across runs, so force the default back at every run start.
    if ModConfigMenu and ModConfigMenu.Config[MCM_CATEGORY] then
        ModConfigMenu.Config[MCM_CATEGORY].mainSlot = config.mainSlot
    end
end

local function showNotice(text)
    notice.text = text
    notice.framesLeft = text and NOTICE_FRAMES or 0
end

local function cycleMainSlot()
    -- Cycle only across "none" and the players actually in session; fixed
    -- P3/P4 slots would collapse onto the last participant and feel like
    -- dead presses.
    local count = getParticipants().count
    local current = math.min(ModConfigMenu.Config[MCM_CATEGORY].mainSlot or config.mainSlot, count)
    local nextSlot = (current + 1) % (count + 1)
    ModConfigMenu.Config[MCM_CATEGORY].mainSlot = nextSlot

    showNotice(nextSlot > 0 and ("P" .. nextSlot) or nil)
end

local function cycleColor()
    local current = ModConfigMenu.Config[MCM_CATEGORY].color or defaultColorIndex
    local nextIndex = current % #config.palette + 1
    ModConfigMenu.Config[MCM_CATEGORY].color = nextIndex

    showNotice(config.palette[nextIndex].name)
end

local HOTKEYS = {
    { attribute = "cycleKey", default = config.hotkeys.cycleMainPlayer, action = cycleMainSlot },
    { attribute = "cycleColorKey", default = config.hotkeys.cycleColor, action = cycleColor },
}

-- Polled at render rate (60fps): MC_POST_UPDATE runs at 30fps, misses short
-- key taps between logic frames and doesn't run while the game is paused.
-- Hotkeys write to the MCM config, so they're inactive without it.
local function checkHotkeys()
    if not ModConfigMenu or not ModConfigMenu.Config[MCM_CATEGORY] then
        return
    end

    for _, hotkey in ipairs(HOTKEYS) do
        local key = mcmValue(hotkey.attribute, hotkey.default)
        if key and key >= 0 and Input.IsButtonTriggered(key, 0) then
            hotkey.action()
        end
    end
end

local function renderNotice()
    if notice.framesLeft <= 0 then
        return
    end
    notice.framesLeft = notice.framesLeft - 1

    local alpha = math.min(notice.framesLeft / 30, 1) -- fade out over the last half second
    noticeFont:DrawString(
        notice.text,
        0, Isaac.GetScreenHeight() - 24,
        KColor(1, 1, 1, alpha),
        Isaac.GetScreenWidth(), true
    )
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, renderRing)
mod:AddCallback(ModCallbacks.MC_POST_FAMILIAR_RENDER, ownedEntityRenderer("highlightFamiliars", config.highlight.familiars))
mod:AddCallback(ModCallbacks.MC_POST_TEAR_RENDER, ownedEntityRenderer("highlightTears", config.highlight.tears))
mod:AddCallback(ModCallbacks.MC_POST_RENDER, checkHotkeys)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, renderNotice)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onGameStarted)
