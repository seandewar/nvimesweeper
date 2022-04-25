local fn, uv = vim.fn, vim.loop

local config_mod = require "nvimesweeper.config"
local game = require "nvimesweeper.game"
local util = require "nvimesweeper.util"
local error = util.error

local opt_types = {
  width = "number",
  height = "number",
  mines = "number",
  seed = "number", -- can be nil
  tab = "boolean",
}

local M = {}

function M.setup(new_config)
  return config_mod.apply_config(new_config or {})
end

function M.play(opts)
  -- ensure that we're setup
  if not config_mod.config then
    M.setup {}
  end

  local config = config_mod.config
  opts = vim.tbl_extend("force", config.opts, opts or {})

  -- modifying opts while iterating it with pairs() is "A Bad Idea(TM)", so
  -- modify new_opts instead and replace opts with it later
  local new_opts = {}
  for opt, value in pairs(opts) do
    local correct_type = opt_types[opt]
    local preset
    if not correct_type then
      preset = config.presets[opt]
      if preset then
        correct_type = "boolean" -- presets act like bool options
      else
        error('unknown option "' .. opt .. '"')
      end
    end

    value = util.convert_to(value, correct_type)
    if value == nil then
      error(opt .. " should be a " .. correct_type .. "!")
    end

    if preset and value then
      new_opts = vim.tbl_extend("force", new_opts, preset)
    else
      new_opts[opt] = value
    end
  end
  opts = new_opts

  -- if nothing was specified for the board size and mine count, prompt for a
  -- preset to use instead
  if not opts.width and not opts.height and not opts.mines then
    local lines = { "Choose a game preset: " }
    local choices = {}
    for _, preset_name in ipairs(config.prompt_presets) do
      local preset = config.presets[preset_name]
      lines[#lines + 1] = string.format(
        "- %s (%dx%d, %d mines)",
        preset_name,
        preset.width,
        preset.height,
        preset.mines
      )
      choices[#choices + 1] = "&" .. preset_name
    end
    lines[#lines + 1] = ""
    choices[#choices + 1] = "&custom"

    local choice = fn.confirm(
      table.concat(lines, "\n"),
      table.concat(choices, "\n"),
      #config.prompt_presets + 1
    )
    if choice == 0 then
      return -- cancelled
    elseif choice <= #config.prompt_presets then
      local preset = config.presets[config.prompt_presets[choice]]
      opts = vim.tbl_extend("force", opts, preset)
    end
  end

  if not opts.seed then
    -- choose a seed based on the current time (in seconds) if omitted
    local seconds, _ = uv.gettimeofday()
    opts.seed = seconds
  elseif not util.is_integer(opts.seed) then
    error "the seed must be an integer!"
  end

  -- ensure we have a value for the board size and mine count
  local function input_nr(str, opt, default)
    opts[opt] = opts[opt]
      or util.convert_to(fn.input(str, default), opt_types[opt])
    return opts[opt] ~= ""
  end
  if
    not input_nr("Board width? ", "width", "40")
    or not input_nr("Board height? ", "height", "12")
    or not input_nr(
      "How many mines? ",
      "mines",
      math.max(2, math.floor(opts.width * opts.height * 0.15))
    )
  then
    return -- cancelled
  end

  if
    not util.is_integer(opts.width)
    or not util.is_integer(opts.height)
    or not util.is_integer(opts.mines)
    or opts.width <= 0
    or opts.height <= 0
    or opts.mines <= 0
  then
    error "board size and mine count must be positive integers!"
  end

  local size = opts.width * opts.height
  if opts.mines == 1 or opts.mines == size - 1 then
    error(
      "way too easy; your first chosen square is always safe, so this would be "
        .. "a guaranteed win..."
    )
  elseif opts.mines >= size then
    error "impossible game; too many mines!"
  end

  game.new_game(opts.width, opts.height, opts.mines, opts.seed, opts.tab)
end

function M.play_cmd(args)
  args = vim.split(args or "", " ")
  local opts = {}
  for _, arg in ipairs(args) do
    if arg ~= "" then
      local opt, equal, value_str = string.match(arg, "([^=]+)(=?)(.*)")
      if not opt then
        error "malformed arguments!"
      elseif equal == "" then
        value_str = "true"
      end
      opts[opt] = value_str -- this will be converted by play()
    end
  end

  M.play(opts)
end

return M
