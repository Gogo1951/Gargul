local _, App = ...;

App.RollOff = App.RollOff or {};
App.MasterLooterUI = App.MasterLooterUI or {};
App.Ace.ScrollingTable = App.Ace.ScrollingTable or LibStub("ScrollingTable");

local UI = App.UI;
local Utils = App.Utils;
local AceGUI = App.Ace.GUI;
local Settings = App.Settings;
local MasterLooterUI = App.MasterLooterUI;
local ScrollingTable = App.Ace.ScrollingTable;

MasterLooterUI.Defaults = {
    itemIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
    itemBoxText = "",
};

MasterLooterUI.UIComponents = {
    Frame = {},
    Buttons = {},
    EditBoxes = {},
    Labels = {},
    Tables = {},
    Icons = {},
};

MasterLooterUI.ItemBoxHoldsValidItem = false;

MasterLooterUI.PlayersTable = {};

-- This is the UI the person who rolls off an item uses to prepare everything e.g:
-- Select an item
-- Set the duration of the roll off
-- Award the item to the winner
function MasterLooterUI:draw(itemLink)
    Utils:debug("MasterLooterUI:draw");

    if (not App.User.isMasterLooter
        and not App.User.hasAssist
    ) then
        return Utils:warning("You need to be the master looter or have an assist / lead role!");
    end

    -- Close the reopen masterlooter button if it exists
    if (self.UIComponents.Buttons.ReopenMasterLooterButton) then
        self.UIComponents.Buttons.ReopenMasterLooterButton:Hide();
    end

    -- First we need to check if the frame hasn't been
    -- rendered already. If so then show it (if it's hidden)
    -- and pass the itemLink along in case one was provided
    if (MasterLooterUI.UIComponents.Frame
        and MasterLooterUI.UIComponents.Frame.rendered
    ) then
        if (itemLink) then
            MasterLooterUI:passItemLink(itemLink);
        end

        -- If the frame is hidden we need to show it again
        if (not MasterLooterUI.UIComponents.Frame:IsShown()) then
            MasterLooterUI.UIComponents.Frame:Show();
        end

        return;
    end

    -- Create a container/parent frame
    local RollOffFrame = AceGUI:Create("Frame");
    RollOffFrame:SetTitle(App.name .. " v" .. App.version);
    RollOffFrame:SetLayout("Flow");
    RollOffFrame:SetWidth(430);
    RollOffFrame:SetHeight(350);
    RollOffFrame:EnableResize(false);
    RollOffFrame.rendered = true;
    RollOffFrame.frame:SetFrameStrata("HIGH");
    RollOffFrame.statustext:GetParent():Hide(); -- Hide the statustext bar
    RollOffFrame:SetCallback("OnClose", function(widget)
        local point, _, relativePoint, offsetX, offsetY = RollOffFrame:GetPoint();

        -- Store the frame's last position for future play sessions
        Settings:set("UI.RollOff.Position.point", point);
        Settings:set("UI.RollOff.Position.relativePoint", relativePoint);
        Settings:set("UI.RollOff.Position.offsetX", offsetX);
        Settings:set("UI.RollOff.Position.offsetY", offsetY);

        -- When the master looter closes the master loot window with a master
        -- loot still in progress we show the reopen master looter button
        if (App.RollOff.inProgress
            and App.RollOff.CurrentRollOff.initiator == App.User.name
        ) then
            self:drawReopenMasterLooterUIButton();
        end
    end);
    RollOffFrame:SetPoint(
        Settings:get("UI.RollOff.Position.point"),
        UIParent,
        Settings:get("UI.RollOff.Position.relativePoint"),
        Settings:get("UI.RollOff.Position.offsetX"),
        Settings:get("UI.RollOff.Position.offsetY")
    );

    MasterLooterUI.UIComponents.Frame = RollOffFrame;

            --[[
                FIRST ROW (ITEM ICON AND LINK BOX)
            ]]

            local FirstRow = AceGUI:Create("SimpleGroup");
            FirstRow:SetLayout("Flow");
            FirstRow:SetFullWidth(true);
            FirstRow:SetHeight(30);
            RollOffFrame:AddChild(FirstRow);

                    --[[
                        ITEM ICON
                    ]]

                    local ItemIcon = AceGUI:Create("Icon");
                    ItemIcon:SetImage(MasterLooterUI.Defaults.itemIcon);
                    ItemIcon:SetImageSize(30, 30);
                    ItemIcon:SetWidth(40);
                    FirstRow:AddChild(ItemIcon);
                    MasterLooterUI.UIComponents.Icons.Item = ItemIcon;

                    --[[
                        ITEM TEXTBOX
                    ]]
                    local ItemBox = AceGUI:Create("EditBox");

                    ItemBox:DisableButton(true);
                    ItemBox:SetHeight(20);
                    ItemBox:SetWidth(170);
                    ItemBox:SetCallback("OnTextChanged", MasterLooterUI.ItemBoxChanged); -- Update item info when input value changes
                    ItemBox:SetCallback("OnEnterPressed", MasterLooterUI.ItemBoxChanged); -- Update item info when item is dragged on top (makes no sense to use OnEnterPressed I know)

                    MasterLooterUI.UIComponents.EditBoxes.Item = ItemBox;

                    FirstRow:AddChild(ItemBox);

                    -- Show a gametooltip if the icon shown belongs to an item
                    ItemIcon:SetCallback("OnEnter", function()
                        if (not MasterLooterUI.ItemBoxHoldsValidItem) then
                            return;
                        end

                        local itemLink = ItemBox:GetText();
                        GameTooltip:SetOwner(ItemIcon.frame, "ANCHOR_TOP");
                        GameTooltip:SetHyperlink(itemLink);
                        GameTooltip:Show();
                    end)

                    ItemIcon:SetCallback("OnLeave", function()
                        GameTooltip:Hide();
                    end)

                    --[[
                        BUTTON PADDER
                        CONTAINER FOR PADDING PURPOSES ONLY
                    ]]

                    local ButtonPadder = AceGUI:Create("SimpleGroup");
                    ButtonPadder:SetLayout("Flow");
                    ButtonPadder:SetWidth(14);
                    ButtonPadder:SetHeight(30);
                    FirstRow:AddChild(ButtonPadder);

                    --[[
                        START/STOP BUTTON
                    ]]

                    local StartButton = AceGUI:Create("Button");
                    StartButton:SetText("Start");
                    StartButton:SetWidth(80);
                    StartButton:SetHeight(20);
                    StartButton:SetDisabled(true);
                    StartButton:SetCallback("OnClick", function()
                        App.RollOff.inProgress = true;

                        App.RollOff:announceStart(
                            MasterLooterUI.UIComponents.EditBoxes.Item:GetText(),
                            MasterLooterUI.UIComponents.EditBoxes.Timer:GetText(),
                            MasterLooterUI.UIComponents.EditBoxes.ItemNote:GetText()
                        );

                        MasterLooterUI:updateWidgets();
                    end);
                    FirstRow:AddChild(StartButton);
                    MasterLooterUI.UIComponents.Buttons.StartButton = StartButton;

                    --[[
                        STOP BUTTON
                    ]]

                    local StopButton = AceGUI:Create("Button");
                    StopButton:SetText("Stop");
                    StopButton:SetWidth(80);
                    StopButton:SetHeight(20);
                    StopButton:SetDisabled(true);
                    StopButton:SetCallback("OnClick", function()
                        App.RollOff:announceStop();
                    end);
                    FirstRow:AddChild(StopButton);
                    MasterLooterUI.UIComponents.Buttons.StopButton = StopButton;

            --[[
                SECOND ROW
            ]]

            local SecondRow = AceGUI:Create("SimpleGroup");
            SecondRow:SetLayout("Flow");
            SecondRow:SetFullWidth(true);
            SecondRow:SetHeight(20);
            RollOffFrame:AddChild(SecondRow);

                    --[[
                        SPACER
                    ]]

                    local PreItemNoteLabelSpacer = AceGUI:Create("SimpleGroup");
                    PreItemNoteLabelSpacer:SetLayout("Flow");
                    PreItemNoteLabelSpacer:SetWidth(8);
                    PreItemNoteLabelSpacer:SetHeight(20);
                    SecondRow:AddChild(PreItemNoteLabelSpacer);

                    --[[
                        ITEM NOTE LABEL
                    ]]

                    local ItemNoteLabel = AceGUI:Create("Label");
                    ItemNoteLabel:SetText("NOTE");
                    ItemNoteLabel:SetHeight(20);
                    ItemNoteLabel:SetWidth(35);
                    SecondRow:AddChild(ItemNoteLabel);
                    MasterLooterUI.UIComponents.EditBoxes.ItemNoteLabel = ItemNoteLabel;

                    --[[
                        ITEM NOTE
                    ]]

                    local ItemNote = AceGUI:Create("EditBox");
                    ItemNote:DisableButton(true);
                    ItemNote:SetHeight(20);
                    ItemNote:SetWidth(340);
                    SecondRow:AddChild(ItemNote);
                    MasterLooterUI.UIComponents.EditBoxes.ItemNote = ItemNote;

            --[[
                THID ROW (ROLL TIMER)
            ]]

            local ThirdRow = AceGUI:Create("SimpleGroup");
            ThirdRow:SetLayout("Flow");
            ThirdRow:SetFullWidth(true);
            ThirdRow:SetHeight(20);
            RollOffFrame:AddChild(ThirdRow);

                    --[[
                        SPACER
                    ]]

                    local PreTimerLabelSpacer = AceGUI:Create("SimpleGroup");
                    PreTimerLabelSpacer:SetLayout("Flow");
                    PreTimerLabelSpacer:SetWidth(8);
                    PreTimerLabelSpacer:SetHeight(20);
                    ThirdRow:AddChild(PreTimerLabelSpacer);

                    --[[
                        TIMER LABEL
                    ]]

                    local TimerLabel = AceGUI:Create("Label");
                    TimerLabel:SetText("TIMER (s)");
                    TimerLabel:SetHeight(20);
                    TimerLabel:SetWidth(55);
                    ThirdRow:AddChild(TimerLabel);
                    MasterLooterUI.UIComponents.Labels.TimerLabel = TimerLabel;

                    --[[
                        TIMER TEXTBOX
                    ]]

                    local TimerBox = AceGUI:Create("EditBox");
                    TimerBox:DisableButton(true);
                    TimerBox:SetHeight(20);
                    TimerBox:SetWidth(40);
                    TimerBox:SetText(Settings:get("UI.RollOff.timer"));
                    ThirdRow:AddChild(TimerBox);
                    MasterLooterUI.UIComponents.EditBoxes.Timer = TimerBox;

                    --[[
                        SPACER
                    ]]

                    local TimerAndAwardSpacer = AceGUI:Create("SimpleGroup");
                    TimerAndAwardSpacer:SetLayout("Flow");
                    TimerAndAwardSpacer:SetWidth(20);
                    TimerAndAwardSpacer:SetHeight(30);
                    ThirdRow:AddChild(TimerAndAwardSpacer);

                    --[[
                        RESET BUTTON
                    ]]
                    local ClearButton = AceGUI:Create("Button");
                    ClearButton:SetText("Clear");
                    ClearButton:SetWidth(66);
                    ClearButton:SetHeight(20);
                    ClearButton:SetDisabled(false);
                    ClearButton:SetCallback("OnClick", function()
                        MasterLooterUI:reset();
                    end);
                    ThirdRow:AddChild(ClearButton);
                    MasterLooterUI.UIComponents.Buttons.ClearButton = ClearButton;

                    --[[
                        AWARD BUTTON
                    ]]

                    local AwardButton = AceGUI:Create("Button");
                    AwardButton:SetText("Award");
                    AwardButton:SetWidth(70);
                    AwardButton:SetHeight(20);
                    AwardButton:SetDisabled(true);
                    AwardButton:SetCallback("OnClick", function()
                        local PlayersTable = MasterLooterUI.UIComponents.Tables.Players;
                        local selected = PlayersTable:GetRow(PlayersTable:GetSelection());

                        if (not selected
                            or not type(selected) == "table"
                        ) then
                            return Utils:warning("You need to select a player first");
                        end

                        return App.RollOff:award(unpack(selected), MasterLooterUI.UIComponents.EditBoxes.Item:GetText());
                    end);
                    ThirdRow:AddChild(AwardButton);
                    MasterLooterUI.UIComponents.Buttons.AwardButton = AwardButton;

            --[[
                FOURTH ROW (GROUP MEMBERS)
            ]]

            local FourthRow = AceGUI:Create("SimpleGroup");
            FourthRow:SetLayout("Flow");
            FourthRow:SetFullWidth(true);
            FourthRow:SetHeight(50);
            RollOffFrame:AddChild(FourthRow);

            MasterLooterUI:drawPlayersTable(RollOffFrame.frame);

    if (itemLink
        and type(itemLink) == "string"
    ) then
        MasterLooterUI:passItemLink(itemLink);
    end
end

-- This button allows the master looter to easily reopen the
-- master looter window when it's closed with a roll in progress
-- This is very common in hectic situations where the master looter has to participate in combat f.e.
function MasterLooterUI:drawReopenMasterLooterUIButton()
    Utils:debug("MasterLooterUI:drawReopenMasterLooterUIButton");

    local texture = App.RollOff.CurrentRollOff.itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark";

    if (self.UIComponents.ReopenMasterLooterButtonIcon) then
        self.UIComponents.ReopenMasterLooterButtonIcon:Show();
        return;
    end

    self.UIComponents.Buttons.ReopenMasterLooterButton = UI:createFrame("Button", "ReopenMasterLooterButton", nil, Frame);
    local Button = self.UIComponents.Buttons.ReopenMasterLooterButton;

    Button:SetSize(44, 44);
    Button:SetNormalTexture(texture);
    Button:SetText("text");
    Button:SetPoint(
        Settings:get("UI.ReopenMasterLooterUIButton.Position.point"),
        UIParent,
        Settings:get("UI.ReopenMasterLooterUIButton.Position.relativePoint"),
        Settings:get("UI.ReopenMasterLooterUIButton.Position.offsetX"),
        Settings:get("UI.ReopenMasterLooterUIButton.Position.offsetY")
    );

    Button:SetMovable(true);
    Button:EnableMouse(true);
    Button:SetClampedToScreen(true);
    Button:SetFrameStrata("HIGH");
    Button:RegisterForDrag("LeftButton");
    Button:SetScript("OnDragStart", Button.StartMoving);
    Button:SetScript("OnDragStop", function()
        Button:StopMovingOrSizing();
        local point, _, relativePoint, offsetX, offsetY = Button:GetPoint();

        -- Store the frame's last position for future play sessions
        Settings:set("UI.ReopenMasterLooterUIButton.Position.point", point);
        Settings:set("UI.ReopenMasterLooterUIButton.Position.relativePoint", relativePoint);
        Settings:set("UI.ReopenMasterLooterUIButton.Position.offsetX", offsetX);
        Settings:set("UI.ReopenMasterLooterUIButton.Position.offsetY", offsetY);
    end);

    local ButtonBackground = Button:CreateTexture(nil, "BACKGROUND");
    ButtonBackground:SetAllPoints(Button);
    ButtonBackground:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
    ButtonBackground:SetTexCoord(0, 1, 0.23, 0.77);
    ButtonBackground:SetBlendMode("ADD");
    Button.ButtonBackground = ButtonBackground;

    local ButtonHighlight = Button:CreateTexture(nil, "HIGHLIGHT");
    ButtonHighlight:SetAllPoints(Button);
    ButtonHighlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight");
    ButtonHighlight:SetTexCoord(0, 1, 0.23, 0.77);
    ButtonHighlight:SetBlendMode("ADD");
    Button.ButtonHighlight = ButtonHighlight;

    Button:SetScript("OnMouseUp", function (_, button)
        if (button == "LeftButton") then
            self:draw();
        end
    end);

    Button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(Button, "ANCHOR_TOP");
        GameTooltip:SetText("Open master looter window");
        GameTooltip:Show();
    end);

    Button:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
