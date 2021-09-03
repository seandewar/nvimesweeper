local default_config = {
  opts = {
    tab = false,
  },
  prompt_presets = { "easy", "medium", "hard", "insane", "nightmare" },
  presets = {
    easy = {
      width = 9,
      height = 9,
      mines = 10,
    },
    medium = {
      width = 16,
      height = 16,
      mines = 40,
    },
    hard = {
      width = 30,
      height = 16,
      mines = 99,
    },
    insane = {
      width = 40,
      height = 16,
      mines = 192,
    },
    nightmare = {
      width = 60,
      height = 16,
      mines = 384,
    },
  },
  board_chars = {
    unrevealed = " ",
    revealed = " ",
    mine = "*",
    flag = "!",
    flag_wrong = "X",
    maybe = "?",
  },
}

local M = {}

function M.apply_config(config)
  M.config = vim.tbl_deep_extend("force", default_config, config)
end

return M
