-- ====================================================================================================
-- =                                        Some fixed locals.                                        =
-- ====================================================================================================

local AddonName = "MobID"                   -- The name of the addon, just so it's easy to reuse code.
local Debug = false                         -- Debug of the addon.
local LogInTime = GetTime()                 -- Used for a timer for the welcome message.
local legendaryColor = "|cffFF8000"         -- The color we use to mark addon name.
local RogueColor = "|cFFFFF468"             -- Color my name Rogue color.
local resetColor = "|r"                     -- Stop the coloring of text.
local MobIdWelcome = false                  -- Used to see if we already have said "Welcome"

-- ====================================================================================================
-- =                                 Create frame and register events                                 =
-- ====================================================================================================

local f = CreateFrame("Frame");
    f:RegisterEvent("ADDON_LOADED");
    -- Is it Turtle WoW we are running, we only allow the addon to run on Turtle as we have no idea if other versions of the game use same ID's.
    if (TURTLE_WOW_VERSION) then
        f:RegisterEvent("PLAYER_TARGET_CHANGED");
        f:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
    end

-- ====================================================================================================
-- =                                          Event handler.                                          =
-- ====================================================================================================

-- f:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
f:SetScript("OnEvent", function()
    if (event == "ADDON_LOADED") and (arg1 == AddonName) then
        
        f:UnregisterEvent("ADDON_LOADED");
-- ====================================================================================================
    -- Did we target change ?
    elseif (event == "PLAYER_TARGET_CHANGED") then
        -- Run the check of the target, if we have a target.
        if UnitExists("target") then
            GetTheMobInfo("target")
        end
-- ====================================================================================================
    -- Did we mouseover a target ?
    elseif (event == "UPDATE_MOUSEOVER_UNIT") then
        -- Run the check of the mouseover, if we have a mouseover.
        if UnitExists("mouseover") then
            GetTheMobInfo("mouseover")
        end
        -- Check if we want to show a tooltip with the ID
        AddMobIDToTooltip();
    end
end)

-- ====================================================================================================
-- =                                     OnUpdate on every frame.                                     =
-- ====================================================================================================

f:SetScript("OnUpdate", function()

    -- A delay for showing a welcome message.
    if ((LogInTime + 5) < GetTime()) and (not MobIdWelcome) then
        DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. " by " .. RogueColor .. "Subby" .. resetColor .. " is loaded.");
        MobIdWelcome = true

        -- Is it Turtle WoW we are running.
        if (not TURTLE_WOW_VERSION) then
            -- It was not Turtle WoW, stop it all as we have no idea if ID's are the same in other versions of the game.
            DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": You are not running Turtle WoW, " .. AddonName .. " disabled.")
            return;
        end

        -- Check if there is updates to us from Import.lua
        ImportNewMobs()

        -- Split the list so we easy can add the missing ID's.
        UpdateMobIDs()

        -- A small info about how many mobs have ID and how many there is missing.
        WhoIsMissingID()

    end

end)

-- ====================================================================================================
-- =                                         Get the mob "ID"                                         =
-- ====================================================================================================

function GetTheMobInfo(source)
    -- Stop if it's a player or invalid target.
    if not UnitExists(source) or UnitIsPlayer(source) then
        return;
    end

    -- Get all the data we need.
    local mobName = UnitName(source)
    local mobLevel = UnitLevel(source)
    local zoneName = GetRealZoneText()
    local mobDataRow;

    -- Check if we are missing some data.
    if (not mobName) or (not mobLevel) or (not zoneName) or (mobName == "") or (mobLevel == "") or (zoneName == "") or (mobName == "Unknown")  then
        if (Debug) then
            DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": ERROR: Missing data for mob (Name, Level or Zone).");
        end
        return;
    end

    -- Convert mob level to a number, just to be sure.
    mobLevel = tonumber(mobLevel);

    -- Check if MOB_LIST is created correct, if not we create it.
    if (not MOB_LIST) or (not type(MOB_LIST) == "table") then
        MOB_LIST = {}
    end

-- ====================================================================================================

    -- Check if mob name is saved already.
    for i, mobData in ipairs(MOB_LIST) do
        -- Is name and zone the same ?
        if (mobData.Name == mobName) and (mobData.Zone == zoneName) then
            -- We found the name of the mob, save referance number in table.
            mobDataRow = mobData;
            break;
        end
    end

