--[[
Created By: Augur ShicKla
Special Thanks To: TRC & matousss
v0.7.2

System Requirements:
Tier 3.5 Memory
Tier 3 GPU
Tier 3 Screen
]]--

Version = "0.7.2"
local component = require("component")
local computer = require("computer")
local event = require("event")
os = require("os")
term = require("term")
thread = require("thread")
serialization = require("serialization")
unicode = require("unicode")
local filesystem = require("filesystem")
screen = component.screen
local gpu = component.gpu
local modem = {}

-- Checking System Requirements are Met --------------------------------------------
if gpu.maxResolution() ~= 160 then
  io.stderr:write("Tier 3 GPU and Screen Required")
  os.exit(1)
end
if computer.totalMemory() < 1048576 then
  io.stderr:write("Not Enough Memory To Run. Please Install More Memory.")
  os.exit(1)
end
if not component.isAvailable("stargate") then
  io.stderr:write("No Stargate Connected.")
  os.exit(1)
end
NumberOfGates = 0
for k,v in component.list() do
  if v == "stargate" then NumberOfGates = NumberOfGates+1 end
end
if NumberOfGates > 1 then
  io.stderr:write("Too Many Stargates Connected to Computer.")
  os.exit(1)
end
-- End of Checking System Requirements ---------------------------------------------

-- Declarations --------------------------------------------------------------------
local sg = component.stargate

GlyphsMW = {"Andromeda","Aquarius","Aries","Auriga","Bootes","Cancer","Canis Minor","Capricornus","Centaurus","Cetus","Corona Australis","Crater","Equuleus","Eridanus","Gemini","Hydra","Leo","Leo Minor","Libra","Lynx","Microscopium","Monoceros","Norma","Orion","Pegasus","Perseus","Pisces","Piscis Austrinus","Sagittarius","Scorpius","Sculptor","Scutum","Serpens Caput","Sextans","Taurus","Triangulum","Virgo"}
GlyphsPG = {"Aaxel","Abrin","Acjesis","Aldeni","Alura","Amiwill","Arami","Avoniv","Baselai","Bydo","Ca Po","Danami","Dawnre","Ecrumig","Elenami","Gilltin","Hacemill","Hamlinto","Illume","Laylox","Lenchan","Olavii","Once El","Poco Re","Ramnon","Recktic","Robandus","Roehi","Salma","Sandovi","Setas","Sibbron","Tahnan","Zamilloz","Zeo"}

GateType = ""
GateTypeName = ""
ConnectionErrorString = "Communication error with Stargate. Please disconnect and reconnect.\nIf problem persists verify AUNIS 1.9.6 or greater is installed, and replace Stargate base block."
local DatabaseFile = "gateEntries.ff"
local DatabaseFileBackup = "gateEntries.bak"
local configFile = "dialer.cfg"
gateEntries = {}
historyEntries = {}
AddressBuffer = {}
keyCombo = {}
ActiveButtons = {}
gateName = ""
addAddressMode = false
adrEntryType = ""
ComputerDialingInterlocked = false
editGateEntryMode = false
manualAdrEntryMode = false
isDirectDialing = false
AbortingDialing = false
local WasCanceled = false
wasTerminated = false
MainLoop = true
HadNoError = true
ErrorMessage = ""
OutgoingWormhole = false
DialingInterlocked = false
DebugMode = false
UNGateResetting = false
RootDrive = nil
DialedAddress = {}
IncomingWormhole = false
GateStatusString, GateStatusBool = nil
local freeMemoryPercent = ""
local infoExtensionMode = nil
local IrisType = nil
local IrisMetaType = nil
local DatabaseWriteTimer = nil
local IrisSettings = {IDC = nil, AutoCloseIris = true, ModemIDCPort = nil}
local IDC = nil
local ModemIDCPort = nil
local IrisDurability = ""
local OutgoingIDC = nil
local ChildThread = {}
local HasModem = false
local AdminList = {}
local User = ""
local AdminOnlySettings = {Quit = true, AddEntry = true, EditEntry = true, History = true, ToggleIris = true}
local MiscSettings = {HideLocalAddr = false}
-- End of Declarations -------------------------------------------------------------

-- Pre-Initialization --------------------------------------------------------------
if sg.getGateType() == "MILKYWAY" then
  GateType = "MW"
  GateTypeName = "Milky Way"
  if not pcall(function() sg.getEnergyRequiredToDial({GlyphsMW[1]}) end) then
    io.stderr:write("MW: "..ConnectionErrorString)
    os.exit(1)
  end
elseif sg.getGateType() == "UNIVERSE" then
  GateType = "UN"
  GateTypeName = "Universe"
  if not pcall(function() sg.getEnergyRequiredToDial({"G1"}) end) then
    io.stderr:write("UN: "..ConnectionErrorString)
    os.exit(1)
  end
elseif sg.getGateType() == "PEGASUS" then
  GateType = "PG"
  GateTypeName = "Pegasus"
  if not pcall(function() sg.getEnergyRequiredToDial({GlyphsPG[1]}) end) then
    io.stderr:write("PG: "..ConnectionErrorString)
    os.exit(1)
  end
else
  io.stderr:write("Gate Type Not Recognized")
  os.exit(1)
end

for k,v in filesystem.mounts() do -- Searches for the filesystem that holds root and assigns it to the RootDrive variable
  if v == "/" then
    RootDrive = k
  end
end

if component.isAvailable("modem") then
  HasModem = true
  modem = component.modem
end
-- End of Pre-Initialization -------------------------------------------------------

-- Config File IO ------------------------------------------------------------------
local function readConfig()
  local file = io.open("dialer.cfg", "r")
  if file == nil then return end
  file:close()
  if not pcall(function() dofile("dialer.cfg") end) then
    io.stderr:write("Failed to load config file!\n")
  end
end

function IrisConfig(options)
  if type(options.IDC) == "number" and options.IDC >= 0 and options.IDC < 1e9 and math.floor(options.IDC) == options.IDC then
    IDC = options.IDC
  elseif options.IDC == nil then
    io.stderr:write("No IDC Provided\n")
  else
    io.stderr:write("IDC in config file is invalid\n")
  end
  
  if type(options.AutoCloseIris) == "boolean" then
    IrisSettings.AutoCloseIris = options.AutoCloseIris
  else
    io.stderr:write("AutoCloseIris in config file is invalid\n")
  end
  
  if type(options.NetworkPort) == "number" and options.NetworkPort > 0 and options.NetworkPort <= 65535 and math.floor(options.NetworkPort) == options.NetworkPort then
    ModemIDCPort = options.NetworkPort
    if HasModem then modem.open(ModemIDCPort) end
  elseif options.NetworkPort == nil then
    io.stderr:write("No IDC Network Port Provided\n")
  else
    io.stderr:write("IDC Network Port in config file is invalid\n")
  end  
  
  IrisConfig = nil
end

function AdminAccess(options)
  if type(options.Quit) == "boolean" then AdminOnlySettings.Quit = options.Quit end
  if type(options.AddEntry) == "boolean" then AdminOnlySettings.AddEntry = options.AddEntry end
  if type(options.EditEntry) == "boolean" then AdminOnlySettings.EditEntry = options.EditEntry end
  if type(options.History) == "boolean" then AdminOnlySettings.History = options.History end
  if type(options.ToggleIris) == "boolean" then AdminOnlySettings.ToggleIris = options.ToggleIris end

  AdminConfig = nil
end

function OtherSettings(options)
  if type(options.HideLocalAddr) == "boolean" then MiscSettings.HideLocalAddr = options.HideLocalAddr end
  OtherSettings = nil
end

local function writeConfig()
  local file = io.open("dialer.cfg", "w")
  file:write("-- Do not edit this file directly unless you know what you are doing.\n\n")
  file:write("IrisConfig{IDC="..tostring(IDC)..",AutoCloseIris="..tostring(IrisSettings.AutoCloseIris)..",NetworkPort="..tostring(ModemIDCPort).."}\n")
  file:write("AdminAccess{Quit="..tostring(AdminOnlySettings.Quit)..",AddEntry="..tostring(AdminOnlySettings.AddEntry)..",EditEntry="..tostring(AdminOnlySettings.EditEntry)..",History="..tostring(AdminOnlySettings.History)..",ToggleIris="..tostring(AdminOnlySettings.ToggleIris).."}\n")
  file:write("OtherSettings{HideLocalAddr="..tostring(MiscSettings.HideLocalAddr).."}\n")
  file:close()
end

readConfig()
writeConfig()
-- Config File IO End --------------------------------------------------------------

-- AdminList File IO ---------------------------------------------------------------
local function readAdminList()
  if filesystem.exists(shell.getWorkingDirectory().."/adminList.txt") then
    for line in io.lines("adminList.txt") do
      table.insert(AdminList, line)
    end
  else
    file = io.open("adminList.txt", "w")
    file:close()
  end
end

readAdminList()
-- AdminList File IO End -----------------------------------------------------------

-- Button Object -------------------------------------------------------------------
Button = {}
Button.__index = Button
function Button.new(xPos, yPos, width, height, label, func, border)
  local self = setmetatable({}, Button)
  if xPos < 1 or xPos > term.window.width then xPos = 1 end
  if yPos < 1 or yPos > term.window.height then yPos = 1 end
  if (width-2) < unicode.len(label) then width = unicode.len(label)+2 end
  if height < 3 then height = 3 end
  if border == nil then
    self.border = true
  else
    self.border = border
  end
  self.xPos = xPos
  self.yPos = yPos
  self.width = width
  self.height = height
  self.label = label
  self.func = func
  self.visible = false
  self.disabled = false
  return self
end

function Button.display(self, x, y)
  table.insert(ActiveButtons, 1, self)
  if (self.width-2) < unicode.len(self.label) then self.width = unicode.len(self.label)+2 end
  if x ~= nil and y ~= nil then
    self.xPos = x
    self.yPos = y
  end
  if self.border then
    gpu.fill(self.xPos+1, self.yPos, self.width-2, 1, "─")
    gpu.fill(self.xPos+1, self.yPos+self.height-1, self.width-2, 1, "─")
    gpu.fill(self.xPos, self.yPos+1, 1, self.height-2, "│")
    gpu.fill(self.xPos+self.width-1, self.yPos+1, 1, self.height-2, "│")
    gpu.set(self.xPos, self.yPos, "┌")
    gpu.set(self.xPos+self.width-1, self.yPos, "┐")
    gpu.set(self.xPos, self.yPos+self.height-1, "└")
    gpu.set(self.xPos+self.width-1, self.yPos+self.height-1, "┘")
  end
  gpu.set(self.xPos+1, self.yPos+1, self.label)
  self.visible = true
end

function Button.hide(self)
  self.visible = false
  for i,v in ipairs(ActiveButtons) do
    if v == self then table.remove(ActiveButtons, i) end
  end
  if self.border then
    gpu.fill(self.xPos, self.yPos, self.width, self.height, " ")
  else
    gpu.fill(self.xPos+1, self.yPos+1, self.width-2, 1, " ")
  end
end

function Button.disable(self, bool)
  if bool == nil then
    self.disabled = false
  else
    self.disabled = bool
  end
  if self.disabled then gpu.setForeground(0x0F0F0F) end
  if self.visible then self:display() end
  gpu.setForeground(0xFFFFFF)
end

function Button.touch(self, x, y)
  local wasTouched = false
  if self.visible and not self.disabled then  
    if self.border then
      if x >= self.xPos and x <= (self.xPos+self.width-1) and y >= self.yPos and y <= (self.yPos+self.height-1) then wasTouched = true end
    else
      if x >= self.xPos+1 and x <= (self.xPos+self.width-2) and y >= self.yPos+1 and y <= (self.yPos+self.height-2) then wasTouched = true end
    end
  end
  if wasTouched then
    gpu.setBackground(0x878787)
    gpu.set(self.xPos+1, self.yPos+1, self.label)
    gpu.setBackground(0x000000)
    if self.visible then gpu.set(self.xPos+1, self.yPos+1, self.label) end
    local success, msg = pcall(self.func)
    if not success then
      HadNoError = false
      ErrorMessage = debug.traceback(msg)
    end
  end
  return wasTouched
end
-- End of Button Object ------------------------------------------------------------

-- Check Box Object ----------------------------------------------------------------
local CheckBox = {}
CheckBox.__index = CheckBox
function CheckBox.new(xPos, yPos, tbl, tblKey, func)
  local self = setmetatable({}, CheckBox)
  self.xPos = xPos
  self.yPos = yPos
  self.tbl = tbl
  self.tblKey = tblKey
  self.visible = false
  self.disabled = false
  self.isChecked = self.tbl[self.tblKey]
  self.func = func
  return self
end

function CheckBox.display(self, isChecked, x, y)
  table.insert(ActiveButtons, 1, self)
  if isChecked ~= nil then
    self.isChecked = isChecked
  end  
  if x ~= nil and y ~= nil then
    self.xPos = x
    self.yPos = y
  end
  gpu.set(self.xPos, self.yPos, "[ ]")
  if self.isChecked then
    gpu.setForeground(0x00FF00)
    gpu.set(self.xPos+1, self.yPos, "X")
    gpu.setForeground(0xFFFFFF)
  end
  self.visible = true
end

function CheckBox.hide(self)
  self.visible = false
  for i,v in ipairs(ActiveButtons) do
    if v == self then table.remove(ActiveButtons, i) end
  end
  gpu.fill(self.xPos, self.yPos, 3, 1, " ")
end

function CheckBox.disable(self, bool)
  if bool == nil then
    self.disabled = false
  else
    self.disabled = bool
  end
  if self.disabled then gpu.setForeground(0x0F0F0F) end
  if self.visible then self:display() end
  gpu.setForeground(0xFFFFFF)
end

function CheckBox.touch(self, x, y)
  local wasTouched = false
  if self.visible and not self.disabled and x >= self.xPos and x < (self.xPos+3) and y == self.yPos then
    wasTouched = true
  end
  if wasTouched then
    if self.isChecked then
      self.isChecked = false
    elseif not self.isChecked then
      self.isChecked = true
    end
    self.tbl[self.tblKey] = self.isChecked
    if type(self.func) == "function" then
      local success, msg = pcall(self.func)
      if not success then
        HadNoError = false
        ErrorMessage = debug.traceback(msg)
      end
    end
    self:display()
  end
  return wasTouched
