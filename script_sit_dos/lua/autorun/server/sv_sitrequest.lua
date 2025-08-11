local antispam = {}
util.AddNetworkString("SitRequest")
util.AddNetworkString("SitResponse")

local function CanPlayerRequestSit(ply, target)
    if not antispam[ply] then
        antispam[ply] = 0
    end

    if antispam[ply] > CurTime() then
        if not ply.NextSpamWarning or ply.NextSpamWarning < CurTime() then
            ply:ChatPrint("Veuillez attendre avant de faire une autre demande.")
            ply.NextSpamWarning = CurTime() + 1
        end
        return false
    end

    if ply.SurLeDos then
        ply:ChatPrint("Vous portez déjà quelqu'un.")
        return false
    end

    if ply:GetPos():Distance(target:GetPos()) > 200 then
        ply:ChatPrint("Vous devez être à moins de 200 unités de la personne.")
        return false
    end

    if ply:InVehicle() then
        ply:ChatPrint("Vous êtes déjà assis.")
        return false
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

hook.Add("PlayerButtonDown", "PlayerButtonDown::AssitSurLaPersonne", function(ply, button)
    if button == KEY_G then
        local ent = ply:GetEyeTrace().Entity
        if ent and ent:IsPlayer() and CanPlayerRequestSit(ply, ent) then
            net.Start("SitRequest")
            net.WriteEntity(ply)
            net.Send(ent)
            antispam[ply] = CurTime() + 10
        end
    end
end)

net.Receive("SitResponse", function(len, ply)
    local requester = net.ReadEntity()
    local response = net.ReadBool()

    if IsValid(requester) and requester:IsPlayer() then
        if response then
            if requester:InVehicle() then
                ply:ChatPrint("La personne que vous essayez de porter est déjà assise.")
                return
            end

            if IsValid(ply.SurLeDos) then
                --ply.SurLeDos:Remove()
            end

            local pos = ply:GetPos()
            local chair = ents.Create("prop_vehicle_prisoner_pod")
            chair:SetModel("models/nova/jeep_seat.mdl")
            chair:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
            chair:SetKeyValue("limitview", 0)
            local ang = ply:GetAngles()
            ang:RotateAroundAxis(ang:Up(), -90)
            chair:SetAngles(ang)
            chair:SetPos(pos)
            requester:SetParent(chair)

            chair:Spawn()
            chair:Activate()
            chair:SetColor(Color(255, 255, 255, 0))
            chair:SetRenderMode(RENDERMODE_TRANSALPHA)
            chair:DrawShadow(false)
            chair:SetSolid(SOLID_NONE)
            chair:SetParent(ply)
            ply.SurLeDos = chair
            requester.isSitOnEnt = true
            ply.SurLeDos:SetPos(Vector(0, 0, 40))

            hook.Run("SitPositionThink", requester, ply)

            timer.Simple(0.2, function()
                requester:EnterVehicle(chair)

                -- Adjust bones after player has entered the vehicle
                local FT = FrameTime()
                local ang1 = requester:GetNWFloat("ang1")
                requester:SetNWFloat("ang1", Lerp(FT * 15, ang1, 1))
                ManipulateBones(requester, ang1)
            end)

        else
            requester:ChatPrint("Votre demande d'assise a été rejetée.")
        end
    end
end)

hook.Add("SitPositionThink", "SitPositionThinks", function(ply, ent)
    if not ply.isSitOnEnt then
        if IsValid(ent.SurLeDos) then
            ent.SurLeDos:Remove()
        end
        return
    end

    if IsValid(ent.SurLeDos) then
        ent.SurLeDos:SetLocalAngles(Angle(ent:GetAngles().p, ent:GetAngles().y + 270, ent:GetAngles().r))
    end

    timer.Simple(0.1, function()
        if IsValid(ply) and IsValid(ent) then
            hook.Run("SitPositionThink", ply, ent)
        end
    end)
end)

hook.Add("PlayerLeaveVehicle", "PlayerLeaveVehicleTurnOn", function(ply, veh)
    ply.isSitOnEnt = false
    local FT = FrameTime()

    local ang1 = ply:GetNWFloat("ang1")
    local ang2 = ply:GetNWFloat("ang2")
    local pos1 = ply:GetNWFloat("pos1")
    local pos2 = ply:GetNWFloat("pos2")

    ply:SetNWFloat("ang1", Lerp(FT * 5, ang1, 0))
    ply:SetNWFloat("ang2", Lerp(FT * 5, ang2, 0))
    ply:SetNWFloat("pos1", Lerp(FT * 5, ang1, 0))
    ply:SetNWFloat("pos2", Lerp(FT * 5, ang2, 0))

    if IsValid(ply) and ply:IsPlayer() then
        ResetBones(ply)
    end
    ply:SetViewEntity(ply)
end)

hook.Add("PlayerDeath", "PlayerDeath::DropCarriedPlayer", function(victim, inflictor, attacker)
    if IsValid(victim.SurLeDos) then
        local chair = victim.SurLeDos
        local carriedPlayer = chair:GetParent()
        
        if IsValid(carriedPlayer) and carriedPlayer:IsPlayer() then
            carriedPlayer:ExitVehicle()
            carriedPlayer:SetParent(nil)
            carriedPlayer.isSitOnEnt = false
            ResetBones(carriedPlayer)
        end
        
        chair:Remove()
    end
end)
