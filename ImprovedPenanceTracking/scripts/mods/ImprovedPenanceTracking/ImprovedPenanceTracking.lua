local mod = get_mod("ImprovedPenanceTracking")

local HudElementTacticalOverlay = require("scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay")

local need_redraw = false

local function get_local_player()
    local local_player_id = 1
    return Managers.player:local_player(local_player_id)
end

local function is_eligable(achievement)
    if mod:get("disable_per_character_tracking") then
        local player = get_local_player()
        local archetype_name = player:archetype_name()
        if achievement.category == "ogryn_2" or achievement.category == "ogryn_progression" or achievement.category == "ogryn_abilites" then
            return archetype_name == "ogryn"
        end
        if achievement.category == "zealot_2" or achievement.category == "zealot_progression" or achievement.category == "zealot_abilites" then
            return archetype_name == "zealot"
        end
        if achievement.category == "psyker_2" or achievement.category == "psyker_progression" or achievement.category == "psyker_abilites" then
            return archetype_name == "psyker"
        end
        if achievement.category == "veteran_2" or achievement.category == "veteran_progression" or achievement.category == "veteran_abilites" then
            return archetype_name == "veteran"
        end
        if achievement.category == "adamant" or achievement.category == "adamant_progression" or achievement.category == "adamant_abilites" then
            return archetype_name == "adamant"
        end
        if achievement.category == "broker" or achievement.category == "broker_progression" or achievement.category == "broker_abilites" then
            return archetype_name == "broker"
        end
    end
    return true
end

mod.on_setting_changed = function(setting_id)
    if setting_id == "disable_per_character_tracking" then
        need_redraw = true
    end
end

mod:hook_require("scripts/settings/ui/ui_settings", function(instance)
    instance.max_favorite_achievements = 20
end)

mod:hook(HudElementTacticalOverlay, "_update_achievements", function(f, self, dt, ui_renderer)
    local save_data = Managers.save:account_data()
    local favorite_achievements = save_data.favorite_achievements
    local current_achievements = self._current_achievements
    local has_achievements = current_achievements ~= nil
    local tracked_achievements_changed = self._favorite_achievements and not table.array_equals(self._favorite_achievements, favorite_achievements)
    local show_right_side = self._context.show_right_side
    local should_update = show_right_side and
        (not has_achievements or need_redraw or tracked_achievements_changed)

    if should_update then
        self:_setup_achievements(ui_renderer)
        need_redraw = false
    end
end)

mod:hook(HudElementTacticalOverlay, "_setup_achievements", function(f, self, ui_renderer)
    local page_key = "achievements"
    local save_data = Managers.save:account_data()
    local favorite_achievements = save_data.favorite_achievements
    local configs = {}
    local current_achievements = {}

    for i = 1, #favorite_achievements do
        local id = favorite_achievements[i]

        local definition = Managers.achievements:achievement_definition(id)

        if definition and is_eligable(definition) then
            configs[#configs + 1] = {
                blueprint = "achievement",
                id = id,
            }
            current_achievements[#current_achievements + 1] = id
        end
    end

    self._current_achievements = current_achievements
    self._tracked_achievements = #current_achievements
    self._favorite_achievements = table.shallow_copy_array(favorite_achievements)

    if #current_achievements == 0 then
        self:_delete_right_panel_widgets(page_key, ui_renderer)
        return
    end

    self:_create_right_panel_widgets(page_key, configs, ui_renderer)
end)