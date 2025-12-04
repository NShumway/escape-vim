" Utility functions for Escape Vim
" Shared helpers used across multiple modules

" Format seconds as MM:SS
" @param seconds: integer number of seconds
" @return: string formatted as "MM:SS"
function! Util_FormatTime(seconds)
  let l:mins = a:seconds / 60
  let l:secs = a:seconds % 60
  return printf('%02d:%02d', l:mins, l:secs)
endfunction

" Get or create a scratch buffer for UI display
" @param bufnr: current buffer number (-1 if none)
" @return: valid buffer number (creates new if needed)
function! Util_GetScratchBuffer(bufnr)
  if a:bufnr < 0 || !bufexists(a:bufnr)
    let l:bufnr = bufadd('')
    call bufload(l:bufnr)

    call setbufvar(l:bufnr, '&buftype', 'nofile')
    call setbufvar(l:bufnr, '&bufhidden', 'hide')
    call setbufvar(l:bufnr, '&swapfile', 0)
    call setbufvar(l:bufnr, '&buflisted', 0)

    return l:bufnr
  endif

  return a:bufnr
endfunction
