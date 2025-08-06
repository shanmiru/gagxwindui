--=== [ Services and Essentials ] ===--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Data Services
local dataService = require(ReplicatedStorage.Modules.DataService)
local playerData = dataService:GetData()
local petdatas = playerData.PetsData
local petInventory = petdatas.PetInventory.Data

-- Remote Events
local ActivePetService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("ActivePetService")
local PetZoneAbility = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetZoneAbility")

-- Pet Services
local activePetsService = require(ReplicatedStorage.Modules.PetServices.ActivePetsService)
local LocalPlayer = Players.LocalPlayer

-- Configuration
local ZONE_ABILITY_DELAY = 2 -- Wait 2 seconds after zone ability
local MIDDLE_DURATION = 3 -- Run middling for 3 seconds
local PET_UPDATE_INTERVAL = 0.5 -- Update pets during middling
local NORMAL_UPDATE_INTERVAL = 0.45 -- Normal idle update interval

-- Variables
local zoneAbilityConnection = nil
local middleConnection = nil
local delayTimer = nil
local normalLoops = {} -- Store normal pet loops
local isMiddling = false

-- Function to set pet state
local function setPetState(uuid, state)
    pcall(function()
        activePetsService:SetPetState(uuid, state)
    end)
end

-- Function to start normal pet loops
local function startNormalPetLoops()
    if isMiddling then return end -- Don't start if we're middling
    
    for _, uuid in pairs(petdatas.EquippedPets) do
        local foundpet = petInventory[uuid]
        if foundpet then
            normalLoops[uuid] = task.spawn(function()
                while not isMiddling do -- Stop if middling starts
                    task.wait(NORMAL_UPDATE_INTERVAL)
                    if not isMiddling then -- Double check before setting state
                        setPetState(uuid, "Idle")
                    end
                end
            end)
        end
    end
end

-- Function to stop normal pet loops
local function stopNormalPetLoops()
    for uuid, loop in pairs(normalLoops) do
        if loop then
            task.cancel(loop)
        end
    end
    normalLoops = {}
end

-- Function to run pet middling
local function runPetMiddle()
    for _, uuid in pairs(petdatas.EquippedPets) do
        local foundpet = petInventory[uuid]
        if foundpet then
            setPetState(uuid, "Idle")
        end
    end
end

-- Function to handle zone ability event
local function onPetZoneAbility()
    print("Zone ability detected! Starting pet middle sequence...")
    
    -- Set middling flag
    isMiddling = true
    
    -- Stop normal loops
    stopNormalPetLoops()
    
    -- Cancel any existing timers
    if delayTimer then
        task.cancel(delayTimer)
    end
    
    -- Stop any existing middle connection
    if middleConnection then
        middleConnection:Disconnect()
        middleConnection = nil
    end
    
    -- Start delay timer
    delayTimer = task.spawn(function()
        -- Wait for zone ability delay
        task.wait(ZONE_ABILITY_DELAY)
        
        print("Starting pet middling...")
        
        -- Start intensive middling loop
        local startTime = tick()
        middleConnection = RunService.Heartbeat:Connect(function()
            local elapsed = tick() - startTime
            
            if elapsed >= MIDDLE_DURATION then
                -- Stop middling after duration
                middleConnection:Disconnect()
                middleConnection = nil
                isMiddling = false
                
                print("Pet middling completed! Resuming normal loops...")
                
                -- Resume normal pet loops
                startNormalPetLoops()
                return
            end
            
            -- Run intensive middling
            runPetMiddle()
            task.wait(PET_UPDATE_INTERVAL)
        end)
    end)
end

-- Setup the zone ability listener
zoneAbilityConnection = PetZoneAbility.OnClientEvent:Connect(onPetZoneAbility)

-- Start normal pet loops initially
startNormalPetLoops()

print("Integrated Pet Middle system initialized!")
print("- Normal pet idle loops running every", NORMAL_UPDATE_INTERVAL, "seconds")
print("- Zone ability middle system active")
print("- Pets will intensively middle for", MIDDLE_DURATION, "seconds after zone abilities")

-- Cleanup function
local function cleanup()
    isMiddling = false
    stopNormalPetLoops()
    
    if zoneAbilityConnection then
        zoneAbilityConnection:Disconnect()
        zoneAbilityConnection = nil
    end
    
    if middleConnection then
        middleConnection:Disconnect()
        middleConnection = nil
    end
    
    if delayTimer then
        task.cancel(delayTimer)
        delayTimer = nil
    end
    
    print("Pet Middle system cleaned up!")
end

-- Make cleanup available globally
_G.cleanupPetMiddle = cleanup
