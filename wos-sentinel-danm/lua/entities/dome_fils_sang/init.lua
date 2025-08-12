AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')
if SERVER then include("wos/advswl/forcepowers/sh_speedmanager.lua") end

local DOME_CONFIG = {
    RAYON = 800,
    DUREE = 20,
    EXPANSION = 0.1,
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
    timer.Simple(DOME_CONFIG.DUREE, function()
        if IsValid(self) then
            self:FermerCage()
        end
    end)
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

-- Physique: collision sphérique dure du dôme
function ENT:AppliquerCollisionDome(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not self.dome or not self.dome.actif then return end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return end
    if self.dome.owner and IsValid(self.dome.owner) and ply == self.dome.owner then return end

    local centre = self.dome.pos
    local positionJoueur = ply:GetPos()
    local vecteurCentreVersJoueur = positionJoueur - centre
    local distance = vecteurCentreVersJoueur:Length()
    if distance <= 0.001 then return end

    local direction = vecteurCentreVersJoueur:GetNormalized()

    -- Rayon autorisé légèrement réduit pour tenir compte du gabarit du joueur (~16u)
    local rayonAutorise = math.max(0, (DOME_CONFIG.RAYON or 0) - 16)

    -- Si dehors, on re-téléporte juste à l'intérieur et on annule la vitesse radiale sortante
    if distance > rayonAutorise then
        local nouvellePos = centre + direction * rayonAutorise
        ply:SetPos(nouvellePos)

        local vitesse = ply:GetVelocity()
        local vitesseRadiale = vitesse:Dot(direction)
        if vitesseRadiale > 0 then
            -- SetVelocity ajoute une impulsion; on applique l'opposé pour annuler la composante sortante
            ply:SetVelocity(-direction * (vitesseRadiale + 50))
        end
        return
    end

    -- Si très proche de la bordure et en train d'aller vers l'extérieur, on annule l'élan sortant
    if distance > (rayonAutorise - 8) then
        local vitesse = ply:GetVelocity()
        local vitesseRadiale = vitesse:Dot(direction)
        if vitesseRadiale > 0 then
            local correction = math.min(vitesseRadiale + 50, 300)
            ply:SetVelocity(-direction * correction)
        end
    end
end

function ENT:GererJoueurDansDome(ply)
    if not IsValid(ply) or not self.dome or not self.dome.actif then return end
    if self.dome.owner and IsValid(self.dome.owner) and ply == self.dome.owner then
        -- Le propriétaire est exempté des debuffs/saignements, mais reste confiné par la collision dans AppliquerCollisionDome
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
        -- Suppression de l'ancienne répulsion; la collision est gérée par AppliquerCollisionDome
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
        -- Plus de poussée vers l'intérieur; AppliquerCollisionDome se charge de ramener le joueur
    end
end

function ENT:Think()
    if self.dome and self.dome.actif then
        if CurTime() > self.dome.timer then
            self:FermerCage()
        else
            for _, ply in ipairs(player.GetAll()) do
                -- D'abord, appliquer la collision dure du dôme
                self:AppliquerCollisionDome(ply)
                -- Puis, gérer les effets du dôme (debuffs/saignement) si applicable
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
