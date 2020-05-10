--[[
Created By: Augur ShicKla
v0.6.0

System Requirements:
Tier 3.5 Memory
Tier 3 GPU
Tier 3 Screen
]]--

Version = "0.6.0"
c = require("component")
computer = require("computer")
event = require("event")
os = require("os")
term = require("term")
thread = require("thread")
serialization = require("serialization")
unicode = require("unicode")
filesystem = require("filesystem")
screen = c.screen
gpu = c.gpu


-- Checking System Requirements are Met --------------------------------------------
if gpu.maxResolution() ~= 160 then
  io.stderr:write("Tier 3 GPU and Screen Required")
  os.exit(1)
end
if computer.totalMemory() < 1048576 then
  io.stderr:write("Not Enough Memory To Run. Please Install More Memory.")
  os.exit(1)
end
if not c.isAvailable("stargate") then
  io.stderr:write("No Stargate Connected.")
  os.exit(1)
end
NumberOfGates = 0
for k,v in c.list() do
  if v == "stargate" then NumberOfGates = NumberOfGates+1 end
end
if NumberOfGates > 1 then
  io.stderr:write("Too Many Stargates Connected to Computer.")
  os.exit(1)
end
-- End of Checking System Requirements ---------------------------------------------

-- Declarations --------------------------------------------------------------------
sg = c.stargate

GlyphsMW = {"Andromeda","Aquarius","Aries","Auriga","Bootes","Cancer","Canis Minor","Capricornus","Centaurus","Cetus","Corona Australis","Crater","Equuleus","Eridanus","Gemini","Hydra","Leo","Leo Minor","Libra","Lynx","Microscopium","Monoceros","Norma","Orion","Pegasus","Perseus","Pisces","Piscis Austrinus","Sagittarius","Scorpius","Sculptor","Scutum","Serpens Caput","Sextans","Taurus","Triangulum","Virgo"}
GlyphsPG = {"Aaxel","Abrin","Acjesis","Aldeni","Alura","Amiwill","Arami","Avoniv","Baselai","Bydo","Ca Po","Danami","Dawnre","Ecrumig","Elenami","Gilltin","Hacemill","Hamlinto","Illume","Laylox","Lenchan","Olavii","Once El","Poco Re","Ramnon","Recktic","Robandus","Roehi","Salma","Sandovi","Setas","Sibbron","Subido","Tahnan","Zamilloz","Zeo"}

GateType = ""
GateTypeName = ""
ConnectionErrorString = "Communication error with Stargate. Please disconnect and reconnect.\nIf problem persists verify AUNIS 1.9.6 or greater is installed, and replace Stargate base block."
DatabaseFile = "gateEntries.ff"
gateEntries = {}
AddressBuffer = {}
keyCombo = {}
ActiveButtons = {}
gateName = ""
addAddressMode = false
adrEntryType = ""
local ComputerDialingInterlocked = false
editGateEntryMode = false
manualAdrEntryMode = false
isDirectDialing = false
AbortingDialing = false
WasCanceled = false
local ErrorMessage = ""
local OutgoingWormhole = false
local DialingInterlocked = false
DebugMode = false
local DebugEventName = ""
UNGateResetting = false
RootDrive = nil
DialedAddress = {}
GateStatusString, GateStatusBool = nil
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
-- End of Pre-Initialization -------------------------------------------------------

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
    if v == self then table.remove(ActiveButtons
    , i) end
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

-- Special Functions ---------------------------------------------------------------
function GateEntry(ge)
  if ge.gateAddress.UN ~= nil and #ge.gateAddress.UN ~= 0 then
    for i,v in ipairs(ge.gateAddress.UN) do
      _,ge.gateAddress.UN[i] = checkGlyph(v, "UN")
    end
  end
  table.insert(gateEntries, ge)
end

