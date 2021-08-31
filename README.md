# Nvimesweeper

![Banner Image](./media/nvimesweeper.png)

Play Minesweeper in Neovim: because if Emacs has taught us one thing, it's that
text editors are for gaming!

_This plugin is probably a work-in-progress until I decide I want to be
productive again._

## How to play

Install it using your favourite package manager like any other plugin, then run
`:Nvimesweeper` and pray that it works properly, I guess.

Press `!` or `?` to toggle a square as flagged or TODO respectively, or press
`<Space>` to cycle between them.

Press `<CR>` (Enter/Return) or `x` to reveal a square; just try not to step on a
mine!

### Seeding the random number generator

Nvimesweeper does not take responsibility for seeding the random number
generator used to place the mines, meaning you may see the same mine layout
after restarting Nvim.

To solve this, you may want to seed the RNG before running `:Nvimesweeper`,
like:

```vim
:lua math.randomseed(os.time())
```

## Why did you make this?

I don't know...
