AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

if SERVER then include("wos/advswl/forcepowers/sh_speedmanager.lua") end

local DOME_CONFIG = {
    RAYON = 800,
    DUREE = 20,
    EXPANSION = 0.5,
    CONTRACTION = 0.5,
    DEGATS_MIN = 50,
    DEGATS_MAX = 75,
    DEBUFF_AMOUNT = 25,
}

local debuff_prefix = "fdsDebuff_"

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetNotSolid(true)
    self:DrawShadow(false)
    self.dome = {
        actif = false,
        pos = Vector(),
        timer = 0,
        expandStart = 0,
        contractStart = 0,
        etat = "expansion",
        owner = nil
    }
    self.joueursData = {}
    timer.Simple(0.1, function()
        if IsValid(self) then
            self:StartDome()
        end
    end)
end

function ENT:StartDome()
    self.dome.pos = self:GetPos()
    self.dome.actif = true
    self.dome.timer = CurTime() + DOME_CONFIG.DUREE
    self.dome.expandStart = CurTime()
    self.dome.etat = "expansion"
    local owner = self:GetOwner()
    if IsValid(owner) then
        self.dome.owner = owner
    else
        self.dome.owner = nil
    end
    net.Start("ActivationDomeFilsDeSang")
    net.WriteEntity(self.dome.owner or self)
    net.WriteVector(self.dome.pos)
    net.WriteFloat(DOME_CONFIG.RAYON)
    net.WriteFloat(self.dome.expandStart)
    net.WriteFloat(DOME_CONFIG.EXPANSION)
    net.WriteFloat(DOME_CONFIG.CONTRACTION)
    net.Broadcast()
    local e = EffectData()
    e:SetOrigin(self.dome.pos)
    e:SetScale(DOME_CONFIG.RAYON / 200)
    self:CreatePhysicsBarrier()
    timer.Simple(DOME_CONFIG.DUREE, function()
        if IsValid(self) then
            self:FermerCage()
        end
    end)
end

function ENT:CreatePhysicsBarrier()
    self.barrierSegments = {}
    local radius = DOME_CONFIG.RAYON
    local numSegments = 36
    local height = 180
    local thickness = 8
    local center = self.dome.pos

    self.dome.hookid_collide = "DomeFds_ShouldCollide_" .. self:EntIndex()
    local selfref = self
    hook.Add("ShouldCollide", self.dome.hookid_collide, function(ent1, ent2)
        local domeSeg, other = nil, nil
        if IsValid(ent1) and ent1.IsDomeFDSBarrier and ent1.BarrierParent == selfref then
            domeSeg = ent1
            other = ent2
        elseif IsValid(ent2) and ent2.IsDomeFDSBarrier and ent2.BarrierParent == selfref then
            domeSeg = ent2
            other = ent1
        end
        if not domeSeg then return end
        local owner = selfref.dome and selfref.dome.owner
        if IsValid(owner) and other == owner then
            return false
        end
    end)

    for i = 0, numSegments - 1 do
        local angDeg = (i / numSegments) * 360
        local rad = math.rad(angDeg)
        local normal = Vector(math.cos(rad), math.sin(rad), 0)
        local chord = 2 * radius * math.sin(math.pi / numSegments)
        local halfSize = Vector(thickness * 0.5, chord * 0.5, height * 0.5)
        local pos = center + normal * (radius - halfSize.x) + Vector(0, 0, halfSize.z)
        local ang = Angle(0, angDeg + 90, 0)

        local seg = ents.Create("base_anim")
        if not IsValid(seg) then continue end
        seg:SetPos(pos)
        seg:SetAngles(ang)
        seg:SetModel("models/hunter/blocks/cube025x025x025.mdl")
        seg:SetNoDraw(true)
        seg:Spawn()
        seg:Activate()
        seg:PhysicsInitBox(-halfSize, halfSize)
        seg:SetSolid(SOLID_VPHYSICS)
        seg:SetMoveType(MOVETYPE_NONE)
        seg:SetCollisionGroup(COLLISION_GROUP_NONE)
        seg:SetNotSolid(false)
        local phys = seg:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end
        seg.IsDomeFDSBarrier = true
        seg.BarrierParent = self
        seg:SetParent(self)
        table.insert(self.barrierSegments, seg)
    end