function readAddressFile()
  gateEntries = {}
  local file = io.open(DatabaseFile, "r")
  if file == nil then
    file = io.open(DatabaseFile, "w")
    file:close()
  end
  dofile(DatabaseFile)
end

function writeToDatabase()
  local file, msg = io.open(DatabaseFile, "w")
  for i,v in ipairs(gateEntries) do
    file:write("GateEntry"..serialization.serialize(v).."\n")
  end
  file:close()
  readAddressFile()
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
  gpu.fill(41, 2, 120-(2*glyphListWindow.width), 42, " ")
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
      if w ~= "Glyph 17" then table.insert(adrBuf, w) end
    end
    for i,v in ipairs(adrBuf) do
      _,adrBuf[i] = checkGlyph(v, adrType)
    end
  else
    adrBuf = adrStr
  end
  return adrBuf
end

function userInput(x, y, maxLength)
  for _,v in pairs(ChildThread) do v:suspend() end
  local inputString = ""
  local strLength = 0
  if maxLength == nil or maxLength == 0 then maxLength = 32 end
  term.setCursor(x, y)
  term.setCursorBlink(true)
  while true do
    term.setCursorBlink(true)
    local event, address, arg1, arg2, arg3 = term.pull()
    if event == "key_down" then
      if arg2 ~= 28 and arg2 ~= 14 and arg1 ~= 0 and strLength < maxLength then -- Not Enter, Backspace, or Other
        inputString = inputString..unicode.char(arg1)
      elseif arg2 == 14 then -- Backspace Key
        inputString = unicode.wtrunc(inputString, strLength)
      elseif arg2 == 28 then -- Enter Key
        break
      end
    end
    if WasCanceled then
      WasCanceled = false
      inputString = ""
      break
    end
    strLength = unicode.len(inputString)
    gpu.fill(x, y, maxLength, 1, " ")
    gpu.set(x, y, inputString)
    term.setCursor(x+strLength, y)
  end
  term.setCursorBlink(false)
  for _,v in pairs(ChildThread) do v:resume() end
  return inputString
end
-- End of Special Functions --------------------------------------------------------

-- Info Center ---------------------------------------------------------------------
function displayInfoCenter()
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
  displayLocalAddress(48,term.window.height-5)
end

function displaySystemStatus()
  local xPos = 2
  local yPos = 45
  local energyStored = sg.getEnergyStored()
  local energyMax = sg.getMaxEnergyStored()
  local capCount = sg.getCapacitorsInstalled()
  local freeMemory = computer.freeMemory()
  local totalComputerMemory = computer.totalMemory()
  gpu.set(33, term.window.height-6, "╡")
  gpu.set(45, term.window.height-6, "╞")
  gpu.setForeground(0x000000)
  if GateStatusString == "open" then
    gpu.setBackground(0xFFFF00)
    gpu.set(34, term.window.height-6, " GATE OPEN ")
  else
    gpu.setBackground(0x00FF00)
    gpu.set(34, term.window.height-6, "GATE CLOSED")
  end
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)
  gpu.fill(xPos, yPos, 44, 3, " ")
  gpu.set(xPos+1, yPos, "Energy Level: "..energyStored.."/"..energyMax.." RF "..math.floor((energyStored/energyMax)*100).."%")
  gpu.set(xPos+1, yPos+1, "Capacitors Installed: "..capCount.."/3")
  gpu.set(xPos+1, yPos+2, "Computer Memory Remaining: "..math.floor((freeMemory/totalComputerMemory)*100).."%")
  
  -- gpu.fill(1, 42, 39, 1, " ") -- For Debug
  -- x,y = term.getCursor() -- For Debug
  -- gpu.set(1, 42, "Cursor: "..x..", "..y)  -- For Debug
  -- gpu.set(1, 42, tostring(AlertThread)) -- For Debug
  -- gpu.set(1, 42, serialization.serialize(AddressBuffer)) -- For Debug
end

