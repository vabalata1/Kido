surface.CreateFont("Hayden:Sit", {
    font = "Blood Crow",
    size = 24,
    antialias = true,
    shadow = false
})

net.Receive("SitRequest", function()
    local requester = net.ReadEntity()

    if not IsValid(requester) then return end

    local Frame = vgui.Create("DFrame")
    Frame:SetTitle("")
    Frame:SetSize(350, 200)  -- Augmenter la taille de la fenêtre
    Frame:Center()
    Frame:MakePopup()
    Frame:ShowCloseButton(false) -- Désactiver la croix de base
    Frame.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("fondderma.png"))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    local CloseButton = vgui.Create("DButton", Frame)
    CloseButton:SetPos(Frame:GetWide() - 32, 2)
    CloseButton:SetSize(30, 30)
    CloseButton:SetText("")
    CloseButton.DoClick = function()
        Frame:Close()
    end
    CloseButton.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("cross.png"))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    local PseudoLabel = vgui.Create("DLabel", Frame)
    PseudoLabel:SetPos(10, 40)
    PseudoLabel:SetSize(330, 30)
    PseudoLabel:SetText(requester:Nick())
    PseudoLabel:SetFont("Hayden:Sit")
    PseudoLabel:SetTextColor(Color(255, 255, 255))
    PseudoLabel:SetContentAlignment(5) -- Centrer le texte

    local TextLabel = vgui.Create("DLabel", Frame)
    TextLabel:SetPos(10, 70)
    TextLabel:SetSize(330, 30)
    TextLabel:SetText("veut s'asseoir sur votre dos.")
    TextLabel:SetFont("Hayden:Sit")
    TextLabel:SetTextColor(Color(255, 255, 255))
    TextLabel:SetContentAlignment(5) -- Centrer le texte

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
    AcceptButton.Paint = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("button.png"))
        surface.DrawTexturedRect(0, 0, w, h)
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
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("button.png"))
        surface.DrawTexturedRect(0, 0, w, h)
        draw.SimpleText("Refuser", "Hayden:Sit", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
