--Always AddCSLua the modules (needed for updater)
local function addCsLuaRecursive( folder )
	local files, folders = file.Find( folder .. "/*", "LUA" )
	for k, filename in pairs( files ) do
		local realmPrefix = string.sub( filename, 1, 2 )
		if ( realmPrefix != "sh" and realmPrefix != "cl" and realmPrefix != "sv" ) or filename[3] != "_" then
			KLogf( 2, "[ERROR] Couldn't determine realm of file %s! Please name your file sh_*/cl_*/sv_*.lua", filename )
			continue
		end
		local fullpath = folder .. "/" .. filename
		if SERVER and ( realmPrefix == "sh" or realmPrefix == "cl" ) then
			AddCSLuaFile( fullpath )
		end
	end

	for k, v in pairs( folders ) do
		addCsLuaRecursive( folder .. "/" .. v )
	end
end
addCsLuaRecursive( "ps2/modules" )

-- Ensure LibK is loaded before using it
if not LibK then
	if SERVER then AddCSLuaFile("libk/autorun/_libk_loader.lua") end
	if file.Exists("libk/autorun/_libk_loader.lua", "LUA") then
		include("libk/autorun/_libk_loader.lua")
	end
end

-- If LibK is still not available, abort init with a readable error
if not LibK then
	ErrorNoHalt("[Pointshop2] LibK is missing or failed to load. Ensure the LibK addon is installed and enabled.\n")
	return
end

-- Now safe to use LibK helpers
LibK.AddCSLuaDir( "kinv/items" )

LibK.InitializeAddon{
	addonName = "Pointshop2",             --Name of the addon
	author = "Kamshak",                   --Name of the author
	luaroot = "ps2",                      --Folder that contains the client/shared/server structure relative to the lua folder,
	loadAfterGamemode = false,
	version = "2.22.0",
	requires = { "KInventory" }
}

LibK.addReloadFile( "autorun/pointshop2_init.lua" )
print( Format( "Pointshop2 Version %s : %s loaded", "{{ script_id }}", "{{ user_id }}" ) )