end

function MasterLooterUI:drawPlayersTable(parent)
    Utils:debug("MasterLooterUI:drawPlayersTable");

    -- Combined width of all colums should be 340
    local columns = {
        {
            name = "Player",
            width = 110,
            align = "LEFT",
            color = {
                r = 0.5,
                g = 0.5,
                b = 1.0,
                a = 1.0
            },
            colorargs = nil,
        },
        {
            name = "Roll",
            width = 85,
            align = "LEFT",
            color = {
                r = 0.5,
                g = 0.5,
                b = 1.0,
                a = 1.0
            },
            colorargs = nil,
            sort = App.Data.Constants.ScrollingTable.descending,
        },
        {
            name = " ",
            width = 145,
            align = "LEFT",
            color = {
                r = 0.5,
                g = 0.5,
                b = 1.0,
                a = 1.0
            },
            colorargs = nil,
            sort = App.Data.Constants.ScrollingTable.descending,
        },
    };

    local table = ScrollingTable:CreateST(columns, 8, 15, nil, parent);
    table:EnableSelection(true);
    table.frame:SetPoint("BOTTOM", parent, "BOTTOM", 0, 50);
    MasterLooterUI.UIComponents.Tables.Players = table;
end

-- The item box contents changed
function MasterLooterUI:ItemBoxChanged()
    Utils:debug("MasterLooterUI:ItemBoxChanged");

    local itemLink = MasterLooterUI.UIComponents.EditBoxes.Item:GetText();

    MasterLooterUI:passItemLink(itemLink);
