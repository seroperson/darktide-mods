return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`FilterTrash` encountered an error loading the Darktide Mod Framework.")

		new_mod("FilterTrash", {
			mod_script       = "FilterTrash/scripts/mods/FilterTrash/FilterTrash",
			mod_data         = "FilterTrash/scripts/mods/FilterTrash/FilterTrash_data",
			mod_localization = "FilterTrash/scripts/mods/FilterTrash/FilterTrash_localization",
		})
	end,
	packages = {},
}
