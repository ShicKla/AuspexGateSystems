--[[
Created By: Augur ShicKla
v0.4.2

System Requirements:
Tier 3.5 Memory
Tier 3 GPU
Tier 3 Screen
]]--

c = require("component")
computer = require("computer")
event = require("event")
os = require("os")
term = require("term")
thread = require("thread")
serialization = require("serialization")
unicode = require("unicode")
gpu = c.gpu


-- Checking System Requirements are Met --------------------------------------------
if gpu.maxResolution() ~= 160 then
  io.stderr:write("Tier 3 GPU and Screen Required")
  return
end
if computer.totalMemory() < 1048576 then
  io.stderr:write("Not Enough Memory To Run. Please Install More Memory.")
  return
end
if not c.isAvailable("stargate") then
  io.stderr:write("No Stargate Connected.")
  return
end
NumberOfGates = 0
for k,v in c.list() do
  if v == "stargate" then NumberOfGates = NumberOfGates+1 end
end
if NumberOfGates > 1 then
  io.stderr:write("Too Many Stargates Connected to Computer.")
  return
end
-- End of Checking System Requirements ---------------------------------------------

-- Declarations --------------------------------------------------------------------
sg = c.stargate

GlyphsMW = {"Monoceros", "Centaurus", "Scorpius", "Sculptor", "Bootes", "Virgo", "Pisces", "Scutum", "Sextans", "Sagittarius", "Hydra", "Leo Minor", "Eridanus", "Libra", "Aries", "Serpens Caput", "Andromeda", "Pegasus", "Cetus", "Leo", "Gemini", "Corona Australis", "Auriga", "Piscis Austrinus", "Orion", "Lynx", "Capricornus", "Canis Minor", "Taurus", "Norma", "Cancer", "Perseus", "Crater", "Equuleus", "Microscopium", "Aquarius", "Triangulum"}
GlyphsPG = {"Acjesis", "Lenchan", "Alura", "Ca Po", "Laylox", "Ecrumig", "Avoniv", "Bydo", "Aaxel", "Aldeni", "Setas", "Arami", "Danami", "Poco Re", "Robandus", "Recktic", "Zamilloz", "Subido", "Dawnre", "Salma", "Hamlinto", "Elenami", "Tahnan", "Zeo", "Roehi", "Once El", "Baselai", "Sandovi", "Illume", "Amiwill", "Sibbron", "Gilltin", "Abrin", "Ramnon", "Olavii", "Hacemill"}

GateType = ""
GateTypeName = ""
ConnectionErrorString = "Communication error with Stargate. Please disconnect and reconnect.\nIf problem persists verify AUNIS 1.9.6 or greater is installed, and replace Stargate base block."
DatabaseFile = "gateEntries.ff"
gateEntries = {}
addressBuffer = {}
keyCombo = {}
Button = {}
Button.__index = Button
ActiveButtons = {}
gateName = ""
stopRequest = false
addAddressMode = false
adrEntryType = ""
DialingModeInterlocked = false
editGateEntryMode = false
manualAdrEntryMode = false
isDirectDialing = false
AbortDialing = false
WasCanceled = false
DialerInterlocked = false
-- End of Declarations -------------------------------------------------------------

-- Pre-Initialization --------------------------------------------------------------
if sg.getGateType() == "MILKYWAY" then
  GateType = "MW"
  GateTypeName = "Milky Way"
  if not pcall(function() sg.getEnergyRequiredToDial({GlyphsMW[1]}) end) then
    io.stderr:write("MW: "..ConnectionErrorString)
    return
  end
elseif sg.getGateType() == "UNIVERSE" then
  GateType = "UN"
  GateTypeName = "Universe"
  if not pcall(function() sg.getEnergyRequiredToDial({"G1"}) end) then
    io.stderr:write("UN: "..ConnectionErrorString)
    return
  end
elseif sg.getGateType() == "PEGASUS" then
  GateType = "PG"
  GateTypeName = "Pegasus"
  if not pcall(function() sg.getEnergyRequiredToDial({GlyphsPG[1]}) end) then
    io.stderr:write("PG: "..ConnectionErrorString)
    return
  end
else
  io.stderr:write("Gate Type Not Recognized")
  return
end

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
  return self
end

function Button.display(self, x, y)
  table.insert(ActiveButtons
, 1, self)
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