end

-- Pass an item link to the master looter UI
-- This method is used when alt clicking an item
-- in a loot window or when executing /gl roll [itemlink]
function MasterLooterUI:passItemLink(itemLink)
    Utils:debug("MasterLooterUI:passItemLink");

    if (not MasterLooterUI.UIComponents.Frame.rendered) then
        return;
    end

    if (App.RollOff.inProgress) then
        return Utils:warning("A roll is currently in progress");
    end

    MasterLooterUI.UIComponents.EditBoxes.Item:SetText(itemLink);
    return MasterLooterUI:update();
end

-- Update the master looter UI based on the value of the ItemBox input
function MasterLooterUI:update()
    Utils:debug("MasterLooterUI:update");

    local IconWidget = MasterLooterUI.UIComponents.Icons.Item;
    local itemLink = MasterLooterUI.UIComponents.EditBoxes.Item:GetText();

    -- If the item link is not valid then
    --   Show the default question mark icon
    --   Remove the item priority string
    if (not itemLink or itemLink == "") then
        Utils:debug("MasterLooterUI:update. Item link is invalid");

        MasterLooterUI.ItemBoxHoldsValidItem = false;
        IconWidget:SetImage(MasterLooterUI.Defaults.itemIcon);

        MasterLooterUI:updateItemNote();
        MasterLooterUI:updateWidgets();
        return;
    end

    -- The item's icon is in the 10th position
    local icon = select(10, GetItemInfo(itemLink));

    if (icon) then
        -- TODO: Reset players / roll table
        MasterLooterUI.UIComponents.Tables.Players:ClearSelection();

        IconWidget:SetImage(icon);
        MasterLooterUI.ItemBoxHoldsValidItem = true;
    else
        MasterLooterUI.ItemBoxHoldsValidItem = false;
        IconWidget:SetImage(MasterLooterUI.Defaults.itemIcon);
    end

    MasterLooterUI:updateItemNote();
    MasterLooterUI:updateWidgets();
