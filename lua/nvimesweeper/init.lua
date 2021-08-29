local fn = vim.fn

local game = require "nvimesweeper.game"
local util = require "nvimesweeper.util"
local error = util.error

local M = {
  default_opts = {
    width = 20,
    height = 20,
    mine_count = 10,
  },
}

function M.play(opts)
  opts = vim.tbl_extend("force", M.default_opts, opts)

  if opts.width <= 0 or opts.height <= 0 or opts.mine_count <= 0 then
    error "board size and mine count must be positive integers!"
    return false
  end

  game.new_game(opts.width, opts.height, opts.mine_count)
  return true
end

function M.play_cmd(args)
  local opts = {}

  args = vim.split(args, " ")
  for _, arg in ipairs(args) do
    if arg ~= "" then
      local opt, value = string.match(arg, "(.+)=(.+)")
      if not opt then
        error "malformed arguments!"
        return false
      end

      opts[opt] = value
    end
  end

  local function input(str, opt)
    local value = tonumber(opts[opt] or fn.input(str, M.default_opts[opt]))
    if not value then
      error(opt .. " must be a number!")
      return false
    end

    opts[opt] = value
    return true
  end

  if
    not input("What board width to use? ", "width")
    or not input("What board height to use? ", "height")
    or not input("How many mines? ", "mine_count")
  then
    return false
  end

  return M.play(opts)
end

return M
