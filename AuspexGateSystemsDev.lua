--[[
Created By: Augur ShicKla
v1.0.0
]]--


component = require("component")
serialization = require("serialization")
filesystem = require("filesystem")
internet = nil
HasInternet = component.isAvailable("internet")
if HasInternet then internet = require("internet") end

VersionsURL = "https://pastebin.com/raw/W66rzsAm"
CurrentVersions = nil
LocalVersions = nil
DialerFound = false

function getCurrentVersions()
  local result = ""
  CurrentVersions = {}
  local response = internet.request(VersionsURL)
  local isGood = pcall(function() 
    for chunk in response do
      result = result..chunk
    end
    CurrentVersions = serialization.unserialize(result)
  end)
  if not isGood then
    io.stderr:write("Version Check Failed")
    os.exit()
  end
end

function readVersionFile()
  local file = io.open("ags.ff", "r")
  if file == nil then
    if HasInternet then
      file = io.open("ags.ff", "w")
      file:write(serialization.serialize(CurrentVersions))
      file:close()
      file = io.open("ags.ff", "r")
    else
      io.stderr:write("Version Information Missing. Need Internet to Download")
      os.exit()
    end
  end
  LocalVersions = serialization.unserialize(file:read("*a"))
  file:close()
end

function saveVersionFile()
  local file = io.open("ags.ff", "w")
  file:write(serialization.serialize(LocalVersions))
  file:close()
end

function compareVersions()
  if isVersionGreater(LocalVersions.launcher.ver, CurrentVersions.launcher.ver) then
    print("Launcher needs to update, please wait.")
    downloadFile(CurrentVersions.launcher.url, CurrentVersions.launcher.file)
    print("Launcher has been updated and will need to be restarted")
    LocalVersions.launcher = CurrentVersions.launcher
    saveVersionFile()
    os.exit()
  end  
  if isVersionGreater(LocalVersions.dialer.ver, CurrentVersions.dialer.ver) then
    print("There is a new version of the Dialer. Would you like to update?")
    io.write("Yes/No : ")
    local userInput = io.read(1)
    if userInput:lower() == "y" then
      print("Downloading Dialer Program, Please Wait")
      downloadFile(CurrentVersions.dialer.url, CurrentVersions.dialer.file)
      print("Dialer Program Has Been Downloaded")
      LocalVersions.dialer = CurrentVersions.dialer
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
  DialerFound = filesystem.exists(os.getenv("PWD").."/"..LocalVersions.dialer.file)
  if not DialerFound then
    print("Downloading Dialer Program, Please Wait")
    downloadFile(CurrentVersions.dialer.url, CurrentVersions.dialer.file)
    print("Dialer Program Has Been Downloaded")
  end
end

function downloadFile(url, fileName)
  local result = ""
  local response = internet.request(url)
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
    error(err)
    os.exit()
  end
end


if HasInternet then
  print("Running in Online Mode")
  getCurrentVersions()
else
  print("Running in Offline Mode")
end
readVersionFile()
if CurrentVersions ~= nil then compareVersions() end


print("Launching Dialer")
dofile(LocalVersions.dialer.file)