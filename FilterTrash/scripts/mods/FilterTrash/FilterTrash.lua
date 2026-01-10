local mod = get_mod("FilterTrash")

mod._info = {
    title = "FilterTrash",
    author = "seroperson",
    date = "2025/12/09",
    version = "0.2.0",
}
mod:info("Version " .. mod._info.version)

local Promise = require("scripts/foundation/utilities/promise")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local WeaponStats = require("scripts/utilities/weapon_stats")
local MasterItems = require("scripts/backend/master_items")
local Items = require("scripts/utilities/items")

local function filter_items(key, data)
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
