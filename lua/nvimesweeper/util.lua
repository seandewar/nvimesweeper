local M = {}

function M.error(str)
  error("[nvimesweeper] " .. str)
end

function M.reload()
  package.loaded.nvimesweeper = nil
  package.loaded["nvimesweeper.game"] = nil
  package.loaded["nvimesweeper.util"] = nil

  return require "nvimesweeper"
end

function M.is_integer(number)
  return type(number) == "number" and math.floor(number) == number
end

return M
