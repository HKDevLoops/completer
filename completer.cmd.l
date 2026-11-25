-- ============================================================================
-- completer.cmd.l - Clink (cmd.exe) native Lua completion manager.  Lua 5.2.
--
-- ZERO STARTUP WORK: loading this script only DEFINES functions/globals and a
-- doskey discoverability macro. No probing/file writes happen at load.
--
-- Native APIs used (all from official docs below):
--   clink.argmatcher("completer"):addarg(...)   (self-completion; argmatcher_basics)
--   os.getalias / os.getaliases                 (read-only alias introspection)
--   doskey NAME=TEXT / doskey NAME=             (native alias add/remove)
--   io.open / io.popen / os.rename / os.date / os.getenv / os.execute
--   clink.reload()                              (reload scripts after writes)
--   carapace _carapace cmd-clink                (carapace bridge for cmd)
--
-- Official docs:
--   https://chrisant996.github.io/clink/clink.html          (argmatcher, doskey, scripts)
--   https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/doskey
--   https://carapace-sh.github.io/carapace-bin/setup.html#cmd
--   https://github.com/ajeetdsouza/zoxide                    (no native cmd init)
--
-- GAPs vs the universal surface:
--   - cmd.exe has NO function-definition mechanism. The universal `completer`
--     surface is implemented as a Lua global function `completer(...)` callable
--     from Clink Lua scripts/the Clink Lua console. A doskey macro is created
--     only for discoverability; an interactive `completer ...` command with full
--     parity would require a batch wrapper (an executable, which is disallowed).
--   - Native alias add/remove uses `doskey` (Clink Lua API is read-only here).
--   - No native `zoxide init cmd/clink` exists (only third-party clink-zoxide);
--     `completer zoxide` still runs native `zoxide init <shell>` for the 8 target
--     shells into files, and documents the clink gap. No API is invented.
--   - Self-completion is installed by `completer("self")`, not at load.
-- ============================================================================

local M = {}

M.MARK_B = ">>> completer:%s:%s >>>"
M.MARK_E = "<<< completer:%s:%s <<<"

function M.root()
    if os.getenv("COMPLETER_ROOT") and os.getenv("COMPLETER_ROOT") ~= "" then
        return os.getenv("COMPLETER_ROOT")
    end
    local cfg = os.getenv("XDG_CONFIG_HOME")
    if not cfg or cfg == "" then
        cfg = (os.getenv("USERPROFILE") or ".") .. "/.config"
    end
    return cfg .. "/completer"
end

function M.token(shell)
    if shell == "nu" or shell == "nushell" then return "nushell" end
    if shell == "pwsh" or shell == "powershell" then return "powershell" end
    if shell == "cmd" or shell == "clink" then return "cmd-clink" end
    return shell
end

function M.ext(shell)
    if shell == "nu" then return "nu" end
    if shell == "xonsh" then return "xsh" end
    if shell == "pwsh" then return "ps1" end
    if shell == "cmd" or shell == "clink" then return "lua" end
    return shell
end

