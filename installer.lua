-- Modular PE runner

local title = "Modular Installer"
local repository = "https://raw.githubusercontent.com/Galaxy-Computing/Modular-Packages/refs/heads/dev/" -- repo to install from
local installpackages = { -- packages we install with the main two
    "craftos-bin",
    "shell",
    "sudo",
}
local tArgs = {...}

term.redirect(term.native())

function screen(maintext,bottomtext)
    term.setBackgroundColor(colours.blue)
    term.clear()
    local w,h = term.getSize()
    term.setCursorPos(1,h)
    term.setBackgroundColor(colours.lightGrey)
    term.setTextColor(colours.black)
    for i=1,w do
        write(" ")
    end
    term.setCursorPos(1,h)
    write(" "..bottomtext)
    term.setBackgroundColor(colours.blue)
    term.setTextColor(colours.white)
    term.setCursorPos(1,1)
    print(title)
    for i=1,string.len(title) do
        write("=")
    end
    print()
    print()
    write(maintext)
end

function waitForEnter()
    local continue = false
    while not continue do
        local _,keycode,_ = os.pullEvent("key")
        if keycode == 28 then continue = true end
    end
end

if #tArgs == 1 then
    if tArgs[1] == "postreboot" then -- we're after the reboot
        screen("   The installer is now installing software.","")
        for i,name in ipairs(packages) do
            screen("   The installer is now installing software.","Installing "..name.."... ("..i.."/"..#packages..")")
            local win = window.create(term.current(),1,1,1,1,false)
            term.redirect(win)
            shell.run("wget "..repository..name..".mpk /modular/.setup/"..name..".mpk")
            shell.run("/modular/modules/modctl/main.lua i ".."/modular/.setup/"..name..".mpk y") -- no modular shell yet, so run using the direct path
        end
        -- now we have all software, time to put the normal config and kernel meta back
        fs.delete("/modular/config")
        fs.makeDir("/modular/config")
        fs.delete("/modular/modules/modular-kernel/meta.lua")
        fs.copy("/modular/.setup/oldmeta.lua","/modular/modules/modular-kernel/meta.lua")
        fs.delete("/modular/.setup") -- finally delete the .setup folder, it's no longer needed
        screen("   Installation is now finished.\n   Use the username \"root\" and a blank password to login.\n   Press ENTER to reboot.","ENTER = Reboot")
        waitForEnter()
        screen("   The system will now reboot.","Rebooting in 3.")
        sleep(1)
        screen("   The system will now reboot.","Rebooting in 2..")
        sleep(1)
        screen("   The system will now reboot.","Rebooting in 1...")
        sleep(1)
        os.reboot()
        return
    end
end

screen("   Welcome to the Modular Installer.\n   To start the installation, press ENTER.\n   To cancel, hold CTRL+T.","ENTER = Continue")
waitForEnter()

screen("","Creating folders...")
fs.makeDir("/modular")
fs.makeDir("/modular/config")
fs.makeDir("/modular/modules")
fs.makeDir("/modular/modules/modular-kernel")
fs.makeDir("/modular/modules/modctl")
fs.makeDir("/modular/.setup")

screen("   The installer is now downloading and installing critical system files.","Downloading modular-kernel... (1/2)")
local win = window.create(term.current(),1,1,1,1,false)
term.redirect(win)
shell.run("wget "..repository.."installer.lua /modular/.setup/installer.lua") -- saving the file in a known spot for later
shell.run("wget "..repository.."modular-kernel.mpk /modular/.setup/modular-kernel.mpk")
term.redirect(term.native())
if not fs.exists("/modular/.setup/modular-kernel.mpk") then
    screen("   The installer failed to download files.\n   File: modular-kernel.mpk\n   The install will be incomplete.\nPress ENTER to exit the installer.","ENTER = Exit")
    waitForEnter()
    return
end

screen("   The installer is now downloading and installing critical system files.","Downloading modctl... (2/2)")
term.redirect(win)
shell.run("wget "..repository.."modctl.mpk /modular/.setup/modctl.mpk")
term.redirect(term.native())
if not fs.exists("/modular/.setup/modctl.mpk") then
    screen("   The installer failed to download files.\n   File: modctl.mpk\n   The install will be incomplete.\nPress ENTER to exit the installer.","ENTER = Exit")
    waitForEnter()
    return
end

screen("   The installer is now downloading and installing critical system files.","Installing modular-kernel... (1/2)")
local files = dofile("/modular/.setup/modular-kernel.mpk")
for path,data in pairs(files) do
    path = "/modular/modules/modular-kernel/"..path -- hard coded, we don't have modular-kernel yet
    local f = fs.open(path,"w")
    f.write(data)
    f.close()
end

screen("   The installer is now downloading and installing critical system files.","Installing modctl... (2/2)")
local files = dofile("/modular/.setup/modctl.mpk")
for path,data in pairs(files) do
    path = "/modular/modules/modctl/"..path -- hard coded, we don't have modular-kernel yet
    local f = fs.open(path,"w")
    f.write(data)
    f.close()
end

if fs.exists("/startup.lua") then
    fs.copy("/startup.lua","/startup.old.lua")
end
local f = fs.open("/startup.lua","w")
f.write("shell.run(\"/modular/modules/modular-kernel/kernel.lua\")")
f.close()
local f = fs.open("/modular/modules/modular-kernel/meta.lua","r")
local oldmeta = f.readAll()
f.close()

-- kernel meta hackiness
fs.copy("/modular/modules/modular-kernel/meta.lua","/modular/.setup/oldmeta.lua") -- saving this for later
local f = fs.open("/modular/modules/modular-kernel/meta.lua","w")
local newmeta = "module.currentUser = \"root\"\n"..oldmeta -- hacky way to skip the logon prompt on boot
newmeta = "module.config[\"modular-kernel\"][\"cmdline\"] = \"/modular/.setup/installer.lua postreboot\"\n"..newmeta -- hacky way to get the kernel to run us instead of a shell (which doesn't exist yet)
f.write(newmeta) 
f.close()

screen("   The system will now reboot.","Rebooting in 3.")
sleep(1)
screen("   The system will now reboot.","Rebooting in 2..")
sleep(1)
screen("   The system will now reboot.","Rebooting in 1...")
sleep(1)
os.reboot()