local mod = get_mod("FilterTrash")

mod._info = {
    title = "FilterTrash",
    author = "seroperson",
    date = "2025/12/09",
    version = "0.3.1",
}
mod:info("=== FilterTrash Version " .. mod._info.version .. " Loading ===")

-- State variable to track if filtering is enabled
mod.filtering_enabled = true

-- Toggle function for hotkey
function mod.toggle_filtering()
    mod.filtering_enabled = not mod.filtering_enabled
    local status = mod.filtering_enabled and "enabled" or "disabled"
    mod:echo("Filtering " .. status)
end

local Promise = require("scripts/foundation/utilities/promise")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local WeaponStats = require("scripts/utilities/weapon_stats")
local MasterItems = require("scripts/backend/master_items")
local Items = require("scripts/utilities/items")
local StoreNames = require("scripts/settings/backend/store_names")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISettings = require("scripts/settings/ui/ui_settings")

local function filter_items(key, data)
    -- If filtering is disabled, return data without modification
    if not mod.filtering_enabled then
        return Promise.resolved(data)
    end

    local show_ideal_60 = mod:get(string.format("%s_show_ideal_60", key))
    local show_ideal_percent = mod:get(string.format("%s_show_ideal_percent", key))
    local ideal_percent = mod:get(string.format("%s_ideal_percent", key))
    local gadget_item_level_filter_is_enabled = mod:get(string.format("%s_gadget_group_filter_by_item_level",
        key))
    local gadget_item_level_filter = mod:get(string.format("%s_gadget_item_level", key))

    local filtering_by_stat = {}
    for _, weapon_template in pairs(WeaponTemplates) do
        if weapon_template.base_stats then
            for stat_name, stat_object in pairs(weapon_template.base_stats) do
                if stat_object and stat_object.display_name then
                    -- if filtering by this stat is enabled
                    if mod:get(string.format("group_filter_by_stat_%s", stat_object.display_name)) then
                        filtering_by_stat[stat_name] = mod:get(stat_object.display_name)
                    end
                end
            end
        end
    end

    data.offers = table.compact_array(table.filter(data.offers, function(offer)
        local modified_desciption = table.clone(offer.description)
        modified_desciption.gear_id = offer.description.gearId
        local item = MasterItems.get_store_item_instance(modified_desciption)

        if not item then
            return true
        end

        if offer.description.type == "weapon" then
            local result = true

            local weapon_stats = WeaponStats:new(item)
            local comparing_stats = weapon_stats:get_comparing_stats()
            local max_stats = Items.preview_stats_change(item, Items.max_expertise_level(), comparing_stats)

            if not max_stats then
                return result
            end

            local ideal_bad_stat = table.filter(max_stats, function(max_stat)
                return max_stat.value == 60
            end)
            local has_ideal_bad_stat = table.size(ideal_bad_stat) == 1

            local all_stats_above_threshold = table.filter(max_stats, function(max_stat)
                return max_stat.value >= ideal_percent
            end)
            local has_all_stats_above_threshold = table.size(all_stats_above_threshold) == 5

            -- Filter if:
            -- - toggle is enabled and condition satisfied
            -- - both toggles are disabled
            result = result and
                ((show_ideal_60 and has_ideal_bad_stat) or (show_ideal_percent and has_all_stats_above_threshold) or (not show_ideal_60 and not show_ideal_percent))

            for i = 1, #comparing_stats do
                local stat_data = comparing_stats[i]
                local key = stat_data.name
                local value = max_stats[stat_data.display_name].value
                if filtering_by_stat[key] then
                    local this_filtering = value >= filtering_by_stat[key]
                    if result == nil then
                        result = this_filtering
                    else
                        result = result and this_filtering
                    end
                end
            end

            return result
        else
            local result = true
            if gadget_item_level_filter_is_enabled then
                -- +0 is a conversion from string to number
                local gadget_level = Items.expertise_level(item, true, true) + 0
                result = gadget_level >= gadget_item_level_filter
            end

            return result
        end
    end))

    return Promise.resolved(data)
end

local function filter_items_contracts(data)
    return filter_items("contracts", data)
end

local function filter_items_brunt(data)
    return filter_items("brunt", data)
end

-- Store character profile data for items
mod.character_avatar_data = {}