function Button.touch(self, x, y)
  local wasTouched = false
  if self.visible then  
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
    self.func()
    if self.visible then gpu.set(self.xPos+1, self.yPos+1, self.label) end
  end
  return wasTouched
end

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
-- End of Pre-Initialization -------------------------------------------------------

-- Special Functions ---------------------------------------------------------------
function writeToDatabase()
  GateEntriesWindow.update()
  local file = io.open(DatabaseFile, "w")
  for i,v in ipairs(gateEntries) do
    file:write("GateEntry"..serialization.serialize(v).."\n")
  end
  file:close()
  readAddressFile()
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
      if w ~= "G17" then table.insert(adrBuf, w) end
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
    if WasCanceled then
      WasCanceled = false
      inputString = ""
      break
    end
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
  gpu.set(140, 43, "Ctrl+Q to Force Quit")
end

function displaySystemStatus()
  local xPos = 2
  local yPos = 45
  local gateStatus, statusBool = sg.getGateStatus()
  if statusBool == true and not buttons.closeGateButton.visible then buttons.closeGateButton:display() end
  if statusBool == nil and buttons.closeGateButton.visible then buttons.closeGateButton:hide() end
  local energyStored = sg.getEnergyStored()
  local energyMax = sg.getMaxEnergyStored()
  local capCount = sg.getCapacitorsInstalled()
  local freeMemory = computer.freeMemory()
  local totalComputerMemory = computer.totalMemory()
  gpu.set(33, term.window.height-6, "╡")
  gpu.set(45, term.window.height-6, "╞")
  gpu.setForeground(0x000000)
  if gateStatus == "open" then
    gpu.setBackground(0xFFFF00)
    gpu.set(34, term.window.height-6, " GATE OPEN ")
  else
    gpu.setBackground(0x00FF00)
    gpu.set(34, term.window.height-6, "GATE CLOSED")
  end
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)
  gpu.fill(xPos, yPos, 44, 4, " ")
  gpu.set(xPos+1, yPos, "Energy Level: "..energyStored.."/"..energyMax.." RF "..math.floor((energyStored/energyMax)*100).."%")
  gpu.set(xPos+1, yPos+1, "Capacitors Installed: "..capCount.."/3")
  gpu.set(xPos+1, yPos+2, "Computer Memory Remaining: "..math.floor((freeMemory/totalComputerMemory)*100).."%")
  if gateStatus == "dialing" then
    glyphListWindow.locked = true
    glyphListWindow.showAddress()
  end
  if not DialerInterlocked and gateStatus ~= "idle" then DialerInterlocked = true end
  
  -- gpu.fill(1, 42, 39, 1, " ") -- For Debug
  -- gpu.set(1, 42, "DialerInterlocked: "..tostring(DialerInterlocked)) -- For Debug
  -- gpu.set(xPos+1, yPos+3, "Gate Status: "..gateStatus.." "..tostring(statusBool)) -- For Debug
  -- x,y = term.getCursor() -- For Debug
  -- gpu.set(1, 42, "Cursor: "..x..", "..y)  -- For Debug
  -- gpu.set(1, 42, tostring(AlertThread)) -- For Debug
  -- gpu.set(1, 42, serialization.serialize(addressBuffer)) -- For Debug
end

function displayLocalAddress(xPos,yPos)
  gpu.set(xPos, yPos, "Milky Way "..addressToString(localMWAddress))
  gpu.set(xPos, yPos+1, "Universe  "..addressToString(localUNAddress))
  gpu.set(xPos, yPos+2, "Pegasus   "..addressToString(localPGAddress))
end

function alert(msg, lvl)
  if AlertThread ~= nil then AlertThread:kill() end
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
end
-- End of Info Center --------------------------------------------------------------

