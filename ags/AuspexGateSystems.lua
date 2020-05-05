--[[
Created By: Augur ShicKla
v1.1.1
]]--


component = require("component")
serialization = require("serialization")
filesystem = require("filesystem")
shell = require("shell")
term = require("term")
gpu = component.gpu
internet = nil
HasInternet = component.isAvailable("internet")
if HasInternet then internet = require("internet") end

BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/release"
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
  if LogoDisplayed then term.setCursor(1, 31) end
  if HasInternet then
    print("Running in Online Mode\n")
    getReleaseVersions()
  else
    print("No Internet Card Installed")
    print("Running in Offline Mode\n")
  end
  UsersWorkingDir = shell.getWorkingDirectory()
  shell.setWorkingDirectory("/ags/")
  if SelfFileName ~= "/ags/AuspexGateSystems.lua" then
    print("The Auspex Gate Systems Launcher is running from")
    print("the wrong directory")
    print("Please use the 'ags' system command to run the")
    print("launcher.")
    forceExit(true)
  end
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
end

function saveVersionFile()
  local file = io.open("/ags/installedVersions.ff", "w")
  file:write(serialization.serialize(LocalVersions))
  file:close()
end

function compareVersions()
  if isVersionGreater(LocalVersions.launcher.ver, ReleaseVersions.launcher.ver) then
    print("Launcher needs to update, please wait.")
    downloadManifestedFiles(ReleaseVersions.launcher)
    print("Launcher has been updated and will restart")
    LocalVersions.launcher = ReleaseVersions.launcher
    saveVersionFile()
    shell.setWorkingDirectory(UsersWorkingDir)
    shell.execute("/ags/AuspexGateSystems.lua")
    forceExit(true)
  end
  if LocalVersions.dialer == nil or isVersionGreater(LocalVersions.dialer.ver, ReleaseVersions.dialer.ver) then
    print("There is a new version of the Dialer. ")
    changelogShow()
    io.write("Would you like to update, yes or no? ")
    local userInput = io.read("*l")
    if (userInput:lower()):sub(1,1) == "y" then
      print("Updating Dialer Program, Please Wait")
      downloadManifestedFiles(ReleaseVersions.dialer)
      print("Dialer Program Has Been Updated")
      LocalVersions.dialer = ReleaseVersions.dialer
      saveVersionFile()
    end
  end
  checkForDialer()
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

function checkForDialer()
  if not filesystem.exists("/ags/SG_Dialer.lua") then
    print("Dialer program will now be installed.")
    changelogShow()
    io.write("Press Enter to Continue ")
    io.read("*l")
    print("Installing Dialer Program, Please Wait")
    downloadManifestedFiles(ReleaseVersions.dialer)
    print("Dialer Program Has Been Installed")
    LocalVersions.dialer = ReleaseVersions.dialer
    saveVersionFile()
  end
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

term.clear()
initialization()
readVersionFile()
compareVersions()

print("Launching Dialer")
dofile("/ags/SG_Dialer.lua")

shell.setWorkingDirectory(UsersWorkingDir) -- Returns the user back to their original working directory