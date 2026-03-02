local mod = get_mod("GlobalStore")

local Promise = require("scripts/foundation/utilities/promise")
local StoreNames = require("scripts/settings/backend/store_names")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISettings = require("scripts/settings/ui/ui_settings")
local StoreService = require("scripts/managers/data_service/services/store_service")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local MarksVendorView = require("scripts/ui/views/marks_vendor_view/marks_vendor_view")

-- Fixing undefined unpack
table.unpack = table.unpack or unpack

-- Store character profile data for items
mod.character_avatar_data = {}
mod.character_avatar_data_contracts = {}

local function get_all_character_profiles()
    return Managers.data_service.profiles:fetch_all_profiles():next(function(result)
        return Promise.resolved(result.profiles or {})
    end)
end

-- Function to fetch stores for all characters and merge them (Credits/Armoury)
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
                    -- Wrap with catch to handle failures gracefully
                    store_promise = store_promise:catch(function(error)
                        mod:notify(string.format("Failed to fetch credits store for character %s: %s", profile.name,
                            tostring(error)))
                        return nil
                    end)
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
                local profile = profile_lookup[i]

                if store and store.data then
                    local offers = store.data.personal
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
                current_rotation_end = stores[1] and stores[1].data.currentRotationEnd,
                offer_to_profile = offer_to_profile
            }

            return Promise.resolved(merged_store)
        end)
    end)
end

-- Function to fetch marks stores for all characters and merge them (Contracts)
local function get_all_characters_marks_store()
    return get_all_character_profiles():next(function(profiles)
        if #profiles == 0 then
            return Promise.rejected("No characters found")
        end

        -- Create promises for each character's marks store
        local store_promises = {}
        local profile_lookup = {}
        for i = 1, #profiles do
            local profile = profiles[i]
            local character_id = profile.character_id
            local archetype = profile.archetype
            local archetype_name = archetype.name

            -- Store profile for later lookup
            profile_lookup[i] = profile

            -- Get the marks store method name for this archetype
            local store_method_name = StoreNames.by_archetype.mark[archetype_name]

            if store_method_name then
                local store_backend = Managers.backend.interfaces.store

                -- Call the backend store method directly
                if store_backend[store_method_name] then
                    local store_promise = store_backend[store_method_name](store_backend, nil, character_id)
                    -- Wrap with catch to handle failures gracefully
                    store_promise = store_promise:catch(function(error)
                        mod:notify(string.format("Failed to fetch marks store for character %s: %s", profile.name,
                            tostring(error)))
                        return nil
                    end)
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
                local profile = profile_lookup[i]

                if store and store.data then
                    local offers = store.data.personal
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
                current_rotation_end = stores[1] and stores[1].data.currentRotationEnd,
                offer_to_profile = offer_to_profile
            }

            return Promise.resolved(merged_store)
        end)
    end)
end


local function get_player_portrait_frame_material(profile)
    local frame_material = UISettings.portrait_frame_default_material

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

    if content.portrait_load_id then
        Managers.ui:unload_profile_portrait(content.portrait_load_id)

        content.portrait_load_id = nil
    end

    if profile then
        local profile_icon_loaded_callback = callback(mod, "cb_set_player_icon", widget)
        local profile_icon_unloaded_callback = callback(mod, "cb_unset_player_icon", widget, self._ui_renderer)

        content.portrait_load_id = Managers.ui:load_profile_portrait(profile, profile_icon_loaded_callback, nil,
            profile_icon_unloaded_callback)
    end
end

mod.cb_set_player_icon = function(self, widget, grid_index, rows, columns, render_target)
    local profile = widget.content.profile
    local portrait_style = widget.style.portrait

    widget.content.character_portrait = get_player_portrait_frame_material(profile)

    local material_values = portrait_style.material_values

    material_values.use_placeholder_texture = 0
    material_values.rows = rows
    material_values.columns = columns
    material_values.grid_index = grid_index - 1
    material_values.texture_icon = render_target
end

mod.cb_unset_player_icon = function(self, widget, ui_renderer)
    UIWidget.set_visible(widget, ui_renderer, false)

    local material_values = widget.style.portrait.material_values

    material_values.use_placeholder_texture = nil
    material_values.rows = nil
    material_values.columns = nil
    material_values.grid_index = nil
    material_values.texture_icon = nil
    widget.content.character_portrait = "content/ui/materials/base/ui_portrait_frame_base_no_render"
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

-- Add our custom methods to StoreService
StoreService.get_all_characters_store_custom = function(self, ignore_event_trigger)
    return get_all_characters_store()
end

