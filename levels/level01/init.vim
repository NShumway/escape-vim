" Level 1: The Maze
" Launch with: ./vim --clean -S levels/level01/init.vim

" Load the maze
edit levels/level01/maze.txt

" Load game logic
source levels/level01/maze.vim

" Position cursor at start (row 2, col 2 - first open space)
call cursor(2, 2)

" Set exit position for quit checking (row 10, col 27 where Q is)
call gamesetexit(10, 27)

" Make buffer read-only
setlocal nomodifiable
setlocal buftype=nofile
setlocal noswapfile

" Clean UI
set laststatus=0
set noshowcmd
set noshowmode
set shortmess+=F
set noruler
set cmdheight=1

" Disable mouse completely
set mouse=

redraw!
