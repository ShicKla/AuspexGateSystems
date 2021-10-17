c = require("component")
event = require("event")
os = require("os")
m = c.modem

m.open(985) --send
m.open(986) --recive

while true do
  
  print("IDC?")
  local code = io.read()
  print("Send IDC...")
  m.broadcast(985, code)
  
  local EventListeners = {
  modem_message = event.listen('modem_message', function(_, _, _, _, _, message, ...)
   print(tostring(message)) 
  end),
  }
end
