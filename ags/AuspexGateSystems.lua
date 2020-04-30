--[[
Created By: Augur ShicKla
v1.1.0
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

BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/dev"
ReleaseVersionsFile = "/ags/releaseVersions.ff"
ReleaseVersions = nil
LocalVersions = nil
DialerFound = false
UsersWorkingDir = nil
DisplayChangeLog = false
SelfFileName = string.sub(debug.getinfo(2, "S").source, 2)

function initialization()
  if not filesystem.isDirectory("/ags") then
    -- print("Creating \"/ags\" directory") -- For Debug
    local success, msg = filesystem.makeDirectory("/ags")
    if success == nil then
      io.stderr:write("Failed to created \"/ags\" directory, "..msg)
      forceExit(false)
    end
  end
  displayLogo()
  if HasInternet then
    print("Running in Online Mode\n")
    getReleaseVersions()
  else
    print("No Internet Card Installed")
    print("Running in Offline Mode\n")
  end
  UsersWorkingDir = shell.getWorkingDirectory()
  shell.setWorkingDirectory("/ags/")
  if not filesystem.exists("/bin/ags.lua") then
    local agsBinFile = {"shell = require(\"shell\")",
                        "filesystem = require(\"filesystem\")",
                        "if filesystem.exists(\"/ags/AuspexGateSystems.lua\") then",
                        "  shell.execute(\"/ags/AuspexGateSystems.lua\")",
                        "else",
                        "  io.stderr:write(\"Auspex Gate Systems is Not Correctly Installed\\n\")",
                        "end"}
    local file = io.open("/bin/ags.lua", "w")
    for i,v in ipairs(agsBinFile) do file:write(v.."\n") end
    file:close()
  end 
  if SelfFileName ~= "/ags/AuspexGateSystems.lua" then
    print("The Auspex Gate Systems Launcher is running from")
    print("the wrong directory")
    if not filesystem.exists("/ags/AuspexGateSystems.lua") then
        print("Launcher will be copied to \"/ags\"")
        local success, msg = filesystem.copy(SelfFileName, "/ags/AuspexGateSystems.lua")
        if success == nil then
          io.stderr:write(msg)
          forceExit(false)
        end
    end
    print("Please use the 'ags' system command to run the")
    print("launcher.")
    forceExit(true)
  end
  if not filesystem.exists("/ags/gateEntries.ff") then
    if filesystem.exists(UsersWorkingDir.."/gateEntries.ff") then
      print("Your gateEntries.ff file will be copied to")
      print("\"/ags\", and your old file will no longer be used.")
      io.write("Press Enter to Continue ")
      io.read()
      local success, msg = filesystem.copy(UsersWorkingDir.."/gateEntries.ff", "/ags/gateEntries.ff")
      if success == nil then
        io.stderr:write(tostring(msg))
        forceExit(false)
      end
    end
  end
end

function displayLogo()
  if not filesystem.exists("/ags/AuspexLogo.ff") and HasInternet then
    downloadFile("/ags/AuspexLogo.ff")
  elseif not HasInternet then
    return
  end
  if gpu.maxResolution() >= 160 then
    term.setCursor(1, 31)
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
  if isVersionGreater(LocalVersions.dialer.ver, ReleaseVersions.dialer.ver) then
    print("There is a new version of the Dialer. ")
    changelogShow()
    io.write("Would you like to update, yes or no? ")
    local userInput = io.read(1)
    if userInput:lower() == "y" then
      print("Downloading Dialer Program, Please Wait")
      downloadManifestedFiles(ReleaseVersions.dialer)
      print("Dialer Program Has Been Downloaded")
      LocalVersions.dialer = ReleaseVersions.dialer
      saveVersionFile()
    end
  else
    checkForDialer()
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

function checkForDialer()
  DialerFound = filesystem.exists("/ags/SG_Dialer.lua")
  if not DialerFound then
    if DisplayChangeLog then
      changelogShow()
      io.write("Press Enter to Continue ")
      io.read()
    end
    print("Downloading Dialer Program, Please Wait")
    downloadManifestedFiles(ReleaseVersions.dialer)
    print("Dialer Program Has Been Downloaded")
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
  for i,v in ipairs(program.manifest) do downloadFile(v) end
end

function downloadFile(fileName)
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
if ReleaseVersions ~= nil then compareVersions() end


print("Launching Dialer")
dofile("/ags/SG_Dialer.lua")

shell.setWorkingDirectory(UsersWorkingDir) -- Returns the user back to their original working directory