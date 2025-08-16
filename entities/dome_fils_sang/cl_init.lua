include('shared.lua')

local DOME_CONFIG = {
    RAYON = 800,
    DUREE = 10,
    EXPANSION = 0.5,
    CONTRACTION = 0.5,
    RALENTISSEMENT = 0.9,
    DEGATS_MIN = 100,
    DEGATS_MAX = 150
}

local clientDome = {
    actif = false,
    pos = Vector(),
    rayon = 0,
    expandStart = 0,
    expansion = 0,
    contractStart = 0,
    contraction = 0,
    timer = 0,
    etat = "expansion",
    owner = nil
}

function ENT:Initialize()
end

function ENT:Draw()
end

function ENT:Think()
end

local COULEUR_DOME = Color(255, 0, 0, 100)

net.Receive("ActivationDomeFilsDeSang", function()
    local owner = net.ReadEntity()
    local pos = net.ReadVector()
    local rayon = net.ReadFloat()
    local start = net.ReadFloat()
    local exp = net.ReadFloat()
    local cont = net.ReadFloat()

    clientDome.pos = pos
    clientDome.actif = true
    clientDome.rayon = rayon
    clientDome.expandStart = start
    clientDome.expansion = exp
    clientDome.contraction = cont
    clientDome.timer = CurTime() + DOME_CONFIG.DUREE
    clientDome.etat = "expansion"
    clientDome.owner = owner

    local hookName = "DomeFilsDeSang_" .. (IsValid(owner) and owner:EntIndex() or math.random(1000, 9999))

    hook.Add("PostDrawTranslucentRenderables", hookName, function()
        if not clientDome.actif or CurTime() > clientDome.timer then
            hook.Remove("PostDrawTranslucentRenderables", hookName)
            hook.Remove("RenderScreenspaceEffects", "EffetDomeFilsDeSang_Entity")
            clientDome.actif = false
            clientDome.owner = nil
            return
        end

        local progression = 1
        if clientDome.etat == "expansion" then
            progression = math.min(1, (CurTime() - clientDome.expandStart) / clientDome.expansion)
            if progression >= 1 then
                clientDome.etat = "pleinement_deploye"
                clientDome.contractStart = CurTime()
            end
        elseif clientDome.etat == "pleinement_deploye" then
            if CurTime() - clientDome.contractStart > DOME_CONFIG.DUREE - clientDome.expansion - clientDome.contraction then
                clientDome.etat = "contraction"
            end
        else
            progression = math.max(0, 1 - (CurTime() - (clientDome.contractStart + DOME_CONFIG.DUREE - clientDome.expansion - clientDome.contraction)) / clientDome.contraction)
            if progression <= 0 then
                clientDome.actif = false
                clientDome.owner = nil
            end
        end

        local rayonActuel = clientDome.rayon * progression
        render.SetColorMaterial()
        -- Wireframe sphere to visualize full physics radius
        render.DrawWireframeSphere(clientDome.pos, rayonActuel, 24, 24, Color(0, 200, 255, 200), true)
        local segments = 16
        for i = 1, segments do
            if math.random() < 0.2 then
                local angle1 = math.rad(i * (360 / segments))
                local x1 = math.cos(angle1) * rayonActuel
                local y1 = math.sin(angle1) * rayonActuel
                local j = math.random(i + 1, segments)
                local angle2 = math.rad(j * (360 / segments))
                local x2 = math.cos(angle2) * rayonActuel
                local y2 = math.sin(angle2) * rayonActuel
                local pos1 = clientDome.pos + Vector(x1, y1, math.random(-rayonActuel, rayonActuel))
                local pos2 = clientDome.pos + Vector(x2, y2, math.random(-rayonActuel, rayonActuel))
                render.DrawLine(pos1, pos2, COULEUR_DOME, false)
            end
        end
    end)

    hook.Add("RenderScreenspaceEffects", "EffetDomeFilsDeSang_Entity", function()
        if clientDome.actif and IsValid(LocalPlayer()) then
            local dist = LocalPlayer():GetPos():Distance(clientDome.pos)
            if dist < clientDome.rayon then
                DrawColorModify({
                    ["$pp_colour_addr"] = 0.02,
                    ["$pp_colour_addg"] = 0,
                    ["$pp_colour_addb"] = 0,
                    ["$pp_colour_brightness"] = -0.05,
                    ["$pp_colour_contrast"] = 1.1,
                    ["$pp_colour_colour"] = 1.1,
                    ["$pp_colour_mulr"] = 0,
                    ["$pp_colour_mulg"] = 0,
                    ["$pp_colour_mulb"] = 0
                })
                DrawSharpen(0.8, 0.8)
            end
        end
    end)
end)