end
-- End Check Box Object ------------------------------------------------------------

-- Special Functions ---------------------------------------------------------------
function alert(msg, lvl)
  if ChildThread.AlertThread ~= nil then ChildThread.AlertThread:kill() end
  if lvl >= 0 then
    ChildThread.AlertThread = thread.create(function()
        gpu.setForeground(0x000000)
        if lvl == 0 or lvl == 1 then
          gpu.setBackground(0x00FF00)
          if lvl == 1 then computer.beep(1000) end
        elseif lvl == 2 then
          computer.beep()
          gpu.setBackground(0xFFFF00)
        elseif lvl == 3 then
          computer.beep(450, 0.5)
          gpu.setBackground(0xFF0000)
        end
        gpu.fill(1, 1, term.window.width, 1, " ")
        gpu.fill(1, term.window.height, term.window.width, 1, " ")
        gpu.set ((term.window.width/2)-(unicode.len(msg)/2), 1, msg)
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0x000000)
        os.sleep(10)
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0x000000)
        gpu.fill(1, 1, term.window.width, 1, " ")
        gpu.fill(1, term.window.height, term.window.width, 1, " ")
    end)
  else
    gpu.fill(1, 1, term.window.width, 1, " ")
    gpu.fill(1, term.window.height, term.window.width, 1, " ")
  end
end

function GateEntry(ge)
  if ge.gateAddress.UN ~= nil and #ge.gateAddress.UN ~= 0 then
    for i,v in ipairs(ge.gateAddress.UN) do
      _,ge.gateAddress.UN[i] = checkGlyph(v, "UN")
    end
  end
  if ge.fave == nil then ge.fave = false end
  table.insert(gateEntries, ge)
end

function HistoryEntry(ge)
  if ge.gateAddress.UN ~= nil and #ge.gateAddress.UN ~= 0 then
    for i,v in ipairs(ge.gateAddress.UN) do
      _,ge.gateAddress.UN[i] = checkGlyph(v, "UN")
    end
  end
  table.insert(historyEntries, ge)
end

local function initialLoadAddressFile()
  local file = io.open(DatabaseFile, "r")
  if file == nil then
    file = io.open(DatabaseFile, "w")
  end
  file:close()
  gateEntries = {}
  historyEntries = {}
  dofile(DatabaseFile)
  if #gateEntries > 0 then
      file, msg = io.open(DatabaseFileBackup, "w")
      for i,v in ipairs(gateEntries) do
        file:write("GateEntry"..serialization.serialize(v).."\n")
      end
      file:write("\n")
      for i,v in ipairs(historyEntries) do
        file:write("HistoryEntry"..serialization.serialize(v).."\n")
      end
      file:close()  
  else
    file = io.open(DatabaseFileBackup, "r")
    if file ~= nil then
      file:close()
      dofile(DatabaseFileBackup)
    end  
  end
end

local function readAddressFile()
  local file = io.open(DatabaseFile, "r")
  if file == nil then
    file = io.open(DatabaseFile, "w")
  end
  file:close()
  gateEntries = {}
  historyEntries = {}
  dofile(DatabaseFile)
end

local function writeToDatabase()
  if DatabaseWriteTimer ~= nil then
    event.cancel(DatabaseWriteTimer)
    DatabaseWriteTimer = nil
  end
  DatabaseWriteTimer = event.timer(5, function()
    -- alert("Database Saved", 1) -- For Debug
    local file, msg = io.open(DatabaseFile, "w")
    for i,v in ipairs(gateEntries) do
      file:write("GateEntry"..serialization.serialize(v).."\n")
    end
    file:write("\n")
    for i,v in ipairs(historyEntries) do
      file:write("HistoryEntry"..serialization.serialize(v).."\n")
    end
    file:close()
    readAddressFile()
    DatabaseWriteTimer = nil
  end)
  GateEntriesWindow.update() 
end

function addressToString(tbl)
  local str = "["
  for i,v in ipairs(tbl) do
    str = str..v
    if #tbl ~= i then str = str.." - " end
  end
  str = str.."]"
  return str
end

function clearDisplay()
  for k in pairs(buttons) do buttons[k]:hide() end
  gateRingDisplay.isActive = false
  gpu.fill(41, 2, 120-(2*glyphListWindow.width), 39, " ")
  gpu.fill(43, 2, 118-(2*glyphListWindow.width), 42, " ")
end

function checkGlyph(glyph, adrType)
  local isGood = false
  local fixedGlyph = ""
  local glyphsTbl = {}
  if adrType == "UN" then
    for i=1,36,1 do
      if string.lower(glyph) == "g"..i or string.lower(glyph) == "glyph "..i or string.lower(glyph) == "glyph"..i then
        fixedGlyph = "Glyph "..i
        isGood = true
        break
      end
    end
  else
    if adrType == "MW" then
      glyphsTbl = GlyphsMW
    elseif adrType == "PG" then
      glyphsTbl = GlyphsPG
    end
    for i,v in ipairs(glyphsTbl) do
      if string.lower(string.gsub(glyph,"%s+","")) == string.lower(string.gsub(v,"%s+","")) then
        fixedGlyph = v
        isGood = true
        break
      end
    end
  end
  return isGood, fixedGlyph  
end

function entriesDuplicateCheck(adr, entriesTable, adrType, pos)
  local hasDuplicate = false
  local duplicateNames = {}
  local entriesBuffer = {}
  local glyph = ""
  if #entriesTable ~= 0 then
    if pos > 6 then
      hasDuplicate = true
      for i,v in ipairs(entriesTable) do table.insert(duplicateNames, v.name) end
    else
      for i,v in ipairs(entriesTable) do
        if v.gateAddress[adrType] ~= nil and #v.gateAddress[adrType] ~= 0 then
          _,glyph = checkGlyph(adr[pos], adrType)
          if glyph == v.gateAddress[adrType][pos] then
            table.insert(entriesBuffer, v)
          end
        end
      end
      pos = pos + 1
      hasDuplicate, duplicateNames = entriesDuplicateCheck(adr, entriesBuffer, adrType, pos)
    end
  end
  return hasDuplicate, duplicateNames
end

function parseAddressString(adrStr, adrType)
  local adrBuf = {}
  if type(adrStr) == "string" then
    for w in string.gmatch(string.gsub(adrStr, "%s", ""), "%w+") do
      table.insert(adrBuf, w)
    end
    if #adrBuf > 0 then
      for i,v in ipairs(adrBuf) do
        _,adrBuf[i] = checkGlyph(v, adrType)
      end
    end
  end
  return adrBuf
end

local function userInput(x, y, maxLength, touchExits)
  local threadStates = {}
  for _,v in pairs(ChildThread) do
    threadStates[v] = v:status()
    v:suspend()
  end
  local success = true
  local inputString = ""
  local strLength = 0
  if maxLength == nil or maxLength == 0 then maxLength = 32 end
  term.setCursor(x, y)
  term.setCursorBlink(true)
  gpu.setBackground(0x878787)
  gpu.fill(x, y, maxLength, 1, " ")
  gpu.setBackground(0x000000)
  while true do
    -- term.setCursorBlink(true)
    local e, address, arg1, arg2, arg3 = term.pull()
    if e == "touch" and touchExits then
      success = false
      break
    end
    if e == "key_down" then
      if arg2 ~= 28 and arg2 ~= 14 and arg1 ~= 0 and strLength < maxLength then -- Not Enter, Backspace, or Other
        inputString = inputString..unicode.char(arg1)
      elseif arg2 == 14 then -- Backspace Key
        inputString = unicode.wtrunc(inputString, strLength)
      elseif arg2 == 28 then -- Enter Key
        break
      end
      strLength = unicode.len(inputString)
      gpu.setBackground(0x878787)
      gpu.fill(x, y, maxLength, 1, " ")
      gpu.set(x, y, inputString)
      gpu.setBackground(0x000000)
      term.setCursor(x+strLength, y)
    end
    -- if WasCanceled then
      -- WasCanceled = false
      -- inputString = ""
      -- break
    -- end
  end
  -- gpu.setBackground(0x000000)
  -- term.setCursorBlink(false)
  -- gpu.fill(x, y, maxLength, 1, " ")
  for k,v in pairs(threadStates) do
    if v == "running" then k:resume() end
  end
  -- alert("Input Closed", 1) -- For Debug
  return inputString, success
end

function updateHistory()
  local adrName = "UNKNOWN"
  local address = {}
  local timeString = os.date("%H:%M %d/%m", getRealTime())..""
  for i,v in ipairs(DialedAddress) do
    if i < #DialedAddress then
      table.insert(address, v)
    end
  end
  local inDatabase, duplicateNames = entriesDuplicateCheck(address, gateEntries, GateType, 1)
  if inDatabase then
    adrName = duplicateNames[1]
  end
  table.insert(historyEntries, 1, {name=adrName, gateAddress={[GateType]=address}, t=getRealTime()})
  while #historyEntries > 50 do
    table.remove(historyEntries)
  end
  GateEntriesWindow.range.botH = 1
  GateEntriesWindow.range.topH = GateEntriesWindow.range.height
  writeToDatabase()
end

function getRealTime()
  local tmpFile = io.open("/tmp/.time", "w")
  tmpFile:write()
  tmpFile:close()
  return math.floor(filesystem.lastModified("/tmp/.time") / 1000)
end

local function isAuthorized(name, isEnabled)
  local authorized = false
  if type(isEnabled) ~= "boolean" then isEnabled = true end
  if isEnabled then 
    if #AdminList == 0 then
      authorized = true
    else
      for _,v in ipairs(AdminList) do
        if string.lower(v) == string.lower(name) then
          authorized = true
          break
        end
      end
    end
  else
    authorized = true
  end
  if not authorized then alert("ACCESS DENIED", 2) end
  return authorized
end
-- End of Special Functions --------------------------------------------------------

-- Info Center ---------------------------------------------------------------------
local function displaySystemStatus()
  local xPos = 2
  local yPos = 45
  local energyStored = 0
  local energyMax = 0
  local capCount = 0
  local irisState = nil
  local status, err = pcall(function()
    energyStored = sg.getEnergyStored()
    energyMax = sg.getMaxEnergyStored()
    capCount = sg.getCapacitorsInstalled()  
  end)
  if status == false then
    ErrorMessage = "Stargate Has Been Disconnected"
    HadNoError = false
    MainLoop = false
  end
  pcall(function() 
    irisState = sg.getIrisState()
  end)
  -- local freeMemory = computer.freeMemory()
  -- local totalComputerMemory = computer.totalMemory()
  gpu.set(17, term.window.height-6, "╡")
  gpu.set(29, term.window.height-6, "╞")
  gpu.setForeground(0x000000)
  if GateStatusString == "open" then
    gpu.setBackground(0xFFFF00)
    gpu.set(18, term.window.height-6, " GATE OPEN ")
  else
    gpu.setBackground(0x00FF00)
    gpu.set(18, term.window.height-6, "GATE CLOSED")
  end
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)
  gpu.set(30, term.window.height-6, "═════════════")
  if IrisType ~= nil and IrisType ~= "NULL" then
    if IrisType == "SHIELD" then
      gpu.set(30, term.window.height-6, "╡░░░░░░░░░░╞")
      if irisState == "OPENED" then
        if GateStatusString == "open" and GateStatusBool == false then
          gpu.setForeground(0x000000)
          gpu.setBackground(0xFFFF00)
        end
        gpu.set(31, term.window.height-6, "SHIELD OFF")
      elseif irisState == "CLOSED" then
        gpu.set(31, term.window.height-6, "SHIELD ON ")
      end
    else
      gpu.set(30, term.window.height-6, "╡░░░░░░░░░░░╞")
      if irisState == "OPENED" then
        if GateStatusString == "open" and GateStatusBool == false then
          gpu.setForeground(0x000000)
          gpu.setBackground(0xFFFF00)
        end
        gpu.set(31, term.window.height-6, " IRIS OPEN ")
      elseif irisState == "CLOSED" then
        gpu.set(31, term.window.height-6, "IRIS CLOSED")
      end
    end
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
  end
  gpu.fill(xPos, yPos, 44, 4, " ")
  gpu.set(xPos+1, yPos, "Energy Level: "..energyStored.."/"..energyMax.." RF "..math.floor((energyStored/energyMax)*100).."%")
  gpu.set(xPos+1, yPos+1, "Capacitors Installed: "..capCount.."/3")
  -- gpu.set(xPos+1, yPos+3, "Computer Memory Remaining: "..math.floor((freeMemory/totalComputerMemory)*100).."%")
  gpu.set(xPos+1, yPos+3, "Computer Memory Remaining: "..freeMemoryPercent)
  if IrisType ~= nil and IrisType ~= "NULL" then
    gpu.set(xPos+1, yPos+2, "Iris Durability: "..IrisDurability)
  end
end

local function displayLocalAddress()
  gpu.set(48, 45, "Milky Way ")
  gpu.set(48, 46, "Universe  ")
  gpu.set(48, 47, "Pegasus   ")
  if MiscSettings.HideLocalAddr then
    gpu.setForeground(0xFF0000)
    gpu.set(58, 45, "REDACTED")
    gpu.set(58, 46, "REDACTED")
    gpu.set(58, 47, "REDACTED")
    gpu.setForeground(0xFFFFFF)
  else
    gpu.set(58, 45, addressToString(localMWAddress))
    gpu.set(58, 46, addressToString(localUNAddress))
    gpu.set(58, 47, addressToString(localPGAddress))
  end
end

local ConfigPage = {}
ConfigPage.autoIrisCheckBox = CheckBox.new(64, 46, IrisSettings, "AutoCloseIris", writeConfig)

ConfigPage.changeIDCButton = Button.new(65, 46, 0, 0, "         ", function()
  ConfigPage.changeIDCButton:hide()
  local newIDC, successful = userInput(66, 47, 9, true)
  if successful then
    if newIDC == "" then
      alert("IDC Was Cleared", 2)
      IDC = nil
      writeConfig()
    else
      newIDC = tonumber(newIDC)
      if type(newIDC) == "number" and newIDC >= 0 and newIDC < 1e9 and math.floor(newIDC) == newIDC then
        alert("IDC Has Been Changed", 1)
        IDC = newIDC
        writeConfig()
      else
        alert("Invalid IDC", 2)
      end
    end
  end
  if infoExtensionMode == "CONFIG" then ConfigPage.show() end
end, false)

