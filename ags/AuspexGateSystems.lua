--[[
Created By: Augur ShicKla
v1.1.5
]]--

local computer = require("computer")
local component = require("component")
local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")
local term = require("term")
local unicode = require("unicode")
local gpu = component.gpu
local internet = nil
local HasInternet = component.isAvailable("internet")
if HasInternet then internet = require("internet") end

AGSKiosk = nil

local args, opts = shell.parse(...)

term.clear()
if opts.d then
  BranchMsg = [[
┌──────────────────────────┐
│Launcher Set to Dev Branch│
└──────────────────────────┘]]
  BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/dev"
else
  BranchMsg = ""
  BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/release"
end

if opts.k then
  computer.beep()
  AGSKiosk = true
end

ReleaseVersionsFile = "/ags/releaseVersions.ff"
ReleaseVersions = nil
LocalVersions = nil
DialerFound = false
UsersWorkingDir = nil
DisplayChangeLog = false
LogoDisplayed = false
SelfFileName = string.sub(debug.getinfo(2, "S").source, 2)

function initialization()
  displayLogo()
  if LogoDisplayed then
    term.setViewport(160, 50, 0, 31)
    -- term.setCursor(1, 31)
  end
  local yPos = 1
  for line in BranchMsg:gmatch("[^\r\n]+") do
    gpu.set(term.window.width-27, yPos, line)
    yPos = yPos + 1
  end
  if HasInternet then
    print("Running in Online Mode\n")
    getReleaseVersions()
  else
    print("No Internet Card Installed")
    print("Running in Offline Mode\n")
  end
  UsersWorkingDir = shell.getWorkingDirectory()
  shell.setWorkingDirectory("/ags/")
--  if SelfFileName ~= "/ags/AuspexGateSystems.lua" then
--    print("The Auspex Gate Systems Launcher is running from")
--    print("the wrong directory")
--    print("Please use the 'ags' system command to run the")
--    print("launcher.")
--    forceExit(true)
--  end
  if not filesystem.exists("/ags/gateEntries.ff") or filesystem.size("/ags/gateEntries.ff") == 0 then
    if filesystem.exists(UsersWorkingDir.."/gateEntries.ff") then
      print("Found a Gate Entries database file at")
      print(UsersWorkingDir.."/gateEntries.ff")
      print("That file will no longer be used by the dialer.")
      print("Would you like to copy your database file to the")
      print("AGS Install, so it can be used?")
      io.write("Yes/No: ")
      local userInput = io.read("*l")
      if (userInput:lower()):sub(1,1) == "y" then
        local success, msg = filesystem.copy(UsersWorkingDir.."/gateEntries.ff", "/ags/gateEntries.ff")
        if success == nil then
          io.stderr:write(tostring(msg))
          forceExit(false)
        end
        print("Database file has been copied")
      else
        print("Database file will not be copied")
      end      
    end
  end
end

function displayLogo()
  if not filesystem.exists("/ags/AuspexLogo.ff") then
    if HasInternet then
      downloadFile("/ags/AuspexLogo.ff")
    else
      return
    end
  end
  if gpu.maxResolution() >= 160 then
    LogoDisplayed = true
    gpu.fill(1, 1, 160, 30, " ")
    local file = io.open("/ags/AuspexLogo.ff", "r")
    local i = 1
    for line in file:lines() do 
      gpu.set(5, 0+i, line)
      i = i+1
    end
    file:close()
  end
end

function forceExit(code)
  if UsersWorkingDir ~= nil then shell.setWorkingDirectory(UsersWorkingDir) end
  os.exit(code)
end

function getReleaseVersions()
  downloadFile(ReleaseVersionsFile)
  local file = io.open(ReleaseVersionsFile, "r")
  ReleaseVersions = serialization.unserialize(file:read("*a"))
  file:close()
end

function readVersionFile()
  local file = io.open("/ags/installedVersions.ff", "r")
  if file == nil then
    if HasInternet then
      downloadFile(ReleaseVersionsFile)
      filesystem.copy(ReleaseVersionsFile, "/ags/installedVersions.ff")
      if filesystem.exists(UsersWorkingDir.."/ags.ff") then
        filesystem.remove(UsersWorkingDir.."/ags.ff")
      end
      file = io.open("/ags/installedVersions.ff", "r")
      DisplayChangeLog = true
    else
      io.stderr("No Internet Connection, unable to acquire Versions\n")
      forceExit(false)
    end
  end
  LocalVersions = serialization.unserialize(file:read("*a"))
  file:close()
  local yPos = 1
  if opts.d then yPos = 4 end
  local verString = "Launcher: "..LocalVersions.launcher.ver
  if LocalVersions.launcher.dev then verString = verString.." Dev" end
  gpu.set(term.window.width - unicode.len(verString), yPos, verString)
  if LocalVersions.dialer ~= nil then
    verString = "Dialer: "..LocalVersions.dialer.ver
    if LocalVersions.dialer.dev then verString = verString.." Dev" end
    gpu.set(term.window.width - unicode.len(verString), yPos+1, verString)
  end
end

function saveVersionFile()
  local file = io.open("/ags/installedVersions.ff", "w")
  file:write(serialization.serialize(LocalVersions))
  file:close()
end