StoreService.get_all_characters_marks_store_custom = function(self, ignore_event_trigger)
    return get_all_characters_marks_store()
end

-- Hook _get_store to capture character profile data
mod:hook(CreditsVendorView, "_get_store", function(f, self)
    local promise = f(self)

    -- Capture character profile data if using custom store
    if self._optional_store_service == "get_all_characters_store_custom" then
        promise = promise:next(function(data)
            if data and data.offer_to_profile then
                mod.character_avatar_data = data.offer_to_profile
            end
            return data
        end)
    end

    return promise
end)

-- Hook present_grid_layout to create portrait widgets
mod:hook(CreditsVendorView, "present_grid_layout",
    function(func, self, layout, on_present_callback)
        if self._optional_store_service ~= "get_all_characters_store_custom" then
            return func(self, layout, on_present_callback)
        end

        local gen_blueprints_func = require("scripts/ui/view_content_blueprints/item_blueprints")
        local grid_settings = self._definitions.grid_settings
        local grid_size = grid_settings.grid_size
        local blueprints = table.clone(gen_blueprints_func(grid_size))
        local store_item = blueprints.store_item
        local pass_template = store_item.pass_template

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
        }
        table.insert(pass_template, portrait_widget_def)

        -- Character info widget definition (class symbol + character name in one row)
        local character_info_widget_def = {
            pass_type = "text",
            style_id = "character_info_text",
            value = "",
            value_id = "character_info_text",
            style = {
                vertical_alignment = "bottom",
                horizontal_alignment = "left",
                font_type = "proxima_nova_bold",
                font_size = 20,
                text_color = { 255, 220, 220, 220 },
                offset = {
                    52,
                    -12,
                    11
                },
                size = { 400, 20 },
            }
        }
        table.insert(pass_template, character_info_widget_def)

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
            for i = 1, #actual_layout do
                local entry = actual_layout[i]
                if entry.offer and entry.offer.offerId then
                    local profile = mod.character_avatar_data[entry.offer.offerId]
                    local widget = self._item_grid._widgets_by_entry_id[entry.entry_id].widget
                    if widget then
                        widget.style.portrait.size = { 44, 44 }
                        widget.style.portrait.material_values = {
                            use_placeholder_texture = 1
                        }
                        widget.content.profile = profile
                        update_portrait(self, widget, profile)

                        -- Set character info (class symbol + name in one row)
                        if profile then
                            local archetype = profile.archetype
                            local archetype_name = archetype and archetype.name
                            local string_symbol = archetype_name and UISettings.archetype_font_icon[archetype_name] or ""
                            local character_name = profile.name or ""
                            widget.content.character_info_text = string.format("%s %s", string_symbol, character_name)
                        end
                    end
                end
            end
        end

        return self._item_grid:present_grid_layout(layout, blueprints, left_click_callback,
            right_click_callback, grid_display_name, grow_direction, overriden_callback, left_double_click_callback)
    end)

