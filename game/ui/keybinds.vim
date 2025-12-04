" UI Keybind Management for Escape Vim
" Unified blocking/allowing system for UI screens (lore, results, defeat, etc.)

" ============================================================================
" Block All Motion/Editing Keys
" ============================================================================

" Block all standard Vim motion and editing keys for UI screens.
" This prevents unintended cursor movement or buffer modifications.
" Uses the same categories as levels/api/input.vim for consistency.
function! UI_BlockAll()
  " Basic motions
  for l:key in ['h', 'j', 'k', 'l', 'w', 'W', 'e', 'E', 'b', 'B']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Line jumps
  for l:key in ['0', '^', '$', 'gg', 'G', 'H', 'M', 'L']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Paragraph/matching
  for l:key in ['{', '}', '%']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Search and find
  for l:key in ['/', '?', 'n', 'N', '*', '#', 'f', 'F', 't', 'T', ';', ',']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Marks and jumps
  for l:key in ["'", '`', 'm', '<C-O>', '<C-I>']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Scroll
  for l:key in ['<C-D>', '<C-U>', '<C-F>', '<C-B>', '<C-E>', '<C-Y>']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Insert/change/delete
  for l:key in ['i', 'I', 'a', 'A', 'o', 'O', 'c', 'C', 's', 'S', 'd', 'D', 'x', 'X', 'r', 'R']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Visual mode
  for l:key in ['v', 'V', '<C-V>']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Undo/redo
  for l:key in ['u', '<C-R>']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Misc keys that might cause issues
  for l:key in ['p', 'P', 'y', 'Y', '.', '<Space>', '<BS>', '<Del>']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Arrow keys
  for l:key in ['<Up>', '<Down>', '<Left>', '<Right>']
    execute 'nnoremap <buffer> <silent> ' . l:key . ' <Nop>'
  endfor

  " Enter (block by default, screens can re-allow)
  nnoremap <buffer> <silent> <CR> <Nop>

  " Block bare 'q' to prevent accidental macro recording
  nnoremap <buffer> <silent> q <Nop>
endfunction

" ============================================================================
" Allow Specific Keys with Actions
" ============================================================================

" Allow specific keys by mapping them to callback functions.
" @param mappings: dictionary of {key: Funcref} pairs
"   Example: {'j': function('s:SelectNext'), '<CR>': function('s:Start')}
function! UI_AllowKeys(mappings)
  for [l:key, l:Callback] in items(a:mappings)
    execute 'nnoremap <buffer> <silent> ' . l:key . ' :call ' . string(l:Callback) . '()<CR>'
  endfor
endfunction

" ============================================================================
" Standard Quit Handling
" ============================================================================

" Set up standard quit keybindings (ZZ and ZQ).
" These provide a consistent way to exit the game from any UI screen.
function! UI_SetupQuit()
  nnoremap <buffer> <silent> ZZ :qa!<CR>
  nnoremap <buffer> <silent> ZQ :qa!<CR>
endfunction
