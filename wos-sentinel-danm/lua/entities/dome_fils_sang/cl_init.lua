AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

-- Configuration client pour l'affichage
local DOME_CONFIG = {
    RAYON = 800,
    DUREE = 10,
    EXPANSION = 0.1,
    CONTRACTION = 0.5,
}

-- Liste des dômes actifs (côté client)
local ActiveDomes = {}

-- Réception de l'activation d'un dôme depuis le serveur
net.Receive("ActivationDomeFilsDeSang", function()
    local ownerOrEnt = net.ReadEntity()
    local pos = net.ReadVector()
    local rayon = net.ReadFloat()
    local expandStart = net.ReadFloat()
    local expandTime = net.ReadFloat()
    local contractTime = net.ReadFloat()

    table.insert(ActiveDomes, {
        pos = pos,
        rayon = rayon,
        expandStart = expandStart,
        expandTime = expandTime,
        contractTime = contractTime,
        endTime = CurTime() + (DOME_CONFIG.DUREE or 10),
    })
end)

-- Calcule un facteur d'animation 0..1 pour expansion/contraction
local function ComputeScale(dome)
    local t = CurTime() - dome.expandStart
    if t <= dome.expandTime then
        return math.Clamp(t / math.max(dome.expandTime, 0.001), 0, 1)
    end
    local t2 = t - dome.expandTime
    return math.Clamp(1 - (t2 / math.max(dome.contractTime, 0.001)), 0, 1)
end

-- Dessine les dômes de façon translucide
hook.Add("PostDrawTranslucentRenderables", "Draw_DomeFilsDeSang", function(depth, sky)
    if sky then return end
    if #ActiveDomes == 0 then return end

    render.SetColorMaterial()

    local now = CurTime()
    for i = #ActiveDomes, 1, -1 do
        local dome = ActiveDomes[i]
        if not dome or now > dome.endTime then
            table.remove(ActiveDomes, i)
        else
            local scale = ComputeScale(dome)
            local alpha = math.floor(80 * scale)
            local radius = dome.rayon * (0.9 + 0.1 * scale)

            render.DrawSphere(dome.pos, radius, 32, 32, Color(180, 0, 0, alpha))
            render.DrawWireframeSphere(dome.pos, radius, 24, 12, Color(255, 20, 20, math.min(180, alpha + 60)), true)
        end
    end
end)