local function _get_player_portrait_frame_material(profile)
    local frame_material = UISettings.portrait_frame_default_material

    -- mod:dump(profile, "profile", 3)
    if profile and type(profile) == "table" then
        local loadout = profile.loadout

        if loadout then
            local frame_item = loadout.slot_portrait_frame

            if frame_item and frame_item.icon_material and frame_item.icon_material ~= "" then
                frame_material = frame_item.icon_material
            end
        end
    end

    return frame_material
end



local function update_portrait(self, widget, profile)
    local content = widget.content

    if content.frame_load_id then
        Managers.ui:unload_item_icon(content.frame_load_id)

        content.frame_load_id = nil
    end

    if content.portrait_load_id then
        Managers.ui:unload_profile_portrait(content.portrait_load_id)

        content.portrait_load_id = nil
    end

    if profile then
        -- mod:notify("Updating profile for user " .. profile.name)

        local profile_icon_loaded_callback = callback(mod, "_cb_set_player_icon", widget)
        local profile_icon_unloaded_callback = callback(mod, "_cb_unset_player_icon", widget, self._ui_renderer)

        content.portrait_load_id = Managers.ui:load_profile_portrait(profile, profile_icon_loaded_callback, nil,
            profile_icon_unloaded_callback)
    end
end

mod._cb_set_player_icon = function(self, widget, grid_index, rows, columns, render_target)
    -- mod:notify(string.format("%s, %s, %s, %s, %s", widget, profile, grid_index, rows, columns))
    local profile = widget.content.profile
    local portrait_style = widget.style.portrait

    widget.content.character_portrait = _get_player_portrait_frame_material(profile)

    local material_values = portrait_style.material_values

    material_values.use_placeholder_texture = 0
    material_values.rows = rows
    material_values.columns = columns
    material_values.grid_index = grid_index - 1
    material_values.texture_icon = render_target
end

mod._cb_unset_player_icon = function(self, widget, ui_renderer)
    UIWidget.set_visible(widget, ui_renderer, false)

    local material_values = widget.style.portrait.material_values

    material_values.use_placeholder_texture = nil
    material_values.rows = nil
    material_values.columns = nil
    material_values.grid_index = nil
    material_values.texture_icon = nil
    widget.content.character_portrait = "content/ui/materials/base/ui_portrait_frame_base_no_render"
end

-- Function to get all owned character profiles
local function get_all_character_profiles()
    return Managers.data_service.profiles:fetch_all_profiles():next(function(result)
        return Promise.resolved(result.profiles or {})
    end)
end

-- Function to fetch stores for all characters and merge them
local function get_all_characters_store()
    return get_all_character_profiles():next(function(profiles)
        if #profiles == 0 then
            return Promise.rejected("No characters found")
        end

        -- Create promises for each character's store
        local store_promises = {}
        local profile_lookup = {}
        for i = 1, #profiles do
            local profile = profiles[i]
            local character_id = profile.character_id
            local archetype = profile.archetype
            local archetype_name = archetype.name

            -- Store profile for later lookup
            profile_lookup[i] = profile

            -- Get the store method name for this archetype
            local store_method_name = StoreNames.by_archetype.credit[archetype_name]

            if store_method_name then
                local store_backend = Managers.backend.interfaces.store

                -- Call the backend store method directly
                if store_backend[store_method_name] then
                    local store_promise = store_backend[store_method_name](store_backend, nil, character_id)
                    table.insert(store_promises, store_promise)
                end
            end
        end

        -- Wait for all stores to be fetched
        return Promise.all(table.unpack(store_promises)):next(function(stores)
            -- Merge all offers from all stores
            local merged_offers = {}
            local seen_offer_ids = {}
            local offer_to_profile = {}

            for i = 1, #stores do
                local store = stores[i]
                local offers = store.data.personal
                local profile = profile_lookup[i]

                if store and offers then
                    for j = 1, #offers do
                        local offer = offers[j]
                        local offer_id = offer.offerId

                        -- Only add if we haven't seen this offer before
                        if not seen_offer_ids[offer_id] then
                            table.insert(merged_offers, offer)
                            seen_offer_ids[offer_id] = true
                            -- Store the profile for this offer
                            offer_to_profile[offer_id] = profile
                        end
                    end
                end
            end

            -- Return a merged store structure
            local merged_store = {
                offers = merged_offers,
                currentRotation = stores[1] and stores[1].currentRotation or {},
                nextRotation = stores[1] and stores[1].nextRotation or {},
                offer_to_profile = offer_to_profile
            }

            return Promise.resolved(merged_store)
        end)
    end)
