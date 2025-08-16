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
    DEBUG_VISUAL = true,
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
    -- Mark only players currently inside as locked-in
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and (not IsValid(self.dome.owner) or ply ~= self.dome.owner) then
            local dist = ply:GetPos():Distance(self.dome.pos)
            if dist < DOME_CONFIG.RAYON then
                local data = self.joueursData[ply] or {}
                data.lockedIn = true
                self.joueursData[ply] = data
            end
        end
    end
    timer.Simple(DOME_CONFIG.DUREE, function()
        if IsValid(self) then
            self:FermerCage()
        end
    end)
end

function ENT:CreatePhysicsBarrier()
    if not self.dome then self.dome = {} end
    local R = DOME_CONFIG.RAYON
    local thickness = 12
    local subdiv = 1

    local function addVertex(list, v)
        local n = v:GetNormalized()
        table.insert(list, n)
        return #list
    end
    local function midpointIndex(cache, list, i1, i2)
        local a, b = math.min(i1, i2), math.max(i1, i2)
        local key = a .. ":" .. b
        local idx = cache[key]
        if idx then return idx end
        local v = (list[i1] + list[i2]) * 0.5
        idx = addVertex(list, v)
        cache[key] = idx
        return idx
    end

    local verts = {}
    local faces = {}
    local phi = (1 + math.sqrt(5)) * 0.5
    local function av(x, y, z)
        return addVertex(verts, Vector(x, y, z))
    end
    local a = av(-1,  phi, 0)
    local b = av( 1,  phi, 0)
    local c = av(-1, -phi, 0)
    local d = av( 1, -phi, 0)
    local e = av(0, -1,  phi)
    local f = av(0,  1,  phi)
    local g = av(0, -1, -phi)
    local h = av(0,  1, -phi)
    local i = av( phi, 0, -1)
    local j = av( phi, 0,  1)
    local k = av(-phi, 0, -1)
    local l = av(-phi, 0,  1)

    faces = {
        {a,l,f}, {b,f,j}, {c,e,l}, {d,j,e}, {h,a,k}, {h,b,i}, {g,c,k}, {g,d,i},
        {a,f,b}, {a,b,h}, {c,d,e}, {d,c,g}, {e,j,f}, {h,i,b}, {g,k,c}, {l,a,e},
        {k,a,h}, {i,h,g}, {j,d,i}, {l,e,f}
    }

    for _ = 1, subdiv do
        local cache = {}
        local newFaces = {}
        for _, tri in ipairs(faces) do
            local v1, v2, v3 = tri[1], tri[2], tri[3]
            local a2 = midpointIndex(cache, verts, v1, v2)
            local b2 = midpointIndex(cache, verts, v2, v3)
            local c2 = midpointIndex(cache, verts, v3, v1)
            table.insert(newFaces, {v1, a2, c2})
            table.insert(newFaces, {v2, b2, a2})
            table.insert(newFaces, {v3, c2, b2})
            table.insert(newFaces, {a2, b2, c2})
        end
        faces = newFaces
    end

    local convexes = {}
    local halfTh = thickness * 0.5
    for _, tri in ipairs(faces) do
        local p1 = verts[tri[1]] * R
        local p2 = verts[tri[2]] * R
        local p3 = verts[tri[3]] * R
        local normal = ((p2 - p1):Cross(p3 - p1)):GetNormalized()
        local top1 = p1 + normal * halfTh
        local top2 = p2 + normal * halfTh
        local top3 = p3 + normal * halfTh
        local bot1 = p1 - normal * halfTh
        local bot2 = p2 - normal * halfTh
        local bot3 = p3 - normal * halfTh
        table.insert(convexes, {top1, top2, top3, bot1, bot2, bot3})
    end

    self:PhysicsInitMultiConvex(convexes)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetNotSolid(false)
    self:SetCustomCollisionCheck(true)
    self:SetCollisionBounds(Vector(-R, -R, -R), Vector(R, R, R))
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self.dome.hookid_collide = "DomeFds_ShouldCollide_" .. self:EntIndex()
    local selfref = self
    hook.Add("ShouldCollide", self.dome.hookid_collide, function(ent1, ent2)
        local other = nil
        if ent1 == selfref then
            other = ent2
        elseif ent2 == selfref then
            other = ent1
        end
        if not other then return end
        local owner = selfref.dome and selfref.dome.owner
        if IsValid(owner) and other == owner then
            return false
        end
    end)

    if DOME_CONFIG.DEBUG_VISUAL then
        self:EnableBarrierDebug()
    end