-- SECURITY: a shell/program/alias name must be a bare token. This rejects
-- cmd.exe metacharacters (& | ^ < > ( ) " % !), whitespace/newlines, path
-- separators (/ and \) and '..' traversal before any name reaches a shell
-- parser, a generated filename, or a block sourced on the next launch.
function M.safe_name(s)
    return type(s) == "string" and s ~= "" and s:match("^[%w_%-]+$") ~= nil
end

-- SECURITY: doskey macro values are appended verbatim to a cmd.exe command
-- line, so reject the metacharacters that could break out of the macro.
function M.cmd_unsafe(s)
    return type(s) ~= "string" or s:match('[&|^<>()"%%!\r\n]') ~= nil
end

function M.main_config(shell)
    local cfg = os.getenv("XDG_CONFIG_HOME")
    if not cfg or cfg == "" then cfg = (os.getenv("USERPROFILE") or ".") .. "/.config" end
    local home = os.getenv("USERPROFILE") or "."
    local map = {
        bash = home .. "/.bashrc", zsh = home .. "/.zshrc", sh = home .. "/.profile",
        fish = cfg .. "/fish/config.fish",
        pwsh = home .. "/Documents/PowerShell/profile.ps1",
        powershell = home .. "/Documents/PowerShell/profile.ps1",
        nu = cfg .. "/nushell/config.nu", xonsh = cfg .. "/xonsh/.xonshrc",
        elvish = cfg .. "/elvish/rc.elv", tcsh = home .. "/.tcshrc",
        ksh = home .. "/.kshrc", ion = cfg .. "/ion/initrc",
        oil = cfg .. "/oils/oshrc", yash = cfg .. "/yash/rc",
    }
    return map[shell] or (M.root() .. "/completions/" .. shell .. "-completion." .. M.ext(shell))
end

-- Run cmd, return stdout as a string, or nil on failure. Callers pass only
-- fixed command text plus names already checked by M.safe_name().
function M.capture(cmd)
    local h = io.popen(cmd .. " 2>NUL")
    if not h then return nil end
    local out = h:read("*a")
    local ok = h:close()
    if not out or out == "" or not ok then return nil end
    if out:match("^DESCRIPTION") or out:match("^USAGE") then return nil end
    return out
end

function M.exists(cmd)
    if not M.safe_name(cmd) then return false end
    return M.capture("where " .. cmd) ~= nil
end

function M.write(path, text)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(text)
    f:close()
    return true
end

function M.read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function M.backup(path)
    if not M.read(path) then return end
    local stamp = os.date("%Y%m%d-%H%M%S")
    local dst = path .. ".bak." .. stamp
    local s = M.read(path)
    if s then M.write(dst, s) end
    print("  backup -> " .. dst)
end

function M.tail(path)
    return path:match("([^/\\]+)$") or path
end

-- Idempotent, marker-wrapped append link into a main config file.
function M.link(config, file, shell)
    local body = M.read(config)
    if not body then return end
    local marker = string.format(M.MARK_B, shell, M.tail(file))
    if body:find(marker, 1, true) then return end
    local load = ". '" .. file .. "'"
    if shell == "nu" or shell == "fish" then load = "source '" .. file .. "'"
    elseif shell == "xonsh" then load = "execx(open('" .. file .. "').read(), 'exec', __xonsh__.ctx)"
    elseif shell == "elvish" then load = "eval (slurp < '" .. file .. "')"
    elseif shell == "cmd" or shell == "clink" then load = "dofile([=[" .. file .. "]=])"
    end
    local block = "\n" .. marker .. "\n" .. load .. "\n" ..
                  string.format(M.MARK_E, shell, M.tail(file)) .. "\n"
    local f = io.open(config, "ab")
    if f then f:write(block); f:close(); print("  linked -> " .. config) end
end

function M.program_output(prog, tok)
    -- Validate before concatenating anything into a cmd.exe command string.
    if not M.safe_name(prog) or not M.safe_name(tok) then return nil end
    local probes = {
        "completion --shell " .. tok, "completion -s " .. tok, "completion " .. tok,
        "completions " .. tok, "--generate-completion " .. tok, "--completions " .. tok,
    }
    for _, a in ipairs(probes) do
        local out = M.capture(prog .. " " .. a)
        if out then return out end
    end
    return M.capture("carapace " .. prog .. " " .. tok)
end

function M.self()
    -- Native Clink self-completion: argmatcher registered on demand (not at load).
    clink.argmatcher("completer")
        :addarg("add", "remove", "list", "update", "zoxide", "self")
        :addflags("-h", "--help")
    print("Self-completion registered via clink.argmatcher('completer').")
end

function M.update_carapace()
    if not M.exists("carapace") then print("carapace not found; nothing to update"); return end
    print("Refreshing carapace indexes (native carapace CLI)...")
    local dir = M.root() .. "/completions"
    os.execute('mkdir "' .. dir .. '" 2>NUL & mkdir "' .. dir .. '" >NUL 2>&1')
    os.execute("carapace --clear-cache >NUL 2>&1")
    local listed = M.capture("carapace --list") or ""
    local n = 0; for _ in listed:gmatch("[^\r\n]+") do n = n + 1 end
    print("  indexed completers: " .. n)
    for _, sh in ipairs({ "bash", "zsh", "fish", "powershell", "nushell", "xonsh", "cmd-clink" }) do
        local out = dir .. "/carapace-" .. sh .. "-init." .. M.ext(sh)
        local res = M.capture("carapace _carapace " .. sh)
        if res then
            M.backup(out)
            M.write(out, string.format(M.MARK_B, "carapace", sh) .. "\n" .. res .. "\n" ..
                        string.format(M.MARK_E, "carapace", sh) .. "\n")
            print("  indexed: " .. sh .. " -> " .. out)
        end
    end
    print("Carapace index refreshed.")
end

function M.zoxide(shells)
    if not M.exists("zoxide") then print("zoxide not found; nothing to do"); return end
    local dir = M.root() .. "/completions"
    os.execute('mkdir "' .. dir .. '" >NUL 2>&1')
    for _, shell in ipairs(shells) do
        if not M.safe_name(shell) then
            print("  rejected unsafe shell name: " .. tostring(shell))
        elseif shell == "cmd" or shell == "clink" then
            print("  zoxide has NO native clink init (third-party clink-zoxide only); skipped")
        else
            local tok = M.token(shell)
            if shell == "sh" then tok = "posix" end
            local res = M.capture("zoxide init " .. tok)
            if res then
                local out = dir .. "/" .. shell .. "-zoxide-init." .. M.ext(shell)
                M.backup(out)
                M.write(out, res)
                print("  wrote zoxide init -> " .. out)
                M.link(M.main_config(shell), out, shell)
            end
        end
    end
end

function M.alias_add(name, value)
    -- Native cmd.exe alias = doskey macro; Clink Lua alias API is read-only.
    -- SECURITY: name/value reach cmd.exe unescaped -> validate and reject.
    if not M.safe_name(name) then
        print("  rejected unsafe alias name: " .. tostring(name)); return
    end
    if M.cmd_unsafe(value) then
        print("  rejected unsafe alias value: " .. tostring(value)); return
    end
    os.execute('doskey ' .. name .. '=' .. value)
    local file = M.root() .. "/alias.cmd"
    local lines = {}
    local body = M.read(file) or ""
    for line in body:gmatch("[^\r\n]+") do
        if not line:match("^" .. name .. "=") then lines[#lines + 1] = line end
    end
    lines[#lines + 1] = name .. "=" .. value
    M.write(file, table.concat(lines, "\r\n") .. "\r\n")
    print("  alias " .. name .. " -> " .. value .. " (doskey; persists via doskey /macrofile)")
end

function M.alias_remove(name)
    if not M.safe_name(name) then
        print("  rejected unsafe alias name: " .. tostring(name)); return
    end
    os.execute('doskey ' .. name .. '=')
    local file = M.root() .. "/alias.cmd"
    local body = M.read(file)
    if body then
        local lines = {}
        for line in body:gmatch("[^\r\n]+") do
            if not line:match("^" .. name .. "=") then lines[#lines + 1] = line end
        end
        M.write(file, table.concat(lines, "\r\n") .. "\r\n")
    end
    print("  alias " .. name .. " removed")
end

-- Universal command surface. Called as completer(action, ...) from Clink Lua.
function completer(action, ...)
    local args = { ... }
    local dir = M.root() .. "/completions"
    os.execute('mkdir "' .. dir .. '" >NUL 2>&1')

    if action == "list" then
        os.execute('dir "' .. dir .. '"')
        return
    elseif action == "self" then
        M.self(); return
    elseif action == "update" then
        if args[1] == "carapace" then M.update_carapace()
        else print("Unknown update target. Try: completer update carapace") end
        return
    elseif action == "alias" then
        if args[1] == "add" then M.alias_add(args[2], table.concat(args, " ", 3))
        elseif args[1] == "remove" then M.alias_remove(args[2])
        else print("usage: completer alias add <name> <value> | remove <name>") end
        return
    elseif action == "zoxide" then
        local shells = (#args > 0) and args or { "pwsh", "nu", "xonsh" }
        M.zoxide(shells); return
    end

    local shell = action
    if not M.safe_name(shell) then
        print("rejected unsafe shell name: " .. tostring(shell)); return
    end
    local tok = M.token(shell)
    local ext = M.ext(shell)
    local progs = (#args > 0) and args or { "opencode" }
    for _, prog in ipairs(progs) do
        if not M.safe_name(prog) then
            print("  rejected unsafe program name: " .. tostring(prog))
        else
            print("Generating " .. prog .. " completions for " .. shell .. "...")
            local out = dir .. "/" .. shell .. "-" .. prog .. "-completion." .. ext
            local text = M.program_output(prog, tok)
            if not text then print("  no completion for " .. prog .. " (" .. shell .. ")") return end
            M.backup(out)
            local block = string.format(M.MARK_B, prog, shell) .. " generated " .. os.date("%FT%T") .. "\n" ..
                          text .. "\n" .. string.format(M.MARK_E, prog, shell) .. "\n"
            M.write(out, block)
            print("  wrote -> " .. out)
            M.link(M.main_config(shell), out, shell)
        end
    end
    pcall(M.self)
end

-- Discoverability macro only (cmd.exe cannot call Lua functions directly).
pcall(function()
    os.execute('doskey completer=echo Use the Clink Lua console: completer("list") 2>NUL')
end)

return M
