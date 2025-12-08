# Escape Vim

A game built inside Vim. Learn Vim commands by escaping mazes and solving puzzles.

## Installation

### Download (Recommended)

1. Download the latest release from [Releases](https://github.com/NShumway/escape-vim/releases)
2. Extract the tarball:
   ```bash
   tar -xzf escape-vim-*-macos-arm64.tar.gz
   cd escape-vim-*-macos-arm64
   ```
3. Run the installer:
   ```bash
   ./install.sh
   ```
4. Play!
   ```bash
   escape-vim
   ```

### Uninstall

```bash
~/.escape-vim/uninstall.sh
```

### Build from Source

```bash
make
./play.sh
```

## Requirements

- macOS with Apple Silicon (arm64)
- Terminal with 256-color support
- Xcode command line tools (for building from source only)

## Commands

```bash
escape-vim          # Start the game
escape-vim --reset  # Clear save data
escape-vim --help   # Show help
```

## About

Escape Vim is a game that runs inside Vim itself. You play by using real Vim
commands - the same ones you'd use for text editing. Complete levels to unlock
new commands and prove your mastery.

## License

This project is a fork of Vim 9.1 and is distributed under the Vim License.
See [LICENSE](LICENSE) for the full Vim license text.

### Attribution

Escape Vim is built on Vim by Bram Moolenaar and contributors.
- Original Vim: https://www.vim.org
- Vim source: https://github.com/vim/vim

The Vim License requires that modified versions clearly indicate they are
modified. This is done in the game's intro screen and `:version` output.
