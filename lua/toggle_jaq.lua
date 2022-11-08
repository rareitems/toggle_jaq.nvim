---@mod toggle_jaq
---@brief [[
---Just another pluging that allows to quickly run commands and show their results. This time in a togglable terminal window.
---@brief ]]

---@mod toggle_jaq.Variables Variables
---@brief [[
---Your commands can contain variables which will be replaced when you run them.
--->
---  % / $file : Current File
---  # / $altFile : Alternate File
---  $dir : Current Working Directory
---  $filePath : Path to Current File
---  $fileBase : Basename of File (no extension)
---<
---@brief ]]

---@mod toggle_jaq.Usage Usage
---@brief [[
---Set your keymaps for example
--->
---  local opts = { noremap = true, silent = true }
---  vim.keymap.set("n", "<leader>r", t.rerun_show, opts)
---  vim.keymap.set("n", "<M-r>", t.toggle, opts)
---  vim.keymap.set("t", "<M-r>", t.toggle, opts)
---<
---
---Specify command to run and filetype to set in command line or in your config
--->
---  :lua vim.g.toggle_jaq = {cmd = "lua %"}
---<
---Command can also be set to {cmd = 'internal', args = { -- some arguments see *toggle_jaq.variable* }}
---If no `args` is `nil`, `%` (current file) will be used.
---then instead of running terminal, 'luafile' will be used and its output will be showed in a a buffer.
---
---Your cmds can be set in various scopes. In sppecific buffer ('vim.b'), or globally ('vim.g') context.
---Buffer variable will be checked first, then global and last 'filetype' subtable from the configuration
---will be checked if it contains a key with current buffer's filetype.
---
---What command is going to be run can be checked via ':JaqPrint'.
---
---Your commands can contain variables which will be replaced when you run them.
--->
---  % / $file : Current File
---  # / $altFile : Alternate File
---  $dir : Current Working Directory
---  $filePath : Path to Current File
---  $fileBase : Basename of File (no extension)
---<
---Example:
--->
---  "lua %"
---<
---Will run "lua" with the name of your current file.
---
---Not only you can set commands but also filetype to which terminal window
---is going to be set to. This is useful to get a syntax highlighting inside REPL.
---Example:
--->
---  :lua vim.g.toggle_jaq = {cmd = "lua %", ft = "lua"}
---<
---
---There are following nvim commands
---:JaqGSetCmd <cmd> - Sets <cmd> in global vim variable, |vim.g|
---:JaqGSetFt <ft>   - Sets <ft> in global vim variable, |vim.g|
---:JaqBSetCmd <cmd> - Sets <cmd> in buffer vim variable, |vim.b|
---:JaqBSetFt <ft>   - Sets <ft> in buffer vim variable, |vim.b|
---:JaqPrint         - Prints a table of what filetype would be set and command would be run if you tried running terminal in the current buffer
---@brief ]]

---@mod toggle_jaq.Config Config
---@brief [[
---Can be setup with |toggle_jaq.setup|
---
---Default values:
--->
---  {
---    direction = "vertical",
---    hide_numbers = true,
---    size = 50,
---    filetypes = {
---      lua = { cmd = "lua %" },
---      sml = { cmd = "rlwrap sml %", filetype = "sml" },
---      javascript = { cmd = "node %" },
---      typescript = { cmd = "ts-node %" },
---      rust = { cmd = "cargo run" },
---    },
---    create_commands = true,
---    auto_resize = false,
---    dynamic_size = nil,
---    highlight_background = nil,
---  }
---<
---@brief ]]

---@class Config
---@field filetypes table Table of filetypes as keys and table with specified command to run and filetype to set
---@field hide_numbers boolean Turns off `number` and `relativenumber` in the terminal window
---@field direction Direction see |Direction|
---@field size number Size for the terminal window
---@field auto_resize boolean Should 'wincmd =' be called after creating the window
---@field dynamic_size DynamicSizeConfig | nil see |DynamicSizeConfig|, this option will cause to ignore 'size'
---@field highlight_background string | nil Highlight for the terminal background
---@field create_commands boolean

---Allows terminal to be of dynamic size that is based on on the size current window ('current_window') or number of all columns ('all_columns'), scaled by {value}
---@class DynamicSizeConfig
---@field based_on 'current_window' | 'all_columns'
---@field value number

