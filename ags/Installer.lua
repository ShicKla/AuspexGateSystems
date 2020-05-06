--[[
Created By: Augur ShicKla
Installer
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

local args, opts = shell.parse(...)

function onlineCheck() -- Check for internet connection
  if not HasInternet then
    io.stderr:write("No internet connection present. Please install an\nInternet Card\n")
    os.exit(false)
  end
end

if opts.d then
  print([[
┌───────────────────────────┐
│Installer Set to Dev Branch│
└───────────────────────────┘]])
  BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/dev"
else
  BranchURL = "https://raw.githubusercontent.com/ShicKla/AuspexGateSystems/release"
end
ReleaseVersionsFile = "/ags/releaseVersions.ff"
ReleaseVersions = nil

function createInstallDirectory() -- Creates `/ags` directory, if it doesn't already exist
  if not filesystem.isDirectory("/ags") then
    print("Creating \"/ags\" directory")
    local success, msg = filesystem.makeDirectory("/ags")
    if success == nil then
      io.stderr:write("Failed to created \"/ags\" directory, "..msg)
      os.exit(false)
    end
  end
end

function checkForExistingInstall() -- Checks for existing install, and prompt user if one is found
  if filesystem.exists("/ags/AuspexGateSystems.lua") then
    print([[
┌────────────────────────────────────────────────┐
│An existing installation of Auspex Gate Systems │
│was found. Would you like to reinstall?         │
└────────────────────────────────────────────────┘]])
    term.setCursorBlink(true)
    io.write(" Yes/No: ")
    local userInput = io.read("*l")
    if (userInput:lower()):sub(1,1) ~= "y" then
      print(" Canceling Installation")
      os.exit(true)
    end
  end
end

function downloadNeededFiles()
  print("Downloading Files, Please Wait...")
  downloadFile(ReleaseVersionsFile)
  local file = io.open(ReleaseVersionsFile)
  ReleaseVersions = serialization.unserialize(file:read("*a"))
  file:close()
  downloadManifestedFiles(ReleaseVersions.launcher)
  if opts.d then ReleaseVersions.launcher.dev = true end
  file = io.open("/ags/installedVersions.ff", "w")
  file:write("{launcher="..serialization.serialize(ReleaseVersions.launcher)..",}")
  file:close()
end

function createSystemShortcut()
  local agsBinFile = [[
shell = require("shell")
filesystem = require("filesystem")

local args, opts = shell.parse(...)

if filesystem.exists("/ags/AuspexGateSystems.lua") then
  local options = "-"
  for k,v in pairs(opts) do options = options..tostring(k) end
  shell.execute("/ags/AuspexGateSystems.lua "..options)
else
  io.stderr:write("Auspex Gate Systems is Not Correctly Installed\n")
end
  ]]
  local file = io.open("/bin/ags.lua", "w")
  file:write(agsBinFile)
  file:close()
end

function downloadManifestedFiles(program)
  for i,v in ipairs(program.manifest) do downloadFile(v) end
end

function downloadFile(fileName)
  print("Downloading..."..fileName)
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

onlineCheck()
createInstallDirectory()
checkForExistingInstall()
downloadNeededFiles()
createSystemShortcut()
print("Launcher Changes:")
for i,v in ipairs(ReleaseVersions.launcher.note) do print("  "..v) end
print([[
Installation complete!
Please use the 'ags' system command to run the launcher.
]])


