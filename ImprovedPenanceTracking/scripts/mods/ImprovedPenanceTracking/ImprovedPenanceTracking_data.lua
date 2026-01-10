local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")

local mod = get_mod("ImprovedPenanceTracking")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "disable_per_character_tracking",
                type = "checkbox",
                default_value = false,
            },
        },
    },
}