function displayLocalAddress(xPos,yPos)
  gpu.set(xPos, yPos, "Milky Way "..addressToString(localMWAddress))
  gpu.set(xPos, yPos+1, "Universe  "..addressToString(localUNAddress))
  gpu.set(xPos, yPos+2, "Pegasus   "..addressToString(localPGAddress))
end

AlertThread = nil
function alert(msg, lvl)
  if AlertThread ~= nil then AlertThread:kill() end
  if lvl >= 0 then
    AlertThread = thread.create(function()
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
        gpu.fill(1, 1, term.window.width, 1, " ")
        gpu.fill(1, term.window.height, term.window.width, 1, " ")
    end)
  else
    gpu.fill(1, 1, term.window.width, 1, " ")
    gpu.fill(1, term.window.height, term.window.width, 1, " ")
  end
end
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
  self.locked = false
  if GateType == "MW" then self.localAddress = localMWAddress
  elseif GateType == "UN" then self.localAddress = localUNAddress
  elseif GateType == "PG" then self.localAddress = localPGAddress
  end
  gpu.set(1, 2,  "╔╡Gate Entries╞═══════════════════════╗")
  gpu.set(1, 40, "╚═════════════════════════════════════╝")
  gpu.fill(1, 3, 1, 37, "║")
  gpu.fill(39, 3, 1, 37, "║")
  self.scrollUpButton = Button.new(3, 39, 0, 0, "▲PgUp▲", function()
    GateEntriesWindow.increment(-1)
  end, false)
  self.scrollDnButton = Button.new(30, 39, 0, 0, "▼PgDn▼", function()
    GateEntriesWindow.increment(1)
  end, false)
  self.update()
end

function GateEntriesWindow.increment(inc)
  local self = GateEntriesWindow
  if (self.range.top + inc) > #gateEntries or (self.range.bot + inc) < 1 then
    return
  else
    self.range.bot = self.range.bot + inc
    self.range.top = self.range.top + inc
    self.display()
  end
end