end

function ENT:DestroyPhysicsBarrier()
    if self.dome and self.dome.hookid_collide then
        hook.Remove("ShouldCollide", self.dome.hookid_collide)
        self.dome.hookid_collide = nil
    end
    if not self.barrierSegments then return end
    for _, seg in ipairs(self.barrierSegments) do
        if IsValid(seg) then seg:Remove() end
    end
    self.barrierSegments = nil
end

function ENT:EnableDomeMovementBlock()
    self.dome = self.dome or {}
    self.dome.hookid = self.dome.hookid or ("DomeFds_Block_" .. self:EntIndex())
    local hookId = self.dome.hookid
    local selfref = self
    hook.Add("SetupMove", hookId, function(ply, mv, cmd)
        if not IsValid(selfref) then
            hook.Remove("SetupMove", hookId)
            return
        end
        if not selfref.dome or not selfref.dome.actif then return end
        if IsValid(selfref.dome.owner) and ply == selfref.dome.owner then return end
        if not IsValid(ply) or ply:GetMoveType() ~= MOVETYPE_WALK then return end
        local pos = mv:GetOrigin()
        local dir = pos - selfref.dome.pos
        local dist = dir:Length()
        local radius = DOME_CONFIG.RAYON
        if dist <= radius then return end
        local data = selfref.joueursData and selfref.joueursData[ply]
        if not data or not data.marque then return end
        local normal = dir:GetNormalized()
        local newPos = selfref.dome.pos + normal * (radius - 1)
        mv:SetOrigin(newPos)
        local vel = mv:GetVelocity()
        local outward = normal * vel:Dot(normal)
        local tangential = vel - outward
        mv:SetVelocity(tangential)
    end)
end

function ENT:DisableDomeMovementBlock()
    if self.dome and self.dome.hookid then
        hook.Remove("SetupMove", self.dome.hookid)
    end
end

function ENT:NettoyerDonneesJoueur(ply)
    if not self.joueursData or not self.joueursData[ply] then return end
    local owner = self.dome.owner
    local debuff_id = debuff_prefix .. (IsValid(owner) and owner:SteamID() or "unknown")
    if wOS and wOS.RemoveSpeedDebuff then
        wOS.RemoveSpeedDebuff(ply, debuff_id)
    end
    if self.joueursData[ply].saignement then
        local sid = ply:SteamID()
        timer.Remove("Saignement_" .. sid .. "_" .. self:EntIndex())
    end
    self.joueursData[ply] = nil
end

function ENT:FermerCage()
    if not self.dome.actif then return end
    self.dome.actif = false
    self.dome.owner = nil
    local e = EffectData()
    e:SetOrigin(self.dome.pos)
    e:SetScale(DOME_CONFIG.RAYON / 200)
    for ply, data in pairs(self.joueursData) do
        if IsValid(ply) then
            self:NettoyerDonneesJoueur(ply)
        end
    end
    self:DisableDomeMovementBlock()
    self:DestroyPhysicsBarrier()
    self:Remove()
end

function ENT:CommencerSaignement(ply)
    if not IsValid(ply) then return end
    if not self.dome or not self.dome.actif then return end
    if not IsValid(self) then return end
    local data = self.joueursData[ply] or {}
    self.joueursData[ply] = data
    if data.saignement and data.saignement.actif then return end
    data.saignement = { ticks = 0, actif = true, derniereVelocite = ply:GetVelocity():Length() }
    local steamID = ply:SteamID()
    local timerName = "Saignement_" .. steamID .. "_" .. self:EntIndex()
    local selfref = self
    local function TickSaignement()
        if not IsValid(selfref) or not IsValid(ply) then
            timer.Remove(timerName)
            return
        end
        if not selfref.joueursData or not selfref.joueursData[ply] or not selfref.joueursData[ply].saignement then
            timer.Remove(timerName)
            return
        end
        local saignementData = selfref.joueursData[ply].saignement
        saignementData.ticks = saignementData.ticks + 1
        local degats = math.random(DOME_CONFIG.DEGATS_MIN, DOME_CONFIG.DEGATS_MAX)
        ply:TakeDamage(degats)
        ply:EmitSound("fils_de_sang/FDS_Tic_SFX.mp3", 75, 100)
        local effectData = EffectData()
        effectData:SetOrigin(ply:GetPos() + Vector(0, 0, 50))
        effectData:SetScale(1)
        util.Effect("BloodImpact", effectData)
        if saignementData.ticks >= 3 then
            timer.Simple(0.1, function()
                if not IsValid(selfref) or not IsValid(ply) or not selfref.dome or not selfref.dome.actif or not selfref.joueursData or not selfref.joueursData[ply] then
                    timer.Remove(timerName)
                    return
                end
                local velociteActuelle = ply:GetVelocity():Length()
                local dist = ply:GetPos():Distance(selfref.dome.pos)
                if velociteActuelle > 0 and dist < DOME_CONFIG.RAYON then
                    selfref.joueursData[ply].saignement.ticks = 0
                    timer.Simple(1, TickSaignement)
                else
                    if selfref.joueursData[ply] then
                        selfref.joueursData[ply].saignement = nil
                    end
                    timer.Remove(timerName)
                end
            end)
        else
            timer.Simple(1, TickSaignement)
        end
    end
    TickSaignement()
