local api = vim.api

local M = {}

function M.reload()
  package.loaded["nvimesweeper"] = nil
  package.loaded["nvimesweeper.board"] = nil
  package.loaded["nvimesweeper.config"] = nil
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

function M.nnoremap(buf, lhs, rhs, desc)
  if type(lhs) == "string" then
    lhs = { lhs }
  end

  for _, value in ipairs(lhs) do
    local callback = type(rhs) == "function" and rhs or nil
    api.nvim_buf_set_keymap(
      buf,
      "n",
      value,
      callback and "" or rhs,
      { noremap = true, silent = true, callback = callback, desc = desc }
    )
  end
end

-- supports only a limited set of conversions
function M.convert_to(value, to_type)
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
    if value then
      return value ~= 0
    end
  end

  return nil
end

return M