end

function ENT:DestroyPhysicsBarrier()
    if self.dome and self.dome.hookid_collide then
        hook.Remove("ShouldCollide", self.dome.hookid_collide)
        self.dome.hookid_collide = nil
    end
    self:DisableBarrierDebug()
    self:SetSolid(SOLID_NONE)
    self:SetNotSolid(true)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end
end

function ENT:EnableBarrierDebug()
    if not self.dome then self.dome = {} end
    if self.dome.debugTimer then return end
    local timerId = "DomeFds_BarrierDebug_" .. self:EntIndex()
    self.dome.debugTimer = timerId
    timer.Create(timerId, 0.1, 0, function()
        if not IsValid(self) then
            timer.Remove(timerId)
            return
        end
        if not self.dome or not self.dome.actif then return end
        local center = self.dome.pos
        local radius = DOME_CONFIG.RAYON
        debugoverlay.Sphere(center, radius, 0.12, Color(0, 200, 255, 24), true)
    end)
end

function ENT:DisableBarrierDebug()
    if self.dome and self.dome.debugTimer then
        timer.Remove(self.dome.debugTimer)
        self.dome.debugTimer = nil
    end
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

function ENT:AppliquerCollisionDome(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if not self.dome or not self.dome.actif then return end
	if ply:GetMoveType() == MOVETYPE_NOCLIP then return end
	if self.dome.owner and IsValid(self.dome.owner) and ply == self.dome.owner then return end

	local data = self.joueursData and self.joueursData[ply]
	local lockedIn = data and data.lockedIn or false

	local centre = self.dome.pos
	local positionJoueur = ply:GetPos()
	local vecteurCentreVersJoueur = positionJoueur - centre
	local distance = vecteurCentreVersJoueur:Length()
	if distance <= 0.001 then return end

	local direction = vecteurCentreVersJoueur:GetNormalized()
	local R = (DOME_CONFIG.RAYON or 0)
	local marge = 16
	local rayonInterieur = math.max(0, R - marge)
	local rayonExterieur = R + marge

	if lockedIn then
		-- Inside players cannot exit
		if distance > rayonInterieur then
			local nouvellePos = centre + direction * rayonInterieur
			ply:SetPos(nouvellePos)
			local vitesse = ply:GetVelocity()
			local vRad = vitesse:Dot(direction)
			if vRad > 0 then
				ply:SetVelocity(-direction * (vRad + 50))
			end
			return
		end
		if distance > (rayonInterieur - 8) then
			local vitesse = ply:GetVelocity()
			local vRad = vitesse:Dot(direction)
			if vRad > 0 then
				local correction = math.min(vRad + 50, 300)
				ply:SetVelocity(-direction * correction)
			end
		end
	else
		-- Outside players cannot enter
		if distance < R then
			-- Already managed to cross inside: kick back out just beyond the shell
			local nouvellePos = centre + direction * rayonExterieur
			ply:SetPos(nouvellePos)
			local vitesse = ply:GetVelocity()
			local vDot = vitesse:Dot(direction)
			if vDot < 0 then
				ply:SetVelocity(direction * (math.abs(vDot) + 50))
			end
			return
		end
		if distance < rayonExterieur then
			local vitesse = ply:GetVelocity()
			local vDot = vitesse:Dot(direction)
			if vDot < 0 then
				local correction = math.min(math.abs(vDot) + 50, 300)
				ply:SetVelocity(direction * correction)
			end
		end
	end
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
    -- Only affect players who were inside at activation
    if not data.lockedIn then
        -- Ensure any residual debuff is cleared for non-locked players
        if data.ralenti then
            if wOS and wOS.RemoveSpeedDebuff then
                wOS.RemoveSpeedDebuff(ply, debuff_id)
            end
            data.ralenti = false
        end
        return
    end
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
    end
end

function ENT:Think()
    if self.dome and self.dome.actif then
        if CurTime() > self.dome.timer then
            self:FermerCage()
        else
            for _, ply in ipairs(player.GetAll()) do
                self:AppliquerCollisionDome(ply)
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