function GateEntriesWindow.update()
  local self = GateEntriesWindow
  local strBuf = ""
  self.entryStrings = {}
  for i,v in ipairs(gateEntries) do
    strBuf = v.name
    if entriesDuplicateCheck(self.localAddress, {v}, GateType, 1) then
      strBuf = strBuf.." [This Stargate]"
    elseif v.gateAddress[GateType] ~= nil and #v.gateAddress[GateType] ~= 0 then
      strBuf = strBuf.." ("..(#v.gateAddress[GateType]+1).." Glyphs)"
    else
      strBuf = strBuf.." [Empty "..GateType.." Address]"
    end
    if unicode.len(strBuf) > self.width-5 then strBuf = unicode.wtrunc(strBuf, self.width-6) end
    table.insert(self.entryStrings, strBuf)
  end
  if #self.entryStrings > self.range.height then
    gpu.set(1, 40, "╚═╡░░░░░░╞═══════════════════╡░░░░░░╞═╝")
    self.scrollUpButton:display()
    self.scrollDnButton:display()
  else
    self.scrollUpButton:hide()
    self.scrollDnButton:hide()
    gpu.fill(2, 40, 37, 1, "═")
  end
  self.display()
end

function GateEntriesWindow.display()
  if #gateEntries == 0 then alert("WARNING: NO ADDRESSES IN DATABASE!", 2) end
  local self = GateEntriesWindow
  gpu.fill(2, 3, 37, 37, " ")
  self.currentIndices = {}
  local displayCount = 0
  for i,v in ipairs(self.entryStrings) do
    if i >= self.range.bot and i <= self.range.top then
      displayCount = displayCount + 1
      self.currentIndices[displayCount] = i
      gpu.set(3, 2+displayCount, tostring(i))
      if i == self.selectedIndex then gpu.setBackground(0x878787) end
      gpu.set(7, 2+displayCount, v)
      gpu.setBackground(0x000000)
    end
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
      self.display()
    end
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
  end  
  clearDisplay()
  HelpButton:disable(true)
  gateRingDisplay.draw()
  glyphListWindow.reset()
  buttons.abortDialingButton:display()
  ComputerDialingInterlocked = true
  AbortingDialing = false
  glyphListWindow.locked = true
  dialNext(0)
  while ComputerDialingInterlocked and MainLoop do
    dialAddressWindow.display(gateEntry)
    os.sleep(0.05)
  end
  ComputerDialingInterlocked = false
  isDirectDialing = false
  mainInterface()
end

function dialNext(dialed)
  if not AbortingDialing then
    local glyph = AddressBuffer[dialed + 1]
    dialAddressWindow.glyph = glyph
    sg.engageSymbol(glyph)
    glyphListWindow.insertGlyph(glyph)
    if (dialed+1) < 7 then
      gateRingDisplay.traces(dialed+1, 1)
    elseif (dialed+1) == #AddressBuffer then
      gateRingDisplay.traces(7, 1)
    else
      gateRingDisplay.traces(dialed+2, 1)
    end
    if dialed ~= 0 then os.sleep(0.5) end
    gateRingDisplay.glyphImage(glyph)
  end
end

function abortDialing()
  AbortingDialing = true
  alert("ABORTING DIALING... PLEASE WAIT", 2)
  while sg.getGateStatus() ~= "idle" do os.sleep() end
  alert("DIALING ABORTED", 2)
  sg.engageGate()
  while sg.getGateStatus() == "failing" do os.sleep() end
  ComputerDialingInterlocked = false
  AbortingDialing = false
  mainInterface()
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
    givenInput = userInput(104, 8, 1)
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
      givenInput = userInput(79, 6, 21)
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
  gpu.set(42, 7, "Then hit the 'Big Red Button'")
  while DHD_AdrEntryMode do
    os.sleep()
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
      completeAddressEntry("MW")
      addAddressMode = false
    end
  end
  DHD_AdrEntryMode = false
end

function dialerAddressEntry()
  alert("", -1)
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
  while sg.getGateStatus() == "unstable" do os.sleep() end
  sg.disengageGate()
  dialerAdrEntryMode = false
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
end

function manualAddressEntry()
  glyphListWindow.locked = false
  if adrEntryType ~= nil and adrEntryType ~= "" then
    clearDisplay()
    buttons.cancelButton:display()
    manualAdrEntryMode = true
    if glyphListWindow.glyphType ~= adrEntryType then
      glyphListWindow.initialize(adrEntryType)
    end
    gpu.set(42, 6, "Enter the address using the glyphs to the right. Then hit 'Origin' to complete.")
    while manualAdrEntryMode do os.sleep() end
  end
end
-- End of Address Entry ------------------------------------------------------------

-- Edit Gate Entry -----------------------------------------------------------------
function editGateEntry(index)
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
  buttons.deleteButton:display()
  glyphListWindow.locked = true
  glyphListWindow.display()
  editGateEntryMode = true
  if gateEntry.gateAddress.MW == nil then gateEntry.gateAddress["MW"] = {} end
  if gateEntry.gateAddress.UN == nil then gateEntry.gateAddress["UN"] = {} end
  if gateEntry.gateAddress.PG == nil then gateEntry.gateAddress["PG"] = {} end
  gpu.set(42, 6, "Name: "..gateEntry.name)
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
  gpu.set(49, 19, "To change an address click on its name.")
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

function renameGateEntry(index)
  buttons.deleteButton:disable(true)
  local newName = ""
  local oldName = gateEntries[index].name
  gpu.fill(48, 6, 20, 1, " ")
  newName = userInput(48, 6, 21)
  if newName ~= "" then
    gateEntries[index].name = newName
    alert("\""..oldName.."\" HAS BEEN RENAMED TO \""..gateEntries[index].name.."\"", 1)
    gpu.set(48, 6, gateEntries[index].name)
    writeToDatabase()
  end
  buttons.deleteButton:disable(false)
end

function deleteGateEntry(value)
  buttons.renameButton:disable(true)
  if value == 0 then
    gpu.set(59, 23, "┬─────┬")
    gpu.set(59, 24, "│     │")
    gpu.set(59, 25, "├─────┤")
    gpu.set(59, 26, "│     │")
    gpu.set(59, 27, "└─────┘")
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
    gpu.fill(59, 23, 7, 5, " ")
    gpu.set(59, 23, "───────")
    buttons.deleteYesButton:hide()
    buttons.deleteNoButton:hide()
    alert("DELETE CANCELED", 1)
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
  for i=1,9 do table.insert(self.chevronStates, false) end
  for i=1,9 do table.insert(self.traceStates, 0) end
  dofile("gateRing.ff") -- Loads the gate ring graphics
  if GateType == "MW" then
    dofile("glyphsMW.ff") -- Loads MW Glyph Images
  elseif GateType == "UN" then
    dofile("glyphsUN.ff") -- Loads UN Glyph Images
  end
  self.ringTbl, self.topTbl, self.midTbl, self.botTbl = {},{},{},{}
  self.chevTbl = {"⢤⣤⣤⣤⣤⡤","⠀⢻⣿⣿⡟","⠀⠀⢻⡟"}
  self.dotTbl = {"⢀⣴⣶⣦⡀","⣿⣿⣿⣿⣿","⠈⠻⠿⠟⠁"}
  self.dot2Tbl = {"⣠⣾⣿⣷⣄", "⢿⣿⣿⣿⡿", "⠙⠛⠋"}
  if GateType == "MW" then
    self.offColor = 0x662400
    self.onColor = 0x994900
    self.ringColor = 0x4B4B4B
    self.horizonColor = 0x006DFF
  else
    self.offColor = 0xA5A5A5
    self.onColor = 0xFFFFFF
    self.ringColor = 0x1E1E1E
    self.horizonColor = 0xD2D2D2
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
  if GateType == "MW" then
    xPos = 64
    yPos = 15
    gpu.fill(xPos, yPos, 32, 16, " ")
  elseif GateType == "UN" then
    xPos = 77
    yPos = 14
    gpu.fill(xPos, yPos, 6, 18, " ")
  end
  if glyphName == nil and isEngaged == nil then return end
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
  if self.isActive then
    gpu.setForeground(self.ringColor)
    if isOpen then
      gpu.setBackground(self.horizonColor)
      self.eventHorizonState = true
    else
      gpu.setBackground(0x000000)
      self.eventHorizonState = false
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
  local self = gateRingDisplay
  if count <= self.engagedChevronCount then return end
  local glyphName = DialedAddress[count]
  if glyphName == "" then glyphName = "Point of Origin" end
  if not hideImage then self.glyphImage(glyphName, true) end
  if count < 7 then
    self.setChevron(count, true)
    self.traces(count, 2)
  else
    if DialedAddress[count] == "" then
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
  key_downEvent = event.listen("key_down", function(_, keyboardAddress, chr, code, playerName)
    table.insert(keyCombo, code)
    if #keyCombo > 1 and (keyCombo[1] == 29 and keyCombo[2] == 16) then -- Ctrl+Q to Completely Exit
      WasCanceled = true
      MainLoop = false
    end
    if code == 201 then GateEntriesWindow.increment(-1) end -- PgUp
    if code == 209 then GateEntriesWindow.increment(1) end  -- PgDn
  end),

  key_upEvent = event.listen("key_up", function(_, keyboardAddress, chr, code, playerName)
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
  end),

  touchEvent = event.listen("touch", function(_, screenAddress, x, y, button, playerName)
    if button == 0 then
      for i,v in ipairs(ActiveButtons) do
        if v:touch(x,y) then break end
      end
      glyphListWindow.touch(x, y)
      GateEntriesWindow.touch(x, y)
    end
    if DebugMode then
      gpu.fill(150, 43, 10, 1, " ") -- For Debug
      gpu.set(150, 43, x..", "..y)  -- For Debug
    end
  end),

  scrollEvent = event.listen("scroll", function(_, screenAddress, x, y, direction, playerName)
      GateEntriesWindow.increment(direction*-1)
  end),

  component_unavailableEvent = event.listen("component_unavailable", function(_, componentString)
    if componentString == "stargate" then
      ErrorMessage = "Stargate Has Been Disconnected"
      HadNoError = false
    end
  end),

  interruptedEvent = event.listen("interrupted", function()
    wasTerminated = true
    -- HadNoError = false
    MainLoop = false
  end),
}

