local shitlist = ...
Shitlist = LibStub("AceAddon-3.0"):NewAddon(shitlist, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0"
, "AceSerializer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(shitlist, true)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

function Shitlist:OnInitialize()
    -- uses the "Default" profile instead of character-specific profiles
    -- https://www.wowace.com/projects/ace3/pages/api/ace-db-3-0
    self.db = LibStub("AceDB-3.0"):New("ShitlistDB", self.defaults, true)
    self.db.RegisterCallback(self, "OnNewProfile", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

    -- registers an options table and adds it to the Blizzard options window
    -- https://www.wowace.com/projects/ace3/pages/api/ace-config-3-0
    AceConfig:RegisterOptionsTable("ShitlistSettings Info", self.options.Info)
    AceConfigDialog:AddToBlizOptions("ShitlistSettings Info", shitlist)

    AceConfig:RegisterOptionsTable("ShitlistSettings Options", self.options.Settings, { "slo" })
    AceConfigDialog:AddToBlizOptions("ShitlistSettings Options", L["SHITLIST_MENU_SETTINGS"], shitlist)

    AceConfig:RegisterOptionsTable("ShitlistSettings Reasons", self.options.Reasons, { "slr" })
    AceConfigDialog:AddToBlizOptions("ShitlistSettings Reasons", L["SHITLIST_MENU_REASONS"], shitlist)

    AceConfig:RegisterOptionsTable("ShitlistSettings Listed_Players", self.options.ListedPlayers, { "slp" })
    AceConfigDialog:AddToBlizOptions("ShitlistSettings Listed_Players", L["SHITLIST_MENU_LISTED_PLAYERS"], shitlist)

    -- adds a child options table, in this case our profiles panel
    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    AceConfig:RegisterOptionsTable("ShitlistSettings Profiles", profiles)
    AceConfigDialog:AddToBlizOptions("ShitlistSettings Profiles", L["SHITLIST_MENU_PROFILES"], shitlist)

    LibDBIcon:Register(shitlist, self:MiniMapIcon(), self.db.profile.minimap)

    -- https://www.wowace.com/projects/ace3/pages/api/ace-console-3-0
    self:RegisterChatCommand("slm", "ToggleMiniMapIcon")
    self:RegisterChatCommand("sldebug", "ToggleDebug")

    self:GetOldConfigData()
    self:RefreshConfig()
end

function Shitlist:OnEnable()
    self:Print(L["SHITLIST_CONFIG_LOADING"])
    self:Print(L["SHITLIST_CONFIG_VERSION"], _G["ORANGE_FONT_COLOR_CODE"], self:GetVersion())
    self:Print(L["SHITLIST_CONFIG_REASONS"], _G["GREEN_FONT_COLOR_CODE"], #self:GetReasons())
    self:Print(L["SHITLIST_CONFIG_LISTEDPLAYERS"], _G["GREEN_FONT_COLOR_CODE"], #self:GetListedPlayers())

    if not self:IsHooked("UnitPopup_ShowMenu") then
        self:SecureHook("UnitPopup_ShowMenu", self.UnitPopup_ShowMenu)
    end

    -- Retail 10.0.2 https://wowpedia.fandom.com/wiki/Patch_10.0.2/API_changes#Tooltip_Changes
    if (TooltipDataProcessor) then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, self.GameTooltip)
    else
        -- Backwards compatibility WOTLK, Classic
        GameTooltip:HookScript("OnTooltipSetUnit", self.GameTooltip)
    end
    self:Print(L["SHITLIST_CONFIG_LOADED"])
end

function Shitlist:OnDisable()
    self:Print(L["SHITLIST_DISABLE"])
end

function Shitlist:RefreshConfig()
    self.db.profile.alert.last = {}

    if self.db.profile.minimap.hide then
        LibDBIcon:Hide(shitlist)
    else
        LibDBIcon:Show(shitlist)
    end

    --@debug@
    self:PrintDebug(L["SHITLIST_CONFIG_REFRESH"])
    self:PrintDebug("Debug:", _G["GREEN_FONT_COLOR_CODE"], self.db.profile.debug)
    self:PrintDebug("Mini Map Icon:", _G["GREEN_FONT_COLOR_CODE"], not self.db.profile.minimap.hide)
    --@end-debug@
end

function Shitlist:GetOldConfigData()
    if _G.ShitlistDB.ListedPlayers == nil and _G.ShitlistDB.Reasons == nil then
        return
    end
    self:Print(L["SHITLIST_CONFIG_CHECK_OLD_DATA"])

    local oldReasons = _G.ShitlistDB.Reasons
    local oldListedPlayers = _G.ShitlistDB.ListedPlayers
    local reasons = self:GetReasons()
    local listedPlayers = self:GetListedPlayers()
    local newPlayers = {}

    -- Check old listed player list
    if oldListedPlayers ~= nil then
        for _, player in pairs(listedPlayers) do
            newPlayers[player.name .. "-" .. player.realm] = true
        end

        for key, value in pairs(oldListedPlayers) do
            local name, realm = key:match("([^-]+)-([^-]+)")
            if name and realm then
                if not newPlayers[name .. "-" .. realm] then
                    local reason = value[1]
                    local description = value[2]

                    -- Check if the reason exist already and get it's id.
                    local reasonId = nil
                    for _, r in ipairs(reasons) do
                        if r.reason == reason then
                            reasonId = r.id
                            break
                        end
                    end
                    -- If the reason do not exist add it to the reason data.
                    if not reasonId then
                        reasonId = #reasons + 1
                        reasons[reasonId] = {
                            id = reasonId,
                            reason = reason,
                            color = { r = 1, g = 1, b = 1 },
                            alert = true,
                        }
                    end

                    -- Add the old player to the new listed players
                    listedPlayers[#listedPlayers + 1] = {
                        id = #listedPlayers + 1,
                        name = name,
                        realm = realm,
                        reason = reasonId,
                        description = description,
                        color = { r = 1, g = 1, b = 1 },
                        alert = true,
                    }

                    self:Print(L["SHITLIST_CONFIG_ADDED_OLD_DATA"], name .. "-" .. realm)
                else
                    self:Print(L["SHITLIST_CONFIG_DUPLICATE_DATA"], name .. "-" .. realm)
                end
            end
        end

        -- remove the old listed players from the database
        _G.ShitlistDB.ListedPlayers = nil
        _G.ShitlistDB.Reasons = nil
    end
end

function Shitlist:UnitPopup_ShowMenu(target, unit, menuList)
    local name, realm = self.name, GetRealmName()
    local listedPlayer = Shitlist:GetListedPlayer(name, realm)

    -- Check if this is the root level of the dropdown menu
    if UIDROPDOWNMENU_MENU_LEVEL == 1 and UnitIsPlayer(unit) and target ~= "SELF" then
        if (listedPlayer) then
            UIDropDownMenu_AddButton({
                text = shitlist,
                notCheckable = true,
                hasArrow = true,
                keepShownOnClick = true,
            }, UIDROPDOWNMENU_MENU_LEVEL)
        else
            UIDropDownMenu_AddButton({
                text = L["SHITLIST_POPUP_ADD"],
                notCheckable = true,
                icon = Shitlist.db.profile.icon,
                value = { name, realm },
                func = function()
                    Shitlist:Print(L["SHITLIST_POPUP_NEW_ADDED"], name, realm)
                    local new_player = Shitlist:NewListedPlayer(name, realm)
                    Shitlist.db.profile.listedPlayer.id = new_player.id
                    Shitlist.db.profile.listedPlayer.name = new_player.name
                    Shitlist.db.profile.listedPlayer.realm = new_player.realm
                    Shitlist.db.profile.listedPlayer.reason = new_player.reason
                    Shitlist.db.profile.listedPlayer.description = new_player.description
                    Shitlist.db.profile.listedPlayer.color = new_player.color
                    Shitlist.db.profile.listedPlayer.alert = new_player.alert

                    AceConfigDialog:CloseAll()
                    local AceGUI = Shitlist:AceGUIDefaults()
                    AceGUI:SetTitle(L["SHITLIST_LISTED_PLAYERS_TITLE"])
                    AceConfigDialog:SetDefaultSize("ShitlistSettings Listed_Players", 500, 300)
                    AceConfigDialog:Open("ShitlistSettings Listed_Players")
                end,
            }, UIDROPDOWNMENU_MENU_LEVEL)
        end
    elseif UIDROPDOWNMENU_MENU_VALUE == shitlist then
        Shitlist:AddSubMenu(listedPlayer)
    end
end

function Shitlist:AddSubMenu(player)
    local menuItem = UIDropDownMenu_CreateInfo()
    menuItem.text = shitlist
    menuItem.notCheckable = true
    menuItem.keepShownOnClick = true
    menuItem.hasArrow = false
    menuItem.isTitle = true
    menuItem.disabled = true
    menuItem.icon = Shitlist.db.profile.icon
    UIDropDownMenu_AddButton(menuItem, UIDROPDOWNMENU_MENU_LEVEL)

    menuItem = UIDropDownMenu_CreateInfo()
    menuItem.text = L["SHITLIST_POPUP_EDIT"]
    menuItem.notCheckable = true
    menuItem.hasArrow = false
    menuItem.value = player
    menuItem.func = function()
        if (player) then
            Shitlist.db.profile.listedPlayer.id = player.id
            Shitlist.db.profile.listedPlayer.name = player.name
            Shitlist.db.profile.listedPlayer.realm = player.realm
            Shitlist.db.profile.listedPlayer.reason = player.reason
            Shitlist.db.profile.listedPlayer.description = player.description
            Shitlist.db.profile.listedPlayer.color = player.color
            Shitlist.db.profile.listedPlayer.alert = player.alert

            AceConfigDialog:CloseAll()
            local AceGUI = Shitlist:AceGUIDefaults()
            AceGUI:SetTitle(L["SHITLIST_LISTED_PLAYERS_TITLE"])
            AceConfigDialog:SetDefaultSize("ShitlistSettings Listed_Players", 500, 300)
            AceConfigDialog:Open("ShitlistSettings Listed_Players")
        end
    end
    UIDropDownMenu_AddButton(menuItem, UIDROPDOWNMENU_MENU_LEVEL)

    menuItem = UIDropDownMenu_CreateInfo()
    menuItem.text = L["SHITLIST_POPUP_ANNOUNCEMENT"]
    menuItem.notCheckable = true
    menuItem.isTitle = true
    local a = Shitlist.db.profile.announcement
    if a.guild or a.party or a.instance or a.raid then
        UIDropDownMenu_AddButton(menuItem, UIDROPDOWNMENU_MENU_LEVEL)
    end

    local function _SendChatMessage(chat)
        SendChatMessage(L["SHITLIST_CHAT_PLAYER"] .. player.name .. "-" .. player.realm, chat, nil, nil)
        if self.db.profile.reasons[player.reason].reason ~= "None" then
            SendChatMessage(L["SHITLIST_CHAT_REASON"] .. self.db.profile.reasons[player.reason].reason, chat, nil, nil)
        end
        if player.description ~= "" then
            SendChatMessage(L["SHITLIST_CHAT_DESCRIPTION"] .. player.description, chat, nil, nil)
        end
    end
    local options = {
        {
            text = "Guild",
            notCheckable = true,
            func = function() _SendChatMessage("GUILD") end,
            disabled = not self.db.profile.announcement.guild
        },
        {
            text = "Party",
            notCheckable = true,
            func = function() _SendChatMessage("PARTY") end,
            disabled = not self.db.profile.announcement.party
        },
        {
            text = "Instance",
            notCheckable = true,
            func = function() _SendChatMessage("INSTANCE_CHAT") end,
            disabled = not self.db.profile.announcement.instance
        },
        {
            text = "Raid",
            notCheckable = true,
            func = function() _SendChatMessage("RAID") end,
            disabled = not self.db.profile.announcement.raid
        },
    }

    for _, option in ipairs(options) do
        if not option.disabled then
            UIDropDownMenu_AddButton(option, UIDROPDOWNMENU_MENU_LEVEL)
        end
    end
end

function Shitlist:GameTooltip()
    local _name, unit = self:GetUnit()
    if not (unit and UnitIsPlayer(unit)) then return end

    local name, realm = UnitFullName(unit)
    if (_name ~= name) then return end

    if (realm == nil) then realm = GetRealmName() end

    local listedPlayer = Shitlist:GetListedPlayer(name, realm)
    if (not listedPlayer) then return end

    local reason = Shitlist:GetReasons()[listedPlayer.reason]
    local _reason = reason
    local _listedPlayer = listedPlayer

    --@debug@
    Shitlist:PrintDebug("|cffff0000<GameTooltip>|cffffffff Playername:", name, "Realm:", realm, "Reason:", _reason
        .reason,
        "Note:", _listedPlayer.description)
    --@end-debug@

    -- Tooltip
    if not (_reason.reason == "None" and _listedPlayer.description == "") then
        self:AddLine("\n")
        self:AddDoubleLine(_reason.reason:gsub("None", ""), "|T" .. Shitlist.db.profile.icon .. ":0|t",
            _reason.color.r or 1, _reason.color.g or 1, _reason.color.b or 1)
        self:AddLine(_listedPlayer.description, _listedPlayer.color.r or 1, _listedPlayer.color.g or 1,
            _listedPlayer.color.b or 1, false)
    end

    -- Alert
    local time = time()
    local alert = Shitlist.db.profile.alert
    if (alert.enabled and reason.alert) then
        if (listedPlayer.alert and not alert.last[name]) then
            alert.last[name] = time + alert.delay
            Shitlist:ScheduleTimer("AlertDelayTimer", alert.delay, name)
            Shitlist:PlayAlertEffect()
            --@debug@
            Shitlist:PrintDebug("|cffff0000<ALERT>|cffffffff Sound effect disabled for player", name, "for", alert.delay,
                "seconds.")
            --@end-debug@
        end
    end
end

-- Called within ScheduleTimer and fires when timer ends.
function Shitlist:AlertDelayTimer(name)
    --@debug@
    Shitlist:PrintDebug("|cffff0000<ALERT>|cffffffff Sound effect is now enabled for player", name)
    --@end-debug@
    Shitlist.db.profile.alert.last[name] = nil
end

function Shitlist:MiniMapIcon()
    -- Create minimap launcher
    -- https://github.com/tekkub/libdatabroker-1-1/wiki/How-to-provide-a-dataobject
    return LibDataBroker:NewDataObject(shitlist, {
        type = "launcher",
        text = shitlist,
        icon = Shitlist.db.profile.icon,
        OnClick = function(clickedframe, button)
            AceConfigDialog:Close("ShitlistSettings Options")
            AceConfigDialog:CloseAll()
            local AceGUI = Shitlist:AceGUIDefaults()
            if button == "RightButton" then
                InterfaceOptionsFrame_OpenToCategory(shitlist)
            elseif button == "LeftButton" then
                if IsShiftKeyDown() then
                    AceGUI:SetTitle(L["SHITLIST_REASONS_TITLE"])
                    AceConfigDialog:SetDefaultSize("ShitlistSettings Reasons", 500, 200)
                    AceConfigDialog:Open("ShitlistSettings Reasons")
                elseif IsControlKeyDown() then
                    AceGUI:SetTitle(L["SHITLIST_LISTED_PLAYERS_TITLE"])
                    AceConfigDialog:SetDefaultSize("ShitlistSettings Listed_Players", 500, 300)
                    AceConfigDialog:Open("ShitlistSettings Listed_Players")
                else
                    AceGUI:SetTitle(L["SHITLIST_SETTINGS_TITLE"])
                    AceConfigDialog:SetDefaultSize("ShitlistSettings Options", 500, 350)
                    AceConfigDialog:Open("ShitlistSettings Options")
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddDoubleLine("|T" .. Shitlist.db.profile.icon .. ":0|t " .. L["SHITLIST_MINIMAP_TOOLTIP_TITLE"],
                Shitlist:GetVersion())
            tooltip:AddLine("\n")
            tooltip:AddLine(L["SHITLIST_MINIMAP_TOOLTIP_RIGHT_CLICK"])
            tooltip:AddLine(L["SHITLIST_MINIMAP_TOOLTIP_LEFT_CLICK"])
            tooltip:AddLine(L["SHITLIST_MINIMAP_TOOLTIP_SHIFT_LEFT_CLICK"])
            tooltip:AddLine(L["SHITLIST_MINIMAP_TOOLTIP_CTRL_LEFT_CLICK"])
        end,
    })
end

function Shitlist:ToggleMiniMapIcon()
    self.db.profile.minimap.hide = not self.db.profile.minimap.hide
    self:RefreshConfig()
end

function Shitlist:ToggleDebug()
    self.db.profile.debug = not self.db.profile.debug
    self:RefreshConfig()
end