ConfigPage.changePortButton = Button.new(65, 47, 0, 0, "     ", function()
  ConfigPage.changePortButton:hide()
  local newPort, successful = userInput(66, 48, 5, true)
  if successful then
    if newPort == "" then
      alert("IDC Network Port Was Closed", 2)
      if ModemIDCPort ~= nil then modem.close(ModemIDCPort) end
      ModemIDCPort = nil
      writeConfig()
    else
      newPort = tonumber(newPort)
      if type(newPort) == "number" and newPort > 0 and newPort <= 65535 and math.floor(newPort) == newPort then
        alert("IDC Network Port Has Been Changed", 1)
        if ModemIDCPort ~= nil then modem.close(ModemIDCPort) end
        ModemIDCPort = newPort
        modem.open(ModemIDCPort)
        writeConfig()
      else
        alert("Invalid Port Number", 2)
      end
    end
  end
  if infoExtensionMode == "CONFIG" then ConfigPage.show() end
end, false)

local adminOffset = 75
ConfigPage.adminQuitCheckBox = CheckBox.new(adminOffset+15, 46, AdminOnlySettings, "Quit", writeConfig)
ConfigPage.adminAddEntryCheckBox = CheckBox.new(adminOffset+21, 47, AdminOnlySettings, "AddEntry", writeConfig)
ConfigPage.adminEditEntryCheckBox = CheckBox.new(adminOffset+18, 48, AdminOnlySettings, "EditEntry", writeConfig)
ConfigPage.adminHistoryCheckBox = CheckBox.new(adminOffset+43, 46, AdminOnlySettings, "History", writeConfig)
ConfigPage.adminToggleIrisCheckBox = CheckBox.new(adminOffset+39, 47, AdminOnlySettings, "ToggleIris", writeConfig)

local otherOffset = 121
ConfigPage.hideLocalAddrCheckBox = CheckBox.new(otherOffset+23, 46, MiscSettings, "HideLocalAddr", writeConfig)

function ConfigPage.show()
  ConfigPage.autoIrisCheckBox:display()
  gpu.set(47, 45, "╭Iris / Shield Settings─────")
  gpu.fill(47, 46, 1, 3, "│")
  gpu.set(48, 46, "Auto Close Iris [ ]")
  ConfigPage.changeIDCButton:display()
  if IrisSettings.AutoCloseIris == true then
    gpu.setForeground(0x00FF00)
    gpu.set(65, 46, "X")
    gpu.setForeground(0xFFFFFF)
  end
  gpu.set(48, 47, "Iris/Shield Code:")
  gpu.setBackground(0x878787)
  gpu.set(66, 47, "         ")
  if IDC ~= nil then gpu.set(66, 47, tostring(IDC)) end
  gpu.setBackground(0x000000)
  gpu.set(48,48, "IDC Network Port:")
  if HasModem then
    ConfigPage.changePortButton:display()
    gpu.setBackground(0x878787)
    gpu.set(66, 48, "     ")
    if ModemIDCPort ~= nil then gpu.set(66, 48, tostring(ModemIDCPort)) end
    gpu.setBackground(0x000000)
  else
    gpu.set(66, 48, "No Card")
  end
  gpu.fill(adminOffset, 46, 1, 3, "│")
  gpu.set(adminOffset, 45, "┬Admin Only Access Settings──────────────────────────╮")
  if #AdminList > 0 then
    gpu.set(adminOffset+1, 46, "Quit Program: [ ]")
    ConfigPage.adminQuitCheckBox:display()
    gpu.set(adminOffset+1, 47, "Add New Gate Entry: [ ]")
    ConfigPage.adminAddEntryCheckBox:display()
    gpu.set(adminOffset+1, 48, "Edit Gate Entry: [ ]")
    ConfigPage.adminEditEntryCheckBox:display()
    gpu.set(adminOffset+26, 46, "Dialing History: [ ]")
    ConfigPage.adminHistoryCheckBox:display()
    gpu.set(adminOffset+26, 47, "Toggle Iris: [ ]")
    ConfigPage.adminToggleIrisCheckBox:display()
  else
    gpu.setForeground(0xFFFF00)
    gpu.set(adminOffset+5, 47, "There are no Names in the Admin List")
    gpu.setForeground(0xFFFFFF)
  end
  gpu.fill(otherOffset, 46, 1, 3, "│")
  gpu.set(otherOffset, 45, "┬Other Settings───────────────────────╮")
  gpu.set(otherOffset+1, 46, "Hide Local Addresses: [ ]")
  ConfigPage.hideLocalAddrCheckBox:display()
  gpu.fill(otherOffset+38, 46, 1, 3, "│")
end

function ConfigPage.hide()
  ConfigPage.autoIrisCheckBox:hide()
  ConfigPage.changeIDCButton:hide()
  ConfigPage.changePortButton:hide()
  
  ConfigPage.adminQuitCheckBox:hide()
  ConfigPage.adminAddEntryCheckBox:hide()
  ConfigPage.adminEditEntryCheckBox:hide()
  ConfigPage.adminHistoryCheckBox:hide()
  ConfigPage.adminToggleIrisCheckBox:hide()
  
  ConfigPage.hideLocalAddrCheckBox:hide()
end

local function infoExtensionSwitch(mode)
  if DebugMode then
    gpu.set(47, 44, "╡This Stargate's Addresses╞═╡Settings╞═╡Debug╞")
  else
    gpu.set(47, 44, "╡This Stargate's Addresses╞═╡Settings╞════════")
  end
  gpu.fill(47, 45, 113, 4, " ")
  ChildThread.debugWindowThread:suspend()
  ConfigPage.hide()
  if mode == "ADDRESS" then
    gpu.setBackground(0x878787)
    gpu.set(48, 44, "This Stargate's Addresses")
    gpu.setBackground(0x000000)
    displayLocalAddress()
    infoExtensionMode = "ADDRESS"
  elseif mode == "CONFIG" then
    gpu.setBackground(0x878787)
    gpu.set(76, 44, "Settings")
    gpu.setBackground(0x000000)
    infoExtensionMode = "CONFIG"
    ConfigPage.show()
  elseif mode == "DEBUG" then
    gpu.setBackground(0x878787)
    gpu.set(87, 44, "Debug")
    gpu.setBackground(0x000000)
    infoExtensionMode = "DEBUG"
    ChildThread.debugWindowThread:resume()
  end
end

local addressButton = Button.new(47, 43, 0, 0, "This Stargate's Addresses", function() infoExtensionSwitch("ADDRESS") end, false)
local configButton = Button.new(75, 43, 0, 0, "Settings", function() 
  if isAuthorized(User) then
    infoExtensionSwitch("CONFIG")
  end
end, false)
local debugButton = Button.new(86, 43, 0, 0, "Debug", function() infoExtensionSwitch("DEBUG") end, false)

local function toggleDebugMode()
    if not DebugMode then
      alert("DEBUG MODE ACTIVATED", 1)
      DebugMode = true
      debugButton:display()
      infoExtensionSwitch("DEBUG")
      ChildThread.debugWindowThread:resume()
    elseif DebugMode then
      debugButton:hide()
      gpu.set(86, 44, "═══════")
      alert("DEBUG MODE DEACTIVATED", 1)
      DebugMode = false
      ChildThread.debugWindowThread:suspend()
      if infoExtensionMode == "DEBUG" then infoExtensionSwitch("ADDRESS") end
      gpu.fill(150, 43, 10, 1, " ")
    end 
end

local function displayInfoCenter()
  gpu.setBackground(0x000000)
  gpu.fill(1, term.window.height-6, term.window.width, 1, "═")
  gpu.fill(1, term.window.height-5, 1, 4, "║")
  gpu.fill(46, term.window.height-5, 1, 4, "║")
  gpu.fill(term.window.width, term.window.height-5, 1, 4, "║")
  gpu.fill(1, term.window.height-1, term.window.width, 1, "═")
  gpu.set(1, term.window.height-6, "╔╡System Status╞")
  gpu.set(46, term.window.height-6, "╦")
  gpu.set(47, term.window.height-6, "╡This Stargate's Addresses╞")
  gpu.set(term.window.width, term.window.height-6, "╗")
  gpu.set(1, term.window.height-1, "╚")
  gpu.set(46, term.window.height-1, "╩")
  gpu.set(term.window.width, term.window.height-1, "╝")
  addressButton:display()
  configButton:display()
  infoExtensionSwitch("ADDRESS")
end

ChildThread.statusThread = thread.create(function()
  HadNoError, ErrorMessage = xpcall(function()
    while HadNoError do
      displaySystemStatus()
      os.sleep(0.05)
    end
  end, debug.traceback)
end)

ChildThread.debugWindowThread = thread.create(function() -- For Debug
  HadNoError, ErrorMessage = xpcall(function()
    while HadNoError do
      local used = RootDrive.spaceUsed()
      local total = RootDrive.spaceTotal()
      local dialedAddress = nil
      pcall(function() dialedAddress = sg.dialedAddress end)
      if DebugMode then
        gpu.fill(48, 45, 110, 4, " ")
        gpu.set(48, 45, "DHD_AdrEntryMode: "..tostring(DHD_AdrEntryMode))
        gpu.set(48, 46, "DialingInterlocked: "..tostring(DialingInterlocked))
        gpu.set(48, 47, "ComputerDialingInterlocked: "..tostring(ComputerDialingInterlocked))
        gpu.set(84, 46, "dialerAdrEntryMode: "..tostring(dialerAdrEntryMode))
        gpu.set(84, 45, "glyphListWindow.locked: "..tostring(glyphListWindow.locked))
        gpu.set(48, 48, tostring(dialedAddress))
        gpu.set(84, 47, "Gate Status: "..tostring(GateStatusString).." | "..tostring(GateStatusBool))
        -- gpu.set(120, 45, "Drive Usage: "..used.."/"..total.." "..math.floor((used/total)*100).."%")
        -- gpu.set(120, 45, "Index: "..tostring(GateEntriesWindow.selectedIndex))
        gpu.set(120, 45, "UNGateResetting: "..tostring(UNGateResetting))
        -- gpu.set(120, 46, "manualAdrEntryMode: "..tostring(manualAdrEntryMode))
        -- gpu.set(120, 46, "editGateEntryMode: "..tostring(editGateEntryMode))
        -- gpu.set(120, 47, "DatabaseWriteTimer ID: "..tostring(DatabaseWriteTimer))
        -- gpu.set(120, 46, "IrisState: "..tostring(sg.getIrisState()))
        -- gpu.set(120, 47, "IrisType: "..tostring(IrisType))
        gpu.set(120, 46, "AdminOnlyQuit: "..tostring(AdminOnlySettings["Quit"]))
        gpu.set(120, 47, "MainLoop: "..tostring(MainLoop))
      end
      os.sleep(0.1)
    end
  end, debug.traceback)
end)


-- End of Info Center --------------------------------------------------------------

-- Gate Entries Window -------------------------------------------------------------
GateEntriesWindow = {}
function GateEntriesWindow.set()
  local self = GateEntriesWindow
  self.xPos = 2
  self.yPos = 3
  self.width = 37
  self.height = 37
  gpu.fill(1, 2, 40, 39, " ")
  self.entries = {}
  self.range = {}
  self.range.bot = 1
  self.range.height = 37
  self.range.top = self.range.height
  self.range.botH = 1
  self.range.topH = self.range.height
  self.scrollingTimer = nil
  self.locked = false
  if GateType == "MW" then self.localAddress = localMWAddress
  elseif GateType == "UN" then self.localAddress = localUNAddress
  elseif GateType == "PG" then self.localAddress = localPGAddress
  end
  self.mode = "database"
  gpu.set(1, 2,  "╔╡Gate Entries╞══════════════╡History╞╗")
  gpu.set(1, 40, "╚═════════════════════════════════════╝")
  gpu.fill(1, 3, 1, 37, "║")
  gpu.fill(39, 3, 1, 37, "║")
  self.scrollUpButton = Button.new(3, 39, 0, 0, "↑PgUp↑", function()
    GateEntriesWindow.increment(-1)
  end, false)
  self.scrollDnButton = Button.new(30, 39, 0, 0, "↓PgDn↓", function()
    GateEntriesWindow.increment(1)
  end, false)
  self.clearHistoryButton = Button.new(13, 39, 0, 0, "Clear History", function()
    historyEntries = {}
    writeToDatabase()
    -- GateEntriesWindow.clearHistoryButton:hide()
  end, false)
  self.update()
end

function GateEntriesWindow.increment(inc)
  local self = GateEntriesWindow
  if self.scrollingTimer == nil then
    self.scrollingTimer = event.timer(0.05, function() self.scrollingTimer = nil end)
    if self.mode == "database" then
      if (self.range.top + inc) > #gateEntries or (self.range.bot + inc) < 1 then
        return
      else
        self.range.bot = self.range.bot + inc
        self.range.top = self.range.top + inc
        self.display()
      end
    elseif self.mode == "history" then
      if (self.range.topH + inc) > #historyEntries or (self.range.botH + inc) < 1 then
        return
      else
        self.range.botH = self.range.botH + inc
        self.range.topH = self.range.topH + inc
        self.display()
      end
    end
  end
end

