local fn = vim.fn

local game = require "nvimesweeper.game"
local util = require "nvimesweeper.util"
local error = util.error

local M = {
  default_opts = {
    width = 40,
    height = 12,
    mines = 60,
    tab = false,
  },
}

local opt_types = {
  width = "number",
  height = "number",
  mines = "number",
  tab = "boolean",
}

local function convert(opt, value, to_type)
  local from_type = type(value)
  if from_type == to_type then
    return value
  end

  if to_type == "number" then
    return tonumber(value)
  elseif to_type == "boolean" then
    if from_type == "string" then
      if value == "true" then
        return true
      elseif value == "false" then
        return false
      end
    end

    value = tonumber(value)
    return value == nil and nil or value ~= 0
  end

  return nil
end

function M.play(opts)
  opts = vim.tbl_extend("force", M.default_opts, opts)

  for opt, value in pairs(opts) do
    local correct_type = opt_types[opt]
    if not correct_type then
      error('unknown option "' .. opt .. '"')
    end

    value = convert(opt, value, correct_type)
    if value == nil then
      error(opt .. " should be a " .. correct_type .. "!")
    end
    opts[opt] = value
  end

  if
    opts.width <= 0
    or opts.height <= 0
    or opts.mines <= 0
    or not util.is_integer(opts.width)
    or not util.is_integer(opts.height)
    or not util.is_integer(opts.mines)
  then
    error "board size and mine count must be positive integers!"
  end

  local size = opts.width * opts.height
  if opts.mines == 1 or opts.mine_count == size - 1 then
    error(
      "way too easy; your first chosen square is always safe, so this would be "
        .. "a guaranteed win..."
    )
  elseif opts.mines >= size then
    error "impossible game; too many mines!"
  end

  game.new_game(opts.width, opts.height, opts.mines, opts.tab)
end

function M.play_cmd(args)
  args = vim.split(args, " ")
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

  local function input_nr(str, opt)
    opts[opt] = opts[opt] or fn.input(str, M.default_opts[opt])
  end

  input_nr("Board width? ", "width")
  input_nr("Board height? ", "height")
  input_nr("How many mines? ", "mines")
  M.play(opts)
end

return M