local eventFunctions = {}
function eventFunctions.stargate_spin_chevron_engaged(_, _, caller, num, lock, glyph)
  gateRingDisplay.glyphImage(glyph, true)
  if lock then
    alert("CHEVRON "..math.floor(num).." LOCKED", 1)
    gateRingDisplay.setChevron(7, true)
    gateRingDisplay.traces(7, 2)
    if not AbortingDialing then sg.engageGate() end
    os.sleep()
    ComputerDialingInterlocked = false
  else
    if (num) < 7 then
      gateRingDisplay.setChevron(num, true)
      gateRingDisplay.traces(num, 2)
    else
      gateRingDisplay.setChevron(num+1, true)
      gateRingDisplay.traces(num+1, 2)
    end        
    os.sleep()
    if not AbortingDialing then 
      alert("CHEVRON "..math.floor(num).." ENGAGED", 0)
      dialNext(num)
    end
  end
end

function eventFunctions.stargate_incoming_wormhole(_, _, caller, dialedAddressSize)
  alert("INCOMING WORMHOLE", 2)
  for i=1,dialedAddressSize do gateRingDisplay.chevronStates[i] = true end
  if gateRingDisplay.isActive then
    for i,v in ipairs(gateRingDisplay.chevronStates) do gateRingDisplay.setChevron(i, v) end
  end
  -- thread.create(function()
    -- while true do
      -- if sg.dialedAddress ~= nil and sg.dialedAddress ~= "[]" then
        -- alert(tostring(sg.dialedAddress), 3)
        -- break
      -- end
    -- end
  -- end)
