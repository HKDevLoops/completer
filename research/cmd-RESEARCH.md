# Cmd (cmd.exe via Clink) — Official-Docs Research (INSPECTION-ONLY)

> **INSPECTION-ONLY**: cmd.exe/Clink is ABSENT on this host. No binary was inspected; all
> facts below come solely from official documentation (chrisant996.github.io/clink,
> learn.microsoft.com, carapace-sh.github.io, github.com/ajeetdsouza/zoxide). No speculation.

## 1. Config / RC path

cmd.exe is Windows-only — no POSIX path exists. All paths below are Windows.

Source: https://chrisant996.github.io/clink/clink.html#file-locations (section "File Locations").

Default profile directory (verbatim facts):
- Windows Vista onwards: `c:\Users\username\AppData\Local\clink` (= `%LOCALAPPDATA%\clink`). [https://chrisant996.github.io/clink/clink.html#filelocations]
- Windows XP: `c:\Documents and Settings\username\Local Settings\Application Data\clink`. [https://chrisant996.github.io/clink/clink.html#filelocations]
- Overrides: `--profile path` (for `clink inject`) or `%CLINK_PROFILE%` env var (takes precedence). [https://chrisant996.github.io/clink/clink.html#filelocations]
- Autorun installs set profile explicitly to `%LOCALAPPDATA%\clink`. [https://chrisant996.github.io/clink/clink.html#overriding-the-profile-directory-when-installed-for-autorun]
- `clink info` prints the directories/config files for the current session. [https://chrisant996.github.io/clink/clink.html#filelocations]

Files in the profile directory (verbatim, https://chrisant996.github.io/clink/clink.html#files):
- `.inputrc` — Readline config (key bindings, settings). Created at `%userprofile%\.inputrc` per https://chrisant996.github.io/clink/clink.html#gettingstarted_inputrc.
- `clink_settings` — Clink settings (override with `%CLINK_SETTINGS%`).
- `clink_history` — command history.
- `default_settings`, `default_inputrc` — optional portable defaults.
- `clink_start.cmd` — auto-run startup script in binaries and profile dirs, before Lua scripts run. [https://chrisant996.github.io/clink/clink.html#gettingstarted_startupcmdscript]

**Lua script locations** (verbatim, https://chrisant996.github.io/clink/clink.html#lua-scripts-location):
1. All directories in the `clink.path` setting (semicolon-delimited).
2. If `clink.path` unset: the DLL directory and the profile directory.
3. All directories in `%CLINK_PATH%` (semicolon-delimited).
4. All directories registered by `clink installscripts`.

**Completion directories**: `%CLINK_COMPLETIONS_DIR%` (semicolon-delimited) and a `completions\`
subdirectory under each script directory — Lua scripts there load on demand by command name.
[https://chrisant996.github.io/clink/clink.html#completion-directories]

Sibling-folder note (per project spec, researcher D owns placement): the natural root is
`%LOCALAPPDATA%\clink` with a `completions\` subfolder for on-demand scripts.

## 2. Native completion API

Source: https://chrisant996.github.io/clink/clink.html#argumentcompletion (section "Argument Completion").

Clink builds an **argmatcher** parser via `clink.argmatcher()`, then `:addarg()` (positional)
and `:addflags()` (position-independent). Verbatim basic example
(https://chrisant996.github.io/clink/clink.html#argmatcher_basics):
```lua
clink.argmatcher("foobar")
:addarg({ "hello", "hi" })               -- Completions for arg #1.
:addarg({ "world", "wombles", "xyzzy" }) -- Completions for arg #2.
:addflags("-foo", "-bar")                -- Flags.
```

Verbatim API signature (https://chrisant996.github.io/clink/clink.html#clink.argmatcher):
```
clink.argmatcher ( [commands...:string] ) : _argmatcher
```
- Passing one command registers the argmatcher with that command; if one already exists it is
  returned (merging is supported). Passing more than one command registers with all of them.
  Passing no command creates an unregistered (linked) parser. [https://chrisant996.github.io/clink/clink.html#clink.argmatcher]
- `clink.argmatcherloader(function)` registers a loader called when a command word has no
  argmatcher yet. Verbatim example (https://chrisant996.github.io/clink/clink.html#clink.argmatcherloader):
```lua
local function custom_loader(command_word, quoted, no_cmd)
    if command_word == "blah" then
        clink.argmatcher("blah"):addarg("abc", "xyz")
    end
end

clink.argmatcherloader(custom_loader)
```
- Custom match generators use `clink.generator()`, `clink.classifier()`, etc.
  [https://chrisant996.github.io/clink/clink.html#matchgenerators]
- Clink uses Lua 5.2. [https://chrisant996.github.io/clink/clink.html#tips-for-starting-to-write-lua-scripts]

## 3. Alias add / remove (native mechanism)

Aliases in cmd.exe are **doskey macros** (native to cmd.exe); Clink reads/expands them and
includes them in completion and coloring. [https://chrisant996.github.io/clink/clink.html#enhanced-doskey-expansion]

Verbatim syntax and examples from the official Microsoft `doskey` reference
(https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/doskey):
```
doskey [/reinstall] [/listsize=<size>] [/macros:[all | <exename>] [/history] [/insert | /overstrike] [/exename=<exename>] [/macrofile=<filename>] [<macroname>=[<text>]]
```
- Add: `doskey qf=format $1 /q /u` — "Creates a macro that carries out the commands specified by
  Text"; if Text is left blank, MacroName is cleared. [https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/doskey]
- Remove (verbatim MS example): `doskey vlist =` — "To delete a macro called *vlist*". [https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/doskey]
- Load from file: `doskey /macrofile=macinit`. [https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/doskey]

Clink-specific facts:
- A doskey macro like `gco=git checkout $*` reuses the `git` argmatcher automatically.
  [https://chrisant996.github.io/clink/clink.html#argmatcher_basics]
- Lua read-only alias APIs: `os.getalias(name)` returns the command string for a doskey alias
  (or nil), `os.getaliases()` returns alias names in a table.
  [https://chrisant996.github.io/clink/clink.html#os.getalias, https://chrisant996.github.io/clink/clink.html#os.getaliases]
- No Clink Lua API for adding/removing doskey aliases appears in the official Lua API index
  (https://chrisant996.github.io/clink/clink.html#lua-api); use the native `doskey` command.

## 4. Sourcing generated files

- Clink auto-executes all Lua scripts found in the script directories (§1); "Loading a Lua
  script executes it." [https://chrisant996.github.io/clink/clink.html#tips-for-starting-to-write-lua-scripts]
- Explicit loading in Lua: standard Lua `dofile`, `load`, `require` (Lua 5.2); modules via
  `clink.addpackagepath(dir)` then `require(modname)`.
  [https://chrisant996.github.io/clink/clink.html#using-modules, https://chrisant996.github.io/clink/clink.html#clink.addpackagepath]
- On-demand: place a script named `<command>.lua` in a `completions\` directory; Clink loads it
  when that command is typed. [https://chrisant996.github.io/clink/clink.html#completion-directories]
- Reload scripts: `clink-reload` bindable command (Ctrl-x Ctrl-r) or `clink.reload()` API.
  [https://chrisant996.github.io/clink/clink.html#lua-scripts-location, https://chrisant996.github.io/clink/clink.html#clink.reload]

## 5. Carapace bridge

Official carapace setup snippet for Cmd (verbatim,
https://carapace-sh.github.io/carapace-bin/setup.html#cmd):
```lua
-- ~/AppData/Local/clink/carapace.lua
load(io.popen('carapace _carapace cmd-clink'):read("*a"))()
```
The page notes "Needs clink" and links https://chrisant996.github.io/clink/.
[https://carapace-sh.github.io/carapace-bin/setup.html#cmd]

## 6. Zoxide init

- The official zoxide README lists no native `zoxide init cmd` / `zoxide init clink` shell setup
  (supported inits: bash, elvish, fish, nushell, powershell, tcsh, xonsh, zsh, posix).
  [https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell]
- zoxide documents Clink integration only as a **third-party plugin**: `clink-zoxide`
  (https://github.com/shunsambongi/clink-zoxide) under "Third-party integrations".
  [https://github.com/ajeetdsouza/zoxide#third-party-integrations]
- Windows zoxide install: `winget install ajeetdsouza.zoxide` (or choco/scoop/cargo).
  [https://github.com/ajeetdsouza/zoxide#installation]

## 7. Self-completion (completion for the shell's own `completer` function)

**Feasible: YES.** `clink.argmatcher()` accepts a command name and registers an argmatcher for
it; naming it `completer` gives the `completer` command its own completions.
[https://chrisant996.github.io/clink/clink.html#clink.argmatcher]

Exact snippet (assembled from the documented `clink.argmatcher` pattern at
https://chrisant996.github.io/clink/clink.html#argmatcher_basics — the docs carry no
`completer`-specific example, so this is a direct application of the documented API, not a
quoted passage):
```lua
-- e.g. ~/AppData/Local/clink/completer.lua (or completions\completer.lua for on-demand load)
clink.argmatcher("completer")
:addarg("add", "remove", "list", "update", "zoxide") -- subcommands
:addflags("-h", "--help")
```
For on-demand loading when the user types `completer`, place the script as
`completions\completer.lua` (Clink loads it by command name).
[https://chrisant996.github.io/clink/clink.html#completion-directories]

## Sources
- https://chrisant996.github.io/clink/ (overview, download, installation)
- https://chrisant996.github.io/clink/clink.html (File Locations, Lua script locations, completion dirs, Argument Completion, Lua API, doskey notes)
- https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/doskey (native alias add/remove)
- https://carapace-sh.github.io/carapace-bin/setup.html#cmd (carapace cmd-clink bridge)
- https://github.com/ajeetdsouza/zoxide (zoxide init list, clink-zoxide integration)

## GAPS
- The official docs give no `completer`-specific argmatcher example; §7 snippet is assembled
  from the documented `clink.argmatcher` pattern, not quoted verbatim.
- No native `zoxide init cmd` documented — only third-party `clink-zoxide`; we did not fetch
  that plugin's setup instructions (out of scope of official zoxide/clink docs).
- No Clink Lua API for adding/removing doskey aliases found in the official API index; only
  read-only `os.getalias`/`os.getaliases`. Native `doskey` command used instead.
- No POSIX config path (cmd.exe is Windows-only).
- Host binaries absent; all APIs are INSPECTION-ONLY and unverified locally.