-- ====================================================================================================

    -- Did we found the mob ?
    if (mobDataRow) then

        -- Checks whether the detected level is outside the current range.
        if (mobLevel < mobDataRow.minLevel) or (mobLevel > mobDataRow.maxLevel) then

            local updated = false;

            -- Check if the saved level on min / max is -1 but mobLevel is diffrent.
            -- (Can for example happen if a low level Horde player meet a high level Alliance mob)
            if (mobDataRow.minLevel == -1) and (mobDataRow.maxLevel == -1) and (mobLevel > 0) then
                mobDataRow.minLevel = mobLevel;
                mobDataRow.maxLevel = mobLevel;
                updated = true;

            -- Is it a lower level ?
            elseif (mobLevel < mobDataRow.minLevel) and (mobDataRow.minLevel ~= -1) then
                mobDataRow.minLevel = mobLevel;
                updated = true;

            -- Is it a higher level ?
            elseif (mobLevel > mobDataRow.maxLevel) then
                mobDataRow.maxLevel = mobLevel;
                updated = true;
            end

            -- Did we update anything ?
            if (updated) then
                DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": Updated: " .. mobName .. " level range: |cFFFF8000" .. mobDataRow.minLevel .. " - " .. mobDataRow.maxLevel .. "|r");
            end

        end

-- ====================================================================================================

    else
        -- Locals
        SaveTheMob = false
        TheSavedPetOwner = nil

        -- Filter it so we catch Hunter and Warlock pets and same with repair bot's and so on.
        -- Check of the extra info contains for example "Subby's Pet" or "Subby's Minion.
        local PetOwner = GetPetOwnerName(source);

        -- Did we get a pet/minion owner name ?
        if (PetOwner) then
            -- Do we have the name of the owner in database ?
            for i, savedMobData in ipairs(MOB_LIST) do
                if (savedMobData.Name == PetOwner) then
                    SaveTheMob = true
                    TheSavedPetOwner = PetOwner
                    break;
                end
            end
        -- Not a pet or a minion.
        else
            SaveTheMob = true
        end

-- ====================================================================================================

        -- Do we want to save the mob ?
        if (SaveTheMob) then
            -- Was it a NPC pet, minion or totem ?
            if (TheSavedPetOwner) then
                -- New mob, so we insert it to the MOB_LIST.
                table.insert(MOB_LIST, {
                    Name = mobName,
                    minLevel = mobLevel,
                    maxLevel = mobLevel,
                    Zone = zoneName,
                    ID = "Missing",
                    Owner = PetOwner,
                    });
            else
                -- New mob, so we insert it to the MOB_LIST.
                table.insert(MOB_LIST, {
                    Name = mobName,
                    minLevel = mobLevel,
                    maxLevel = mobLevel,
                    Zone = zoneName,
                    ID = "Missing",
                });
            end

-- ====================================================================================================

            -- Sort the list alphabetically.
            SortAlphabetic()
        end
    end
end

-- ====================================================================================================
-- =                        Sort the table alphabetic so it's easy to enter ID                        =
-- ====================================================================================================

function SortAlphabetic()
    -- Check if MOB_LIST is made, if not we just stop.
    if (not MOB_LIST) or (not type(MOB_LIST) == "table") then
        return;
    end

    -- Check if MOB_LIST is empty.
    if (table.getn(MOB_LIST) == 0) then
        return;
    end

    -- Sort MOB_LIST from A to Z acording to mob name.
    table.sort(MOB_LIST, function(a, b)
        return a.Name < b.Name;
    end);

    if (Debug) then
        DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": SUCCESS:" .. "|r" .. " The mob list is now sorted alphabetically (" .. table.getn(MOB_LIST) .. " elements).");
    end
end

-- ====================================================================================================
-- =                                      Check targets tooltip.                                      =
-- ====================================================================================================

-- Creates a global reference to the scannertooltip.
local PetScannerTooltip = CreateFrame("GameTooltip", "PetScanTooltip", nil, "GameTooltipTemplate");
    PetScannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE"); -- Make it invisible on the screen