end

function ENT:GererJoueurDansDome(ply)
    if not IsValid(ply) or not self.dome or not self.dome.actif then return end
    if self.dome.owner and IsValid(self.dome.owner) and ply == self.dome.owner then
        return
    end
    local dist = ply:GetPos():Distance(self.dome.pos)
    local data = self.joueursData[ply] or {}
    self.joueursData[ply] = data
    local owner = self.dome.owner
    local debuff_id = debuff_prefix .. (IsValid(owner) and owner:SteamID() or "unknown")
    if dist < DOME_CONFIG.RAYON then
        if not data.marque then
            data.marque = true
        end
        if not data.ralenti then
            if wOS and wOS.AddSpeedDebuff then
                wOS.AddSpeedDebuff(ply, debuff_id, DOME_CONFIG.DEBUFF_AMOUNT, DOME_CONFIG.DUREE)
            end
            data.ralenti = true
        end
        if data.marque then
            local velociteActuelle = ply:GetVelocity():Length()
            if velociteActuelle > 0 and (not data.saignement or not data.saignement.actif) then
                self:CommencerSaignement(ply)
            end
        end
        if dist > DOME_CONFIG.RAYON * 0.9 then
            local direction = (self.dome.pos - ply:GetPos()):GetNormalized()
            local force = (DOME_CONFIG.RAYON - dist) * 10
            ply:SetVelocity(direction * force)
        end
    else
        if data.marque then
            data.marque = false
        end
        if data.ralenti then
            if wOS and wOS.RemoveSpeedDebuff then
                wOS.RemoveSpeedDebuff(ply, debuff_id)
            end
            data.ralenti = false
        end
        if dist < DOME_CONFIG.RAYON * 1.1 then
            local direction = (ply:GetPos() - self.dome.pos):GetNormalized()
            local force = (DOME_CONFIG.RAYON * 1.1 - dist) * 15
            ply:SetVelocity(direction * force)
        end
    end
end

function ENT:Think()
    if self.dome and self.dome.actif then
        if CurTime() > self.dome.timer then
            self:FermerCage()
        else
            for _, ply in ipairs(player.GetAll()) do
                self:GererJoueurDansDome(ply)
            end
        end
    end
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:OnRemove()
    self:DisableDomeMovementBlock()
    self:DestroyPhysicsBarrier()
    if not self.joueursData then return end
    for ply, _ in pairs(self.joueursData) do
        if IsValid(ply) then
            self:NettoyerDonneesJoueur(ply)
        end
    end
end

hook.Add("PlayerDeath", "DomeFilsDeSang_PlayerDeath", function(ply)
    for _, ent in pairs(ents.FindByClass("dome_fils_sang")) do
        if IsValid(ent) then
            ent:NettoyerDonneesJoueur(ply)
        end
    end
end)

hook.Add("PlayerDisconnected", "DomeFilsDeSang_PlayerDisconnected", function(ply)
    for _, ent in pairs(ents.FindByClass("dome_fils_sang")) do
        if IsValid(ent) then
            ent:NettoyerDonneesJoueur(ply)
        end
    end
end)

util.AddNetworkString("ActivationDomeFilsDeSang")
