local shell = require("shell")
local filesystem = require("filesystem")

local args, opts = shell.parse(...)

if not opts.r and not opts.b and not opts.a then
  io.write([[
This program is used to backup and restore Auspex Gate Systems, to or from a floppy disk
Usage: floppyBackup [OPTIONS]
 -b: Backup to floppy disk
 -r: Restore from floppy disk
  ]])
  os.exit(1)
end

function findFloppy()
  local floppyCount = 0
  local floppyDisk = nil
  local mountPoint = nil
  for k,v in filesystem.mounts() do
    if v:sub(1, 5) == "/mnt/" then
      if k.spaceTotal() < 1e6 then
        floppyCount = floppyCount + 1
        if floppyCount > 1 then
          io.stderr:write("More then one floppy disk detected\nPlease, only have one disk inserted\n")
          os.exit(true)
        end
        floppyDisk = k
        mountPoint = v
      end
    end
  end
  if floppyCount < 1 then
    io.stderr:write("No floppy disk inserted\n")
    os.exit(true)
  end
  return floppyDisk, mountPoint
end

local floppyComponent, mountPoint = findFloppy()

function runBackup()
  if not filesystem.isDirectory(mountPoint.."/ags") then
    local success, msg = filesystem.makeDirectory(mountPoint.."/ags")
    if success == nil then
      io.stderr:write("Failed to created "..mountPoint..[["/ags" directory, ]]..msg)
      os.exit(false)
    end
  end
  for fileName in filesystem.list("/ags/") do
    print("Copying..."..fileName)
    local success = filesystem.copy("/ags/"..fileName, mountPoint.."/ags/"..fileName)
    if not success then
      io.stderr("Unknown Error Occurred\n")
      os.exit(false)
    end
  end
  floppyComponent.setLabel("Auspex GS")
  createAutorun()
end

function runRestore()
  local floppyFiles = {}
  for fileName in filesystem.list(mountPoint.."/ags/") do table.insert(floppyFiles, fileName) end
  if not filesystem.isDirectory("/ags") then
    print("\nInstalling Auspex Gate Systems")
    local success, msg = filesystem.makeDirectory("/ags")
    if success == nil then
      io.stderr:write([["Failed to created "/ags" directory, ]]..msg)
      os.exit(false)
    end
    for i,fileName in ipairs(floppyFiles) do
      local success, msg = filesystem.copy(mountPoint.."/ags/"..fileName, "/ags/"..fileName)
      if not success then print(fileName..": error: "..msg) end
    end
    print("Installation Complete")
  elseif not opts.a then
    for i,fileName in ipairs(floppyFiles) do
      local overwrite = true
      if fileName == "gateEntries.ff" and filesystem.exists("/ags/gateEntries.ff") then
        print("A Gate Entries database file already exists on")
        print("this computer. Do you want to overwrite it with")
        print("the file from the floppy?")
        io.write("Yes/No: ")
        local userInput = io.read("*l")
        if (userInput:lower()):sub(1,1) ~= "y" then overwrite = false end
      end
      if overwrite then
        local success, msg = filesystem.copy(mountPoint.."/ags/"..fileName, "/ags/"..fileName)
        if not success then print(fileName..": error: "..msg) end
      end
    end
  end
  createSystemShortcut()
end

function createAutorun()
  local autoRunFile = [[
shell = require("shell")
filesystem = require("filesystem")
floppyRoot = (debug.getinfo(2, "S").short_src):match("(.*/)")
if filesystem.exists(floppyRoot.."ags/floppyBackup.lua") then
  shell.execute(floppyRoot.."ags/floppyBackup.lua -a")
else
  print("Floppy Autorun Failed")
end
  ]]
  local file = io.open(mountPoint.."/autorun.lua", "w")
  file:write(autoRunFile)
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

if opts.b then
  runBackup()
elseif opts.a then
  runRestore()
elseif opts.r then
  io.write([[
Would you like to copy the files from the
Auspex Gate Systems floppy to this computer?
Yes/No: ]])
  local userInput = io.read("*l")
  if (userInput:lower()):sub(1,1) ~= "y" then
    print("Exiting file restorer")
    os.exit(1)
  end
  runRestore()
end