local api = vim.api

local M = {}

function M.reload()
  package.loaded.nvimesweeper = nil
  package.loaded["nvimesweeper.board"] = nil
  package.loaded["nvimesweeper.game"] = nil
  package.loaded["nvimesweeper.game_state"] = nil
  package.loaded["nvimesweeper.ui"] = nil
  package.loaded["nvimesweeper.util"] = nil

  return require "nvimesweeper"
end

function M.error(str)
  error("[nvimesweeper] " .. str)
end

function M.is_integer(number)
  return type(number) == "number" and math.floor(number) == number
end

function M.nnoremap(buf, lhs, rhs)
  api.nvim_buf_set_keymap(buf, "n", lhs, rhs, { noremap = true, silent = true })
end

function M.tbl_rep(value, count)
  local result = {}
  for i = 1, count do
    result[i] = value
  end
  return result
end

return M
