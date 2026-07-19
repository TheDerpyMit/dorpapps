local mon
for _,s in ipairs(peripheral.getNames()) do
  if peripheral.getType(s) == "monitor" then mon = peripheral.wrap(s) break end
end
if not mon then error("No monitor found") end
mon.setTextScale(0.5)
local ok,err = pcall(dofile, arg[1])
if not ok then
  term.redirect(term.native())
  printError(err)
end