function GetPetOwnerName(unitID)
    -- Check that the unit exists.
    if (not UnitExists(unitID)) then
        return nil
    end

    -- Set the invisible tooltip to show info about the device
    PetScannerTooltip:SetUnit(unitID);

    -- GameTooltipTextLeft2 is the built-in UI framework for the 2nd line.
    -- In Lua 5.0 we should use _G[] or simply PetScanTooltipTextLeft2 (if it is globally named)
    local line2 = _G["PetScanTooltipTextLeft2"]; 

    -- Get the text from the line
    local text = line2:GetText();

    if (text) then
        -- This pattern is language dependent!
        local PetPattern = "(.+)'s Pet";
        local MinionPattern = "(.+)'s Minion";
        local CreationPattern = "(.+)'s Creation"; -- Used for Shaman totems.

        -- Use string.find to see if the text matches the pattern
        local _, _, PetOwnerName = string.find(text, PetPattern);
        local _, _, MinionOwnerName = string.find(text, MinionPattern);
        local _, _, CreationOwnerName = string.find(text, CreationPattern);

        if (PetOwnerName) then
            return PetOwnerName;
        elseif (MinionOwnerName) then
            return MinionOwnerName;
        elseif (CreationOwnerName) then
            return CreationOwnerName;
        end
    end

    -- Was not a pet or minion.
    return nil;

end

-- ====================================================================================================
-- =                    Check how many there have ID and how many there is missing                    =
-- ====================================================================================================

function WhoIsMissingID()

    -- Locals
    local IsNumber = 0
    local IsNotNumber = 0

    for i, CheckId in ipairs(MOB_LIST) do
        if (type(CheckId.ID) == "number") then
            IsNumber = IsNumber + 1
        else
            -- DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": " .. CheckId.Name)
            IsNotNumber = IsNotNumber + 1
        end
    end

    -- Write the message.
    DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": Have ID: " .. IsNumber .. " - Missing ID: " .. IsNotNumber .. ".");

end

-- ====================================================================================================
-- =                     Split what have ID and what is missing ID for easy check                     =
-- ====================================================================================================

function UpdateMobIDs()

    -- Check if MOB_LIST is created correct, if not we create it.
    if (not MOB_LIST) or (not type(MOB_LIST) == "table") then
        MOB_LIST = {}
    end

    -- Check if MISSING_MOB_ID is created correct, if not we create it.
    if (not MISSING_MOB_ID) or (not type(MISSING_MOB_ID) == "table") then
        MISSING_MOB_ID = {}
    end

    -- Create a empty table that we use temporarily.
    local NewMobList = {};

    -- Loop through the table to collect all data to the the temp table.
    for key, mobData in pairs(MOB_LIST) do
        table.insert(NewMobList, mobData);
    end

    -- Save all the data in the right order now.
    MOB_LIST = NewMobList;

    -- Empty the temp table again.
    local NewMobList = {};

    -- Loop through the table to collect all data to the the temp table.
    for key, mobData in pairs(MISSING_MOB_ID) do
        table.insert(NewMobList, mobData);
    end

    -- Save all the data in the right order now.
    MISSING_MOB_ID = NewMobList;

    local updatedCount = 0;

    -- Loop through MISSING_MOB_ID (We use ipairs here as we store indices for later removal)
    for i, missingMobData in ipairs(MISSING_MOB_ID) do

        -- Check if the ID is now a valid number.
        local potentialID = tonumber(missingMobData.ID);

        -- ID found.
        if (potentialID) then

            -- Find the matching element in MOB_LIST.
            for j, mobData in ipairs(MOB_LIST) do

                -- Match based on the unique keys: Name and Zone.
                if (mobData.Name == missingMobData.Name) and (mobData.Zone == missingMobData.Zone) then

                    -- Update ID in the primary list.
                    mobData.ID = potentialID;
                    updatedCount = updatedCount + 1;

                    -- Stop the inner loop (j)
                    break; 
                end
            end
        end
    end

    -- Create the new table, or clear it if it already exists.
    MISSING_MOB_ID = {}; 

    -- Iterate over all elements in MOB_LIST
    for i, mobData in ipairs(MOB_LIST) do

        -- Check if the ID field matches the string "Missing"
        if (mobData.ID == "Missing") then

            -- Copy the ENTIRE row (Name, Level, Zone, ID) into the new list.
            table.insert(MISSING_MOB_ID, mobData);
        end
    end

    -- Did we update anything ?
    if (updatedCount > 0) then
        DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": " .. updatedCount .. " new ID(s) have been added to " .. AddonName .. ".");
    end

end

-- ====================================================================================================
-- =                Import ID's from the Import.lua file so everyone can get the ID's.                =
-- ====================================================================================================

