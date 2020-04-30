--[[
Created By: Augur ShicKla
v1.1.0
]]--


component = require("component")
serialization = require("serialization")
filesystem = require("filesystem")
shell = require("shell")
internet = nil
HasInternet = component.isAvailable("internet")
if HasInternet then internet = require("internet") end

BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/dev"
VersionsURL = BranchURL.."/ReleaseVersions.ff"
ReleaseVersions = nil
LocalVersions = nil
DialerFound = false
UsersWorkingDir = nil
SelfFileName = string.sub(debug.getinfo(2, "S").source, 2)

function initialization()
  if not filesystem.isDirectory("/ags") then
    print("Creating \"/ags\" directory")
    local success, msg = filesystem.makeDirectory("/ags")
    if success == nil then
      io.stderr:write("Failed to created \"/ags\" directory, "..msg)
      forceExit(false)
    end
  end
  UsersWorkingDir = shell.getWorkingDirectory()
  shell.setWorkingDirectory("/ags")
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
    print("the wrong directory, and it will be copied to")
    print("\"/ags\", if it does not already exist.")
    print("Please use the 'ags' system command to run the")
    print("launcher.")
    if not filesystem.exists("/ags/AuspexGateSystems.lua") then
        local success, msg = filesystem.copy(SelfFileName, "/ags/AuspexGateSystems.lua")
        if success == nil then
          io.stderr:write(msg)
          forceExit(false)
        end
    end
    forceExit(true)
  end
  if not filesystem.exists("/ags/installedVersions.ff") then
    if filesystem.exists(UsersWorkingDir.."/ags.ff") then
      print("Moving ags.ff file")
      local success, msg = filesystem.copy(UsersWorkingDir.."/ags.ff", "/ags/installedVersions.ff")
      if success then
        filesystem.remove(UsersWorkingDir.."/ags.ff")
      elseif success == nil then
        io.stderr:write(msg)
        forceExit(false)
      end
    end
  end
  if not filesystem.exists("/ags/gateEntries.ff") then
    if filesystem.exists(UsersWorkingDir.."/gateEntries.ff") then
      print("Your gateEntries.ff file will be copied to")
      print("\"/ags\", and your old file will no longer be used.")
      io.write("Press Enter to Continue")
      io.read()
      local success, msg = filesystem.copy(UsersWorkingDir.."/gateEntries.ff", "/ags/gateEntries.ff")
      if success == nil then
        io.stderr:write(msg)
        forceExit(false)
      end
    end
  end
end

function displayLogo()
  
end

function forceExit(code)
  if UsersWorkingDir ~= nil then shell.setWorkingDirectory(UsersWorkingDir) end
  os.exit(code)
end

function getCurrentVersions()
  local result = ""
  ReleaseVersions = {}
  local response = internet.request(VersionsURL)
  local isGood = pcall(function() 
    for chunk in response do
      result = result..chunk
    end
    ReleaseVersions = serialization.unserialize(result)
  end)
  if not isGood then
    io.stderr:write("Version Check Failed")
    forceExit(false)
  end
end

function readVersionFile()
  local file = io.open("/ags/installedVersions.ff", "r")
  if file == nil then
    if HasInternet then
      file = io.open("/ags/installedVersions.ff", "w")
      file:write(serialization.serialize(ReleaseVersions))
      file:close()
      file = io.open("/ags/installedVersions.ff", "r")
    else
      io.stderr:write("Version Information Missing. Need Internet to Download")
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
    if #ReleaseVersions.dialer.note > 0 then
      print("Changes:")
      for i,v in ipairs(ReleaseVersions.dialer.note) do print("  "..v) end
      print()
    end
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
    print("Downloading Dialer Program, Please Wait")
    downloadManifestedFiles(ReleaseVersions.dialer)
    print("Dialer Program Has Been Downloaded")
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
if HasInternet then
  print("Running in Online Mode\n")
  getCurrentVersions()
else
  print("Running in Offline Mode\n")
end
initialization()
readVersionFile()
if ReleaseVersions ~= nil then compareVersions() end


print("Launching Dialer")
dofile(LocalVersions.dialer.file)

shell.setWorkingDirectory(UsersWorkingDir) -- Returns the user back to their original working directory