end

-- Hook the credits vendor background view to add our custom button
mod:hook_require("scripts/ui/views/credits_vendor_background_view/credits_vendor_background_view_definitions",
    function(definitions)
        -- Add a new button option for "All Characters"
        local button_options = definitions.button_options_definitions

        while #button_options > 2 do
            table.remove(button_options, 2)
        end

        -- Insert the new button after the first "Buy" button
        local localized_button_name = mod:localize("all_characters_button")
        local localized_title = mod:localize("all_characters_title")

        table.insert(button_options, 2, {
            unlocalized_name = localized_button_name,
            localized = true,
            callback = function(self)
                local UISettings = require("scripts/settings/ui/ui_settings")

                local tab_bar_params = {
                    hide_tabs = true,
                    layer = 10,
                    tabs_params = {
                        {
                            blur_background = false,
                            unlocalized_name = localized_title,
                            view = "credits_vendor_view",
                            context = {
                                use_item_categories = true,
                                optional_store_service = "get_all_characters_store_custom",
                            },
                            input_legend_buttons = {
                                {
                                    alignment = "right_alignment",
                                    display_name = "loc_weapon_inventory_inspect_button",
                                    input_action = "hotkey_item_inspect",
                                    on_pressed_callback = "cb_on_inspect_pressed",
                                    visibility_function = function(parent)
                                        local active_view = parent._active_view

                                        if active_view then
                                            local view_instance = Managers.ui:view_instance(active_view)
                                            local previewed_item = view_instance and view_instance._previewed_item

                                            if previewed_item then
                                                local item_type = previewed_item.item_type
                                                local ITEM_TYPES = UISettings.ITEM_TYPES

                                                if item_type == ITEM_TYPES.WEAPON_MELEE or item_type == ITEM_TYPES.WEAPON_RANGED or item_type == ITEM_TYPES.WEAPON_SKIN or item_type == ITEM_TYPES.END_OF_ROUND or item_type == ITEM_TYPES.GEAR_EXTRA_COSMETIC or item_type == ITEM_TYPES.GEAR_HEAD or item_type == ITEM_TYPES.GEAR_LOWERBODY or item_type == ITEM_TYPES.GEAR_UPPERBODY or item_type == ITEM_TYPES.COMPANION_GEAR_FULL or item_type == ITEM_TYPES.EMOTE then
                                                    return true
                                                end
                                            end
                                        end

                                        return false
                                    end,
                                },
                                {
                                    alignment = "right_alignment",
                                    display_name = "loc_item_toggle_equipped_compare",
                                    input_action = "hotkey_item_compare",
                                    on_pressed_callback = "cb_on_toggle_item_compare",
                                    visibility_function = function(parent)
                                        local active_view = parent._active_view

                                        if active_view then
                                            local view_instance = Managers.ui:view_instance(active_view)

                                            return view_instance and view_instance._previewed_item ~= nil
                                        end

                                        return false
                                    end,
                                },
                            },
                        },
                    },
                }

                self:_setup_tab_bar(tab_bar_params, {
                    fetch_store_items_on_enter = true,
                    hide_price = true,
                })
            end,
        })

        return definitions
    end)

-- Hook the store service to add our custom method
mod:hook_require("scripts/managers/data_service/services/store_service", function(StoreService)
    StoreService.get_all_characters_store_custom = function(self, ignore_event_trigger)
        return get_all_characters_store()
    end

    return StoreService
end)

mod:hook_require("scripts/ui/views/marks_vendor_view/marks_vendor_view", function(instance)
    mod:hook(instance, "_get_store", function(f, self)
        return f(self):next(filter_items_contracts)
    end)
end)