function ImportNewMobs()

    -- Check if IMPORT_MOB_ID is created correct and there is some posts there, if not then we stop.
    if (not IMPORT_MOB_ID) or (not type(IMPORT_MOB_ID) == "table") or (table.getn(IMPORT_MOB_ID) == 0) then
        return;
    end

    -- Check if MOB_LIST is created correct, if not we create it.
    if (not MOB_LIST) or (not type(MOB_LIST) == "table") then
        MOB_LIST = {}
    end

    -- Locals
    local updatedCount = 0; -- If a mob is updated.
    local addedCount = 0; -- If a mob is added.

    -- Loop through IMPORT_MOB_ID and look for new info.
    for _, importMob in ipairs(IMPORT_MOB_ID) do

        -- Check that we found a mob and a zone.
        if (importMob.Name) and (importMob.Zone) then

            local foundInExistingList = false;

            -- Loop through MOB_LIST and look if we already have the mob in our list.
            for k, existingMob in ipairs(MOB_LIST) do

                -- Is it same name and zone ?
                if (existingMob.Name == importMob.Name) and (existingMob.Zone == importMob.Zone) then

                    -- We found the mob
                    foundInExistingList = true;
                    -- No changes found yet.
                    local changed = false;

                    -- Save in some locals.
                    local newID = tonumber(importMob.ID) or importMob.ID;
                    local newMinLevel = tonumber(importMob.minLevel);
                    local newMaxLevel = tonumber(importMob.maxLevel);

                    -- Is the ID a number? We don't want to overwrite the ID we manually entered with "Missing".
                    if (tonumber(newID)) then
                        -- Maybe someone have found the ID for us, so is if diffrent then what we have ?
                        if (existingMob.ID ~= newID) then
                            existingMob.ID = newID;
                            changed = true;
                        end
                    end

                    -- Is the new minimum level lower then the level we have found ?
                    if (newMinLevel) and (existingMob.minLevel > newMinLevel) then
                        existingMob.minLevel = newMinLevel;
                        changed = true;
                    end

                    -- Is the max level higher then what we have found ?
                    if (newMaxLevel) and (existingMob.maxLevel < newMaxLevel) then
                        existingMob.maxLevel = newMaxLevel;
                        changed = true;
                    end

                    -- If we changed anything, then add 1
                    if (changed) then
                        updatedCount = updatedCount + 1;
                    end

                    -- Match found, stop the loop!
                    break; 
                end
            end

            -- Import new mobs.
            if (not foundInExistingList) then

                -- Convert to number if possible.
                local minL = tonumber(importMob.minLevel);
                local maxL = tonumber(importMob.maxLevel);
                local mobID = tonumber(importMob.ID) or importMob.ID

                -- Insert to our own table.
                table.insert(MOB_LIST, {
                    Name = importMob.Name,
                    minLevel = minL,
                    maxLevel = maxL,
                    Zone = importMob.Zone,
                    ID = mobID,
                });
                addedCount = addedCount + 1;
            end
        end

    end

    -- Inform if we added or updated something.
    if (updatedCount > 0) or (addedCount > 0) then
        DEFAULT_CHAT_FRAME:AddMessage(legendaryColor .. AddonName .. resetColor .. ": Import completed! " .. addedCount .. " new mob(s) added - " .. updatedCount .. " mob(s) updated.");
    end

end

-- ====================================================================================================
-- =                            Add ID to tooltip when we mouseover a mob.                            =
-- ====================================================================================================

function FindMobData(mobName, zoneName)

    -- Check if MOB_LIST is created correct, if not we create it.
    if (not MOB_LIST) or (not type(MOB_LIST) == "table") then
        MOB_LIST = {}
    end

    -- 
    for _, mobData in ipairs(MOB_LIST) do
        -- Match by Name and Zone.
        if (mobData.Name == mobName) and (mobData.Zone == zoneName) then
            return mobData;
        end
    end
    return nil;
end

-- ====================================================================================================

function AddMobIDToTooltip()

    -- If the mouse is not over a unit or it is a player, exit.
    if (not UnitExists("mouseover")) or (UnitIsPlayer("mouseover")) then 
        return;
    end

    -- Save Name and Zone in a local.
    local mobName = UnitName("mouseover");
    local zoneName = GetRealZoneText();

    -- Did we find a Name and a Zone ?
    if (mobName) and (zoneName) then
        local mobData = FindMobData(mobName, zoneName);

        -- Did we find the data ?
        if (mobData) then
            local mobID = mobData.ID;
            local idText = tostring(mobID);
            colorR, colorG, colorB = 0.2, 1.0, 0.2; -- Green

            -- If ID is "Missing", then we stop.
            if (mobID == "Missing") then
                return;
            end

            -- Add the Tooltip lines.
            GameTooltip:AddDoubleLine("Mob ID:", mobID, 1, 1, 1, colorR, colorG, colorB);

            -- Force the Tooltip to show.
            GameTooltip:Show();
        end
    end

end





