end

function eventFunctions.stargate_open(_, _, caller, isInitiating)
  if GateType == "UN" and not caller and isInitiating then 
    gateRingDisplay.traces(7, 2)
    gateRingDisplay.setChevron(7, true)
    gateRingDisplay.glyphImage("Glyph 17", true)
  end
  if dialerAdrEntryMode then
    dialerAdrEntryMode = false
  end
  glyphListWindow.locked = false
  glyphListWindow.display()
  os.sleep(2)
  gateRingDisplay.eventHorizon(true)
end

function eventFunctions.stargate_close(_, _, caller, reason)
  if GateType == "UN" and OutgoingWormhole then UNGateResetting = true end
  if not addAddressMode then
    glyphListWindow.locked = false
    glyphListWindow.display()
  end
  gateRingDisplay.reset()
  os.sleep(1.5)
  alert("CONNECTION HAS CLOSED", 1)
  gateRingDisplay.eventHorizon(false)
end

function eventFunctions.stargate_wormhole_closed_fully(_, _, caller, isInitiating)
  OutgoingWormhole = false
  if UNGateResetting then
    gateRingDisplay.UNreset()
    UNGateResetting = false
  end
end

function eventFunctions.stargate_failed(_, _, caller, reason)
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
  ComputerDialingInterlocked = false
end
-- End of Event Section ------------------------------------------------------------