mod:hook_require("scripts/ui/views/credits_vendor_view/credits_vendor_view", function(instance)
    -- Original filtering hook
    mod:hook(instance, "_get_store", function(f, self)
        local promise = f(self)

        -- Apply filtering
        promise = promise:next(filter_items_brunt)

        -- Capture character profile data if using custom store
        if self._optional_store_service == "get_all_characters_store_custom" then
            promise = promise:next(function(data)
                if data and data.offer_to_profile then
                    mod.character_avatar_data = data.offer_to_profile
                    local count = 0
                    for k, v in pairs(mod.character_avatar_data) do
                        count = count + 1
                    end
                end
                return data
            end)
        end

        return promise
    end)

    --  Hook _convert_offers_to_layout_entries to add profile data
    mod:hook(instance, "_convert_offers_to_layout_entries", function(func, self, item_offers)
        local layout = func(self, item_offers)

        -- Add character profile to each layout entry if available
        local profile_count = 0
        if mod.character_avatar_data then
            for k, v in pairs(mod.character_avatar_data) do
                profile_count = profile_count + 1
            end
        end
        if mod.character_avatar_data and profile_count > 0 then
            for i = 1, #layout do
                local entry = layout[i]

                if entry.offer and entry.offer.offerId then
                    local profile = mod.character_avatar_data[entry.offer.offerId]
                    if profile then
                        entry.character_profile = profile
                        -- mod:notify(string.format("Added profile for offer %s at layout index %d", entry.offer.offerId, i))
                    end
                end
            end
        end

        return layout
    end)

    mod:hook(instance, "init", function(func, self, definitions, settings, context, dynamic_package_name)
        func(self, definitions, settings, context, dynamic_package_name)
    end)

    -- Hook present_grid_layout to create portrait widgets
    mod:hook(instance, "present_grid_layout",
        function(func, self, layout, on_present_callback)
            -- mod:notify(string.format("In present_grid_layout"))

            local gen_blueprints_func = require("scripts/ui/view_content_blueprints/item_blueprints")
            local grid_settings = self._definitions.grid_settings
            local grid_size = grid_settings.grid_size
            local blueprints = table.clone(gen_blueprints_func(grid_size))
            local store_item = blueprints.store_item
            local pass_template = store_item.pass_template
            -- save_original_funcs(store_item)
            -- store_item.init = function(parent, widget, ...)
            -- item_init_func(parent, widget, ...)
            -- end

            local portrait_widget_def = {
                pass_type = "texture_uv",
                style_id = "portrait",
                value = "content/ui/materials/base/ui_portrait_frame_base",
                value_id = "portrait",
                style = {
                    vertical_alignment = "bottom",
                    offset = {
                        5,
                        0,
                        10
                    },
                }
                -- change_function = function(content, style)
                -- mod:dump(content, "content_blueprint", 2)
                -- return false
                -- end,
            }
            -- portrait_widget.content.portrait_load_id = Managers.ui:load_profile_portrait(profile, cb)
            table.insert(pass_template, portrait_widget_def)

            local grid_display_name = self._grid_display_name
            local left_click_callback = callback(self, "cb_on_grid_entry_left_pressed")
            local left_double_click_callback = callback(self, "cb_on_grid_entry_left_double_click")
            local right_click_callback = callback(self, "cb_on_grid_entry_right_pressed")
            if layout[1] and not layout[1].is_external then
                self:_add_external_layout(layout)
            end
            local grow_direction = self._grow_direction or "down"

            local overriden_callback = function()
                if on_present_callback then
                    on_present_callback()
                end
                local actual_layout = self:grid_layout()
                -- mod:notify(string.format("In callback, size of grid_layout: %d", #actual_layout))
                -- local portraitWidget = self._item_grid.widgets_by_name.portrait
                --mod:dump(, "portraitWidget", 3)
                for i = 1, #actual_layout do
                    local entry = actual_layout[i]
                    if entry.offer and entry.offer.offerId then
                        local profile = mod.character_avatar_data[entry.offer.offerId]
                        -- mod:dump(entry, "entry", 1)
                        local widget = self._item_grid._widgets_by_entry_id[entry.entry_id].widget
                        if widget then
                            -- mod:notify("Has widget!")
                            -- widget.content = { size = { 32, 32 }, element = {} }
                            widget.style.portrait.size = { 44, 44 }
                            widget.style.portrait.material_values = {
                                use_placeholder_texture = 1
                            }
                            widget.content.profile = profile
                            -- mod:notify("Widget: " .. widget.type)
                            update_portrait(self, widget, profile)
                        end
                        -- mod:notify(string.format("Got profile %s, got entryId %s", profile.name, entry.entry_id))
                    end
                end
            end

            return self._item_grid:present_grid_layout(layout, blueprints, left_click_callback,
                right_click_callback, grid_display_name, grow_direction, overriden_callback, left_double_click_callback)
        end)
end)

