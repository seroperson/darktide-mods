local mod = get_mod("FilterTrash")

local Promise = require("scripts/foundation/utilities/promise")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local MasterItems = require("scripts/backend/master_items")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")

mod.on_enabled = function()
	if Managers.data_service.crafting._trait_sticker_book_cache then
		Managers.data_service.crafting:warm_trait_sticker_book_cache()
	end
end

-- credits to ItemSorting mod
local function has_unearned_trait(item)
	if item.item_type ~= "WEAPON_MELEE" and item.item_type ~= "WEAPON_RANGED" then
		return false
	end
	if not item.traits then
		return false
	end
	local cache = Managers.data_service.crafting._trait_sticker_book_cache
	if not cache then
		return false
	end
	local category = cache:cached_data_by_key(item.trait_category)
	if not category then
		return false
	end

	for _, trait in ipairs(item.traits) do
		if trait.rarity then
			local book = category[trait.id]
			if book then
				if book[trait.rarity] ~= "seen" then
					local i = trait.rarity + 1
					local low = false
					while book[i] and book[i] ~= "invalid" do
						if book[i] == "seen" then
							low = true
							break
						end
						i = i + 1
					end
					if not low then
						return true
					end
				end
			end
		end
	end
	return false
end

local function get_store_filtered(self)
	local item_level_base_filter_is_enabled = mod:get("group_filter_by_base_item_level")
	local item_level_base_filter = mod:get("item_level_base")
	local ignore_filtering_when_unlearned = mod:get("ignore_filtering_when_unlearned")

	local filtering_by_stat = {}
	for _, weapon_template in pairs(WeaponTemplates) do
		if weapon_template.base_stats then
			for stat_name, stat_object in pairs(weapon_template.base_stats) do
				if stat_object and stat_object.display_name then
					-- if filtering by this stat is enabled
					if mod:get(string.format("group_filter_by_stat_%s", stat_object.display_name)) then
						filtering_by_stat[stat_name] = mod:get(stat_object.display_name) / 100.0
					end
				end
			end
		end
	end

	local store_service = Managers.data_service.store
	local store_promise = nil
	local optional_store_service = self._optional_store_service

	if optional_store_service and store_service[optional_store_service] then
		store_promise = store_service[optional_store_service](store_service)
	else
		store_promise = store_service:get_credits_store()
	end

	if not store_promise then
		return
	end

	return store_promise:next(function(data)
		local local_player_id = 1
		local player = Managers.player:local_player(local_player_id)
		local character_id = player:character_id()

		-- the main filtering code
		data.offers = table.compact_array(table.filter(data.offers, function(offer)
			if offer.description.type == "weapon" then
				if ignore_filtering_when_unlearned then
					local sku = offer.sku
					local category = sku.category

					if category == "item_instance" then
						if has_unearned_trait(MasterItems.get_store_item_instance(offer.description)) then
							return true
						end
					end
				end

				local result = nil
				if item_level_base_filter_is_enabled then
					result = offer.description.overrides.baseItemLevel >= item_level_base_filter
				end

				if offer.description.overrides.base_stats then
					for i = 1, #offer.description.overrides.base_stats do
						local key = offer.description.overrides.base_stats[i].name
						local value = offer.description.overrides.base_stats[i].value
						if filtering_by_stat[key] then
							if result == nil then
								result = value >= filtering_by_stat[key]
							else
								result = result and value >= filtering_by_stat[key]
							end
						end
					end
				end

				return result
			else
				return true
			end
		end))

		return Managers.data_service.gear:fetch_inventory(character_id):next(function(items)
			local offers = data.offers

			for i = 1, #offers do
				local offer = offers[i]
				local sku = offer.sku
				local category = sku.category

				if category == "item_instance" and offer.state == "active" then
					local item = offer.description

					if self:_does_item_exist_in_list(items, item) then
						offer.state = "owned"
					end
				end
			end

			return Promise.resolved(data)
		end)
	end)
end

mod:hook(CreditsVendorView, "_get_store", function(func, self)
	return get_store_filtered(self)
end)
