local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")

local mod = get_mod("FilterTrash")

local function sort_by_keywords_size(t, a, b)
	local order_a = #t[a].keywords
	local order_b = #t[b].keywords

	return order_a > order_b
end

local function build_stat_widgets()
	local all_stat_names = {}

	for _, weapon_template in pairs(WeaponTemplates) do
		if weapon_template.base_stats then
			for _, stat_object in pairs(weapon_template.base_stats) do
				if stat_object and stat_object.display_name then
					if all_stat_names[stat_object.display_name] then
						if weapon_template.keywords then
							table.append(
								all_stat_names[stat_object.display_name].keywords,
								table.clone(weapon_template.keywords)
							)
						end
						all_stat_names[stat_object.display_name].keywords =
							table.unique_array_values(all_stat_names[stat_object.display_name].keywords)
					else
						all_stat_names[stat_object.display_name] = {
							keywords = table.clone(weapon_template.keywords),
						}
					end
				end
			end
		end
	end

	local widgets = {}

	local sorting_temp_keys = {}
	for display_name, _ in table.sorted(all_stat_names, sorting_temp_keys, sort_by_keywords_size) do
		table.insert(widgets, {
			setting_id = string.format("group_filter_by_stat_%s", display_name),
			title = Localize(display_name),
			localize = false,
			type = "checkbox",
			default_value = false,
			sub_widgets = {
				{
					setting_id = display_name,
					title = mod:localize("stat_level"),
					type = "numeric",
					default_value = 70,
					range = { 1, 80 },
					decimals_number = 0,
					localize = false,
				},
			},
		})
	end

	return widgets
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "group_filter_by_base_item_level",
				type = "checkbox",
				default_value = true,
				sub_widgets = {
					{
						setting_id = "item_level_base",
						type = "numeric",
						default_value = 370,
						range = { 1, 380 },
						decimals_number = 0,
					},
				},
			},
			{
				setting_id = "ignore_filtering_when_unlearned",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "group_filter_by_stats",
				type = "group",
				sub_widgets = build_stat_widgets(),
			},
		},
	},
}