end

-- Update the item priority string
function MasterLooterUI:updateItemNote()
    Utils:debug("MasterLooterUI:updateItemNote");

    local ItemNote = MasterLooterUI.UIComponents.EditBoxes.ItemNote;
    local itemLink = MasterLooterUI.UIComponents.EditBoxes.Item:GetText();

    -- We don't have a valid itemlink at hand, clear the note
    if (not MasterLooterUI.ItemBoxHoldsValidItem) then
        return ItemNote:SetText("");
    end

    local itemPriority = App.LootPriority:getPriorityByItemLink(itemLink);

    -- If there is no item priority then label the item with "Off spec"
    if (not itemPriority) then
        return ItemNote:SetText("Off spec");
    end

    -- There is a priority for this item
    itemPriority = table.concat(itemPriority, " > ");
    ItemNote:SetText(itemPriority);
end

-- Reset the roll off UI to its defaults
function MasterLooterUI:reset()
    Utils:debug("MasterLooterUI:reset");

    MasterLooterUI.UIComponents.Icons.Item:SetImage(MasterLooterUI.Defaults.itemIcon);
    MasterLooterUI.UIComponents.EditBoxes.Item:SetText(MasterLooterUI.Defaults.itemText);
    MasterLooterUI.UIComponents.EditBoxes.Timer:SetText(Settings:get("UI.RollOff.timer"));
    MasterLooterUI.UIComponents.EditBoxes.ItemNote:SetText("");
    MasterLooterUI.ItemBoxHoldsValidItem = false;

    MasterLooterUI.UIComponents.Tables.Players:ClearSelection();
    MasterLooterUI.UIComponents.Tables.Players:ClearSelection();
    MasterLooterUI.UIComponents.Tables.Players:SetData({}, true);

    MasterLooterUI:updateWidgets();