-- Hook the contracts background view to add our custom button
mod:hook_require("scripts/ui/views/contracts_background_view/contracts_background_view_definitions",
    function(definitions)
        -- Add a new button option for "All Characters Contracts"
        local button_options = definitions.button_options_definitions

        -- Remove extra buttons to avoid duplicates on reload
        while #button_options > 4 do
            table.remove(button_options, 3)
        end

        -- Insert the new button after the second button (Requisitorium Weekly)
        local localized_button_name = mod:localize("all_characters_button")
        local localized_title = mod:localize("all_characters_contracts_title")

        local UISettings = require("scripts/settings/ui/ui_settings")

        table.insert(button_options, 3, {
            blur_background = false,
            unlocalized_name = localized_button_name,
            callback = function(self)
                local tab_bar_params = {
                    hide_tabs = true,
                    layer = 10,
                    tabs_params = {
                        {
                            unlocalized_name = localized_title,
                            view = "marks_vendor_view",
                            view_function = "show_items",
                            context = {
                                optional_store_service = "get_all_characters_marks_store_custom",
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

                                                if item_type == ITEM_TYPES.WEAPON_MELEE or item_type == ITEM_TYPES.WEAPON_RANGED or item_type == ITEM_TYPES.END_OF_ROUND or item_type == ITEM_TYPES.GEAR_EXTRA_COSMETIC or item_type == ITEM_TYPES.GEAR_HEAD or item_type == ITEM_TYPES.GEAR_LOWERBODY or item_type == ITEM_TYPES.GEAR_UPPERBODY or item_type == ITEM_TYPES.COMPANION_GEAR_FULL or item_type == ITEM_TYPES.EMOTE then
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
                    hide_price = true,
                })
            end,
        })

        return definitions
    end)

-- Hook init to capture the optional_store_service from context
mod:hook(MarksVendorView, "init", function(f, self, settings, context)
    f(self, settings, context)

    -- Store the optional store service if provided
    if context and context.optional_store_service then
        self._optional_store_service = context.optional_store_service
    end
end)

-- Hook _get_store to use custom store service
mod:hook(MarksVendorView, "_get_store", function(f, self)
    local optional_store_service = self._optional_store_service

    if optional_store_service then
        local store_service = Managers.data_service.store
        local store_method = store_service[optional_store_service]

        if store_method then
            local promise = store_method(store_service)

            -- Capture character profile data if using custom store
            promise = promise:next(function(data)
                if data and data.offer_to_profile then
                    mod.character_avatar_data_contracts = data.offer_to_profile
                end
                return data
            end)

            return promise
        end
    end

    return f(self)
end)

-- Hook present_grid_layout to create portrait widgets
mod:hook(MarksVendorView, "present_grid_layout",
    function(func, self, layout, on_present_callback)
        if self._optional_store_service ~= "get_all_characters_marks_store_custom" then
            return func(self, layout, on_present_callback)
        end

        local gen_blueprints_func = require("scripts/ui/view_content_blueprints/item_blueprints")
        local grid_settings = self._definitions.grid_settings
        local grid_size = grid_settings.grid_size
        local blueprints = table.clone(gen_blueprints_func(grid_size))
        local store_item = blueprints.store_item
        local pass_template = store_item.pass_template

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
        }
        table.insert(pass_template, portrait_widget_def)

        -- Character info widget definition (class symbol + character name in one row)
        local character_info_widget_def = {
            pass_type = "text",
            style_id = "character_info_text",
            value = "",
            value_id = "character_info_text",
            style = {
                vertical_alignment = "bottom",
                horizontal_alignment = "left",
                font_type = "proxima_nova_bold",
                font_size = 20,
                text_color = { 255, 220, 220, 220 },
                offset = {
                    52,
                    -12,
                    11
                },
                size = { 400, 20 },
            }
        }
        table.insert(pass_template, character_info_widget_def)

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
            for i = 1, #actual_layout do
                local entry = actual_layout[i]
                if entry.offer and entry.offer.offerId then
                    local profile = mod.character_avatar_data_contracts[entry.offer.offerId]
                    local widget = self._item_grid._widgets_by_entry_id[entry.entry_id].widget
                    if widget then
                        widget.style.portrait.size = { 44, 44 }
                        widget.style.portrait.material_values = {
                            use_placeholder_texture = 1
                        }
                        widget.content.profile = profile
                        update_portrait(self, widget, profile)

                        -- Set character info (class symbol + name in one row)
                        if profile then
                            local archetype = profile.archetype
                            local archetype_name = archetype and archetype.name
                            local string_symbol = archetype_name and UISettings.archetype_font_icon[archetype_name] or ""
                            local character_name = profile.name or ""
                            widget.content.character_info_text = string.format("%s %s", string_symbol, character_name)
                        end
                    end
                end
            end
        end

        return self._item_grid:present_grid_layout(layout, blueprints, left_click_callback,
            right_click_callback, grid_display_name, grow_direction, overriden_callback, left_double_click_callback)
    end)

-- Cleanup portrait resources when CreditsVendorView is destroyed
mod:hook(CreditsVendorView, "destroy", function(func, self)
    if self._optional_store_service == "get_all_characters_store_custom" then
        local item_grid = self._item_grid

        if item_grid and item_grid._widgets_by_entry_id then
            for _, entry_data in pairs(item_grid._widgets_by_entry_id) do
                local widget = entry_data.widget

                if widget and widget.content and widget.content.portrait_load_id then
                    Managers.ui:unload_profile_portrait(widget.content.portrait_load_id)
                    widget.content.portrait_load_id = nil
                end
            end
        end
    end

    return func(self)
end)

-- Cleanup portrait resources when MarksVendorView is destroyed
mod:hook(MarksVendorView, "destroy", function(func, self)
    if self._optional_store_service == "get_all_characters_marks_store_custom" then
        local item_grid = self._item_grid

        if item_grid and item_grid._widgets_by_entry_id then
            for _, entry_data in pairs(item_grid._widgets_by_entry_id) do
                local widget = entry_data.widget

                if widget and widget.content and widget.content.portrait_load_id then
                    Managers.ui:unload_profile_portrait(widget.content.portrait_load_id)
                    widget.content.portrait_load_id = nil
                end
            end
        end
    end

    return func(self)
end)
