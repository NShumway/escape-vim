" Input API for Escape Vim
" Declarative command blocking/allowing per level

" Command Categories
let g:GameCommandCategories = {
  \ 'arrows': ['<Up>', '<Down>', '<Left>', '<Right>'],
  \ 'search': ['/', '?', 'n', 'N', '*', '#'],
  \ 'find_char': ['f', 'F', 't', 'T', ';', ','],
  \ 'word_motion': ['w', 'W', 'e', 'E', 'b', 'B'],
  \ 'line_jump': ['gg', 'G', 'H', 'M', 'L', '0', '$', '^'],
  \ 'paragraph': ['{', '}'],
  \ 'matching': ['%'],
  \ 'marks': ["'", '`', 'm'],
  \ 'jump_list': ['<C-O>', '<C-I>'],
  \ 'scroll': ['<C-D>', '<C-U>', '<C-F>', '<C-B>'],
  \ 'insert': ['i', 'I', 'a', 'A', 'o', 'O'],
  \ 'change': ['c', 'C', 's', 'S'],
  \ 'delete': ['d', 'D', 'x', 'X'],
  \ 'visual': ['v', 'V', '<C-V>'],
  \ 'undo_redo': ['u', '<C-R>'],
  \ }

" Private state
let s:block_callback = v:null

" Set the callback for blocked command attempts
" @param Callback: funcref that receives (key, category) arguments
function! Input_SetBlockCallback(Callback)
  let s:block_callback = a:Callback
endfunction

" Internal handler for blocked keys
function! s:OnBlocked(key, category)
  if s:block_callback != v:null
    call s:block_callback(a:key, a:category)
  endif
  return ''
endfunction

" Block all commands in specified categories
" @param categories: list of category names from g:GameCommandCategories
function! Input_BlockCategories(categories)
  for l:cat in a:categories
    if has_key(g:GameCommandCategories, l:cat)
      call Input_BlockKeys(g:GameCommandCategories[l:cat], l:cat)
    endif
  endfor
endfunction

" Block specific keys (for custom per-level blocking)
" @param keys: list of key notations (e.g., ['<Space>', 'x'])
" @param category: category name for the block message
function! Input_BlockKeys(keys, category)
  for l:key in a:keys
    " Map to <Nop> for silent blocking - no command line output
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor
endfunction

" Unblock all commands in specified categories
" @param categories: list of category names
function! Input_UnblockCategories(categories)
  for l:cat in a:categories
    if has_key(g:GameCommandCategories, l:cat)
      for l:key in g:GameCommandCategories[l:cat]
        silent! execute 'nunmap <buffer> ' . l:key
      endfor
    endif
  endfor
endfunction

" Block all categories (for restrictive levels)
function! Input_BlockAll()
  call Input_BlockCategories(keys(g:GameCommandCategories))
endfunction

" Unblock all commands
function! Input_UnblockAll()
  call Input_UnblockCategories(keys(g:GameCommandCategories))
endfunction
