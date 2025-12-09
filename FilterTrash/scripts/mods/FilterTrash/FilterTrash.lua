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

local function filter_items(data)
	local show_only_ideal = mod:get("show_only_ideal")
	local item_level_base_filter_is_enabled = mod:get("group_filter_by_base_item_level")
	local item_level_base_filter = mod:get("item_level_base")

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
		if offer.description.type == "weapon" then
			local result = true
			if item_level_base_filter_is_enabled then
				result = offer.description.overrides.baseItemLevel >= item_level_base_filter
			end

			local base_stats = offer.description.overrides.base_stats
			local modified_desciption = table.clone(offer.description)
			modified_desciption.gear_id = offer.description.gearId
			local item = MasterItems.get_store_item_instance(modified_desciption)

			if not item then
				return result
			end

			local weapon_stats = WeaponStats:new(item)
			local comparing_stats = weapon_stats:get_comparing_stats()
			local added_stats = Items.preview_stats_change(item, 0, comparing_stats)
			local max_stats = Items.preview_stats_change(item, Items.max_expertise_level(), comparing_stats)

			if not max_stats then
				return result
			end

			if show_only_ideal then
				local ideal_bad_stat = table.filter(max_stats, function(max_stat)
					return max_stat.value == 60
				end)
				
				result = result and table.size(ideal_bad_stat) == 1
			end

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
			return true
		end
	end))

	return Promise.resolved(data)
end

mod:hook_require("scripts/ui/views/credits_vendor_view/credits_vendor_view", function(instance)
	mod:hook(instance, "_get_store", function(f, self)
		return f(self):next(filter_items)
	end)
end)