---Direction in which terminal window is going to be created
---@alias Direction
---| '"vertical"' # Corresponds to |vsplit|
---| '"horizontal"' # Corresponds to |split|

---@private
---@alias WinId number | nil

---@private
---@alias BuffNr number | nil

---@private
---@class Internal table
---@field cmd "internal"
---@field args table

---@private
---@alias Cmd Internal | string | nil

---Config
---@type Config
local Config = {
  direction = "vertical",
  hide_numbers = true,
  size = 50,
  filetypes = {
    lua = { cmd = "lua %" },
    sml = { cmd = "rlwrap sml %", filetype = "sml" },
    javascript = { cmd = "node %" },
    typescript = { cmd = "ts-node %" },
    rust = { cmd = "cargo run" },
  },
  create_commands = true,
  auto_resize = false,
  dynamic_size = nil,
  highlight_background = nil,
}

-- Credits to https://github.com/is0n/jaq-nvim/blob/master/lua/jaq-nvim.lua
local function transform_cmd(cmd)
  cmd = cmd:gsub("%%", vim.fn.expand("%"))
  cmd = cmd:gsub("$fileBase", vim.fn.expand("%:r"))
  cmd = cmd:gsub("$filePath", vim.fn.expand("%:p"))
  cmd = cmd:gsub("$file", vim.fn.expand("%"))
  cmd = cmd:gsub("$dir", vim.fn.expand("%:p:h"))
  cmd = cmd:gsub("#", vim.fn.expand("#"))
  cmd = cmd:gsub("$altFile", vim.fn.expand("#"))
  return cmd
end

local function scroll_to_bottom()
  local info = vim.api.nvim_get_mode()
  if info and (info.mode == "nt" or info.mode == "n") then
    vim.api.nvim_cmd({ cmd = "normal", bang = true, args = { "G" } }, {})
  end
end

local AUGROUP_NAME = "toggle_jaq"
local GROUP = vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })

local function spawn_term(cmd, bufnr)
  vim.fn.termopen(cmd, {
    detach = 0,
    on_stdout = function()
      vim.api.nvim_buf_call(bufnr, scroll_to_bottom)
    end,
    on_stderr = function()
      vim.api.nvim_buf_call(bufnr, scroll_to_bottom)
    end,
  })
end

---@private
---Returns a table containing command to run and filetype to set based on following priority
---Check if vim.b.toggle_jaq exists if yes set return that
---Check if vim.g.toggle_jaq exists if yes set return that
---Check if Config.filetype contains a table for current's buffer filetype exists if yes return that
---Else returns 'nil'
---@return table | nil
local function get_cmd()
  local cmd = nil
  local ft = nil

  local current_ft = vim.bo.filetype

  if vim.b.toggle_jaq ~= nil then
    cmd = vim.b.toggle_jaq.cmd
    ft = vim.b.toggle_jaq.ft
  elseif vim.g.toggle_jaq ~= nil then
    cmd = vim.g.toggle_jaq.cmd
    ft = vim.g.toggle_jaq.ft
  elseif Config.filetypes[current_ft] ~= nil then
    cmd = Config.filetypes[current_ft].cmd
    ft = Config.filetypes[current_ft].filetype
  else
    return nil
  end

  return { cmd = cmd, ft = ft }
end

---Object storing information about the window in which terminal is going to be shown
---@private
---@class Window
---@field winid WinId
---@field direction Direction
---@field size number

---Global Window object
---@private
---@type Window
local Window = {
  winid = nil,
  direction = Config.direction,
  size = Config.size,
}

---Creates the window and resizes the window
function Window:create()
  -- NOTE: making a split like this always enters the split, if we leave if with "wincmd p" it would break the user's last open window
  -- NOTE: see: https://github.com/neovim/neovim/issues/14315
  if Config.dynamic_size then
    local size
    if Config.dynamic_size.based_on == "all_columns" then
      size = vim.opt.columns:get()
    elseif Config.dynamic_size.based_on == "current_window" then
      size = vim.fn.winwidth(0)
    else
      vim.notify("toggle_jaq: The only possible values for config.dynamic_size.based_on are 'all_columns' and 'current_window', was " .. vim.inspect(Config.dynamic_size.based_on), vim.log.levels.ERROR)
    end
    self.size = math.ceil(size * Config.dynamic_size.value)
  end

  if self.direction == "vertical" then
    vim.api.nvim_cmd({ cmd = "vsplit", mods = { split = "botright" } }, {})
  else
    vim.api.nvim_cmd({ cmd = "split", mods = { split = "botright" } }, {})
  end

  if Config.auto_resize then
    vim.cmd.wincmd("=")
  else
    Window:resize()
  end

  self.winid = vim.api.nvim_get_current_win()

  vim.api.nvim_create_autocmd("WinClosed", {
    group = GROUP,
    pattern = "" .. self.winid,
    callback = function()
      self.winid = nil
      vim.api.nvim_clear_autocmds({ group = GROUP })
    end,
  })

  if Config.hide_numbers then
    vim.wo[self.winid].number = false
    vim.wo[self.winid].signcolumn = "no"
    vim.wo[self.winid].relativenumber = false
  end

  if Config.highlight_background then
    vim.wo[self.winid].winhighlight = "Normal:ToggleJaqTerm"
  end
