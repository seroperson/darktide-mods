return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`GlobalStore` encountered an error loading the Darktide Mod Framework.")

        new_mod("GlobalStore", {
            mod_script       = "GlobalStore/scripts/mods/GlobalStore/GlobalStore",
            mod_data         = "GlobalStore/scripts/mods/GlobalStore/GlobalStore_data",
            mod_localization = "GlobalStore/scripts/mods/GlobalStore/GlobalStore_localization",
        })
    end,
    packages = {},
    load_before = {
        "FilterTrash",
    },
    version = "0.4.0",
}