end

-- Update the widgets based on the current state of the roll off
function MasterLooterUI:updateWidgets()
    Utils:debug("MasterLooterUI:updateWidgets");

    -- If the itembox doesn't hold a valid item link then:
    --   The start button should not be available
    --   The stop button should be available
    --   The item box should be available
    if (not MasterLooterUI.ItemBoxHoldsValidItem
        or not App.User.isInGroup
    ) then
        MasterLooterUI.UIComponents.Buttons.StartButton:SetDisabled(true);
        MasterLooterUI.UIComponents.Buttons.StopButton:SetDisabled(true);
        MasterLooterUI.UIComponents.EditBoxes.Item:SetDisabled(false);

        return;
    end

    -- The value in the itembox is valid (e.g. contains a valid item link)

    -- If no roll off is currently in progress then:
    --   The start button should be available
    --   The stop button should not be available
    --   The award button should not be available
    --   The clear button should not be available
    --   The item box should be available so we can enter an item link
    if (not App.RollOff.inProgress) then
        MasterLooterUI.UIComponents.Buttons.StartButton:SetDisabled(false);
        MasterLooterUI.UIComponents.Buttons.StopButton:SetDisabled(true);
        MasterLooterUI.UIComponents.Buttons.AwardButton:SetDisabled(false);
        MasterLooterUI.UIComponents.Buttons.ClearButton:SetDisabled(false);
        MasterLooterUI.UIComponents.EditBoxes.Item:SetDisabled(false);

    -- If a roll off is currently in progress then:
    --   The start button should not be available
    --   The stop button should be available
    --   The award button should not be available
    --   The clear button should not be available
    --   The item box should not be available
    else
        MasterLooterUI.UIComponents.Buttons.StartButton:SetDisabled(true);
        MasterLooterUI.UIComponents.Buttons.StopButton:SetDisabled(false);
        MasterLooterUI.UIComponents.Buttons.AwardButton:SetDisabled(true);
        MasterLooterUI.UIComponents.Buttons.ClearButton:SetDisabled(true);
        MasterLooterUI.UIComponents.EditBoxes.Item:SetDisabled(true);
    end
end

Utils:debug("MasterLooterUI.lua");