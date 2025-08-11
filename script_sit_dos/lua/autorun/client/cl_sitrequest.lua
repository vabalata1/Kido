surface.CreateFont("Hayden:Sit", {
    font = (system.IsLinux() or system.IsWindows()) and "Trebuchet24" or "Blood Crow",
    size = 24,
    antialias = true,
    shadow = false
})

local function materialSafe(path)
    local mat = Material(path)
    if mat:IsError() then
        return nil
    end
    return mat
end

net.Receive("SitRequest", function()
    local requester = net.ReadEntity()

    if not IsValid(requester) then return end

    local Frame = vgui.Create("DFrame")
    Frame:SetTitle("")
    Frame:SetSize(350, 200)
    Frame:Center()
    Frame:MakePopup()
    Frame:ShowCloseButton(false)

    local bgMat = materialSafe("fondderma.png")
    Frame.Paint = function(self, w, h)
        if bgMat then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(bgMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            surface.SetDrawColor(20, 20, 20, 240)
            surface.DrawRect(0, 0, w, h)
        end
    end

    local CloseButton = vgui.Create("DButton", Frame)
    CloseButton:SetPos(Frame:GetWide() - 32, 2)
    CloseButton:SetSize(30, 30)
    CloseButton:SetText("")
    CloseButton.DoClick = function()
        Frame:Close()
    end

    local crossMat = materialSafe("cross.png")
    CloseButton.Paint = function(self, w, h)
        if crossMat then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(crossMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            surface.SetDrawColor(200, 60, 60, 255)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("X", "Hayden:Sit", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local PseudoLabel = vgui.Create("DLabel", Frame)
    PseudoLabel:SetPos(10, 40)
    PseudoLabel:SetSize(330, 30)
    PseudoLabel:SetText(requester:Nick())
    PseudoLabel:SetFont("Hayden:Sit")
    PseudoLabel:SetTextColor(Color(255, 255, 255))
    PseudoLabel:SetContentAlignment(5)

    local TextLabel = vgui.Create("DLabel", Frame)
    TextLabel:SetPos(10, 70)
    TextLabel:SetSize(330, 30)
    TextLabel:SetText("veut s'asseoir sur votre dos.")
    TextLabel:SetFont("Hayden:Sit")
    TextLabel:SetTextColor(Color(255, 255, 255))
    TextLabel:SetContentAlignment(5)

    local AcceptButton = vgui.Create("DButton", Frame)
    AcceptButton:SetPos(50, 120)
    AcceptButton:SetSize(100, 30)
    AcceptButton:SetText("")
    AcceptButton.DoClick = function()
        net.Start("SitResponse")
        net.WriteEntity(requester)
        net.WriteBool(true)
        net.SendToServer()
        Frame:Close()
    end

    local btnMat = materialSafe("button.png")
    AcceptButton.Paint = function(self, w, h)
        if btnMat then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(btnMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            surface.SetDrawColor(60, 160, 80, 255)
            surface.DrawRect(0, 0, w, h)
        end
        draw.SimpleText("Accepter", "Hayden:Sit", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local RejectButton = vgui.Create("DButton", Frame)
    RejectButton:SetPos(200, 120)
    RejectButton:SetSize(100, 30)
    RejectButton:SetText("")
    RejectButton.DoClick = function()
        net.Start("SitResponse")
        net.WriteEntity(requester)
        net.WriteBool(false)
        net.SendToServer()
        Frame:Close()
    end
    RejectButton.Paint = function(self, w, h)
        if btnMat then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(btnMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            surface.SetDrawColor(160, 60, 60, 255)
            surface.DrawRect(0, 0, w, h)
        end
        draw.SimpleText("Refuser", "Hayden:Sit", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Timeout auto après 10 secondes => refus
    timer.Simple(10, function()
        if not IsValid(Frame) then return end
        net.Start("SitResponse")
        net.WriteEntity(requester)
        net.WriteBool(false)
        net.SendToServer()
        if IsValid(Frame) then Frame:Close() end
    end)
end)