end

---Shows the terminal buffer inside the window has to be inside the buffer.
---@param buffer Buffer
function Window:show_terminal(buffer)
  vim.api.nvim_set_current_buf(buffer.bufnr)
end

---Creates, resizes and shows the buffer under 'buffer.bufnr' number inside the created window
---@param buffer Buffer
function Window:show(buffer)
  self:create()
  self:show_terminal(buffer)
end

---Closes the Window
function Window:close()
  if self:is_hidden() then
    vim.notify("toggle_jaq: Tried to close hidden terminal")
  else
    vim.api.nvim_win_close(self.winid, false)
    self.winid = nil
  end
end

function Window:is_hidden()
  return self.winid == nil
end

---Resizes the window has to be inside the actual window
function Window:resize()
  if self.direction == "vertical" then
    vim.api.nvim_cmd({ cmd = "resize", args = { self.size }, mods = { vertical = true } }, {})
  else
    vim.api.nvim_cmd({ cmd = "resize", args = { self.size }, mods = { vertical = false } }, {})
  end
end

---Updates the values of Window from the given config
---@param config Config
function Window:update_config(config)
  self.direction = config.direction
  self.size = config.size
end

---Object storing information about the buffer in which terminal is running
---@private
---@class Buffer
---@field bufnr BuffNr
---@field cmd Cmd Command terminal is going to run

---@type Buffer
local Buffer = {
  bufnr = nil,
  cmd = nil,
}

---Checks if buffer exists
---@return boolean
function Buffer:is_exist()
  return self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr)
end

---Tries to create the buffer with terminal running the command inside of it
---Returns true if it was successful creating a terminal buffer else false
---@return boolean
function Buffer:new()
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.notify("toggle_jaq: Trying to create a buffer with already valid buffer existing")
    return false
  end

  local result = get_cmd()

  if not result then
    vim.notify("toggle_jaq: There isn't a command assigned to buffer nor global nor to the current filetype: " .. vim.bo.filetype)
    return false
  end

  local bufnr = vim.api.nvim_create_buf(false, false)
  if bufnr == 0 then
    vim.notify("toggle_jaq: Could not create a buffer", vim.log.levels.ERROR)
    return false
  else
    self.bufnr = bufnr
  end

  if result.cmd == "internal" then
    local args
    if result.cmd.args then
      args = transform_cmd(result.cmd.args)
    else
      args = "%"
    end
    local output = vim.api.nvim_cmd({ cmd = "luafile", args = { args } }, { output = true })
    local output_table = {}
    for s in output:gmatch("[^\r\n]+") do
      table.insert(output_table, s)
    end
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, output_table)
  else
    local cmd = transform_cmd(result.cmd)
    vim.api.nvim_buf_call(self.bufnr, function()
      spawn_term(cmd, self.bufnr)
    end)

    if result.ft ~= nil then
      vim.bo[self.bufnr].filetype = result.ft
    end
  end

  return true
end

---If buffer exists and is valid deletes the buffer and returns true, otherwise returns false
---@return boolean
function Buffer:delete()
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
    self.bufnr = nil
    return true
  end
  return false
end

---APIS
local toggle_jaq = {}