function launcherVersionCheck(forceDownload)
  if isVersionGreater(LocalVersions.launcher.ver, ReleaseVersions.launcher.ver) or forceDownload then
    if not forceDownload then print("Launcher needs to update, please wait.") end
    downloadManifestedFiles(ReleaseVersions.launcher)
    print("Launcher has been updated and will restart")
    LocalVersions.launcher = ReleaseVersions.launcher
    local runString = "/ags/AuspexGateSystems.lua"
    if opts.d then 
      LocalVersions.launcher.dev = true
      runString = runString.." -d"
    end
    saveVersionFile()
    shell.setWorkingDirectory(UsersWorkingDir)
    shell.execute(runString)
    forceExit(true)
  end
end

function dialerVersionCheck(forceDownload)
  if LocalVersions.dialer == nil then
    dialerNewInstall()
  elseif isVersionGreater(LocalVersions.dialer.ver, ReleaseVersions.dialer.ver) or forceDownload then
    if not forceDownload then print("There is a new version of the Dialer. ") end
    changelogShow()
    io.write("Would you like to update, yes or no? ")
    local userInput = io.read("*l")
    if (userInput:lower()):sub(1,1) == "y" then
      print("Updating Dialer Program, Please Wait")
      downloadManifestedFiles(ReleaseVersions.dialer)
      print("Dialer Program Has Been Updated")
      LocalVersions.dialer = ReleaseVersions.dialer
      if opts.d then LocalVersions.dialer.dev = true end
      saveVersionFile()
    end
  end
end

function dialerNewInstall()
  print("Dialer program will now be installed.")
  changelogShow()
  io.write("Press Enter to Continue ")
  io.read("*l")
  print("Installing Dialer Program, Please Wait")
  downloadManifestedFiles(ReleaseVersions.dialer)
  print("Dialer Program Has Been Installed")
  LocalVersions.dialer = ReleaseVersions.dialer
  if opts.d then LocalVersions.dialer.dev = true end
  saveVersionFile()
end

function compareVersions()
  if opts.d then
    if not LocalVersions.launcher.dev then
      io.write([[
┌────────────────────────────────────────────────┐
│Current installed launcher is the Release       │
│version. Do you want to install the Dev version │
│of the launcher?                                │
└────────────────────────────────────────────────┘
 Yes/No: ]])
      local userInput = io.read("*l")
      if (userInput:lower()):sub(1,1) == "y" then
        launcherVersionCheck(true)
      end
    else
      launcherVersionCheck()
    end
    
    if LocalVersions.dialer ~= nil and not LocalVersions.dialer.dev then
      io.write([[
┌────────────────────────────────────────────────┐
│Current installed dialer is the Release version.│
│Do you want to install the Dev version of the   │
│dialer?                                         │
└────────────────────────────────────────────────┘
 Yes/No: ]])
      local userInput = io.read("*l")
      if (userInput:lower()):sub(1,1) == "y" then
        dialerNewInstall()
      end
    else
      dialerVersionCheck()
    end
  else
    if LocalVersions.launcher.dev then
      io.write([[
┌────────────────────────────────────────────────┐
│Current installed launcher is the Dev version.  │
│Do you want to install the Release version of   │
│the launcher?                                   │
└────────────────────────────────────────────────┘
 Yes/No: ]])
      local userInput = io.read("*l")
      if (userInput:lower()):sub(1,1) == "y" then
        launcherVersionCheck(true)
      end
    else
      launcherVersionCheck()
    end

    if LocalVersions.dialer ~= nil and LocalVersions.dialer.dev then
      io.write([[
┌────────────────────────────────────────────────┐
│Current installed dialer is the Dev version. Do │
│you want to install the Release version of the  │
│dialer?                                         │
└────────────────────────────────────────────────┘
 Yes/No: ]])
      local userInput = io.read("*l")
      if (userInput:lower()):sub(1,1) == "y" then
        dialerNewInstall()
      end
    else
      dialerVersionCheck()
    end
  end
end

function isVersionGreater(oldVer, newVer)
  local old = {}
  local new = {}
  old[1], old[2], old[3] = string.match(oldVer, "(.*)%.(.*)%.(.*)")
  new[1], new[2], new[3] = string.match(newVer, "(.*)%.(.*)%.(.*)")
  for i=1,3 do
    if tonumber(new[i]) > tonumber(old[i]) then return true end
  end
  return false
end

function changelogShow()
  if #ReleaseVersions.dialer.note > 0 then
    print("Changes:")
    for i,v in ipairs(ReleaseVersions.dialer.note) do print("  "..v) end
    print()
  end
end

function downloadManifestedFiles(program)
  for i,v in ipairs(program.manifest) do downloadFile(v, true) end
end

function downloadFile(fileName, verbose)
  if verbose then print("Downloading..."..fileName) end
  local result = ""
  local response = internet.request(BranchURL..fileName)
  local isGood, err = pcall(function()
    local file, err = io.open(fileName, "w")
    if file == nil then error(err) end
    for chunk in response do
      file:write(chunk)
    end
    file:close()
  end)
  if not isGood then
    io.stderr:write("Unable to Download\n")
    io.stderr:write(err)
    forceExit(false)
  end
end

initialization()
readVersionFile()
if HasInternet then compareVersions() end

print("Launching Dialer")
if LogoDisplayed then term.setViewport(160,50) end
if AGSKiosk == true then
  while true do
    pcall(function() dofile("/ags/SG_Dialer.lua") end)
    print("\nRestarting AGS Please Wait")
    os.sleep(2)
  end
else
  dofile("/ags/SG_Dialer.lua")
end

shell.setWorkingDirectory(UsersWorkingDir) -- Returns the user back to their original working directory