-- Buttons -------------------------------------------------------------------------
buttons = {
  dialButton = Button.new(41, 2, 0, 3, "  Dial  ", function()
    dialAddress(gateEntries[GateEntriesWindow.selectedIndex])
  end),
  dial7GlyphsButton = Button.new(41, 4, 0, 3, "7 Glyphs", function()
    dialAddress(gateEntries[GateEntriesWindow.selectedIndex], 7)
  end, false),
  dial8GlyphsButton = Button.new(41, 6, 0, 3, "8 Glyphs", function()
    dialAddress(gateEntries[GateEntriesWindow.selectedIndex], 8)
  end, false),
  dial9GlyphsButton = Button.new(41, 8, 0, 3, "9 Glyphs", function()
    dialAddress(gateEntries[GateEntriesWindow.selectedIndex], 9)
  end, false),
  editButton = Button.new(64, 2, 0, 3, "Edit Entry", function()
      editGateEntry(GateEntriesWindow.selectedIndex)
  end),
  renameButton = Button.new(41, 21, 0, 3, "Rename Entry", function()
    renameGateEntry(GateEntriesWindow.selectedIndex)
  end),
  deleteButton = Button.new(56, 21, 0, 3, "Delete Entry", function()
    deleteGateEntry(0)
  end),
  deleteYesButton = Button.new(59, 23, 0, 3, " Yes ", function()
    deleteGateEntry(1)
  end, false),
  deleteNoButton = Button.new(59, 25, 0, 3, " No  ", function()
    deleteGateEntry(-1)
  end, false),
  addEntryButton = Button.new(52, 2, 0, 3, "Add Entry", function()
    addNewGateEntry()
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
  MainLoop = false
end)
CloseGateButton = Button.new(15, 41, 0, 3, "Close Gate", function()
  local s,f = sg.disengageGate()
  if f == "stargate_failure_wrong_end" then
    alert("CAN NOT CLOSE AN INCOMING CONNECTION", 2)
  elseif f == "stargate_failure_not_open" then
    alert("GATE IS NOT OPEN", 1)
  end
end)
HelpButton = Button.new(8, 41, 0, 0, "Help", function()
  HelpWindow.toggle()
end)
-- End Buttons ---------------------------------------------------------------------

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

-- Toggle Debug Mode ---------------------------------------------------------------
function toggleDebugMode()
    if not DebugMode then
      DebugMode = true
      alert("DEBUG MODE ACTIVATED", 1)
    elseif DebugMode then
      alert("DEBUG MODE DEACTIVATED", 1)
      DebugMode = false
      os.sleep()
      gpu.fill(150, 43, 10, 1, " ")
      gpu.fill(48, 45, 110, 4, " ")
      displayLocalAddress(48,term.window.height-5)
    end 
end
-- End of Toggle Debug Mode --------------------------------------------------------

localMWAddress = sg.stargateAddress.MILKYWAY
localUNAddress = sg.stargateAddress.UNIVERSE
localPGAddress = sg.stargateAddress.PEGASUS
term.clear()
readAddressFile()
GateEntriesWindow.set()
wasTerminated = false
HadNoError = true
MainLoop = true

-- Creating Threads ----------------------------------------------------------------
ChildThread = {
  statusThread = thread.create(function()
    local success, msg = pcall(function()
      displayInfoCenter()
      while HadNoError and MainLoop do
        displaySystemStatus()
        os.sleep()
      end
    end)
    if not success then
      HadNoError = false
      ErrorMessage = debug.traceback(msg)
    end
  end),

  eventHandlerThread = thread.create(function()
    local success, msg = pcall(function()
      while HadNoError and MainLoop do
        local eventTable = {event.pull()}
        local eventName = eventTable[1]
        if type(eventFunctions[eventName]) == "function" then thread.create(eventFunctions[eventName], table.unpack(eventTable)) end
        if DebugMode and eventName ~= "thread_exit" and eventName ~= "drop" and eventName ~= "touch" then DebugEventName = eventName end -- For Debug
      end  
    end)
    if not success then
      HadNoError = false
      ErrorMessage = debug.traceback(msg)
    end
  end),
  
  gateStatusThread = thread.create(function()
    local success, msg = pcall(function()
      CloseGateButton:display()
      while HadNoError and MainLoop do
        GateStatusString, GateStatusBool = sg.getGateStatus()
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
        
        if GateStatusString == "dialing" or GateStatusString == "dialing_computer" then
          if not UNGateResetting then
            if buttons.glyphResetButton.visible then buttons.glyphResetButton:hide() end
            if not glyphListWindow.locked then glyphListWindow.locked = true end
            DialedAddress = parseAddressString(sg.dialedAddress, GateType)
            if GateStatusString == "dialing" then glyphListWindow.showAddress() end
            gateRingDisplay.dialedChevrons(#DialedAddress)
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
        os.sleep()
      end
    end)
    if not success then
      HadNoError = false
      ErrorMessage = debug.traceback(msg)
    end
  end),
  
  debugWindowThread = thread.create(function() -- For Debug
    local success, msg = pcall(function()
      while HadNoError and MainLoop do
        local used = RootDrive.spaceUsed()
        local total = RootDrive.spaceTotal()
        local dialedAddress = sg.dialedAddress
        gpu.fill(3, 48, 40, 1, " ")
        if DebugMode then
          if ChildThread.gateStatusThread:status() == "dead" then alert("gateStatusThread is dead", 3) end
          gpu.fill(48, 45, 110, 4, " ")
          gpu.set(48, 45, "DHD_AdrEntryMode: "..tostring(DHD_AdrEntryMode))
          gpu.set(48, 46, "DialingInterlocked: "..tostring(DialingInterlocked))
          gpu.set(48, 47, "ComputerDialingInterlocked: "..tostring(ComputerDialingInterlocked))
          gpu.set(84, 46, "dialerAdrEntryMode: "..tostring(dialerAdrEntryMode))
          gpu.set(84, 45, "glyphListWindow.locked: "..tostring(glyphListWindow.locked))
          gpu.set(48, 48, tostring(dialedAddress))
          gpu.set(84, 47, "Gate Status: "..tostring(GateStatusString).." | "..tostring(GateStatusBool))
          gpu.set(120, 45, "Drive Usage: "..used.."/"..total.." "..math.floor((used/total)*100).."%")
          gpu.set(120, 46, "manualAdrEntryMode: "..tostring(manualAdrEntryMode))
          gpu.set(120, 47, DebugEventName)
        end
        os.sleep()
      end
    end)
    if not success then
      HadNoError = false
      ErrorMessage = debug.traceback(msg)
    end
  end)
}
-- End of Thread Creation ----------------------------------------------------------

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

function mainInterface()
  clearDisplay()
  if glyphListWindow.glyphType ~= GateType then glyphListWindow.initialize(GateType) end
  gateRingDisplay.draw()
  glyphListWindow.display()
  buttons.dialButton:display()
  buttons.editButton:display()
  buttons.addEntryButton:display()
  if HelpButton.disabled then HelpButton:disable(false) end
end

mainInterface()
while MainLoop do
  if not HadNoError then
    MainLoop = false
  end
  os.sleep(0.05)
end

-- Closing Procedures --------------------------------------------------------------
term.clear()
for k,v in pairs(ChildThread) do
  v:kill()
  if wasTerminated or not HadNoError then print(k..": "..v:status()) end -- For Debug
end
if AlertThread ~= nil then AlertThread:kill() end
for k,v in pairs(EventListeners) do
  if wasTerminated or not HadNoError then print("Canceling: "..v.." : "..k) end -- For Debug
  event.cancel(v)
end
if wasTerminated or not HadNoError then
  print("Dialer Program Terminated")
else
  print("Dialer Program Closed")
end
io.stderr:write(ErrorMessage)
screen.setTouchModeInverted(false)
if not term.getCursorBlink() then term.setCursorBlink(true) end