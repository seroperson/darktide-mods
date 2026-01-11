local mod = get_mod("FilterTrash")

mod._info = {
    title = "FilterTrash",
    author = "seroperson",
    date = "2025/12/09",
    version = "0.3.0",
}
mod:info("Version " .. mod._info.version)

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
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local WeaponStats = require("scripts/utilities/weapon_stats")
local MasterItems = require("scripts/backend/master_items")
local Items = require("scripts/utilities/items")
local StoreNames = require("scripts/settings/backend/store_names")

local function filter_items(key, data)
    -- If filtering is disabled, return data without modification
    if not mod.filtering_enabled then
        return Promise.resolved(data)
    end

    local show_only_ideal_60 = mod:get(string.format("%s_show_only_ideal_60", key))
    local show_only_ideal_76 = mod:get(string.format("%s_show_only_ideal_76", key))
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

            local all_stats_equal = table.filter(max_stats, function(max_stat)
                return max_stat.value >= 74
            end)
            local has_all_stats_equal = table.size(all_stats_equal) == 5

            -- Filter if:
            -- - toggle is enabled and condition satisfied
            -- - both toggles are disabled
            result = result and
                ((show_only_ideal_60 and has_ideal_bad_stat) or (show_only_ideal_76 and has_all_stats_equal) or (not show_only_ideal_60 and not show_only_ideal_76))

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

mod:hook_require("scripts/ui/views/credits_vendor_view/credits_vendor_view", function(instance)
    mod:hook(instance, "_get_store", function(f, self)
        return f(self):next(filter_items_brunt)
    end)
end)

mod:hook_require("scripts/ui/views/marks_vendor_view/marks_vendor_view", function(instance)
    mod:hook(instance, "_get_store", function(f, self)
        return f(self):next(filter_items_contracts)
    end)
end)

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
        for i = 1, #profiles do
            local profile = profiles[i]
            local character_id = profile.character_id
            local archetype = profile.archetype
            local archetype_name = archetype.name

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

            for i = 1, #stores do
                local store = stores[i]
                local offers = store.data.personal
                if store and offers then
                    for j = 1, #offers do
                        local offer = offers[j]
                        local offer_id = offer.offerId

                        -- Only add if we haven't seen this offer before
                        if not seen_offer_ids[offer_id] then
                            table.insert(merged_offers, offer)
                            seen_offer_ids[offer_id] = true
                        end
                    end
                end
            end

            -- Return a merged store structure
            local merged_store = {
                offers = merged_offers,
                currentRotation = stores[1] and stores[1].currentRotation or {},
                nextRotation = stores[1] and stores[1].nextRotation or {}
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
