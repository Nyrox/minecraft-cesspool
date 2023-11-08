local component = require("component")

local internet = component.proxy(component.internet.address)
local ae2 = component.proxy(component.me_controller.address)

local stockpile_config_request = internet.request("https://raw.githubusercontent.com/Nyrox/minecraft-cesspool/bonk/ae2_stockpile")

stockpile_config_request.finishConnect()

local function printTable(t)
  for k, v in pairs(t) do print(k, v) end
end


local res, msg, headers = stockpile_config_request.response()

function split_string (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end


local c = ae2.getCraftables()

local term = require("term")

local filters = stockpile_config_request.read()
stockpile_config_request.close()

local entries = split_string(filters, "\n")

local text = require("text")

local filterTable = {}

for k, v in pairs(entries) do
  local tokens = split_string(v, ",")
  local label = text.trim(tokens[1])
  local amount = text.trim(tokens[2])
  print(label, amount)

  local craftable = nil
  local craftables = ae2.getCraftables({ label=label })

  for k, v in pairs(craftables) do
    if v.getItemStack().label == label then
      craftable = v
      break  
    else end
  end  

  if craftable == nil then
    print("WARNING: Craftable missing: ", label)
  end

  filterTable[label] = { targetAmount=amount, craftHandle=craftable, currentlyCrafting=false, currentCraftHandle=nil }
end

local os = require("os")
local craftHandle = nil

function occupation()
  local numCpus = 0
  local numBusy = 0
  local cpus = ae2.getCpus()
 
  for k, v in pairs(cpus) do
    numCpus = numCpus + 1
    if v.busy then
      numBusy = numBusy + 1
    end
  end
 
  return numBusy / numCpus
end

local maxOccupation = 0.5

print("Starting stockpile magic...")

local computer = require("computer")
local MAX_CRAFT_TIME = 600

while true do
  if occupation() > maxOccupation then
    goto closer
  end

  for itemLabel, metadata in pairs(filterTable) do
    for k, v in pairs(ae2.getItemsInNetwork({ label=itemLabel })) do
      if itemLabel == v.label then
        local amountToCreate = metadata.targetAmount - v.size
        if metadata.currentlyCrafting and amountToCreate < 0 then
          print("Item order fulfilled: ", itemLabel)
          metadata.currentlyCrafting = false
        elseif metadata.currentlyCrafting then
          if metadata.currentCraftHandle then
            if metadata.currentCraftHandle.isDone() or metadata.currentCraftHandle.isCanceled() then
              print("item craft finished", itemLabel)
              metadata.currentCraftHandle = nil
              metadata.currentlyCrafting = false
            elseif computer.uptime() - metadata.craftStartTimestamp > MAX_CRAFT_TIME then
              print("item craft timed out", itemLabel)
              metadata.currentCraftHandle = nil
              metadata.currentlyCrafting = false
            end
          end
        elseif amountToCreate > 0 then
          print("Item found: ", itemLabel, ", current stock: ", v.size, ", desired stock: ", metadata.targetAmount)
          print("Scheduling: ", amountToCreate)

          metadata.currentCraftHandle = metadata.craftHandle.request(metadata.targetAmount - v.size)
          if metadata.currentCraftHandle then
            metadata.currentlyCrafting = true
            metadata.craftStartTimestamp = computer.uptime()
            goto closer
          else
            print("Scheduling failed")
          end
        end
      end
    end
  end  

  ::closer::
  os.sleep(5)
end
