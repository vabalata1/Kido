if not LibK then
	if file.Exists("libk/autorun/_libk_loader.lua", "LUA") then
		include("libk/autorun/_libk_loader.lua")
	end
end

LibK.InitializeAddon{
    addonName = "KInventory",             --Name of the addon
    author = "Kamshak",                   --Name of the author
    luaroot = "kinv",                     --Folder that contains the client/shared/server structure relative to the lua folder,
	loadAfterGamemode = false,
}

LibK.addReloadFile( "autorun/ps2_kinv_init.lua" )