function GateEntriesWindow.update()
  local self = GateEntriesWindow
  local strBuf = ""
  local dialable = true
  self.entryStrings = {}
  self.canDial = {}
  gpu.setBackground(0x878787)
  if self.mode == "database" then
    gpu.set(3, 2,  "Gate Entries")
    gpu.setBackground(0x000000)
    gpu.set(31, 2,  "History")
    self.loadedEntries = gateEntries
    self.clearHistoryButton:hide()
    gpu.set(13, 40, "═══════════════")
  elseif self.mode == "history" then
    gpu.set(31, 2,  "History")
    gpu.setBackground(0x000000)
    gpu.set(3, 2,  "Gate Entries")
    self.loadedEntries = historyEntries
    if #historyEntries > 0 then
      self.clearHistoryButton:display()
      gpu.set(13, 40, "╡░░░░░░░░░░░░░╞")
      self.clearHistoryButton:display()
    else
      self.clearHistoryButton:hide()
      gpu.set(13, 40, "═══════════════")
    end
  end
  for i,v in ipairs(self.loadedEntries) do
    strBuf = v.name
    if self.mode == "database" then
      if entriesDuplicateCheck(self.localAddress, {v}, GateType, 1) then
        strBuf = strBuf.." [This Stargate]"
        dialable = false
      elseif v.gateAddress[GateType] ~= nil and #v.gateAddress[GateType] ~= 0 then
        strBuf = strBuf.." ("..(#v.gateAddress[GateType]+1).." Glyphs)"
        dialable = true
      else
        strBuf = strBuf.." [Empty "..GateType.." Address]"
        dialable = false
      end
    end
    if self.mode == "database" then
      while unicode.len(strBuf) < self.width-8 do
        strBuf = strBuf.." "
      end
    end
    if unicode.len(strBuf) > self.width-6 then strBuf = unicode.wtrunc(strBuf, self.width-7) end -- Truncate String to not go past border
    if self.mode == "history" and v.t ~= nil then
      if v.gateAddress[GateType] ~= nil and #v.gateAddress[GateType] > 0 then
        dialable = true
      else
        dialable = false
      end
      while unicode.len(strBuf) < 23 do
        strBuf = strBuf.." "
      end
      strBuf = strBuf.." "..os.date("%d/%m %H:%M", v.t)
    end
    table.insert(self.entryStrings, strBuf)
    table.insert(self.canDial, dialable)
  end
  if #self.entryStrings > self.range.height then
    gpu.set(3, 40, "╡░░░░░░╞")
    gpu.set(30, 40, "╡░░░░░░╞")
    self.scrollUpButton:display()
    self.scrollDnButton:display()
  else
    self.scrollUpButton:hide()
    self.scrollDnButton:hide()
    gpu.set(3, 40, "════════")
    gpu.set(30, 40, "════════")
  end
  self.display()
end

function GateEntriesWindow.display()
  local self = GateEntriesWindow
  if #gateEntries == 0 then alert("WARNING: NO ADDRESSES IN DATABASE!", 2) end
  gpu.fill(2, 3, 37, 37, " ")
  self.currentIndices = {}
  local displayCount = 0
  local top
  local bot
  if self.mode == "database" then
    top = self.range.top
    bot = self.range.bot
  elseif self.mode == "history" then
    top = self.range.topH
    bot = self.range.botH
  end
  for i,v in ipairs(self.entryStrings) do
    if i >= bot and i <= top then
      displayCount = displayCount + 1
      self.currentIndices[displayCount] = i
      -- gpu.set(3, 2+displayCount, tostring(i)) -- Display Number
      if i == self.selectedIndex then gpu.setBackground(0x878787) end
      -- gpu.set(7, 2+displayCount, v) -- Old Postion
      if self.canDial[i] == false then gpu.setForeground(0xB4B4B4) end
      gpu.set(3, 2+displayCount, v)
      gpu.setBackground(0x000000)
      if self.mode == "database" then
        if gateEntries[i].fave ~= nil and gateEntries[i].fave == true then
          gpu.setForeground(0xFFFF00)
        else
          gpu.setForeground(0xB4B4B4)
        end
        gpu.set(37, 2+displayCount, "*")
        if i == 1 or gateEntries[i].fave ~= gateEntries[i-1].fave then
          gpu.setForeground(0x0F0F0F)
        else
          gpu.setForeground(0xFFFFFF)
        end
        gpu.set(33, 2+displayCount, "⇧ ") -- Move Up Arrow
        if i == #self.entryStrings or gateEntries[i].fave ~= gateEntries[i+1].fave then
          gpu.setForeground(0x0F0F0F)
        else
          gpu.setForeground(0xFFFFFF)
        end
        gpu.set(35, 2+displayCount, "⇩ ") -- Move Down Arrow
      end
      gpu.setForeground(0xFFFFFF)
    end
  end
  if bot <= 1 then
    self.scrollUpButton:disable(true)
  else
    self.scrollUpButton:disable(false)
  end
  if top >= #self.entryStrings then
    self.scrollDnButton:disable(true)
  else
    self.scrollDnButton:disable(false)
  end

  -- gpu.fill(1, 42, 23, 1, "░") -- For Debug
  -- gpu.set(1, 42, tostring(gateEntries[self.selectedIndex])) -- For Debug
end

function GateEntriesWindow.touch(x, y)
  local self = GateEntriesWindow
  if x >= self.xPos and x <= 38 and y >= self.yPos and y <= 40 then
    if not ComputerDialingInterlocked and not addAddressMode and not editGateEntryMode then
      self.selectedIndex = self.currentIndices[y - 2]
      if self.selectedIndex == nil then self.selectedIndex = 0 end
      if (x == 33 or x== 35 or x == 37) and self.mode == "database" then
        self.changePosition(x, y)
      end
      self.display()
      updateButtons()
      if self.mode == "database" then
        glyphListWindow.insertAddress(gateEntries[GateEntriesWindow.selectedIndex].gateAddress[GateType])
      else
        glyphListWindow.insertAddress(historyEntries[GateEntriesWindow.selectedIndex].gateAddress[GateType])
      end
    end
  elseif ((x >= 3 and x <= 13) or (x >= 31 and x <= 37)) and y == 2 then
    if x >= 3 and x <= 13 then
      self.mode = "database"
    elseif x >= 31 and x <= 37 and isAuthorized(User, AdminOnlySettings.History) then
      self.mode = "history"
    end
    self.selectedIndex = 0
    updateButtons()
    self.update()
  end
end

function GateEntriesWindow.changePosition(x, y)
  local self = GateEntriesWindow
  local wasInserted = false
  if x == 33 then
    if self.selectedIndex == 1 or gateEntries[self.selectedIndex].fave ~= gateEntries[self.selectedIndex-1].fave then
      return
    else
      -- alert("Going Up", 1) -- For Debug
      local entryBuf = table.remove(gateEntries, self.selectedIndex)
      table.insert(gateEntries, self.selectedIndex-1, entryBuf)
      self.selectedIndex = self.selectedIndex-1
      wasInserted = true
    end
  elseif x == 35 then
    if self.selectedIndex == #self.entryStrings or gateEntries[self.selectedIndex].fave ~= gateEntries[self.selectedIndex+1].fave then
      return
    else
      -- alert("Going Down", 1) -- For Debug
      gpu.set(x, y, "⇩") -- Move Down Arrow
      local entryBuf = table.remove(gateEntries, self.selectedIndex)
      table.insert(gateEntries, self.selectedIndex+1, entryBuf)
      self.selectedIndex = self.selectedIndex+1
      wasInserted = true
    end  
  elseif x == 37 then
    local entryBuf = table.remove(gateEntries, self.selectedIndex)
    if entryBuf.fave == nil or entryBuf.fave == false then
      entryBuf.fave = true
    else
      entryBuf.fave = false
    end
    for i,v in ipairs(gateEntries) do
      if v.fave == nil or v.fave == false then
        table.insert(gateEntries, i, entryBuf)
        self.selectedIndex = i
        wasInserted = true
        break
      end
    end
    if not wasInserted then
      table.insert(gateEntries, entryBuf)
      self.selectedIndex = #gateEntries
      wasInserted = true
    end
  end
  if wasInserted then
    self.update()
    writeToDatabase()
  end
end
-- End of Gate Entries Window ------------------------------------------------------

-- Glyph List Window ---------------------------------------------------------------
glyphListWindow = {xPos=term.window.width, yPos=2, width=0, height=0, locked=false}
function glyphListWindow.initialize(glyphType)
  local self = glyphListWindow
  self.glyphType = glyphType
  self.glyphs = nil
  self.selectedGlyphs = {}
  if glyphType == "MW" then
    self.glyphs = GlyphsMW
  elseif glyphType == "UN" then
    self.glyphs = {}
    for i=1,36,1 do
      if i ~= 17 then table.insert(self.glyphs, "Glyph "..i) end
    end
  elseif glyphType == "PG" then
    self.glyphs = GlyphsPG
  end
  gpu.fill(self.xPos-self.width, self.yPos, 2*self.width, term.window.height-8, " ")
  self.width = 1
  self.xPos = term.window.width
  for i,v in ipairs(self.glyphs) do
    if unicode.len(v)+2 > self.width then self.width = unicode.len(v)+2 end
  end
  if self.width < 12 then self.width = 12 end
  if self.xPos+self.width-1 > term.window.width then self.xPos = term.window.width-self.width+1 end
  self.glyphsHeight = #self.glyphs
  self.height = 4+self.glyphsHeight
  buttons.glyphResetButton.xPos = self.xPos-self.width
  gpu.set(self.xPos, self.yPos, "╓")
  gpu.fill(self.xPos+1, self.yPos, self.width-2, 1, "─")
  gpu.set(self.xPos+self.width-1, self.yPos, "╖")
  gpu.set(self.xPos, self.yPos+1, "║")
  gpu.set(self.xPos+self.width-1, self.yPos+1, "║")
  gpu.set(self.xPos, self.yPos+2, "╠")
  gpu.fill(self.xPos+1, self.yPos+2, self.width-2, 1, "═")
  gpu.set(self.xPos+self.width-1, self.yPos+2, "╣")
  gpu.fill(self.xPos, self.yPos+3, 1, self.glyphsHeight, "║")
  gpu.fill(self.xPos+self.width-1, self.yPos+3, 1, self.glyphsHeight, "║")
  gpu.set(self.xPos, self.yPos+3+self.glyphsHeight, "╚")
  gpu.fill(self.xPos+1, self.yPos+3+self.glyphsHeight, self.width-2, 1, "═")
  gpu.set(self.xPos+self.width-1, self.yPos+3+self.glyphsHeight, "╝")
  gpu.set(self.xPos, self.yPos+3, "╢")
  self.display()
end

function glyphListWindow.display()
  local self = glyphListWindow
  local oStr = "Origin"
  local yOffset = self.yPos + 2
  local xOffset = self.xPos-self.width
  local resetButton = buttons.glyphResetButton
  gpu.fill(self.xPos+1, yOffset+1, self.width-2, self.glyphsHeight, " ")
  gpu.fill(xOffset+1, 7, self.width-2, 8, " ")
  for i,v in ipairs(self.selectedGlyphs) do
    if v == -1 then gpu.setBackground(0x878787) end
  end
  gpu.set(self.xPos+(self.width/2-unicode.len(oStr)/2), self.yPos+1, oStr)
  gpu.setBackground(0x000000)
  for i,v in ipairs(self.glyphs) do
    for i2,v2 in ipairs(self.selectedGlyphs) do
      if i == v2 then gpu.setBackground(0x878787) end
    end
    if v == "Orion" or v == "Urion" then v = "Orion" end
    gpu.set(self.xPos+(self.width/2-unicode.len(v)/2), yOffset+i, tostring(v))
    gpu.setBackground(0x000000)
  end
  if #self.selectedGlyphs > 0 then
    if not self.locked then
      resetButton.xPos = xOffset+(self.width/2-resetButton.width/2)
      resetButton:display()
    end
    gpu.setForeground(0xFFFFFF)
  else
    resetButton:hide()
    gpu.setForeground(0x0F0F0F)
  end
  gpu.set(xOffset, yOffset+2, "┌")
  gpu.fill(xOffset+1, yOffset+2, self.width-2, 1, "─")
  gpu.set(xOffset+self.width-1, yOffset+2, "┐")
  gpu.set(xOffset+(self.width/2)-1, yOffset+2, "┴")
  gpu.set(xOffset+(self.width/2)-1, yOffset+1, "┌")
  gpu.fill(xOffset+(self.width/2), yOffset+1, (self.width/2), 1, "─")
  if gateRingDisplay.isActive then
    gpu.fill(xOffset, yOffset+3, 1, 8, "┤")
  else
    gpu.fill(xOffset, 3, self.width, 1, " ")
    gpu.fill(xOffset, yOffset+3, 1, 8, "│")
  end
  gpu.fill(xOffset+self.width-1, yOffset+3, 1, 8, "│")
  gpu.set(xOffset, yOffset+11, "└")
  gpu.fill(xOffset+1, yOffset+11, self.width-2, 1, "─")
  gpu.set(xOffset+self.width-1, yOffset+11, "┘")
  for i,v in ipairs(self.selectedGlyphs) do
    local glyph = self.glyphs[v]
    if v ~= -1 then gpu.set(xOffset+(self.width/2-unicode.len(glyph)/2), yOffset+2+i, glyph) end
  end
  gpu.setForeground(0xFFFFFF)
end

function glyphListWindow.touch(x,y)
  local self = glyphListWindow
  if not ComputerDialingInterlocked and not dialerAdrEntryMode and not self.locked then
    if x > self.xPos and x < self.xPos+self.width-1 and y > self.yPos and y < self.yPos+self.height-1 then
      local selection = y-self.yPos-2
      local newSelection = true
      for i,v in ipairs(self.selectedGlyphs) do
        if selection == v then newSelection = false end
      end
      if newSelection and #self.selectedGlyphs < 9 then
        if selection > 0 and #self.selectedGlyphs < 8 then
          table.insert(self.selectedGlyphs, selection)
        end
        self.display()
        if selection == -1 then
          AddressBuffer = {}
          local glyph = ""
          for i,v in ipairs(self.selectedGlyphs) do
            if v ~= -1 then
              glyph = self.glyphs[v]
              if self.glyphType == "UN" then _,glyph = checkGlyph(glyph, "UN") end
              table.insert(AddressBuffer, glyph)
            end
          end
          if #AddressBuffer >= 6 then
            if addAddressMode then
              manualAdrEntryMode = false
              completeAddressEntry(self.glyphType)
            else
              directDial()
            end
            self.display()
          elseif #AddressBuffer < 6 then
            AddressBuffer = {}
            self.display()
            alert("ADDRESS IS TOO SHORT", 2)
          end
        end
      end
    end
  end
end

function glyphListWindow.insertGlyph(glyph)
  if GateType == "UN" and glyph:sub(1, 5) ~= "Glyph" then
    glyph = string.gsub(glyph, "G", "Glyph ")
  end
  for i2,v2 in ipairs(glyphListWindow.glyphs) do
    if glyph == v2 then table.insert(glyphListWindow.selectedGlyphs, i2) end
  end
  if glyph == "Glyph 17" or glyph == "Point of Origin" or glyph == "Subido" then table.insert(glyphListWindow.selectedGlyphs, -1) end
  glyphListWindow.display()
end

function glyphListWindow.insertAddress(address)
  glyphListWindow.selectedGlyphs = {}
  if #address > 0 then
    for i,glyph in ipairs(address) do
      if GateType == "UN" and glyph:sub(1, 5) ~= "Glyph" then
        glyph = string.gsub(glyph, "G", "Glyph ")
      end
      for i2,v2 in ipairs(glyphListWindow.glyphs) do
        if glyph == v2 then table.insert(glyphListWindow.selectedGlyphs, i2) end
      end
      if glyph == "Glyph 17" or glyph == "Point of Origin" or glyph == "Subido" then table.insert(glyphListWindow.selectedGlyphs, -1) end
    end
  end
  glyphListWindow.display()
end

function glyphListWindow.showAddress()
  if #DialedAddress ~= #glyphListWindow.selectedGlyphs then
    glyphListWindow.selectedGlyphs = {}
    for i,v in ipairs(DialedAddress) do
      glyphListWindow.insertGlyph(v)
    end
  end
end

function glyphListWindow.reset()
  local self = glyphListWindow
  self.selectedGlyphs = {}
  buttons.glyphResetButton:hide()
  self.display()
  if not editGateEntryMode then
    GateEntriesWindow.selectedIndex = 0
  end
  GateEntriesWindow.display()
  updateButtons()
end
-- End of Glyph List Window -------------------------------------------------------------

-- Direct Dialing -----------------------------------------------------------------------
function directDial()
  local glyph = ""
  if not isDirectDialing then isDirectDialing = true end
  local directEntry = {name="Direct Dial", gateAddress={}}
  directEntry.gateAddress[GateType] = AddressBuffer
  if #AddressBuffer < 6 then
    alert("ENTERED ADDRESS TOO SHORT", 2)
  else
    dialAddress(directEntry, 0)
  end
  isDirectDialing = false
end
-- End of Direct Dialing ----------------------------------------------------------------

-- Address Dialing ----------------------------------------------------------------------
dialAddressWindow = {xPos= 42, yPos=5, width= 35, height=2, glyph=""}
function dialAddressWindow.display(adr)
  local self = dialAddressWindow
  gpu.fill(self.xPos, self.yPos, self.width, self.height, " ")
  gpu.set(self.xPos, self.yPos, "Dialing: "..adr.name)
  gpu.set(self.xPos, self.yPos+1, "Engaging "..self.glyph.."... ")
end

function dialAddress(gateEntry, num)
  if gateEntry == nil then
    alert("NO GATE ENTRY SELECTED", 2)
    return
  end
  if sg.getGateStatus() == "open" then
    alert("CAN NOT DIAL DUE TO STARGATE BEING OPEN", 2)
    return
  end
  if sg.getGateStatus() ~= "idle" or sg.dialedAddress ~= "[]" then
    alert("CAN NOT DIAL DUE TO EXISTING GATE ACTIVITY", 2)
    return
  end
  local localAddress = nil
  if GateType == "MW" then localAddress = localMWAddress
  elseif GateType == "UN" then localAddress = localUNAddress
  elseif GateType == "PG" then localAddress = localPGAddress
  end
  if gateEntry.gateAddress[GateType] == nil or #gateEntry.gateAddress[GateType] == 0 then
    alert("CAN NOT DIAL DUE TO NO GATE ADDRESS ENTRY", 2)
    return
  end
  AddressBuffer = {}
  for i,v in ipairs(gateEntry.gateAddress[GateType]) do table.insert(AddressBuffer, v) end
  -- local requirement, msg = sg.getEnergyRequiredToDial(AddressBuffer) -- Broken in Lua 5.3
  local requirement, msg = sg.getEnergyRequiredToDial(table.unpack(AddressBuffer)) -- Temp Workaround
  if type(requirement) == "string" then
    if requirement == "address_malformed" then
      if entriesDuplicateCheck(localAddress, {gateEntry}, GateType, 1) then
        alert("GATE CAN NOT DIAL ITSELF", 2)
      else
        alert("NO GATE FOUND AT PROVIDED ADDRESS", 2)
      end
    end
    return
  elseif type(requirement) == "table" then
    if requirement.canOpen == false then
      alert("NOT ENOUGH POWER TO OPEN ... "..tostring(requirement.open).." RF NEEDED", 2)
      return
    end
  else
    alert(tostring("\""..msg.."\" RETURNED FROM getEnergyRequiredToDial()"), 3)
    return
  end
  -- Smart Dialing --
  if #AddressBuffer > 6 then
    local shorterAdr = {}
    for i=1,6 do table.insert(shorterAdr, AddressBuffer[i]) end
    for i=7,8 do
      requirement, msg = sg.getEnergyRequiredToDial(table.unpack(shorterAdr))
      if type(requirement) == "table" then
        alert("SMART DIALING ACTIVE", 1)
        break
      else
        table.insert(shorterAdr, AddressBuffer[i])
      end
    end
    AddressBuffer = {}
    for i,v in ipairs(shorterAdr) do table.insert(AddressBuffer, v) end
  end
  -- End of Smart Dialing --
  if GateType == "MW" then
    table.insert(AddressBuffer,"Point of Origin")
  elseif GateType == "UN" then
    table.insert(AddressBuffer,"Glyph 17")
  elseif GateType == "PG" then
    table.insert(AddressBuffer,"Subido")
  end 
  if gateEntry.IDC ~= nil then
    OutgoingIDC = gateEntry.IDC
  end
  -- Preparing to Dial --
  clearDisplay()
  HelpButton:disable(true)
  gateRingDisplay.draw()
  glyphListWindow.reset()
  buttons.abortDialingButton:disable(false)
  buttons.abortDialingButton:display()
  ComputerDialingInterlocked = true
  AbortingDialing = false
  glyphListWindow.locked = true
  dialNext(0)
  -- while ComputerDialingInterlocked and MainLoop do
    -- dialAddressWindow.display(gateEntry)
    -- os.sleep()
  -- end
end

function finishDialing()
  if ComputerDialingInterlocked then
    ComputerDialingInterlocked = false
    isDirectDialing = false
    gpu.fill(41, 2, 38, 5, " ")
    mainInterface("noClear")
  end
end

function dialNext(dialed)
  if not AbortingDialing then
    -- dialAddressWindow.display(gateEntry)
    local glyph = AddressBuffer[dialed + 1]
    dialAddressWindow.glyph = glyph
    sg.engageSymbol(glyph)
    glyphListWindow.insertGlyph(glyph)
    if (dialed+1) < 7 then
      gateRingDisplay.traces(dialed+1, 1)
    elseif (dialed+1) == #AddressBuffer then
      gateRingDisplay.traces(7, 1)
      buttons.abortDialingButton:disable(true)
    else
      gateRingDisplay.traces(dialed+2, 1)
    end
    if dialed ~= 0 then os.sleep(0.5) end
    gateRingDisplay.glyphImage(glyph)
  end
end

function abortDialing()
  buttons.abortDialingButton:disable(true)
  AbortingDialing = true
  alert("ABORTING DIALING... PLEASE WAIT", 2)
  while sg.getGateStatus() ~= "idle" do os.sleep() end
  alert("DIALING ABORTED", 2)
  sg.engageGate()
  while sg.getGateStatus() == "failing" do os.sleep() end
  ComputerDialingInterlocked = false
  AbortingDialing = false
  gpu.fill(41, 2, 38, 5, " ")
  mainInterface("noClear")
end
-- End Address Dialing -------------------------------------------------------------

-- Address Entry -------------------------------------------------------------------
function addressEntry(adrType)
  addAddressMode = true;
  adrEntryType = adrType
  AddressBuffer = {}
  clearDisplay()
  gpu.set(42, 6, "Select one of the below options to enter the address.")
  buttons.cancelButton:display()
  buttons.manualEntryButton:display()
  if GateType == "MW" and adrType == "MW" then
    buttons.dhdEntryButton:display()
  elseif GateType == "PG" and adrType == "PG" then
    buttons.dhdEntryButton:display()
  elseif GateType == "UN" and adrType == "UN" then
    buttons.dialerEntryButton:display()
  else
    manualAddressEntry()
  end
end

function addNewGateEntry()
  alert("", -1)
  clearDisplay()
  HelpButton:disable(true)
  glyphListWindow.locked = true
  glyphListWindow.display()
  buttons.cancelButton:display()
  gpu.set(42, 6, "What type of gate address would you like to enter, for you entry?")
  buttons.addressEntry_MW_Button.border = true
  buttons.addressEntry_UN_Button.border = true
  buttons.addressEntry_PG_Button.border = true
  buttons.addressEntry_MW_Button:display(41, 7)
  buttons.addressEntry_UN_Button:display(53, 7)
  buttons.addressEntry_PG_Button:display(64, 7)
end

function completeAddressEntry(adrType)
  clearDisplay()
  buttons.cancelButton:display()
  glyphListWindow.locked = true
  local index = nil
  local addressName = ""
  local givenName = ""
  local givenInput = ""
  local confirmation = true
  local isDuplicate, duplicateNames = entriesDuplicateCheck(AddressBuffer, gateEntries, adrType, 1)
  if editGateEntryMode then index = GateEntriesWindow.selectedIndex end
  if index ~= nil and index > 0 then addressName = gateEntries[index].name end
  for i,v in ipairs(duplicateNames) do
    if v == addressName then table.remove(duplicateNames, i) end
  end
  if #duplicateNames == 0 then isDuplicate = false end
  if isDuplicate then
    alert("",2)
    gpu.set(42, 6, "Possible duplicate address with the following gate entries:")
    term.setCursor(42, 7)
    for i,v in ipairs(duplicateNames) do
      io.write("'"..v.."'")
      if i ~= #duplicateNames then io.write(", ") end
    end
    gpu.set(42, 8, "Would you still like to have the address entered? [y]es/[n]o: ")
    term.setCursor(104, 8)
    local successful = false
    while not successful and not WasCanceled do
      givenInput, successful = userInput(104, 8, 1, true)
    end
    givenInput = unicode.lower(givenInput)
    if givenInput == "n" then
      alert("ADDRESS ENTRY CANCELED", 1)
      confirmation = false
    end
  end
  if confirmation then
    if index ~= nil and index > 0 then
      gateEntries[index].gateAddress[adrType] = {}
      for i,v in ipairs(AddressBuffer) do table.insert(gateEntries[index].gateAddress[adrType], v) end
      writeToDatabase()
      alert("ADDRESS HAS BEEN CHANGED", 1)
    else
      clearDisplay()
      buttons.cancelButton:display()
      gpu.set(42, 6, "Please enter a name for the address: ")
      local successful = false
      while not successful and not WasCanceled do
        givenInput, successful = userInput(79, 6, 21, true)
      end
      if givenInput == "" then
        addressName = "Unknown"
      else
        addressName = givenInput
      end
      table.insert(gateEntries, {name=addressName, gateAddress={[adrType]=AddressBuffer}})
      writeToDatabase()
      alert("NEW ADDRESS HAS BEEN ADDED", 1)
      manualAdrEntryMode = false
      mainInterface()
      glyphListWindow.reset()
    end
  end
  glyphListWindow.locked = false
  addAddressMode = false
  manualAdrEntryMode = false
  if editGateEntryMode then
    editGateEntry(index)
  else
    mainInterface()
  end
end

function dhdAddressEntry()
  alert("", -1)
  local allGood = true
  DHD_AdrEntryMode = true
  clearDisplay()
  buttons.cancelButton:display()
  glyphListWindow.reset()
  gpu.set(42, 6, "Use the DHD to dial the glyphs of the address, excluding the 'Point of Origin'.")
  if GateType == "MW" then
    gpu.set(42, 7, "Then hit the 'Big Red Button'")
  elseif GateType == "PG" then
    gpu.set(42, 7, "Then hit the 'Big Blue Button'")
  end
  while DHD_AdrEntryMode do
    os.sleep(0.05)
    if WasCanceled then
      allGood = false
      WasCanceled = false
      DHD_AdrEntryMode = false
    end
  end
  if allGood then
    AddressBuffer = {}
    local glyph = ""
    for i,v in ipairs(glyphListWindow.selectedGlyphs) do
      if v ~= -1 then
        glyph = glyphListWindow.glyphs[v]
        if GateType == "UN" then _,glyph = checkGlyph(glyph, "UN") end
        table.insert(AddressBuffer, glyph)
      end
    end
    if #AddressBuffer < 6 then
      alert("ADDRESS WAS TOO SHORT", 2)
    else
      completeAddressEntry(GateType)
      addAddressMode = false
    end
  end
  DHD_AdrEntryMode = false
end

function dialerAddressEntry()
  local allGood = true
  local dialing = false
  clearDisplay()
  glyphListWindow.reset()
  buttons.cancelButton:display()
  dialerAdrEntryMode = true
  gpu.fill(41, 6, 91, 10, " ")
  gpu.set(42, 6, "Dial the gate using your Universe Dialer. The address will be captured once the gate opens.")
  gpu.setForeground(0xFFFF00)
  gpu.set(42, 7, "Warning this process will use power since the gate will open.")
  gpu.set(42, 8, "The gate will close automatically after address capture.")
  gpu.setForeground(0xFFFFFF)
  gpu.set(42, 9, "Please begin dialing or push 'Cancel'")
  -- while dialerAdrEntryMode do os.sleep(0.1) end
  while dialerAdrEntryMode do
    os.sleep(0.05)
    if WasCanceled then
      allGood = false
      WasCanceled = false
      dialerAdrEntryMode = false
    end
    if not dialing and sg.getGateStatus() == "dialing" then dialing = true end
    if dialing then
      alert("PLEASE WAIT", 0)
      if sg.getGateStatus() == "idle" then
        alert("DIALING WAS ABORTED", 2)
        allGood = false
        dialerAdrEntryMode = false
      elseif sg.getGateStatus() == "open" then -- (Backup check of Opening Event)
        dialerAdrEntryMode = false
      end
    end
  end
  if allGood then
    AddressBuffer = {}
    for i,v in ipairs(glyphListWindow.selectedGlyphs) do
      if v ~= -1 then
        glyph = glyphListWindow.glyphs[v]
        table.insert(AddressBuffer, glyph)
      end
    end
    alert("ADDRESS WAS CAPTURED", 1)
    completeAddressEntry("UN")
    addAddressMode = false
  end
  dialerAdrEntryMode = false
end

function manualAddressEntry()
  glyphListWindow.locked = false
  if adrEntryType ~= nil and adrEntryType ~= "" then
    clearDisplay()
    buttons.cancelButton:display()
    manualAdrEntryMode = true
    if glyphListWindow.glyphType ~= adrEntryType then
      glyphListWindow.initialize(adrEntryType)
    else
      glyphListWindow.display()
    end
    gpu.set(42, 6, "Enter the address using the glyphs to the right. Then hit 'Origin' to complete.")
    while manualAdrEntryMode do os.sleep() end
  end
end
-- End of Address Entry ------------------------------------------------------------

-- Edit Gate Entry -----------------------------------------------------------------
local function editGateEntry(index)
  local gateEntry = gateEntries[index]
  if gateEntry == nil then
    alert("SELECT A GATE ENTRY TO EDIT", 2)
    mainInterface()
    return
  end
  clearDisplay()
  HelpButton:disable(true)
  buttons.cancelButton:display()
  buttons.renameButton:display()
  buttons.changeEntryIDCButton:display()
  buttons.deleteButton:display()
  glyphListWindow.locked = true
  glyphListWindow.display()
  editGateEntryMode = true
  if gateEntry.gateAddress.MW == nil then gateEntry.gateAddress["MW"] = {} end
  if gateEntry.gateAddress.UN == nil then gateEntry.gateAddress["UN"] = {} end
  if gateEntry.gateAddress.PG == nil then gateEntry.gateAddress["PG"] = {} end
  gpu.set(42, 6, "Name:")
  gpu.set(73, 6, "IDC:")
  gpu.setBackground(0x878787)
  gpu.fill(48, 6, 21, 1, " ")
  gpu.fill(78, 6, 9, 1, " ")
  gpu.set(48, 6, gateEntry.name)
  if gateEntry.IDC ~= nil then gpu.set(78, 6, tostring(gateEntry.IDC)) end
  gpu.setBackground(0x000000)
  gpu.set(41, 7, "┌────────────────┐  ┌────────────────┐  ┌────────────────┐")
  gpu.set(41, 8, "│   ░░░░░░░░░    │  │    ░░░░░░░░    │  │    ░░░░░░░     │")
  gpu.set(41, 9, "├────────────────┤  ├────────────────┤  ├────────────────┤")
  buttons.addressEntry_MW_Button.border = false
  buttons.addressEntry_UN_Button.border = false
  buttons.addressEntry_PG_Button.border = false
  buttons.addressEntry_MW_Button:display(44, 7)
  buttons.addressEntry_UN_Button:display(65, 7)
  buttons.addressEntry_PG_Button:display(85, 7)
  gpu.fill(41, 10, 1, 8, "│")
  gpu.fill(58, 10, 1, 8, "│")
  gpu.fill(61, 10, 1, 8, "│")
  gpu.fill(78, 10, 1, 8, "│")
  gpu.fill(81, 10, 1, 8, "│")
  gpu.fill(98, 10, 1, 8, "│")
  gpu.set(41, 18, "└────────────────┘  └────────────────┘  └────────────────┘")
  -- gpu.set(49, 19, "To change an address click on its name.")
  gpu.set(42, 19, "To change the entry Name or IDC, directly click on their")
  gpu.set(42, 20, "text field. To change an address click on its name.")
  for i,v in ipairs(gateEntry.gateAddress.MW) do
    gpu.set(41+(9-math.floor(unicode.len(v)/2)), 9+i, v)
  end
  for i,v in ipairs(gateEntry.gateAddress.UN) do
    gpu.set(61+(9-math.ceil(unicode.len(v)/2)), 9+i, v)
  end
  for i,v in ipairs(gateEntry.gateAddress.PG) do
    gpu.set(81+(8-math.floor(unicode.len(v)/2)), 9+i, v)
  end
  if #gateEntry.gateAddress.MW == 0 then gpu.fill(42, 10, 16, 8, "░") end
  if #gateEntry.gateAddress.UN == 0 then gpu.fill(62, 10, 16, 8, "░") end
  if #gateEntry.gateAddress.PG == 0 then gpu.fill(82, 10, 16, 8, "░") end
end

local function renameGateEntry(index)
  buttons.deleteButton:disable(true)
  local oldName = gateEntries[index].name
  local newName, successful = userInput(48, 6, 21, true)
  if successful then
    if newName ~= "" then
      gateEntries[index].name = newName
      alert("\""..oldName.."\" HAS BEEN RENAMED TO \""..gateEntries[index].name.."\"", 1)
      writeToDatabase()
    end
  end
  buttons.deleteButton:disable(false)
  if editGateEntryMode then
    gpu.setBackground(0x878787)
    gpu.fill(48, 6, 21, 1, " ")
    gpu.set(48, 6, gateEntries[index].name)
    gpu.setBackground(0x000000)
  end
end

local function changeEntryIDC(index)
  buttons.deleteButton:disable(true)
  local newIDC, successful = userInput(78, 6, 9, true)
  if successful then
    if newIDC == "" then
      alert("IDC Was Cleared", 2)
      gateEntries[index].IDC = nil
      writeToDatabase()
    else
      newIDC = tonumber(newIDC)
      if type(newIDC) == "number" and newIDC >= 0 and newIDC < 1e9 and math.floor(newIDC) == newIDC then
        alert("IDC Has Been Changed", 1)
        gateEntries[index].IDC = newIDC
        writeToDatabase()
      else
        alert("Invalid IDC", 2)
      end
    end
  end
  buttons.deleteButton:disable(false)
  if editGateEntryMode then
    gpu.setBackground(0x878787)
    gpu.fill(78, 6, 9, 1, " ")
    if gateEntries[index].IDC ~= nil then gpu.set(78, 6, tostring(gateEntries[index].IDC)) end
    gpu.setBackground(0x000000)
  end
end

local function deleteGateEntry(value)
  buttons.renameButton:disable(true)
  if value == 0 then
    gpu.set(44, 23, "┬─────┬")
    gpu.set(44, 24, "│     │")
    gpu.set(44, 25, "├─────┤")
    gpu.set(44, 26, "│     │")
    gpu.set(44, 27, "└─────┘")
    buttons.deleteYesButton:display()
    buttons.deleteNoButton:display()
  elseif value == 1 then
    local index = GateEntriesWindow.selectedIndex
    alert("GATE ENTRY '"..gateEntries[index].name.."' REMOVED", 1)
    table.remove(gateEntries, index)
    writeToDatabase()
    glyphListWindow.locked = false
    editGateEntryMode = false
    buttons.renameButton:disable(false)
    mainInterface()
  elseif value == -1 then
    gpu.fill(44, 23, 7, 5, " ")
    gpu.set(44, 23, "───────")
    buttons.deleteYesButton:hide()
    buttons.deleteNoButton:hide()
    -- alert("DELETE CANCELED", 1) -- For Debug
    buttons.renameButton:disable(false)
  end
end
-- End Edit Gate Entry -------------------------------------------------------------

-- Gate Ring Display ---------------------------------------------------------------
gateRingDisplay = {}
function gateRingDisplay.initialize()
  local self = gateRingDisplay
  self.isActive = false
  if sg.getGateStatus() == "open" then
    self.eventHorizonState = true
  else
    self.eventHorizonState = false
  end
  self.chevronStates = {}
  self.traceStates = {}
  self.engagedChevronCount = 0
  if GateStatusBool == false then
    for i=1,9 do table.insert(self.chevronStates, true) end
  else
    for i=1,9 do table.insert(self.chevronStates, false) end
  end
  for i=1,9 do table.insert(self.traceStates, 0) end
  dofile("gateRing.ff") -- Loads the gate ring graphics
  if GateType == "MW" then
    dofile("glyphsMW.ff") -- Loads MW Glyph Images
  elseif GateType == "UN" then
    dofile("glyphsUN.ff") -- Loads UN Glyph Images
  elseif GateType == "PG" then
    dofile("glyphsPG.ff") -- Loads UN Glyph Images
  end
  self.ringTbl, self.topTbl, self.midTbl, self.botTbl = {},{},{},{}
  self.chevTbl = {"⢤⣤⣤⣤⣤⡤","⠀⢻⣿⣿⡟","⠀⠀⢻⡟"}
  self.dotTbl = {"⢀⣴⣶⣦⡀","⣿⣿⣿⣿⣿","⠈⠻⠿⠟⠁"}
  self.dot2Tbl = {"⣠⣾⣿⣷⣄", "⢿⣿⣿⣿⡿", "⠙⠛⠋"}
  if GateType == "MW" then
    self.offColor = 0x662400
    -- self.offColor = 0x662400
    self.onColor = 0x994900
    self.ringColor = 0x5A5A5A
    -- self.ringColor = 0x696969
    -- self.ringColor = 0x4B4B4B
    self.horizonColor = 0x006DFF
  elseif GateType == "UN" then
    self.offColor = 0xA5A5A5
    self.onColor = 0xFFFFFF
    self.ringColor = 0x1E1E1E
    self.horizonColor = 0x787878
  elseif GateType == "PG" then
    -- self.offColor = 0x4B4B4B
    self.offColor = 0x000040
    self.onColor = 0x0092FF
    -- self.ringColor = 0x5A5A5A
    self.ringColor = 0x4B4B4B
    -- self.ringColor = 0x696969
    self.horizonColor = 0x006DFF
  else
    self.offColor = 0xA5A5A5
    self.onColor = 0xFFFFFF
    self.ringColor = 0x1E1E1E
    self.horizonColor = 0x787878
  end
  for line in GateRing.wholeRing:gmatch("[^\r\n]+") do table.insert(self.ringTbl, line) end
  for line in GateRing.horizonTop:gmatch("[^\r\n]+") do table.insert(self.topTbl, line) end
  for line in GateRing.horizonMid:gmatch("[^\r\n]+") do table.insert(self.midTbl, line) end
  for line in GateRing.horizonBot:gmatch("[^\r\n]+") do table.insert(self.botTbl, line) end
end

function gateRingDisplay.draw()
  local self = gateRingDisplay
  self.isActive = true
  gpu.setForeground(self.ringColor)
  for i,v in ipairs(self.ringTbl) do
    gpu.set(50, 7+i, v)
  end
  self.eventHorizon()
  self.traces()
end

function gateRingDisplay.glyphImage(glyphName, isEngaged)
  local self = gateRingDisplay
  local xPos = 0
  local yPos = 0
  if GateType == "MW" or GateType == "PG" then
    xPos = 64
    yPos = 15
    gpu.fill(xPos, yPos, 32, 16, " ")
  elseif GateType == "UN" then
    xPos = 77
    yPos = 14
    gpu.fill(xPos, yPos, 6, 18, " ")
  end
  if glyphName == nil and isEngaged == nil then return end
  if IncomingWormhole then return end
  if isEngaged then
    gpu.setForeground(self.onColor)
  else
    gpu.setForeground(self.offColor)
  end
  if glyphName ~= nil or glyphName ~= "" then
    local glyphImage = GlyphImages[glyphName]
    for line in glyphImage:gmatch("[^\r\n]+") do
      gpu.set(xPos, yPos, line)
      yPos = yPos + 1
    end
  end
  gpu.setForeground(0xFFFFFF)
end

function gateRingDisplay.traces(num, state)
  local self = gateRingDisplay
  if not self.isActive then return end
  if num == nil or num == -1 then
    for i,v in ipairs(self.traceStates) do self.traces(i, v) end
    return
  end
  local glw = glyphListWindow
  local glyphBoxX = 161 - (2 * glw.width)
  local traceEndOffset = 0
  if glw.width ~= nil then
    traceEndOffset = 2*glw.width
  else
    traceEndOffset = 35
  end
  if state == nil or state == 0 then
    gpu.setForeground(0x0F0F0F)
  elseif state == 1 then
    gpu.setForeground(self.offColor)
  elseif state == 2 then
    gpu.setForeground(self.onColor)
  end
  self.traceStates[num] = state
  
  if num == 1 then
    gpu.set(93, 8, "┌─┴─┐") -- 1
    gpu.set(95, 7, "┌") -- 1
    gpu.fill(96, 7, 65-traceEndOffset, 1, "─") -- 1
  elseif num == 2 then
    gpu.set(110, 18, "┐├┘", true) -- 2
    gpu.set(111, 19, "─┘") -- 2
    gpu.fill(112, 9, 1, 10, "│") -- 2
    gpu.set(112, 8, "┌") -- 2
    gpu.fill(113, 8, 48-traceEndOffset, 1, "─") -- 2
  elseif num == 3 then  
    gpu.set(109, 27, "┐├┘", true) -- 3
    gpu.set(110, 28, "────┘") -- 3
    gpu.fill(114, 10, 1, 18, "│") -- 3
    gpu.set(114, 9, "┌") -- 3
    gpu.fill(115, 9, 46-traceEndOffset, 1, "─") -- 3
  elseif num == 4 then  
    gpu.set(50, 27, "┌┤└", true) -- 4
    gpu.set(48, 28, "┌─") -- 4
    gpu.fill(48, 29, 1, 10, "│") -- 4
    gpu.set(48, 39, "└") -- 4
    gpu.fill(49, 39, 20, 1, "─") -- 4
    gpu.fill(70, 39, 20, 1, "─") -- 4
    gpu.fill(91, 39, 25, 1, "─") -- 4
    gpu.set(116, 39, "┘") -- 4
    gpu.fill(116, 11, 1, 28, "│") -- 4
    gpu.set(116, 10, "┌") -- 4
    gpu.fill(117, 10, 44-traceEndOffset, 1, "─") -- 4
  elseif num == 5 then  
    gpu.set(49, 18, "┌┤└", true) -- 5
    gpu.set(46, 19, "┌──") -- 5
    gpu.fill(46, 20, 1, 20, "│") -- 5
    gpu.set(46, 40, "└") -- 5
    gpu.fill(47, 40, 22, 1, "─") -- 5
    gpu.fill(70, 40, 20, 1, "─") -- 5
    gpu.fill(91, 40, 27, 1, "─") -- 5
    gpu.set(118, 40, "┘") -- 5
    gpu.fill(118, 12, 1, 28, "│") -- 5
    gpu.set(118, 11, "┌") -- 5
    gpu.fill(119, 11, 42-traceEndOffset, 1, "─") -- 5
  elseif num == 6 then  
    gpu.set(62, 8, "┌─┴─┐") -- 6
    gpu.set(64, 7, "┐") -- 6
    gpu.fill(45, 7, 19, 1, "─") -- 6
    gpu.set(44, 7, "┌") -- 6
    gpu.fill(44, 8, 1, 33, "│") -- 6
    gpu.set(44, 41, "└") -- 6
    gpu.fill(45, 41, 24, 1, "─") -- 6
    gpu.fill(70, 41, 20, 1, "─") -- 6
    gpu.fill(91, 41, 29, 1, "─") -- 6
    gpu.set(120, 41, "┘") -- 6
    gpu.fill(120, 13, 1, 28, "│") -- 6
    gpu.set(120, 12, "┌") -- 6
    gpu.fill(121, 12, 40-traceEndOffset, 1, "─") -- 6
  elseif num == 7 then  
    gpu.set(76, 7, "⠏⠉⠉⠉⠉⠉⠉⠹") -- 7
    gpu.fill(79, 4, 1, 3, "⢸") -- 7
    gpu.fill(80, 4, 1, 3, "⡇") -- 7
    gpu.set(79, 3, "⢰⡶") -- 7
    gpu.fill(81, 3, 80-glw.width, 1, "⠶") -- 7
  elseif num == 8 then  
    gpu.set(88, 38, "└─┬─┘") -- 8
    gpu.fill(90, 39, 1, 3, "│") -- 8
    gpu.set(90, 42, "└") -- 8
    gpu.fill(91, 42, 31, 1, "─") -- 8
    gpu.set(122, 42, "┘") -- 8
    gpu.fill(122, 14, 1, 28, "│") -- 8
    gpu.set(122, 13, "┌") -- 8
    gpu.fill(123, 13, 38-traceEndOffset, 1, "─") -- 8
  elseif num == 9 then  
    gpu.set(67, 38, "└─┬─┘") -- 9
    gpu.fill(69, 39, 1, 4, "│") -- 9
    gpu.set(69, 43, "└") -- 9
    gpu.fill(70, 43, 54, 1, "─") -- 9
    gpu.set(124, 43, "┘") -- 9
    gpu.fill(124, 15, 1, 28, "│")
    gpu.set(124, 14, "┌") --9
    gpu.fill(125, 14, 36-traceEndOffset, 1, "─") -- 9
  end
  
  gpu.setForeground(0xFFFFFF)
end

function gateRingDisplay.reset()
  local self = gateRingDisplay
  self.engagedChevronCount = 0
  for i,v in ipairs(self.chevronStates) do self.chevronStates[i] = false end
  for i,v in ipairs(self.traceStates) do self.traceStates[i] = 0 end
  if self.isActive then
    for i,v in ipairs(self.chevronStates) do self.setChevron(i, v) end
    for i,v in ipairs(self.traceStates) do self.traces(i, v) end
  end
end

function gateRingDisplay.eventHorizon(isOpen)
  local self = gateRingDisplay
  if isOpen == nil then isOpen = self.eventHorizonState end
  if isOpen then
    self.eventHorizonState = true
  else
    self.eventHorizonState = false
  end
  if self.isActive then
    gpu.setForeground(self.ringColor)
    if isOpen then
      gpu.setBackground(self.horizonColor)
    else
      gpu.setBackground(0x000000)
    end
    for i,v in ipairs(self.topTbl) do
      gpu.set(66, 10+i, v)
    end
    for i,v in ipairs(self.midTbl) do
      gpu.set(57, 13+i, v)
    end
    for i,v in ipairs(self.botTbl) do
      gpu.set(66, 31+i, v)
    end
    for i,v in ipairs(self.chevronStates) do self.setChevron(i, v) end
  end
end

function gateRingDisplay.setChevron(num, isEngaged)
  local self = gateRingDisplay
  local stateColor = nil
  self.chevronStates[num] = isEngaged
  if not self.isActive then return end
  if isEngaged then stateColor = self.onColor
  else stateColor = self.offColor end
  gpu.setBackground(self.ringColor)
  gpu.setForeground(stateColor)
  if num == 1 then
    for i,v in ipairs(self.dotTbl) do -- 1
      gpu.set(93, 10+i, v)
    end
  elseif num == 2 then
    for i,v in ipairs(self.dotTbl) do -- 2
      gpu.set(103, 17+i, v)
    end
  elseif num == 3 then
    for i,v in ipairs(self.dotTbl) do -- 3
      gpu.set(101, 26+i, v)
    end
  elseif num == 4 then
    for i,v in ipairs(self.dotTbl) do -- 4
      gpu.set(54, 26+i, v)
    end
  elseif num == 5 then
    for i,v in ipairs(self.dotTbl) do -- 5
      gpu.set(52, 17+i, v)
    end
  elseif num == 6 then
    for i,v in ipairs(self.dotTbl) do -- 6
      gpu.set(62, 10+i, v)
    end
  elseif num == 7 then
    for i,v in ipairs(self.chevTbl) do -- 7
      gpu.set(77, 7+i, v)
    end
  elseif num == 8 then
    for i,v in ipairs(self.dot2Tbl) do -- 8
      if i ~= 3 then gpu.set(88, 33+i, v)
      else gpu.set(89, 33+i, v) end
    end
  elseif num == 9 then
    for i,v in ipairs(self.dot2Tbl) do -- 9
      if i ~= 3 then gpu.set(67, 33+i, v)
      else gpu.set(68, 33+i, v) end
    end
  end
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
end

function gateRingDisplay.dialedChevrons(count, hideImage)
  -- if IncomingWormhole then return end
  local self = gateRingDisplay
  if count == 0 then engagedChevronCount = 0 end
  if count <= self.engagedChevronCount then return end
  -- computer.beep() -- For debug
  local glyphName = DialedAddress[count]
  if glyphName == "" then 
    if GateType == "MW" then
      glyphName = "Point of Origin"
    elseif GateType == "PG" then
      glyphName = "Subido"
    end
  end
  if not hideImage then self.glyphImage(glyphName, true) end
  if count < 7 then
    self.setChevron(count, true)
    self.traces(count, 2)
  else
    if glyphName == "Point of Origin" or glyphName == "Glyph 17" or glyphName == "Subido" then
      self.setChevron(7, true)
      self.traces(7, 2)
    else
      self.setChevron(count+1, true)
      self.traces(count+1, 2)
    end
  end
  self.engagedChevronCount = self.engagedChevronCount + 1
end

function gateRingDisplay.UNreset()
  while true do
    os.sleep(0.05)
    if sg.getGateStatus() == "dialing" then break end
  end
  local self = gateRingDisplay
  alert("STARGATE IS RESETTING", 1)
  local sequence = {[1]=7,[2]=1,[3]=2,[4]=3,[5]=8,[6]=9,[7]=4,[8]=5,[9]=6}
  local pos = 1
  while sg.getGateStatus() == "dialing" do
    if pos > 9 then pos = 1 end
    self.setChevron(sequence[pos], true)
    os.sleep()
    self.setChevron(sequence[pos], false)
    pos = pos + 1
  end
  self.setChevron(sequence[pos], false)
  alert("STARGATE HAS RESET", 1)
end
-- End of Gate Ring Display --------------------------------------------------------

-- Event Section -------------------------------------------------------------------
local EventListeners = {
  stargate_spin_chevron_engaged = event.listen("stargate_spin_chevron_engaged", function(_, _, caller, num, lock, glyph)
    if ComputerDialingInterlocked then
      if lock then
        alert("CHEVRON "..math.floor(num).." LOCKED", 1)
        if not AbortingDialing then sg.engageGate() end
        os.sleep()
      else
        if (num) < 7 then
        else
        end        
        os.sleep()
        if not AbortingDialing then 
          alert("CHEVRON "..math.floor(num).." ENGAGED", 0)
          dialNext(num)
        end
      end
    else
      os.sleep(0.1)
      glyphListWindow.showAddress()
    end
  end),
  
  stargate_dhd_chevron_engaged = event.listen("stargate_dhd_chevron_engaged", function()
    glyphListWindow.showAddress()
  end),
  
  stargate_incoming_wormhole = event.listen("stargate_incoming_wormhole", function(_, _, caller, dialedAddressSize)
    AddressBuffer = {}
    if IDC ~= nil and IrisSettings.AutoCloseIris == true and sg.getIrisState() == "OPENED" then
      sg.toggleIris()
    end
    if IncomingWormhole == false then
      IncomingWormhole = true
      AbortingDialing = true
      alert("INCOMING WORMHOLE", 2)
      if gateRingDisplay.isActive then
        gateRingDisplay.glyphImage()
        gateRingDisplay.reset()
        for i=1,dialedAddressSize do gateRingDisplay.chevronStates[i] = true end
        for i,v in ipairs(gateRingDisplay.chevronStates) do gateRingDisplay.setChevron(i, v) end
      end
      updateButtons()
      os.sleep(3)
      IncomingWormhole = false
    end
  end),

  stargate_open = event.listen("stargate_open", function(_, _, caller, isInitiating)
    if DialingInterlocked then DialingInterlocked = false end
    finishDialing()
    glyphListWindow.locked = false
    glyphListWindow.display()
    os.sleep(2)
    gateRingDisplay.eventHorizon(true)
    if isInitiating then
      updateHistory()
    end
  end),
  
  stargate_wormhole_stabilized = event.listen("stargate_wormhole_stabilized", function(_, _, caller, isInitiating)
    if dialerAdrEntryMode then
      os.sleep(0.1)
      sg.disengageGate()
      dialerAdrEntryMode = false
    end
    if isInitiating and OutgoingIDC ~= nil then
      event.timer(2, function()
        alert("Sending IDC",1)
        os.sleep(1)
        sg.sendIrisCode(OutgoingIDC)
      end)
    end
  end),

  stargate_close = event.listen("stargate_close", function(_, _, caller, reason)
    if GateType == "UN" and OutgoingWormhole then UNGateResetting = true end
    if not addAddressMode then
      table.remove(glyphListWindow.selectedGlyphs)
      glyphListWindow.locked = false
      glyphListWindow.display()
    end
    gateRingDisplay.reset()
    os.sleep(1.5)
    alert("CONNECTION HAS CLOSED", 1)
    gateRingDisplay.eventHorizon(false)
  end),

  stargate_wormhole_closed_fully = event.listen("stargate_wormhole_closed_fully", function(_, _, caller, isInitiating)
    OutgoingWormhole = false
    if UNGateResetting then
      gateRingDisplay.UNreset()
      UNGateResetting = false
    end
    updateButtons()
    if sg.getIrisState() == "CLOSED" then
      sg.toggleIris()
    end
  end),

  stargate_failed = event.listen("stargate_failed", function(_, _, caller, reason)
    if reason == nil then return end
    if GateType == "UN" then UNGateResetting = true end
    if not AbortingDialing and not DHD_AdrEntryMode then
      if reason == "address_malformed" then
        alert("UNABLE TO ESTABLISH CONNECTION", 3)
      elseif reason == "not_enough_power" then
        alert("NOT ENOUGH POWER TO CONNECT", 3)
      elseif reason == "aborted" then
        alert("ABORTED BY HAND DIALER", 2)
      end
    end
    gateRingDisplay.glyphImage()
    gateRingDisplay.reset()
    if DialingInterlocked then DialingInterlocked = false end
    finishDialing()
    if not dialerAdrEntryMode then
      glyphListWindow.locked = false
      glyphListWindow.display()
    end
    if DHD_AdrEntryMode then DHD_AdrEntryMode = false end
    if GateType == "UN" then
      thread.create(function()
        UNGateResetting = true
        gateRingDisplay.UNreset()
        UNGateResetting = false
      end)
    end
  end),

  modem_message = event.listen("modem_message", function(_, _, sender, port, _, msg)
    if port == ModemIDCPort and tonumber(msg) ~= nil then
      local code = tonumber(msg)
      if IDC == code then
        if sg.getIrisState() == "CLOSED" then
          sg.toggleIris()
          modem.send(sender, ModemIDCPort, "IDC Accepted!")
        else
          if IrisType == "SHIELD" then
            modem.send(sender, ModemIDCPort, "Shield is Off!")
          else
            modem.send(sender, ModemIDCPort, "Iris is Open!")
          end
        end
      elseif IDC ~= code and sg.getIrisState() == "CLOSED" then
        modem.send(sender, ModemIDCPort, "IDC is Incorrect!")
      end
    end
  end),
  
  received_code = event.listen("received_code", function(_, _, _, code)
    if IDC == code then
      if sg.getIrisState() == "CLOSED" then
        sg.toggleIris()
        sg.sendMessageToIncoming("IDC Accepted!")
      else
        if IrisType == "SHIELD" then
          sg.sendMessageToIncoming("Shield is Off!")
        else
          sg.sendMessageToIncoming("Iris is Open!")
        end
      end
    elseif IDC ~= code and sg.getIrisState() == "CLOSED" then
      sg.sendMessageToIncoming("IDC is Incorrect!")
    end
  end),

  code_respond = event.listen("code_respond", function(_, _, caller, msg)
    msg = string.sub(msg, 1, -3)
    alert(msg, 2)
  end),

  key_down = event.listen("key_down", function(_, keyboardAddress, chr, code, playerName)
    User = playerName
    table.insert(keyCombo, code)
    if #keyCombo > 1 and (keyCombo[1] == 29 and keyCombo[2] == 16) and isAuthorized(User, AdminOnlySettings.Quit) then -- Ctrl+Q to Completely Exit
      WasCanceled = true
      MainLoop = false
    end
    if code == 201 then GateEntriesWindow.increment(-1) end -- PgUp
    if code == 209 then GateEntriesWindow.increment(1) end  -- PgDn
  end),

  key_up = event.listen("key_up", function(_, keyboardAddress, chr, code, playerName)
    keyCombo = {}
    if code == 59 and not HelpButton.disabled then -- Toggles the instructions if F1 is pressed then released
      HelpWindow.toggle()
    end
    if code == 88 then toggleDebugMode() end -- F12 to toggle debug
    if code == 62 and not screen.isTouchModeInverted() then
      alert("TOUCH SCREEN MODE ACTIVATED", 1)
      screen.setTouchModeInverted(true)
    elseif code == 62 and screen.isTouchModeInverted() then
      alert("TOUCH SCREEN MODE DEACTIVATED", 1)
      screen.setTouchModeInverted(false)
    end
    User = ""
  end),

  touch = event.listen("touch", function(_, screenAddress, x, y, button, playerName)
    User = playerName
    term.setCursor(0,0)
    if DebugMode then
      gpu.fill(150, 43, 10, 1, " ") -- For Debug
      gpu.set(150, 43, x..", "..y)  -- For Debug
    end
    if button == 0 then
      for i,v in ipairs(ActiveButtons) do
        if v:touch(x,y) then break end
      end
      glyphListWindow.touch(x, y)
      GateEntriesWindow.touch(x, y)
    end
    User = ""
  end),

  scroll = event.listen("scroll", function(_, screenAddress, x, y, direction, playerName)
      GateEntriesWindow.increment(direction*-1)
  end),

  -- component_unavailable = event.listen("component_unavailable", function(_, componentString)
    -- if componentString == "stargate" then
      -- alert(componentString, 3)
      -- error("Stargate Has Been Disconnected")
      -- ErrorMessage = "Stargate Has Been Disconnected"
      -- HadNoError = false
      -- while MainLoop do 
        -- MainLoop = false
      -- end
    -- end
  -- end),

  interruptedEvent = event.listen("interrupted", function()
    if isAuthorized(User, AdminOnlySettings.Quit) then
      wasTerminated = true
      MainLoop = false
    end
  end),
}
-- End of Event Section ------------------------------------------------------------

-- Buttons -------------------------------------------------------------------------
buttons = {
  dialButton = Button.new(41, 2, 0, 3, "  Dial  ", function()
    if GateEntriesWindow.mode == "database" then
      dialAddress(gateEntries[GateEntriesWindow.selectedIndex])
    elseif GateEntriesWindow.mode == "history" then
      dialAddress(historyEntries[GateEntriesWindow.selectedIndex])
    end
  end),
  editButton = Button.new(64, 2, 0, 3, "Edit Entry", function()
      if isAuthorized(User, AdminOnlySettings.EditEntry) then
        editGateEntry(GateEntriesWindow.selectedIndex)
      end
  end),
  renameButton = Button.new(47, 5, 23, 3, "", function()
    renameGateEntry(GateEntriesWindow.selectedIndex)
  end, false),
  changeEntryIDCButton = Button.new(77, 5, 11, 3, "", function()
    changeEntryIDC(GateEntriesWindow.selectedIndex)
  end, false),
  deleteButton = Button.new(41, 21, 0, 3, "Delete Entry", function() --56
    deleteGateEntry(0)
  end),
  deleteYesButton = Button.new(44, 23, 0, 3, " Yes ", function()
    deleteGateEntry(1)
  end, false),
  deleteNoButton = Button.new(44, 25, 0, 3, " No  ", function()
    deleteGateEntry(-1)
  end, false),
  addEntryButton = Button.new(52, 2, 0, 3, "Add Entry", function()
    if isAuthorized(User, AdminOnlySettings.AddEntry) then
      addNewGateEntry()
    end
  end),
  abortDialingButton = Button.new(41, 2, 0, 3, "Abort Dialing", function()
    abortDialing()
  end),
  glyphResetButton = Button.new(term.window.width-36, 16, 0, 0, "Reset", function()
    if GateStatusBool == nil and sg.dialedAddress ~= nil and sg.dialedAddress ~= "[]" then
       DHD_AdrEntryMode = true
       alert("CLEARING ENGAGED CHEVRONS", 2)
       sg.engageGate()
    end
    glyphListWindow.reset()
    for i,v in ipairs(gateRingDisplay.traceStates) do gateRingDisplay.traceStates[i] = 0 end
    if gateRingDisplay.isActive then
      for i,v in ipairs(gateRingDisplay.traceStates) do gateRingDisplay.traces(i, v) end
    end
  end),
  dhdEntryButton = Button.new(53, 7, 0, 0, "DHD", function()
    dhdAddressEntry()
  end),
  dialerEntryButton = Button.new(53, 7, 0, 0, "Dialer", function()
    dialerAddressEntry()
  end),
  manualEntryButton = Button.new(41, 7, 0, 0, " Manual  ", function()
    manualAddressEntry()
  end),
  addressEntry_MW_Button = Button.new(41, 9, 0, 0, "Milky Way", function()
    addressEntry("MW")
  end, false),
  addressEntry_UN_Button = Button.new(41, 10, 0, 0, "Universe", function()
    addressEntry("UN")
  end, false),
  addressEntry_PG_Button = Button.new(41, 11, 0, 0, "Pegasus", function()
    addressEntry("PG")
  end, false),
  cancelButton = Button.new(41, 2, 0, 0, "Cancel", function()
    glyphListWindow.locked = false
    WasCanceled = true
    editGateEntryMode = false
    addAddressMode = false
    manualAdrEntryMode = false
    editGateEntryMode = false
    glyphListWindow.initialize(GateType)
    mainInterface()
  end),
}
QuitButton = Button.new(1, 41, 0, 3, "Quit", function()
  if isAuthorized(User, AdminOnlySettings.Quit) then
    MainLoop = false
  end
end)
HelpButton = Button.new(8, 41, 0, 0, "Help", function()
  HelpWindow.toggle()
end)
CloseGateButton = Button.new(15, 41, 0, 3, "Close Gate", function()
  local s,f = sg.disengageGate()
  if f == "stargate_failure_wrong_end" then
    alert("CAN NOT CLOSE AN INCOMING CONNECTION", 2)
  elseif f == "stargate_failure_not_open" then
    alert("GATE IS NOT OPEN", 1)
  end
end)
IrisToggleButton = Button.new(28, 41, 0, 0, " ", function()
  if isAuthorized(User, AdminOnlySettings.ToggleIris) then
    sg.toggleIris()
  end
end)
-- IDCButton = Button.new(126, 41, 0, 0, "IDC", function()
  -- alert("Sending IDC: "..tostring(OutgoingIDC), 1)
  -- sg.sendIrisCode(OutgoingIDC)
-- end)


function updateButtons()
  if GateEntriesWindow.canDial[GateEntriesWindow.selectedIndex] == true and GateStatusString == "idle" then
    buttons.dialButton:disable(false)
  else
    buttons.dialButton:disable(true)
  end
  if GateEntriesWindow.mode == "database" then
    buttons.editButton:disable(false)
  elseif GateEntriesWindow.mode == "history" then
    buttons.editButton:disable(true)
  end
end
-- End of Buttons ------------------------------------------------------------------

-- Help Window ---------------------------------------------------------------------
HelpWindow = {visible=false}
function HelpWindow.toggle()
  local helpMessage = {
    "DIALING:",
    " To dial out select a Gate Entry from the list to the left, and click the",
    " 'Dial' button. You can also directly enter an address with the glyphs to",
    " the right, then click 'Origin' to begin dialing.",
    " ",
    "ADD ENTRY:",
    " To add a Gate to the 'Gate Entries' list click the 'Add Entry' button and",
    " follow the prompts.",
    " ",
    "EDIT ENTRY:",
    " To edit a Gate Entry, select it from the list and click the 'Edit Entry'",
    " button. On the 'Edit Entry' screen you can rename the entry, delete it, or",
    " change it's gate addresses.",
    " ",
    "KEY BINDS:",
    " F4: Toggles Touch Screen Mode",
    " F12: Toggles Debug Information",
    " Ctrl+Q: Closes the Dialer Program",
    " Ctrl+C: Forces the Dialer to Close",
    " ",
    "Dialer Version: "..Version
  }
  local self = HelpWindow
  self.xPos = 41
  self.yPos = 5
  self.width = 80
  self.height = 2 + #helpMessage
  if self.visible then
    self.visible = false
    mainInterface()
  elseif not self.visible then
    self.visible = true
    gateRingDisplay.isActive = false
    gpu.fill(self.xPos, self.yPos, self.width, self.height, " ")
    gpu.set(self.xPos, self.yPos,               "╔══════════════════════════════════════════════════════════════════════════════╗")
    gpu.set(self.xPos, self.yPos+self.height-1, "╚══════════════════════════════════════════════════════════════════════════════╝")
    gpu.fill(self.xPos, self.yPos+1, 1, self.height-2, "║")
    gpu.fill(self.xPos+self.width-1, self.yPos+1, 1, self.height-2, "║")
    for i,line in ipairs(helpMessage) do
      gpu.set(self.xPos+1, self.yPos+i, line)
    end
  end
end
-- End of Help Window --------------------------------------------------------------

HadNoError, ErrorMessage = xpcall(function()
  localMWAddress = sg.stargateAddress.MILKYWAY
  localUNAddress = sg.stargateAddress.UNIVERSE
  localPGAddress = sg.stargateAddress.PEGASUS
  term.clear()
  initialLoadAddressFile()
  GateEntriesWindow.set()
end, debug.traceback)

-- Creating Threads ----------------------------------------------------------------


ChildThread.gateStatusThread = thread.create(function()
  CloseGateButton:display()
  while HadNoError do
    HadNoError, ErrorMessage = xpcall(function()
      GateStatusString = nil
      GateStatusBool = nil
      pcall(function() GateStatusString, GateStatusBool = sg.getGateStatus() end)
      if GateStatusBool ~= nil and GateStatusBool == true then
        OutgoingWormhole = true
        if CloseGateButton.disabled then
          CloseGateButton:disable(false)
        end
      elseif not CloseGateButton.disabled then
        CloseGateButton:disable(true)
      end
      if GateStatusString == "dialing" and not UNGateResetting and not DialingInterlocked then
        DialingInterlocked = true
        if sg.dialedAddress == "[]" then glyphListWindow.reset() end
      end
      if DialingInterlocked or ComputerDialingInterlocked then
        if not UNGateResetting and not IncomingWormhole then
          DialedAddress = parseAddressString(sg.dialedAddress, GateType)
          gateRingDisplay.dialedChevrons(#DialedAddress)
          if buttons.glyphResetButton.visible then buttons.glyphResetButton:hide() end
          if not glyphListWindow.locked then glyphListWindow.locked = true end
          if GateStatusString == "dialing" and GateType == "UN" then
            glyphListWindow.showAddress()
          end
        end
      end
      if GateStatusString == "idle" and not ComputerDialingInterlocked then
        if DialingInterlocked then DialingInterlocked = false end
        if glyphListWindow.locked then
          glyphListWindow.locked = false
          glyphListWindow.display()
        end
      end
      if GateStatusString == "dialing" and ComputerDialingInterlocked and not AbortingDialing then abortDialing() end
      os.sleep(0.1)
    end, debug.traceback)
    pcall(function()
      IrisType = sg.getIrisType()
    end)
    if IrisType == nil or IrisType == "NULL" then
      IrisToggleButton:hide()
    else
      local labelString = nil
      if IrisType == "SHIELD" then
        labelString = "Toggle Shield"
        IrisDurability = "∞ Shield ∞"
      else
        labelString = "Toggle Iris"
        IrisDurability = sg.getIrisDurability()
      end
      if not IrisToggleButton.visible or labelString ~= IrisToggleButton.label then
        IrisToggleButton:hide()
        IrisToggleButton.label = labelString
        IrisToggleButton.width = 1
        IrisToggleButton:display()
      end
    end
    freeMemoryPercent = tostring(math.floor((computer.freeMemory()/computer.totalMemory())*100)).."%"
  os.sleep(0.05)
  end
end)
  

-- End of Thread Creation ----------------------------------------------------------

function mainInterface(shouldClear)
  if shouldClear == nil then 
    clearDisplay() 
    gateRingDisplay.draw()
  end
  if glyphListWindow.glyphType ~= GateType then glyphListWindow.initialize(GateType) end
  glyphListWindow.display()
  buttons.dialButton:display()
  buttons.editButton:display()
  buttons.addEntryButton:display()
  updateButtons()
  if HelpButton.disabled then HelpButton:disable(false) end
end

-- Initialization ------------------------------------------------------------------
HadNoError, ErrorMessage = xpcall(function()
  ChildThread.debugWindowThread:suspend()
  QuitButton:display()
  HelpWindow.visible = false
  HelpButton:display()
  glyphListWindow.initialize(GateType)
  gateRingDisplay.initialize()
  gateRingDisplay.draw()
  if sg.dialedAddress ~= nil and sg.dialedAddress ~= "[]" then
    DialedAddress = parseAddressString(sg.dialedAddress, GateType)
    glyphListWindow.showAddress()
    for i in ipairs(DialedAddress) do gateRingDisplay.dialedChevrons(i, true) end
  end
  mainInterface()
  displayInfoCenter()
end, debug.traceback)
-- Initialization End --------------------------------------------------------------

-- Main Loop -----------------------------------------------------------------------
while MainLoop and HadNoError do os.sleep(0.05) end
-- Main Loop End -------------------------------------------------------------------

-- Closing Procedures --------------------------------------------------------------
term.clear()
for k,v in pairs(ChildThread) do
  if (wasTerminated or not HadNoError) and v:status() == "dead" then
    print(k..": dead already")
  else
    v:kill()
    if wasTerminated or not HadNoError then print(k..": "..v:status()) end -- For Debug
  end
end

for k,v in pairs(EventListeners) do
  if wasTerminated or not HadNoError then print("Canceling Event Listener: "..k) end -- For Debug
  event.cancel(v)
end
if wasTerminated or not HadNoError then
  print("Dialer Program Terminated")
else
  print("Dialer Program Closed")
end
if HasModem and ModemIDCPort ~= nil then modem.close(ModemIDCPort) end
if not HadNoError then io.stderr:write(ErrorMessage) end
screen.setTouchModeInverted(false)
if not term.getCursorBlink() then term.setCursorBlink(true) end


