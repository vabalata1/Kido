if not LibK then
	if SERVER then AddCSLuaFile("libk/autorun/_libk_loader.lua") end
	if file.Exists("libk/autorun/_libk_loader.lua", "LUA") then
		include("libk/autorun/_libk_loader.lua")
	end
end

if not LibK then
	ErrorNoHalt("[KInventory] LibK is missing or failed to load. Ensure the LibK addon is installed and enabled.\n")
	return
end

LibK.InitializeAddon{
    addonName = "KInventory",             --Name of the addon
    author = "Kamshak",                   --Name of the author
    luaroot = "kinv",                     --Folder that contains the client/shared/server structure relative to the lua folder,
	loadAfterGamemode = false,
}

LibK.addReloadFile( "autorun/ps2_kinv_init.lua" )