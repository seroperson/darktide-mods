return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ImprovedPenanceTracking` encountered an error loading the Darktide Mod Framework.")

        new_mod("ImprovedPenanceTracking", {
            mod_script       = "ImprovedPenanceTracking/scripts/mods/ImprovedPenanceTracking/ImprovedPenanceTracking",
            mod_data         = "ImprovedPenanceTracking/scripts/mods/ImprovedPenanceTracking/ImprovedPenanceTracking_data",
            mod_localization = "ImprovedPenanceTracking/scripts/mods/ImprovedPenanceTracking/ImprovedPenanceTracking_localization",
        })
    end,
    packages = {},
    version = "0.2.0",
}
