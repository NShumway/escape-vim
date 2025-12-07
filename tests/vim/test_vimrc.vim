" Minimal vimrc for running vader tests
set nocompatible
filetype off
syntax off
set noswapfile
set nobackup
set nowritebackup
set viminfo=

" Add vader.vim to runtimepath
let s:script_dir = expand('<sfile>:p:h')
execute 'set runtimepath+=' . s:script_dir . '/vader.vim'

" Source test helpers
execute 'source ' . s:script_dir . '/fixtures/helpers.vim'
