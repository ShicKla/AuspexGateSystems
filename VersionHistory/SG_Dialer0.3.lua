--[[
Created By: Augur ShicKla
v0.3

System Requirements:
Tier 3.5+ Memory
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
sg = c.stargate

-- Check that GPU and Screen
-- will have a high enough resolution
if gpu.maxResolution() ~= 160 then
  io.stderr:write("Tier 3 GPU and Screen Required")
  return
end
if computer.totalMemory() < 1048576 then
  io.stderr:write("Not Enough Memory Memory To Run. Please Install More Memory.")
  return
end

glyphsMW = {"Monoceros", "Centaurus", "Scorpius", "Sculptor", "Bootes", "Virgo", "Pisces", "Scutum", "Sextans", "Sagittarius", "Hydra", "Leo Minor", "Eridanus", "Libra", "Aries", "Serpens Caput", "Andromeda", "Pegasus", "Cetus", "Leo", "Gemini", "Corona Australis", "Auriga", "Piscis Austrinus", "Orion", "Lynx", "Capricornus", "Canis Minor", "Taurus", "Norma", "Cancer", "Perseus", "Crater", "Equuleus", "Microscopium", "Aquarius", "Triangulum"}
glyphsPG = {"Acjesis", "Lenchan", "Alura", "Ca Po", "Laylox", "Ecrumig", "Avoniv", "Bydo", "Aaxel", "Aldeni", "Setas", "Arami", "Danami", "Poco Re", "Robandus", "Recktic", "Zamilloz", "Subido", "Dawnre", "Salma", "Hamlinto", "Elenami", "Tahnan", "Zeo", "Roehi", "Once El", "Baselai", "Sandovi", "Illume", "Amiwill", "Sibbron", "Gilltin", "Abrin", "Ramnon", "Olavii", "Hacemill"}

gateType = ""
gateTypeName = ""
databaseFile = "gateEntries.ff"
gateEntries = {}
addressBuffer = {}
keyCombo = {}
Button = {}
Button.__index = Button
activeButtons = {}
gateName = ""
stopRequest = false
addAddressMode = false
adrEntryType = ""
dialingMode = false
editGateEntryMode = false
manualAdrEntryMode = false
isDirectDialing = false
abortDialing = false
isGateOpen = false
areEntriesDisplayed = false
wasCanceled = false
glyphListWindow = {xPos=term.window.width, yPos=2, width=0, height=0, locked=false}
gateEntriesWindow = {xPos=0, yPos=0, width=0, height=0, isDisplayed=false, localAddress = {}, range = {height= 0, bot=1, top=1}, currentIndices = {}, selectedIndex = 0}

-- Pre-Initialization --------------------------------------------------------------
if sg.getGateType() == "MILKYWAY" then
  gateType = "MW"
  gateTypeName = "Milky Way"
elseif sg.getGateType() == "UNIVERSE" then
  gateType = "UN"
  gateTypeName = "Universe"
elseif sg.getGateType() == "PEGASUS" then
  gateType = "PG"
  gateTypeName = "Pegasus"
else
  io.stderr:write("Gate Type Not Recognized")
  return
end

if sg.getGateStatus() == "open" then isGateOpen = true end

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
  table.insert(activeButtons, 1, self)
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
  for i,v in ipairs(activeButtons) do
    if v == self then table.remove(activeButtons, i) end
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
  table.insert(gateEntries, ge)
end

function readAddressFile()
  gateEntries = {}
  local file = io.open(databaseFile, "r")
  if file == nil then
    file = io.open(databaseFile, "w")
    file:close()
  end
  dofile(databaseFile)
end
-- End of Pre-Initialization -------------------------------------------------------

-- Special Functions ---------------------------------------------------------------
function writeToDatabase()
  local file = io.open(databaseFile, "w")
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
  gpu.fill(41, 2, 102, 42, " ")
end

function checkGlyph(glyph, adrType)
  local isGood = false
  local fixedGlyph = ""
  local glyphsTbl = {}
  if adrType == "UN" then
    for i=1,36,1 do
      if string.lower(glyph) == "g"..i or string.lower(glyph) == "glyph "..i then
        fixedGlyph = "G"..i
        isGood = true
        break
      end
    end
  else
    if adrType == "MW" then
      glyphsTbl = glyphsMW
    elseif adrType == "PG" then
      glyphsTbl = glyphsPG
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
  if #entriesTable ~= 0 then
    if pos > 6 then
      hasDuplicate = true
      for i,v in ipairs(entriesTable) do table.insert(duplicateNames, v.name) end
    else
      for i,v in ipairs(entriesTable) do
        if v.gateAddress[adrType] ~= nil and #v.gateAddress[adrType] ~= 0 then
          if adr[pos] == v.gateAddress[adrType][pos] then
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
  for w in string.gmatch(string.gsub(adrStr, "%p", ""), "%w+") do
    if w ~= "G17" then table.insert(adrBuf, w) end
  end
  for i,v in ipairs(adrBuf) do
    _,adrBuf[i] = checkGlyph(v, adrType)
  end
  return adrBuf
end
-- End of Special Functions --------------------------------------------------------

-- Info Center ---------------------------------------------------------------------
function displayInfoCenter()
  gpu.setBackground(0x000000)
  if sg.getGateStatus() == "open" and not buttons.closeGateButton.visible then buttons.closeGateButton:display() end
  if sg.getGateStatus() == "idle" and buttons.closeGateButton.visible then buttons.closeGateButton:hide() end
  gpu.fill(1, term.window.height-6, term.window.width, 1, "═")
  gpu.fill(1, term.window.height-5, 1, 4, "║")
  gpu.fill(46, term.window.height-5, 1, 4, "║")
  gpu.fill(term.window.width, term.window.height-5, 1, 4, "║")
  gpu.fill(1, term.window.height-1, term.window.width, 1, "═")
  gpu.set(1, term.window.height-6, "╔╡System Status╞")
  if isGateOpen ~= nil then
    gpu.set(33, term.window.height-6, "╡")
    gpu.set(45, term.window.height-6, "╞")
    gpu.setForeground(0x000000)
    if isGateOpen then
      gpu.setBackground(0xFFFF00)
      gpu.set(34, term.window.height-6, " GATE OPEN ")
    else
      gpu.setBackground(0x00FF00)
      gpu.set(34, term.window.height-6, "GATE CLOSED")
    end
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
  end
  gpu.set(46, term.window.height-6, "╦")
  gpu.set(47, term.window.height-6, "╡This Stargate's Addresses╞")
  gpu.set(term.window.width, term.window.height-6, "╗")
  gpu.set(1, term.window.height-1, "╚")
  gpu.set(46, term.window.height-1, "╩")
  gpu.set(term.window.width, term.window.height-1, "╝")
  displayLocalAddress(48,term.window.height-5)
  displaySystemStatus(2,term.window.height-5)
  gpu.set(140, 43, "Ctrl+Q to Force Quit")
end

function displaySystemStatus(xPos,yPos)
  local energyStored = sg.getEnergyStored()
  local energyMax = sg.getMaxEnergyStored()
  local capCount = sg.getCapacitorsInstalled()
  local freeMemory = computer.freeMemory()
  local totalComputerMemory = computer.totalMemory()
  local gateStatus = sg.getGateStatus()
  gpu.fill(xPos, yPos, 44, 4, " ")
  gpu.set(xPos+1, yPos, "Energy Level: "..energyStored.."/"..energyMax.." RF "..math.floor((energyStored/energyMax)*100).."%")
  gpu.set(xPos+1, yPos+1, "Capacitors Installed: "..capCount.."/3")
  gpu.set(xPos+1, yPos+2, "Computer Memory Remaining: "..math.floor((freeMemory/totalComputerMemory)*100).."%")
  -- gpu.set(xPos+1, yPos+3, "Gate Status: "..gateStatus) -- For Debug
end

function displayLocalAddress(xPos,yPos)
  gpu.set(xPos, yPos, "Milky Way "..addressToString(localMWAddress))
  gpu.set(xPos, yPos+1, "Universe  "..addressToString(localUNAddress))
  gpu.set(xPos, yPos+2, "Pegasus   "..addressToString(localPGAddress))
end

function alert(msg, lvl)
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
end
-- End of Info Center --------------------------------------------------------------

-- gateEntriesWindow ---------------------------------------------------------------
function gateEntriesWindow.increment(inc)
  local self = gateEntriesWindow
  if self.isDisplayed then
    if (self.range.top + inc) > #gateEntries or (self.range.bot + inc) < 1 then
      return
    else
      self.range.bot = self.range.bot + inc
      self.range.top = self.range.top + inc
      self.display()
    end
  end
end

function gateEntriesWindow.set(xPos, yPos, width, height)
  local self = gateEntriesWindow
  gpu.fill(xPos, yPos, width, height, " ")
  self.entries = {}
  self.xPos = xPos
  self.yPos = yPos
  self.width = width
  self.height = height
  self.range.bot = 1
  self.range.height = self.height - 2
  self.range.top = self.range.height
  if gateType == "MW" then self.localAddress = localMWAddress
  elseif gateType == "UN" then self.localAddress = localUNAddress
  elseif gateType == "PG" then self.localAddress = localPGAddress
  end
  self.loadStrings()
  local scrollNote = "╡Scroll with PgUp/PgDn╞"
  if width < unicode.len(scrollNote) + 1 then width = unicode.len(scrollNote) + 1 end
  if xPos > term.window.width - width then xPos = term.window.width - width + 1 end
  gpu.fill(xPos, yPos, width, 1, "═")
  gpu.fill(xPos, yPos+1, 1, gateEntriesWindow.range.height, "║")
  gpu.fill(xPos+width, yPos+1, 1, gateEntriesWindow.range.height, "║")
  gpu.fill(xPos, yPos+height-1, width, 1, "═")
  gpu.set(xPos, yPos, "╔╡Gate Entries╞")
  gpu.set(xPos+width, yPos, "╗")
  gpu.set(xPos, yPos+height-1, "╚")
  gpu.set(xPos+width, yPos+height-1, "╝")
  if #gateEntries > gateEntriesWindow.range.height then
    gpu.set(xPos+1, yPos+height-1, scrollNote)
  end
  self.display()
end

function gateEntriesWindow.loadStrings()
  local self = gateEntriesWindow
  local strBuf = ""
  self.entryStrings = {}
  for i,v in ipairs(gateEntries) do
    strBuf = v.name
    if entriesDuplicateCheck(self.localAddress, {v}, gateType, 1) then
      strBuf = strBuf.." [This Stargate]"
    elseif v.gateAddress[gateType] ~= nil and #v.gateAddress[gateType] ~= 0 then
      strBuf = strBuf.." ("..#v.gateAddress[gateType].." Glyphs)"
    else
      strBuf = strBuf.." [Empty "..gateType.." Address]"
    end
    if unicode.len(strBuf) > self.width-5 then strBuf = unicode.wtrunc(strBuf, self.width-6) end
    table.insert(self.entryStrings, strBuf)
  end
end

function gateEntriesWindow.display()
  local self = gateEntriesWindow
  local xPos = gateEntriesWindow.xPos
  local yPos = gateEntriesWindow.yPos
  local width = gateEntriesWindow.width
  local height = gateEntriesWindow.height
  gpu.fill(xPos+1, yPos+1, width-1, gateEntriesWindow.range.height, " ")
  gateEntriesWindow.currentIndices = {}
  local displayCount = 0
  for i,v in ipairs(self.entryStrings) do
    if i >= self.range.bot and i <= self.range.top then
      displayCount = displayCount + 1
      self.currentIndices[displayCount] = i
      gpu.set(xPos + 2, yPos + displayCount, tostring(i))
      if i == self.selectedIndex then gpu.setBackground(0x878787) end
      gpu.set(xPos + 6, yPos + displayCount, v)
      gpu.setBackground(0x000000)
    end
  end
end

function gateEntriesWindow.touch(x, y)
  local self = gateEntriesWindow
  if not dialingMode and not addAddressMode and not editGateEntryMode then
    if x > self.xPos and x < (self.xPos+gateEntriesWindow.width-2) and y > self.yPos and y < (self.yPos+self.height-2) then
      self.selectedIndex = self.currentIndices[y - self.yPos]
      if self.selectedIndex > #gateEntries then self.selectedIndex = 0 end
      self.display()
    end
  end
end
-- End gateEntriesWindow ----------------------------------------------------------------

-- Glyph List Window --------------------------------------------------------------------
function glyphListWindow.initialize(glyphType)
  local self = glyphListWindow
  self.glyphType = glyphType
  self.glyphs = nil
  self.selectedGlyphs = {}
  if glyphType == "MW" then
    self.glyphs = glyphsMW
  elseif glyphType == "UN" then
    self.glyphs = {}
    for i=1,36,1 do
      if i ~= 17 then table.insert(self.glyphs, "Glyph "..i) end
    end
  elseif glyphType == "PG" then
    self.glyphs = glyphsPG
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
    if not dialingMode and not dhdDialing then
      local resetButton = buttons.glyphResetButton
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
  if not dialingMode and not dhdDialing and not dhdAdrEntryMode and not dialerAdrEntryMode and not self.locked then
    if x > self.xPos and x < self.xPos+self.width-1 and y > self.yPos and y < self.yPos+self.height-1 then
      local selection = y-self.yPos-2
      local newSelection = true
      for i,v in ipairs(self.selectedGlyphs) do
        if selection == v then newSelection = false end
      end
      if newSelection and #self.selectedGlyphs < 9 then
        if selection ~= 0 and #self.selectedGlyphs < 8 then
          computer.beep()
          table.insert(self.selectedGlyphs, selection)
        end
        self.display()
        if selection == -1 then
          computer.beep()
          addressBuffer = {}
          local glyph = ""
          for i,v in ipairs(self.selectedGlyphs) do
            if v ~= -1 then
              glyph = self.glyphs[v]
              if adrEntryType == "UN" then _,glyph = checkGlyph(glyph, "UN") end
              table.insert(addressBuffer, glyph)
            end
          end
          if #addressBuffer >= 6 then
            if addAddressMode then 
              completeAddressEntry(self.glyphType)
            else
              directDial()
            end
            self.reset()
          else
            addressBuffer = {}
            table.remove(self.selectedGlyphs)
            self.display()
            alert("ADDRESS IS TOO SHORT", 2)
          end
        end
      end
    end
  end
end

function glyphListWindow.reset()
  local self = glyphListWindow
  self.selectedGlyphs = {}
  addressBuffer = {}
  buttons.glyphResetButton:hide()
  self.display()
end
-- End of Glyph List Window -------------------------------------------------------------

-- Direct Dialing -----------------------------------------------------------------------
function directDial()
  local glyph = ""
  if not isDirectDialing then isDirectDialing = true end
  local directEntry = {name="Direct Dial", gateAddress={}}
  directEntry.gateAddress[gateType] = addressBuffer
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

function dialAddress(adr)
  if adr == nil then return end
  addressBuffer = {}
  clearDisplay()
  buttons.abortDialingButton:display()
  dialingMode = true
  abortDialing = false
  local localAddress = nil
  if gateType == "MW" then localAddress = localMWAddress
  elseif gateType == "UN" then localAddress = localUNAddress
  elseif gateType == "PG" then localAddress = localPGAddress
  end
  if adr.gateAddress[gateType] == nil or #adr.gateAddress[gateType] == 0 then
    alert("CAN NOT DIAL DUE TO NO GATE ADDRESS ENTRY", 2)
    dialingMode = false
    return
  end
  if sg.getGateStatus() == "open" then
    alert("CAN NOT DIAL DUE TO STARGATE BEING OPEN", 2)
    dialingMode = false
    return
  end
  if dhdDialing then
    alert("CAN NOT DIAL WHILE DHD IS IN USE", 2)
    dialingMode = false
    return
  end
  for i,v in ipairs(adr.gateAddress[gateType]) do table.insert(addressBuffer, v) end
  if entriesDuplicateCheck(localAddress, {adr}, gateType, 1) then
    alert("GATE CAN NOT DIAL ITSELF", 2)
    dialingMode = false
    return
  end
  if not isDirectDialing then
    for i,v in ipairs(addressBuffer) do
      if gateType ~= "UN" then
        for i2,v2 in ipairs(glyphListWindow.glyphs) do
          if v == v2 then table.insert(glyphListWindow.selectedGlyphs, i2) end
        end
      end
    end
    glyphListWindow.display()
  end
  if gateType == "MW" then
    table.insert(addressBuffer,"Point of Origin")
  elseif gateType == "UN" then
    table.insert(addressBuffer,"G17")
  end
  dialNext(0)
  while dialingMode do
    dialAddressWindow.display(adr)
    os.sleep(0.05)
  end
  dialingMode = false
  isDirectDialing = false
  mainHold = false
end

function dialNext(dialed)
  if not abortDialing then
    glyph = addressBuffer[dialed + 1]
    dialAddressWindow.glyph = glyph
    sg.engageSymbol(glyph)
  else
    sg.engageGate()
    alert("DIALING ABORTED", 2)
    dialingMode = false
    abortDialing = false
    mainHold = false
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
  if gateType == "MW" and adrType == "MW" then
    buttons.dhdEntryButton:display()
  elseif gateType == "UN" and adrType == "UN" then
    buttons.dialerEntryButton:display()
  else
    manualAddressEntry()
  end
  gpu.set(42, 6, "Select one of the below options to enter the address.")
end

function addNewGateEntry()
  glyphListWindow.reset()
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
  glyphListWindow.locked = true
  local index = nil
  local addressName = ""
  local userInput = ""
  local isDuplicate, duplicateNames = entriesDuplicateCheck(addressBuffer, gateEntries, adrType, 1)
  if editGateEntryMode then index = gateEntriesWindow.selectedIndex end
  if index ~= nil and index > 0 then addressName = gateEntries[index].name end
  for i,v in ipairs(duplicateNames) do
    if v == addressName then table.remove(duplicateNames, i) end
  end
  if #duplicateNames == 0 then isDuplicate = false end
  if isDuplicate then
    alert("",2)
    gpu.set(42, 20, "Possible duplicate address with the following gate entries:")
    term.setCursor(42, 21)
    for i,v in ipairs(duplicateNames) do
      io.write("'"..v.."'")
      if i ~= #duplicateNames then io.write(", ") end
    end
    gpu.set(42, 22, "Would you still like to have the address entered? [y]es/[n]o: ")
    term.setCursor(104, 22)
    userInput = string.lower(io.read(3))
    if userInput == 'n' then
      alert("ADDRESS ENTRY CANCELED", 1)
      addAddressMode = false
      manualAdrEntryMode = false
      return
    end
  end
  if index ~= nil and index > 0 then
    gateEntries[index].gateAddress[adrType] = {}
    for i,v in ipairs(addressBuffer) do table.insert(gateEntries[index].gateAddress[adrType], v) end
    writeToDatabase()
    alert("ADDRESS HAS BEEN CHANGED", 1)
  else
    gpu.set(42, 23, "Please enter a name for the address: ")
    term.setCursor(79, 23)
    local addressName = io.read()
    if addAddress == "" then addressName = "unknown" end
    table.insert(gateEntries, {name=addressName, gateAddress={[adrType]=addressBuffer}})
    writeToDatabase()
    alert("NEW ADDRESS HAS BEEN ADDED", 1)
    manualAdrEntryMode = false
    dialerAdrEntryMode = false
    dhdAdrEntryMode = false
    mainHold = false
  end
  glyphListWindow.locked = false
  addAddressMode = false
  manualAdrEntryMode = false
  if editGateEntryMode then
    editGateEntry(index)
  end
end

function dhdAddressEntry()
  alert("", -1)
  local allGood = true
  dhdAdrEntryMode = true
  clearDisplay()
  buttons.cancelButton:display()
  gpu.set(42, 6, "Use the DHD to dial the glyphs of the address, excluding the 'Point of Origin'.")
  gpu.set(42, 7, "Then hit the 'Big Red Button'")
  while dhdAdrEntryMode do
    os.sleep(0.01)
    if wasCanceled then
      allGood = false
      wasCanceled = false
      break
    end
  end
  if allGood then
    addressBuffer = {}
    local glyph = ""
    for i,v in ipairs(glyphListWindow.selectedGlyphs) do
      if v ~= -1 then
        glyph = glyphListWindow.glyphs[v]
        if gateType == "UN" then _,glyph = checkGlyph(glyph, "UN") end
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
  while true do
    os.sleep(0.01)
    if wasCanceled then
      allGood = false
      wasCanceled = false
      break
    end
    if not dialing and sg.getGateStatus() == "dialing" then dialing = true end
    if dialing then
      alert("PLEASE WAIT", 0)
      os.sleep(0.5)
      alert("", -1)
      os.sleep(0.25)
      if sg.getGateStatus() == "idle" then
        alert("DIALING WAS ABORTED BY DIALER", 2)
        allGood = false
        break
      elseif sg.getGateStatus() == "open" then
        break
      end
    end
  end
  if allGood then
    addressBuffer = parseAddressString(sg.dialedAddress, "UN")
    sg.disengageGate()
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
    glyphListWindow.initialize(adrEntryType)
    gpu.set(42, 6, "Enter the address using the glyphs to the right. Then hit 'Origin' to complete.")
  end
end
-- End of Address Entry ------------------------------------------------------------

-- Edit Gate Entry -----------------------------------------------------------------
function deleteGateEntry(value)
  if value == 0 then
    buttons.deleteYesButton:display()
    buttons.deleteNoButton:display()
  elseif value == 1 then
    local index = gateEntriesWindow.selectedIndex
    alert("GATE ENTRY '"..gateEntries[index].name.."' REMOVED", 1)
    table.remove(gateEntries, index)
    writeToDatabase()
    glyphListWindow.locked = false
    editGateEntryMode = false
    mainHold = false
  elseif value == -1 then
    buttons.deleteYesButton:hide()
    buttons.deleteNoButton:hide()
    alert("DELETE CANCELED", 1)
  end
end

function editGateEntry(index)
  local gateEntry = gateEntries[index]
  if gateEntry == nil then
    alert("SELECT A GATE ENTRY TO EDIT", 2)
    return
  end
  glyphListWindow.reset()
  glyphListWindow.locked = true
  editGateEntryMode = true
  clearDisplay()
  buttons.cancelButton:display()
  buttons.renameButton:display()
  buttons.deleteButton:display()
  if gateEntry.gateAddress.MW == nil then gateEntry.gateAddress["MW"] = {} end
  if gateEntry.gateAddress.UN == nil then gateEntry.gateAddress["UN"] = {} end
  if gateEntry.gateAddress.PG == nil then gateEntry.gateAddress["PG"] = {} end
  gpu.set(42, 5, "Name: "..gateEntry.name)
  gpu.set(42, 6, "Addresses:")
  gpu.set(42, 7, "│   ░░░░░░░░░    │  │    ░░░░░░░░    │  │    ░░░░░░░     │")
  gpu.set(42, 8, "├────────────────┤  ├────────────────┤  ├────────────────┤")
  buttons.addressEntry_MW_Button.border = false
  buttons.addressEntry_UN_Button.border = false
  buttons.addressEntry_PG_Button.border = false
  buttons.addressEntry_MW_Button:display(45, 6)
  buttons.addressEntry_UN_Button:display(66, 6)
  buttons.addressEntry_PG_Button:display(86, 6)
  for i,v in ipairs(gateEntry.gateAddress.MW) do
    gpu.set(42, 8+i, "│")
    gpu.set(42+(9-math.floor(unicode.len(v)/2)), 8+i, v)
    gpu.set(59, 8+i, "│")
  end
  for i,v in ipairs(gateEntry.gateAddress.UN) do
    gpu.set(62, 8+i, "│")
    gpu.set(62+(9-math.floor(unicode.len(v)/2)), 8+i, v)
    gpu.set(79, 8+i, "│")
  end
  for i,v in ipairs(gateEntry.gateAddress.PG) do
    gpu.set(82, 8+i, "│")
    gpu.set(82+(9-math.floor(unicode.len(v)/2)), 8+i, v)
    gpu.set(99, 8+i, "│")
  end
end

function renameGateEntry(index)
  local newName = ""
  local oldName = gateEntries[index].name
  gpu.fill(48, 5, 20, 1, " ")
  term.setCursor(48, 5)
  newName = io.read()
  if newName ~= "" then
    gateEntries[index].name = newName
  end
  alert("\""..oldName.."\" HAS BEEN RENAMED TO \""..gateEntries[index].name.."\"", 1)
  gpu.set(48, 5, gateEntries[index].name)
  writeToDatabase()
end
-- End Edit Gate Entry -------------------------------------------------------------

-- Event Section -------------------------------------------------------------------
dhdChevronEngaged = event.listen("stargate_dhd_chevron_engaged", function(evname, address, caller, symbolCount, lock, symbolName)
  if not dialingMode and not manualAdrEntryMode then
    dhdDialing = true
    for i,v in ipairs(glyphListWindow.glyphs) do
      if symbolName == v then table.insert(glyphListWindow.selectedGlyphs, i) end
    end
    glyphListWindow.display()
  end
  if dialingMode then
    abortDialing = true
  end
end)

eventSpinEngaged = event.listen("stargate_spin_chevron_engaged", function(evname, address, caller, num, lock, glyph)  
  if dialingMode then
    if lock then
      sg.engageGate()
      os.sleep(0.5)
      dialingMode = false
    else
      alert("CHEVRON "..math.floor(num).." ENGAGED", 0)
      os.sleep(0.5)
      dialNext(num)
    end
  end
end)

openEvent = event.listen("stargate_open", function(evname, address, caller, isInitiating)
  isGateOpen = true
end)

closeEvent = event.listen("stargate_close", function()
  isGateOpen = false
  alert("CONNECTION HAS CLOSED", 1)
  buttons.closeGateButton.visible = false
end)

incomingEvent = event.listen("stargate_incoming_wormhole", function()
  alert("INCOMING WORMHOLE", 2)
end)

failEvent = event.listen("stargate_failed", function(evname, address, caller, reason)
  if not addAddressMode and not dhdAddressEntry then
    if reason == "address_malformed" then
      alert("UNABLE TO ESTABLISH CONNECTION", 3)
    elseif reason == "not_enough_power" then
      alert("NOT ENOUGH POWER TO CONNECT", 3)
    end
    dialingMode = false
    glyphListWindow.reset()
  end
  dhdDialing = false
  if dhdAdrEntryMode then dhdAdrEntryMode = false end
  isGateOpen = false
  
end)

keyDownEvent = event.listen("key_down", function(evname, keyboardAddress, chr, code, playerName)
  table.insert(keyCombo, code)
  if #keyCombo > 1 and (keyCombo[1] == 29 and keyCombo[2] == 16) then -- Ctrl+Q to Completely Exit
    wasCanceled = true
    mainLoop = false
    mainHold = false
  end 
end)

keyUpEvent = event.listen("key_up", function(evname, keyboardAddress, chr, code, playerName)
  keyCombo = {}
end)

touchEvent = event.listen("touch", function(evname, screenAddress, x, y, button, playerName)
  -- gpu.fill(1, 43, 20, 1, " ") -- For Debug
  -- gpu.set(1, 43, x..", "..y)  -- For Debug
  if button == 0 then
    for i,v in ipairs(activeButtons) do
      if v:touch(x,y) then break end
    end
    glyphListWindow.touch(x, y)
  end
end)
-- End of Event Section ------------------------------------------------------------

-- Buttons -------------------------------------------------------------------------
buttons = {
  quitButton = Button.new(73, 2, 0, 3, "Quit", function()
    mainLoop = false
    mainHold = false
  end),
  dialButton = Button.new(41, 2, 0, 3, "Dial", function()
    glyphListWindow.reset()
    if not isGateOpen and not dialingMode and not isDirectDialing then
      if gateEntriesWindow.selectedIndex ~= 0 or gateEntriesWindow.selectedIndex > #gateEntries then
        dialAddress(gateEntries[gateEntriesWindow.selectedIndex])
      end
      mainHold = false
      dialingMode = false
    end
  end),
  editButton = Button.new(60, 2, 0, 3, "Edit Entry", function()
    if not isGateOpen and not dialingMode and not isDirectDialing then
      editGateEntry(gateEntriesWindow.selectedIndex)
    end
  end),
  renameButton = Button.new(42, 20, 0, 3, "Rename Entry", function()
    renameGateEntry(gateEntriesWindow.selectedIndex)
  end),
  deleteButton = Button.new(57, 20, 0, 3, "Delete Entry", function()
    deleteGateEntry(0)
  end),
  deleteYesButton = Button.new(57, 22, 0, 3, "Yes", function()
    deleteGateEntry(1)
  end, false),
  deleteNoButton = Button.new(57, 24, 0, 3, "No", function()
    deleteGateEntry(-1)
  end, false),
  closeGateButton = Button.new(80, 2, 0, 3, "Close Gate", function()
    local s,f = sg.disengageGate()
    if f == "stargate_failure_wrong_end" then
      alert("CAN NOT CLOSE AN INCOMING CONNECTION", 2)
      isGateOpen = true
    elseif f == "stargate_failure_not_open" then
      alert("GATE IS NOT OPEN", 1)
      isGateOpen = false
    end
    buttons.closeGateButton:hide()
  end),
  addEntryButton = Button.new(48, 2, 0, 3, "Add Entry", function()
    addNewGateEntry()
  end),
  abortDialingButton = Button.new(41, 2, 0, 3, "Abort Dialing", function()
    abortDialing = true
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
    wasCanceled = true
    editGateEntryMode = false
    addAddressMode = false
    manualAdrEntryMode = false
    editGateEntryMode = false
    mainHold = false
  end),
}
-- End Buttons ---------------------------------------------------------------------

localMWAddress = parseAddressString(sg.stargateAddress.MILKYWAY, "MW")
localUNAddress = parseAddressString(sg.stargateAddress.UNIVERSE, "UN")
localPGAddress = parseAddressString(sg.stargateAddress.PEGASUS, "PG")

term.clear()
mainLoop = true
readAddressFile()
function mainInterface()
  clearDisplay()
  mainHold = true
  gateEntriesWindow.set(1, 2, 38, 40)
  gateEntriesWindow.isDisplayed = true
  glyphListWindow.initialize(gateType)
  buttons.quitButton:display()
  buttons.dialButton:display()
  buttons.editButton:display()
  buttons.addEntryButton:display()
  while mainHold do os.sleep(0.01) end
end

-- Creating Threads -------------------------------------------------------------------------
statusThread = thread.create(function ()
  while mainLoop do
    displayInfoCenter()
    os.sleep(0.01)
  end
end)

entriesDisplayedThread = thread.create(function()
  local keyUpEvent = event.listen("key_up", function(evname, keyboardAddress, chr, code, playerName)
    if code == 201 and gateEntriesWindow.isDisplayed then gateEntriesWindow.increment(-1) end -- PgUp
    if code == 209 and gateEntriesWindow.isDisplayed then gateEntriesWindow.increment(1) end  -- PgDn
  end)
  local mouseWheelEvent = event.listen("scroll", function(evname, screenAddress, x, y, direction, playerName)
    if gateEntriesWindow.isDisplayed then
      gateEntriesWindow.increment(direction*-1)
    end
  end)
  local touchEvent = event.listen("touch", function(evname, screenAddress, x, y, button, playerName)
    gateEntriesWindow.touch(x, y)
  end)
  
  while mainLoop do os.sleep(0.01) end
  event.cancel(keyUpEvent)
  event.cancel(mouseWheelEvent) 
end)
-- End of Thread Creation --------------------------------------------------------------------------------

hadNoError = true
while mainLoop do
  mainInterface()
  if hadNoError == false then
    mainLoop = false
    io.stderr:write("\n"..err.."\n")
  end
  os.sleep(0.05)
end

-- Clean Up ------------------------------------------------------------------------
statusThread:kill()
entriesDisplayedThread:kill()

if hadNoError then term.clear() end

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)

event.cancel(dhdChevronEngaged)
event.cancel(failEvent)
event.cancel(eventSpinEngaged)
event.cancel(openEvent)
event.cancel(closeEvent)
event.cancel(incomingEvent)
event.cancel(keyDownEvent)
event.cancel(keyUpEvent)
event.cancel(touchEvent)
-- End of Clean Up -----------------------------------------------------------------
print("Dialer Program Closed")