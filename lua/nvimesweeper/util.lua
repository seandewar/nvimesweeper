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

return M
