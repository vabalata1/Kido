local antispam = {}
local pendingRequests = {}
local targetCooldown = {}

util.AddNetworkString("SitRequest")
util.AddNetworkString("SitResponse")

local function getTargetKey(ply)
    return ply:SteamID64() or tostring(ply:UserID())
end

local function canPairCarry(requester, target)
    if not IsValid(requester) or not requester:IsPlayer() then return false, "Demandeur invalide" end
    if not IsValid(target) or not target:IsPlayer() then return false, "Cible invalide" end
    if requester == target then return false, "Vous ne pouvez pas vous porter vous-même." end

    if requester:GetPos():Distance(target:GetPos()) > 200 then
        return false, "Vous devez être à moins de 200 unités de la personne."
    end

    if requester:InVehicle() then
        return false, "Vous êtes déjà assis."
    end

    if target:InVehicle() then
        return false, "La personne visée est déjà assise."
    end

    if requester.SurLeDos then
        return false, "Vous portez déjà quelqu'un."
    end

    if requester.isSitOnEnt then
        return false, "Vous êtes déjà porté par quelqu'un."
    end

    if IsValid(target.SurLeDos) then
        return false, "Cette personne porte déjà quelqu'un."
    end

    return true
end

local function ManipulateBones(ply, ang1)
    local bones = {
        {"ValveBiped.Bip01_L_Hand", Angle(0 * ang1, -90 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_L_Forearm", Angle(20 * ang1, 220 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_L_Upperarm", Angle(-50 * ang1, -190 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_L_Clavicle", Angle(0 * ang1, 0 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_R_Hand", Angle(-30 * ang1, 40 * ang1, 320 * ang1)},
        {"ValveBiped.Bip01_R_Forearm", Angle(70 * ang1, 110 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_R_Upperarm", Angle(200 * ang1, 80 * ang1, -80 * ang1)},
        {"ValveBiped.Bip01_R_Clavicle", Angle(0 * ang1, 0 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_Spine1", Angle(0 * ang1, 20 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_L_Thigh", Angle(-20 * ang1, 0 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_R_Thigh", Angle(20 * ang1, 0 * ang1, 0 * ang1)},
        {"ValveBiped.Bip01_Pelvis", Vector(-20 * ang1, 0 * ang1, -15 * ang1)}
    }

    for _, boneData in ipairs(bones) do
        local bone = ply:LookupBone(boneData[1])
        if bone then
            if isangle(boneData[2]) then
                ply:ManipulateBoneAngles(bone, boneData[2])
            else
                ply:ManipulateBonePosition(bone, boneData[2])
            end
        end
    end
end

local function ResetBones(ply)
    local bones = {
        "ValveBiped.Bip01_R_Hand",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_R_Upperarm",
        "ValveBiped.Bip01_R_Clavicle",
        "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_L_Forearm",
        "ValveBiped.Bip01_L_Upperarm",
        "ValveBiped.Bip01_L_Clavicle",
        "ValveBiped.Bip01_L_Thigh",
        "ValveBiped.Bip01_R_Thigh",
        "ValveBiped.Bip01_Pelvis",
        "ValveBiped.Bip01_Spine1",
        "ValveBiped.Bip01_Head1",
        "ValveBiped.Bip01_R_UpperArm",
        "ValveBiped.Bip01_R_Forearm"
    }

    for _, boneName in ipairs(bones) do
        local bone = ply:LookupBone(boneName)
        if bone then
            ply:ManipulateBoneAngles(bone, Angle(0, 0, 0))
            ply:ManipulateBonePosition(bone, Vector(0, 0, 0))
        end
    end
end

local function cleanupCarry(carrier)
    if not IsValid(carrier) then return end
    local chair = carrier.SurLeDos
    if IsValid(chair) then
        local passenger = chair:GetDriver()
        if IsValid(passenger) and passenger:IsPlayer() then
            passenger:ExitVehicle()
            passenger.isSitOnEnt = false
            ResetBones(passenger)
            passenger:SetParent(nil)
        end
        chair:Remove()
    end
    carrier.SurLeDos = nil
end

local function registerRequest(requester, target)
    local key = getTargetKey(target)
    pendingRequests[key] = { requester = requester, expires = CurTime() + 10 }
end

local function popRequestIfValid(responder, requester)
    local key = getTargetKey(responder)
    local rec = pendingRequests[key]
    if not rec then return false end
    if rec.requester ~= requester then return false end
    if rec.expires < CurTime() then pendingRequests[key] = nil return false end
    pendingRequests[key] = nil
    return true
end

local function hasActiveRequest(target)
    local key = getTargetKey(target)
    local rec = pendingRequests[key]
    return rec ~= nil and rec.expires >= CurTime()
end

-- Envoi d'une demande sur G (serveur)
hook.Add("PlayerButtonDown", "PlayerButtonDown::AssitSurLaPersonne", function(ply, button)
    if button ~= KEY_G then return end

    local ent = ply:GetEyeTrace().Entity
    if not (IsValid(ent) and ent:IsPlayer()) then return end

    if not antispam[ply] then antispam[ply] = 0 end
    if antispam[ply] > CurTime() then
        if not ply.NextSpamWarning or ply.NextSpamWarning < CurTime() then
            ply:ChatPrint("Veuillez attendre avant de faire une autre demande.")
            ply.NextSpamWarning = CurTime() + 1
        end
        return
    end

    if hasActiveRequest(ent) then
        ply:ChatPrint("Cette personne a déjà une demande en attente.")
        return
    end

    local ok, reason = canPairCarry(ply, ent)
    if not ok then
        if reason then ply:ChatPrint(reason) end
        return
    end

    net.Start("SitRequest")
    net.WriteEntity(ply)
    net.Send(ent)

    registerRequest(ply, ent)
    antispam[ply] = CurTime() + 10
end)

net.Receive("SitResponse", function(_, responder)
    local requester = net.ReadEntity()
    local isAccepted = net.ReadBool()

    if not (IsValid(requester) and requester:IsPlayer()) then return end
    if not (IsValid(responder) and responder:IsPlayer()) then return end

    -- Vérifier qu'il y avait bien une demande en attente
    if not popRequestIfValid(responder, requester) then
        responder:ChatPrint("Aucune demande valide à répondre.")
        return
    end

    if not isAccepted then
        if IsValid(requester) then requester:ChatPrint("Votre demande d'assise a été rejetée.") end
        return
    end

    -- Re-vérifier les conditions au moment de l'acceptation
    local ok, reason = canPairCarry(requester, responder)
    if not ok then
        if reason then requester:ChatPrint("Impossible: " .. reason) end
        return
    end

    -- Créer et configurer le siège parenté au porteur (responder)
    local chair = ents.Create("prop_vehicle_prisoner_pod")
    if not IsValid(chair) then return end

    chair:SetModel("models/nova/jeep_seat.mdl")
    chair:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    chair:SetKeyValue("limitview", 0)

    -- Spawn avant parent? On peut spawner puis parent, puis définir offsets locaux
    chair:Spawn()
    chair:Activate()

    chair:SetColor(Color(255, 255, 255, 0))
    chair:SetRenderMode(RENDERMODE_TRANSALPHA)
    chair:DrawShadow(false)
    chair:SetSolid(SOLID_NONE)
    chair:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

    chair:SetParent(responder)
    responder.SurLeDos = chair

    -- Offset local derrière/au-dessus du porteur (ajuster si besoin)
    chair:SetLocalPos(Vector(0, -18, 40))
    chair:SetLocalAngles(Angle(0, 270, 0))

    -- Faire entrer le demandeur dans le siège
    timer.Simple(0.05, function()
        if not (IsValid(requester) and IsValid(chair)) then return end
        requester:EnterVehicle(chair)
        requester.isSitOnEnt = true
        ManipulateBones(requester, 1)
    end)
end)

-- Nettoyage quand le joueur quitte un véhicule
hook.Add("PlayerLeaveVehicle", "PlayerLeaveVehicleTurnOn_Fixed", function(ply, veh)
    if not IsValid(veh) then return end
    local carrier = veh:GetParent()
    if IsValid(carrier) and carrier:IsPlayer() and carrier.SurLeDos == veh then
        cleanupCarry(carrier)
    else
        -- Si ce n'est pas notre siège, au moins reset les os si besoin
        ResetBones(ply)
        ply.isSitOnEnt = false
    end
    ply:SetViewEntity(ply)
end)

-- Nettoyage au décès
hook.Add("PlayerDeath", "PlayerDeath::DropCarriedPlayer_Fixed", function(victim)
    -- Si le porteur meurt
    if IsValid(victim.SurLeDos) then
        cleanupCarry(victim)
        return
    end

    -- Si le porté meurt
    if victim:InVehicle() then
        local veh = victim:GetVehicle()
        if IsValid(veh) then
            local carrier = veh:GetParent()
            if IsValid(carrier) and carrier:IsPlayer() and carrier.SurLeDos == veh then
                cleanupCarry(carrier)
            else
                ResetBones(victim)
                victim.isSitOnEnt = false
                victim:SetParent(nil)
                if IsValid(veh) then veh:Remove() end
            end
        end
    end
end)

-- Nettoyage à la déconnexion
hook.Add("PlayerDisconnected", "PlayerDisconnected::CleanupCarry", function(ply)
    if IsValid(ply.SurLeDos) then
        cleanupCarry(ply)
    end

    -- Si c'était un porté dans un siège parenté
    if ply:InVehicle() then
        local veh = ply:GetVehicle()
        if IsValid(veh) then
            local carrier = veh:GetParent()
            if IsValid(carrier) and carrier:IsPlayer() and carrier.SurLeDos == veh then
                cleanupCarry(carrier)
            end
        end
    end

    -- Annuler une éventuelle demande en attente le concernant
    local key = getTargetKey(ply)
    pendingRequests[key] = nil
end)