---@private
---Creates following commands to use in nvim's commandline
---
---:JaqGSetCmd <cmd> - Sets <cmd> in global vim variable, |vim.g|
---:JaqGSetFt <ft>   - Sets <ft> in global vim variable, |vim.g|
---:JaqBSetCmd <cmd> - Sets <cmd> in buffer vim variable, |vim.b|
---:JaqBSetFt <ft>   - Sets <ft> in buffer vim variable, |vim.b|
---:JaqPrint         - Prints a table of what filetype would be set and command would be run if you tried running terminal in the current buffer
local function create_commands()
  vim.api.nvim_create_user_command("JaqGSetCmd", function(arg)
    local jaq_table = vim.g.toggle_jaq or {}
    jaq_table.cmd = arg.args
    toggle_jaq.set("g", jaq_table)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("JaqGSetFt", function(arg)
    local jaq_table = vim.g.toggle_jaq or {}
    jaq_table.ft = arg.args
    toggle_jaq.set("g", jaq_table)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("JaqBSetFt", function(arg)
    local jaq_table = vim.b.toggle_jaq or {}
    jaq_table.ft = arg.args
    toggle_jaq.set("b", jaq_table)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("JaqBSetCmd", function(arg)
    local jaq_table = vim.b.toggle_jaq or {}
    jaq_table.cmd = arg.args
    toggle_jaq.set("b", jaq_table)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("JaqPrint", function()
    local res = get_cmd()
    vim.pretty_print(res)
  end, {})
end

---Setups up toggle_jaq with the provided {config}
---@param config Config
---@see Config
toggle_jaq.setup = function(config)
  Config = vim.tbl_deep_extend("force", Config, config)
  Window:update_config({ direction = Config.direction, size = Config.size })
  if Config.highlight_background then
    vim.cmd("hi ToggleJaqTerm guibg=" .. Config.highlight_background)
  end

  if Config.create_commands then
    create_commands()
  end
end

---Shows the terminal window
toggle_jaq.show = function()
  if Window:is_hidden() then
    if not Buffer:is_exist() then
      Buffer:new()
    end
    Window:show(Buffer)
  end
end

---Hides the terminal window
toggle_jaq.hide = function()
  if not Window:is_hidden() then
    Window:close()
  end
end

---Toggles the terminal, starting it if necessary
---If terminal is showed, enter insert mode inside of it.
toggle_jaq.toggle_enter = function()
  if Window:is_hidden() then
    if not Buffer:is_exist() then
      if not Buffer:new() then
        return
      end
    end
    Window:show(Buffer)
    vim.cmd.startinsert()
  else
    Window:close()
  end
end

---Toggles the terminal, starting it if necessary
---This will break last opened window ('wincmd p')
toggle_jaq.toggle_show = function()
  if Window:is_hidden() then
    if not Buffer:is_exist() then
      if not Buffer:new() then
        return
      end
    end
    Window:show(Buffer)
    vim.cmd.wincmd("p")
  else
    Window:close()
  end
end

---Tries to rerun the command in the background
---Returns true if it succeeded else false
---@return boolean
toggle_jaq.rerun_in_bg = function()
  if Buffer:is_exist() then
    Buffer:delete()
  end
  return Buffer:new()
end

---Reruns the command, shows the terminal and enters insert mode inside terminal window
---Returns true if it succeeded else false
---@return boolean
toggle_jaq.rerun_enter = function()
  local b = toggle_jaq.rerun_in_bg()
  if not b then
    return false
  end

  -- rerun_in_bg deletes the buffer which also deletes the window, so no need to check if it exists
  Window:show(Buffer)

  vim.cmd.startinsert()

  return true
end

---Reruns the command, shows the terminal, this will break last opened window ('wincmd p')
---Returns true if it succeeded else false
---@return boolean
toggle_jaq.rerun_show = function()
  local b = toggle_jaq.rerun_in_bg()
  if not b then
    return false
  end

  -- rerun_in_bg deletes the buffer which also deletes the window, so no need to check if it exists
  Window:show(Buffer)

  vim.cmd.wincmd("p")

  return true
end

---Returns a table of what filetype would be set and command would be run if you tried running toggle_jaq in current buffer
toggle_jaq.get = function()
  return get_cmd()
end

---Sets the table, {to_set} which contains command and filetype for a given {context}
---@param context string Context in which to set the table, can be 'b' or 'buffer' for 'vim.b', or 'g' or 'global' for global
---@param set table Table with 'cmd' and 'filetype' subtables
toggle_jaq.set = function(context, set)
  local s
  if context == "g" or context == "global" then
    s = "g"
  elseif context == "b" or context == "buffer" then
    s = "b"
  else
    return
  end

  vim[s].toggle_jaq = set
end

return toggle_jaq
