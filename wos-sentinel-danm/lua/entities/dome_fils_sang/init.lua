AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')
if SERVER then include("wos/advswl/forcepowers/sh_speedmanager.lua") end

local DOME_CONFIG = {
    RAYON = 800,
    DUREE = 10,
    EXPANSION = 0.5,
    CONTRACTION = 0.5,
    DEGATS_MIN = 100,
    DEGATS_MAX = 150,
    DEBUFF_AMOUNT = 10,
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
        owner = nil,
        debuff_id = nil,
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
    self.dome.debuff_id = debuff_prefix .. (IsValid(self.dome.owner) and self.dome.owner:SteamID() or "unknown")

    net.Start("ActivationDomeFilsDeSang")
    net.WriteEntity(self.dome.owner or self)
    net.WriteVector(self.dome.pos)
    net.WriteFloat(DOME_CONFIG.RAYON)
    net.WriteFloat(self.dome.expandStart)
    net.WriteFloat(DOME_CONFIG.EXPANSION)
    net.WriteFloat(DOME_CONFIG.CONTRACTION)
    net.WriteFloat(DOME_CONFIG.DUREE)
    net.Broadcast()

    timer.Simple(DOME_CONFIG.DUREE, function()
        if IsValid(self) then
            self:FermerCage()
        end
    end)
end

function ENT:NettoyerDonneesJoueur(ply)
    if not self.joueursData or not self.joueursData[ply] then return end
    if wOS and wOS.RemoveSpeedDebuff and self.dome then
        wOS.RemoveSpeedDebuff(ply, self.dome.debuff_id or "unknown")
    end
    self.joueursData[ply] = nil
end

function ENT:FermerCage()
    if not self.dome.actif then return end
    self.dome.actif = false
    self.dome.owner = nil
    for ply, data in pairs(self.joueursData) do
        if IsValid(ply) then
            self:NettoyerDonneesJoueur(ply)
        end
    end
    self:Remove()
end

-- Démarre l’état de saignement sans timer (tické dans GererJoueurDansDome)
function ENT:CommencerSaignement(ply)
    if not IsValid(ply) then return end
    if not self.dome or not self.dome.actif then return end
    local data = self.joueursData[ply] or {}
    self.joueursData[ply] = data
    if data.saignement and data.saignement.actif then return end
    data.saignement = { ticks = 0, actif = true, nextAt = CurTime() }
end

function ENT:GererJoueurDansDome(ply)
    if not IsValid(ply) or not self.dome or not self.dome.actif then return end
    if self.dome.owner and IsValid(self.dome.owner) and ply == self.dome.owner then
        return
    end

    local pos = ply:GetPos()
    local dist = pos:Distance(self.dome.pos)
    local data = self.joueursData[ply] or {}
    self.joueursData[ply] = data

    local debuff_id = self.dome.debuff_id or "unknown"

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

        local velociteActuelle = ply:GetVelocity():Length()
        if velociteActuelle > 10 then
            if not data.saignement or not data.saignement.actif then
                self:CommencerSaignement(ply)
            end
            local sdata = data.saignement
            if sdata and sdata.actif and CurTime() >= (sdata.nextAt or 0) then
                local degats = math.random(DOME_CONFIG.DEGATS_MIN, DOME_CONFIG.DEGATS_MAX)
                ply:TakeDamage(degats)
                local effectData = EffectData()
                effectData:SetOrigin(ply:GetPos() + Vector(0, 0, 50))
                effectData:SetScale(1)
                util.Effect("BloodImpact", effectData)
                sdata.ticks = (sdata.ticks or 0) + 1
                sdata.nextAt = CurTime() + 1
                if sdata.ticks >= 3 then
                    -- Après 3 ticks consécutifs, on repart de 0 si le joueur continue de bouger
                    sdata.ticks = 0
                end
            end
        else
            -- Arrête le saignement si le joueur ne bouge plus
            data.saignement = nil
        end

        if dist > DOME_CONFIG.RAYON * 0.9 then
            local direction = (self.dome.pos - pos):GetNormalized()
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
        data.saignement = nil

        if dist < DOME_CONFIG.RAYON * 1.1 then
            local direction = (pos - self.dome.pos):GetNormalized()
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