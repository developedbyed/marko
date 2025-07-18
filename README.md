# marko.nvim 🎯

A modern Neovim plugin for enhanced mark management with a beautiful popup interface.

## ✨ Features

- 🎨 **Beautiful popup interface** - Clean, modern UI for browsing marks
- 🎯 **Mark types support** - Buffer marks (a-z) and global marks (A-Z)
- 📝 **Line preview** - See the actual content at each mark
- ⚡ **Fast navigation** - Jump to marks with Enter or click
- 🗑️ **Easy deletion** - Delete marks with 'd' key
- 👻 **Virtual text** - See mark indicators directly in your code
- 🎛️ **Configurable** - Customize appearance and keybindings
- 📱 **Responsive** - Adapts to your terminal size

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'developedbyed/marko.nvim',
  config = function()
    require('marko').setup({
      width = 100,
      height = 100,
      border = "rounded",
      title = " Marks ",
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'developedbyed/marko.nvim',
  config = function()
    require('marko').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'developedbyed/marko.nvim'
```

## 🚀 Usage

### Basic Usage

1. **Set marks** in your files:
   ```vim
   ma    " Set buffer mark 'a'
   mA    " Set global mark 'A'
   ```

2. **Open the marks popup**:
   ```vim
   :Marko
   ```
   Or use the default keymap: `"`

3. **Navigate in the popup**:
   - `Enter` - Jump to mark
   - `d` - Delete mark
   - `q` or `Esc` - Close popup

### Mark Types

- **Buffer marks (a-z)**: Local to the current buffer, lost when buffer is closed
- **Global marks (A-Z)**: Persist across files and vim sessions

### Virtual Text

When enabled, marks are displayed as virtual text in your code:
- Set a mark with `ma`, `mB`, etc. and see the indicator appear immediately
- Virtual text shows both buffer marks (blue) and global marks (red)
- Toggle virtual text on/off with `:MarkoToggleVirtual`

## ⚙️ Configuration

```lua
require('marko').setup({
  -- Popup window dimensions
  width = 100,
  height = 100,
  
  -- Border style: 'rounded', 'single', 'double', 'solid', 'shadow'
  border = "rounded",
  
  -- Popup title
  title = " Marks ",
  
  -- Default keymap to open popup (set to false to disable)
  default_keymap = '"',
  
  -- Key mappings within popup
  -- Can be a single key (string) or multiple keys (table of strings)
  keymaps = {
    delete = "d",
    goto = { "<CR>", "o" }, -- Example of multiple keys
    close = { "<Esc>", "q" },
  },
  
  -- Show marks from all buffers or just current buffer
  show_all_buffers = false,
  
  -- Exclude certain marks from display
  exclude_marks = { "'", "`", "^", ".", "[", "]", "<", ">" },
  
  -- Virtual text configuration
  virtual_text = {
    enabled = true,        -- Enable virtual text marks
    icon = "●",           -- Icon to display
    hl_group = "Comment", -- Highlight group
    position = "eol",     -- Position: "eol" or "overlay"
  },
})
```

## 🎨 Customization

### Custom Keymaps

```lua
-- Disable default keymap and set your own
require('marko').setup({
  default_keymap = false,  -- Disable default ""
})

-- Set custom keymap
vim.keymap.set('n', '"', function()
  require('marko').show_marks()
end, { desc = 'Show marks popup' })

-- Or use leader key
vim.keymap.set('n', '<leader>mm', function()
  require('marko').show_marks()
end, { desc = 'Show marks popup' })
```

### Styling

The plugin respects your colorscheme. You can customize the appearance using highlight groups:

```lua
-- Example customization
vim.cmd([[
  highlight link MarksPopupBorder FloatBorder
  highlight link MarksPopupTitle Title
]])
```

## 🔧 Commands

| Command | Description |
|---------|-------------|
| `:Marko` | Open the marks popup |
| `:MarkoToggleVirtual` | Toggle virtual text marks on/off |

## 🎯 Mark Quick Reference

| Mark | Type | Scope | Persistence |
|------|------|-------|-------------|
| `a-z` | Buffer | Current buffer only | Lost when buffer closes |
| `A-Z` | Global | Across all files | Saved in shada file |

## 🤝 Contributing

Contributions are welcome! Please feel free to:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📚 Related

- [vim-signature](https://github.com/kshenoy/vim-signature) - Mark visualization
- [marks.nvim](https://github.com/chentoast/marks.nvim) - Alternative marks plugin

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the Neovim community
- Inspired by vim's built-in marks system
- Uses Neovim's modern Lua API

---

**Made with ❤️ for Neovim users**