-- Gate Entries Window -------------------------------------------------------------
GateEntriesWindow = {}
function GateEntriesWindow.set()
  local self = GateEntriesWindow
  self.xPos = 2
  self.yPos = 3
  self.width = 37
  self.height = 38
  gpu.fill(1, 2, 40, 40, " ")
  self.entries = {}
  self.range = {}
  self.range.bot = 1
  self.range.height = 38
  self.range.top = self.range.height
  self.locked = false
  if GateType == "MW" then self.localAddress = localMWAddress
  elseif GateType == "UN" then self.localAddress = localUNAddress
  elseif GateType == "PG" then self.localAddress = localPGAddress
  end
  gpu.set(1, 2,  "╔╡Gate Entries╞═══════════════════════╗")
  gpu.set(1, 41, "╚═════════════════════════════════════╝")
  gpu.fill(1, 3, 1, 38, "║")
  gpu.fill(39, 3, 1, 38, "║")
  self.scrollUpButton = Button.new(3, 40, 0, 0, "▲PgUp▲", function()
    GateEntriesWindow.increment(-1)
  end, false)
  self.scrollDnButton = Button.new(30, 40, 0, 0, "▼PgDn▼", function()
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
    gpu.set(1, 41, "╚═╡░░░░░░╞═══════════════════╡░░░░░░╞═╝")
    self.scrollUpButton:display()
    self.scrollDnButton:display()
  else
    self.scrollUpButton:hide()
    self.scrollDnButton:hide()
    gpu.fill(2, 41, 37, 1, "═")
  end
  self.display()
end

function GateEntriesWindow.display()
  if #gateEntries == 0 then alert("WARNING: NO ADDRESSES IN DATABASE!", 2) end
  local self = GateEntriesWindow
  gpu.fill(2, 3, 37, 38, " ")
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
    if not DialingModeInterlocked and not addAddressMode and not editGateEntryMode then
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
  if glyphType == "MW" or glyphType == "PG" then table.sort(self.glyphs) end
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
  self.display()
end

function glyphListWindow.display()
  local self = glyphListWindow
  local oStr = "Origin"
  local yOffset = self.yPos + 2
  local xOffset = self.xPos-self.width
  local resetButton = buttons.glyphResetButton
  gpu.fill(self.xPos+1, yOffset+1, self.width-2, self.glyphsHeight, " ")
  gpu.fill(xOffset, self.yPos, self.width, self.height, " ")
  for i,v in ipairs(self.selectedGlyphs) do
    if v == -1 then gpu.setBackground(0x878787) end
  end
  gpu.set(self.xPos+(self.width/2-unicode.len(oStr)/2), self.yPos+1, oStr)
  gpu.setBackground(0x000000)
  for i,v in ipairs(self.glyphs) do
    for i2,v2 in ipairs(self.selectedGlyphs) do
      if i == v2 then gpu.setBackground(0x878787) end
    end
    gpu.set(self.xPos+(self.width/2-unicode.len(v)/2), yOffset+i, v)
    gpu.setBackground(0x000000)
  end
  if #self.selectedGlyphs > 0 then
    if not self.locked then
      resetButton.xPos = xOffset+(self.width/2-resetButton.width/2)
      resetButton:display()
    end
    gpu.set(xOffset, yOffset+2, "┌")
    gpu.fill(xOffset+1, yOffset+2, self.width-2, 1, "─")
    gpu.set(xOffset+self.width-1, yOffset+2, "┐")
    gpu.set(xOffset+(self.width/2)-1, yOffset+2, "┴")
    gpu.set(xOffset+(self.width/2)-1, yOffset+1, "┌")
    gpu.fill(xOffset+(self.width/2), yOffset+1, (self.width/2), 1, "─")
    gpu.set(self.xPos, yOffset+1, "╢")
    for i,v in ipairs(self.selectedGlyphs) do
      local glyph = self.glyphs[v]
      if v ~= -1 then gpu.set(xOffset+(self.width/2-unicode.len(glyph)/2), yOffset+2+i, glyph) end
    end
  end
end

function glyphListWindow.touch(x,y)
  local self = glyphListWindow
  if not DialingModeInterlocked and not DHD_DialingInterlocked and not dialerAdrEntryMode and not self.locked then
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
          addressBuffer = {}
          local glyph = ""
          for i,v in ipairs(self.selectedGlyphs) do
            if v ~= -1 then
              glyph = self.glyphs[v]
              if self.glyphType == "UN" then _,glyph = checkGlyph(glyph, "UN") end
              table.insert(addressBuffer, glyph)
            end
          end
          if #addressBuffer >= 6 then
            if addAddressMode then 
              completeAddressEntry(self.glyphType)
            else
              directDial()
            end
            self.display()
          elseif #addressBuffer < 6 then
            addressBuffer = {}
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
  dialedAddress = parseAddressString(sg.dialedAddress, GateType)
  if #dialedAddress ~= #glyphListWindow.selectedGlyphs then
    glyphListWindow.selectedGlyphs = {}
    for i,v in ipairs(dialedAddress) do
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
  directEntry.gateAddress[GateType] = addressBuffer
  if #addressBuffer < 6 then
    alert("ENTERED ADDRESS TOO SHORT", 2)
  else
    dialAddress(directEntry)
  end
  isDirectDialing = false
end
-- End of Direct Dialing ----------------------------------------------------------------

-- Address Dialing ----------------------------------------------------------------------
dialAddressWindow = {xPos= 42, yPos=5, width= 80, height=30, glyph=""}
function dialAddressWindow.display(adr)
  local self = dialAddressWindow
  gpu.fill(self.xPos, self.yPos, self.width, self.height, " ")
  gpu.set(self.xPos, self.yPos, "Dialing: "..adr.name)
  gpu.set(self.xPos, self.yPos+1, "Engaging "..self.glyph.."... ")
end

function dialAddress(gateEntry)
  if gateEntry == nil then
    alert("NO GATE ENTRY SELECTED", 2)
    return
  end
  if sg.getGateStatus() == "open" then
    alert("CAN NOT DIAL DUE TO STARGATE BEING OPEN", 2)
    return
  end
  if DHD_DialingInterlocked then
    alert("CAN NOT DIAL WHILE DHD IS IN USE", 2)
    return
  end
  if DialerInterlocked then
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
  addressBuffer = {}
  for i,v in ipairs(gateEntry.gateAddress[GateType]) do table.insert(addressBuffer, v) end
  local requirement = sg.getEnergyRequiredToDial(addressBuffer)
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
    alert(tostring(requirement), 3)
    return
  end
  clearDisplay()
  glyphListWindow.reset()
  buttons.abortDialingButton:display()
  DialingModeInterlocked = true
  AbortDialing = false
  if GateType == "MW" then
    table.insert(addressBuffer,"Point of Origin")
  elseif GateType == "UN" then
    table.insert(addressBuffer,"G17")
  end
  glyphListWindow.locked = true
  dialNext(0)
  while DialingModeInterlocked do
    dialAddressWindow.display(gateEntry)
    os.sleep(0.05)
  end
  DialingModeInterlocked = false
  isDirectDialing = false
  MainHold = false
end

function dialNext(dialed)
  if not AbortDialing then
    local glyph = addressBuffer[dialed + 1]
    dialAddressWindow.glyph = glyph
    sg.engageSymbol(glyph)
    glyphListWindow.insertGlyph(glyph)
  else
    sg.engageGate()
    alert("DIALING ABORTED", 2)
    DialingModeInterlocked = false
    AbortDialing = false
    MainHold = false
  end
end
-- End Address Dialing -------------------------------------------------------------

-- Address Entry -------------------------------------------------------------------
function addressEntry(adrType)
  addAddressMode = true;
  adrEntryType = adrType
  addressBuffer = {}
  clearDisplay()
  buttons.cancelButton:display()
  buttons.manualEntryButton:display()
  if GateType == "MW" and adrType == "MW" then
    buttons.dhdEntryButton:display()
  elseif GateType == "UN" and adrType == "UN" then
    buttons.dialerEntryButton:display()
  else
    manualAddressEntry()
  end
  gpu.set(42, 6, "Select one of the below options to enter the address.")
end

function addNewGateEntry()
  glyphListWindow.locked = true
  alert("", -1)
  clearDisplay()
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
  local isDuplicate, duplicateNames = entriesDuplicateCheck(addressBuffer, gateEntries, adrType, 1)
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
      for i,v in ipairs(addressBuffer) do table.insert(gateEntries[index].gateAddress[adrType], v) end
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
      table.insert(gateEntries, {name=addressName, gateAddress={[adrType]=addressBuffer}})
      writeToDatabase()
      alert("NEW ADDRESS HAS BEEN ADDED", 1)
      manualAdrEntryMode = false
      MainHold = false
      glyphListWindow.reset()
    end
  end
  glyphListWindow.locked = false
  addAddressMode = false
  manualAdrEntryMode = false
  if editGateEntryMode then
    editGateEntry(index)
  else
    MainHold = false
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
    if sg.getGateStatus() == "failing" then break end -- (Backup Check of Failing Event) Implies the BRB was pressed
  end
  if allGood then
    addressBuffer = {}
    local glyph = ""
    for i,v in ipairs(glyphListWindow.selectedGlyphs) do
      if v ~= -1 then
        glyph = glyphListWindow.glyphs[v]
        if GateType == "UN" then _,glyph = checkGlyph(glyph, "UN") end
        table.insert(addressBuffer, glyph)
      end
    end
    if #addressBuffer < 6 then
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
  buttons.cancelButton:display()
  dialerAdrEntryMode = true
  gpu.fill(41, 6, 102, 10, " ")
  gpu.set(42, 6, "Dial the gate using your Universe Dialer. The address will be captured once the gate opens.")
  gpu.setForeground(0xFFFF00)
  gpu.set(42, 7, "Warning this process will use power since the gate will open.")
  gpu.set(42, 8, "The gate will close automatically after address capture.")
  gpu.setForeground(0xFFFFFF)
  gpu.set(42, 9, "Please begin dialing or push 'Cancel'")
  while dialerAdrEntryMode do
    os.sleep()
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
    addressBuffer = parseAddressString(sg.dialedAddress, "UN")
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
    if glyphListWindow.glyphType ~= GateType then glyphListWindow.initialize(adrEntryType) end
    gpu.set(42, 6, "Enter the address using the glyphs to the right. Then hit 'Origin' to complete.")
  end
end
-- End of Address Entry ------------------------------------------------------------

-- Edit Gate Entry -----------------------------------------------------------------
function deleteGateEntry(value)
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
    MainHold = false
  elseif value == -1 then
    gpu.fill(59, 23, 7, 5, " ")
    gpu.set(59, 23, "───────")
    buttons.deleteYesButton:hide()
    buttons.deleteNoButton:hide()
    alert("DELETE CANCELED", 1)
  end
end

function editGateEntry(index)
  clearDisplay()
  local gateEntry = gateEntries[index]
  if gateEntry == nil then
    alert("SELECT A GATE ENTRY TO EDIT", 2)
    MainHold = false
    return
  end
  buttons.cancelButton:display()
  buttons.renameButton:display()
  buttons.deleteButton:display()
  glyphListWindow.locked = true
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
    gpu.set(81+(9-math.floor(unicode.len(v)/2)), 9+i, v)
  end
  if #gateEntry.gateAddress.MW == 0 then gpu.fill(42, 10, 16, 8, "░") end
  if #gateEntry.gateAddress.UN == 0 then gpu.fill(62, 10, 16, 8, "░") end
  if #gateEntry.gateAddress.PG == 0 then gpu.fill(82, 10, 16, 8, "░") end
end

function renameGateEntry(index)
  local newName = ""
  local oldName = gateEntries[index].name
  gpu.fill(48, 6, 20, 1, " ")
  newName = userInput(48, 6, 21)
  if newName ~= "" then
    gateEntries[index].name = newName
    alert("\""..oldName.."\" HAS BEEN RENAMED TO \""..gateEntries[index].name.."\"", 1)
  end
  gpu.set(48, 6, gateEntries[index].name)
  writeToDatabase()
end
-- End Edit Gate Entry -------------------------------------------------------------

-- Event Section -------------------------------------------------------------------
EventListeners = {
  dhdChevronEngaged = event.listen("stargate_dhd_chevron_engaged", function(evname, address, caller, symbolCount, lock, symbolName)
    if DialerInterlocked and not DHD_DialingInterlocked then DHD_DialingInterlocked = true end
    if not glyphListWindow.locked then
      glyphListWindow.reset()
    end
    if DialingModeInterlocked then
      AbortDialing = true
    end
  end),

  eventSpinEngaged = event.listen("stargate_spin_chevron_engaged", function(evname, address, caller, num, lock, glyph)  
    if DialingModeInterlocked then
      if lock then
        alert("CHEVRON "..math.floor(num).." LOCKED", 1)
        sg.engageGate()
        os.sleep()
        DialingModeInterlocked = false
      else
        alert("CHEVRON "..math.floor(num).." ENGAGED", 0)
        os.sleep()
        dialNext(num)
      end
    end
  end),

  openEvent = event.listen("stargate_open", function(evname, address, caller, isInitiating)
    if dialerAdrEntryMode then
      dialerAdrEntryMode = false
    else
      glyphListWindow.locked = true
      glyphListWindow.display()
    end
  end),

  closeEvent = event.listen("stargate_close", function()
    while sg.getGateStatus() == "unstable" do os.sleep() end
    DialerInterlocked = false
    if not addAddressMode then
      alert("CONNECTION HAS CLOSED", 1)
      glyphListWindow.locked = false
      glyphListWindow.display()
    end
  end),

  incomingEvent = event.listen("stargate_incoming_wormhole", function()
    alert("INCOMING WORMHOLE", 2)
  end),

  failEvent = event.listen("stargate_failed", function(evname, address, caller, reason)
    if not DHD_AdrEntryMode then
      if reason == "address_malformed" then
        alert("UNABLE TO ESTABLISH CONNECTION", 3)
      elseif reason == "not_enough_power" then
        alert("NOT ENOUGH POWER TO CONNECT", 3)
      end
      while sg.getGateStatus() == "failing" do os.sleep() end
      DialerInterlocked = false
      DialingModeInterlocked = false
      if not dialerAdrEntryMode then
        glyphListWindow.locked = false
        glyphListWindow.display()
      end
    end
    DHD_DialingInterlocked = false
    if DHD_AdrEntryMode then DHD_AdrEntryMode = false end
  end),

  keyDownEvent = event.listen("key_down", function(evname, keyboardAddress, chr, code, playerName)
    table.insert(keyCombo, code)
    if #keyCombo > 1 and (keyCombo[1] == 29 and keyCombo[2] == 16) then -- Ctrl+Q to Completely Exit
      WasCanceled = true
      MainLoop = false
      MainHold = false
    end
    if code == 201 then GateEntriesWindow.increment(-1) end -- PgUp
    if code == 209 then GateEntriesWindow.increment(1) end  -- PgDn
  end),

  keyUpEvent = event.listen("key_up", function(evname, keyboardAddress, chr, code, playerName)
    keyCombo = {}
    if code == 59 and buttons.helpButton.visible then -- Toggles the instructions if F1 is pressed then released
      help.toggle()
    end
  end),

  touchEvent = event.listen("touch", function(evname, screenAddress, x, y, button, playerName)
    -- gpu.fill(1, 43, 20, 1, " ") -- For Debug
    -- gpu.set(1, 43, x..", "..y)  -- For Debug
    if button == 0 then
      for i,v in ipairs(ActiveButtons
  ) do
        if v:touch(x,y) then break end
      end
      glyphListWindow.touch(x, y)
      GateEntriesWindow.touch(x, y)
    end
  end),

  mouseWheelEvent = event.listen("scroll", function(evname, screenAddress, x, y, direction, playerName)
      GateEntriesWindow.increment(direction*-1)
  end),
  
  componentDisconnectEvent = event.listen("component_unavailable", function(evname, componentString)
    if componentString == "stargate" then
      ErrorString = "Stargate Has Been Disconnected"
      HadNoError = false
      MainHold = false
    end
  end),
}
-- End of Event Section ------------------------------------------------------------

-- Buttons -------------------------------------------------------------------------
buttons = {
  quitButton = Button.new(73, 2, 0, 3, "Quit", function()
    MainLoop = false
    MainHold = false
  end),
  dialButton = Button.new(41, 2, 0, 3, "Dial", function()
    dialAddress(gateEntries[GateEntriesWindow.selectedIndex])
  end),
  editButton = Button.new(60, 2, 0, 3, "Edit Entry", function()
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
  closeGateButton = Button.new(80, 2, 0, 3, "Close Gate", function()
    local s,f = sg.disengageGate()
    if f == "stargate_failure_wrong_end" then
      alert("CAN NOT CLOSE AN INCOMING CONNECTION", 2)
    elseif f == "stargate_failure_not_open" then
      alert("GATE IS NOT OPEN", 1)
    end
    buttons.closeGateButton:hide()
  end),
  addEntryButton = Button.new(48, 2, 0, 3, "Add Entry", function()
    addNewGateEntry()
  end),
  abortDialingButton = Button.new(41, 2, 0, 3, "Abort Dialing", function()
    AbortDialing = true
    alert("ABORTING DIALING... PLEASE WAIT", 2)
  end),
  glyphResetButton = Button.new(term.window.width-36, 2, 0, 0, "Reset", function()
    glyphListWindow.reset()
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
    MainHold = false
  end),
  helpButton = Button.new(41, 39, 0, 0, "Help", function()
    help.toggle()
  end),
}
-- End Buttons ---------------------------------------------------------------------

-- Help Window ---------------------------------------------------------------------
help = {visible=false}
function help.toggle()
  local self = help
  self.xPos = 41
  self.yPos = 5
  self.width = 80
  self.height = 15
  if self.visible then
    self.visible = false
    MainHold = false
  elseif not self.visible then
    self.visible = true
    gpu.fill(self.xPos, self.yPos, self.width, self.height, " ")
    gpu.set(self.xPos, self.yPos,               "╔══════════════════════════════════════════════════════════════════════════════╗")
    gpu.set(self.xPos, self.yPos+self.height-1, "╚══════════════════════════════════════════════════════════════════════════════╝")
    gpu.fill(self.xPos, self.yPos+1, 1, self.height-2, "║")
    gpu.fill(self.xPos+self.width-1, self.yPos+1, 1, self.height-2, "║")
    gpu.set(self.xPos+1, self.yPos+1, "DIALING:")
    gpu.set(self.xPos+2, self.yPos+2, "To dial out select a Gate Entry from the list to the left, and click the")
    gpu.set(self.xPos+2, self.yPos+3, "'Dial' button. You can also directly enter an address with the glyphs to")
    gpu.set(self.xPos+2, self.yPos+4, "the right, then click 'Origin' to begin dialing.")
    gpu.set(self.xPos+1, self.yPos+6, "ADD ENTRY:")
    gpu.set(self.xPos+2, self.yPos+7, "To add a Gate to the 'Gate Entries' list click the 'Add Entry' button and")
    gpu.set(self.xPos+2, self.yPos+8, "follow the prompts.")
    gpu.set(self.xPos+1, self.yPos+10, "EDIT ENTRY:")
    gpu.set(self.xPos+2, self.yPos+11, "To edit a Gate Entry, select it from the list and click the 'Edit Entry'")
    gpu.set(self.xPos+2, self.yPos+12, "button. On the 'Edit Entry' screen you can rename the entry, delete it, or")
    gpu.set(self.xPos+2, self.yPos+13, "change it's gate addresses.")
    -- gpu.set(self.xPos+40, self.yPos+self.height-2, "Height: "..self.height.." Width: "..self.width) -- For Debug
  end
end
-- End of Help Window --------------------------------------------------------------

localMWAddress = sg.stargateAddress.MILKYWAY
localUNAddress = sg.stargateAddress.UNIVERSE
localPGAddress = sg.stargateAddress.PEGASUS
term.clear()
MainLoop = true
readAddressFile()
GateEntriesWindow.set()

-- Creating Threads ----------------------------------------------------------------
ChildThread = {
statusThread = thread.create(function ()
  displayInfoCenter()
  while MainLoop do
    displaySystemStatus()
    os.sleep()
  end
end)
}
-- End of Thread Creation ----------------------------------------------------------

function mainInterface()
  clearDisplay()
  MainHold = true
  if glyphListWindow.glyphType ~= GateType then glyphListWindow.initialize(GateType) end
  if sg.getGateStatus == "open" then glyphListWindow.showAddress() end
  glyphListWindow.display()
  buttons.quitButton:display()
  buttons.dialButton:display()
  buttons.editButton:display()
  buttons.addEntryButton:display()
  help.visible = false
  buttons.helpButton:display()
  while MainHold do os.sleep() end
end

HadNoError = true
while MainLoop do
  mainInterface()
  if not HadNoError then
    MainLoop = false
  end
  os.sleep()
end

-- Clean Up ------------------------------------------------------------------------
term.clear()

for k,v in pairs(ChildThread) do
  v:kill()
  -- print(k..": "..v:status()) -- For Debug
end
if AlertThread ~= nil then AlertThread:kill() end

for k,v in pairs(EventListeners) do
  -- print("Canceling: "..v..":"..k) -- For Debug
  event.cancel(v)
end
-- End of Clean Up -----------------------------------------------------------------
if not HadNoError then io.stderr:write("\n"..ErrorString.."\n") end
print("Dialer Program Closed")