" Debug logging for Escape Vim
" Enable by setting g:escape_vim_debug = 1 before sourcing

" Debug flag (default OFF - production builds don't set this)
if !exists('g:escape_vim_debug')
  let g:escape_vim_debug = 0
endif

let s:log_path = ''

" Initialize debug logging
" Called once at startup if debug mode is enabled
function! Debug_Init()
  if !g:escape_vim_debug
    return
  endif

  " Use same directory as save data
  if has('mac')
    let l:dir = expand('~/Library/Application Support/EscapeVim')
  else
    let l:dir = expand('~/.local/share/escapevim')
  endif

  " Create directory if needed
  if !isdirectory(l:dir)
    call mkdir(l:dir, 'p')
  endif

  let s:log_path = l:dir . '/debug.log'

  " Truncate log file on each launch
  call writefile(['=== Escape Vim Debug Log ===', 'Started: ' . strftime('%Y-%m-%d %H:%M:%S'), ''], s:log_path)

  call Debug_Log('Debug mode initialized')
endfunction

" Log a message (no-op if debug disabled)
function! Debug_Log(msg)
  if !g:escape_vim_debug || s:log_path == ''
    return
  endif

  let l:timestamp = strftime('%H:%M:%S')
  let l:line = '[' . l:timestamp . '] ' . a:msg
  call writefile([l:line], s:log_path, 'a')
endfunction

" Log with context (file/function info)
function! Debug_LogContext(context, msg)
  call Debug_Log(a:context . ': ' . a:msg)
endfunction

" Log an error (always logs if debug enabled, prefixed with ERROR)
function! Debug_Error(msg)
  call Debug_Log('ERROR: ' . a:msg)
endfunction

" Wrap a potentially failing eval and log errors
function! Debug_SafeEval(expr, context)
  try
    return eval(a:expr)
  catch
    call Debug_Error(a:context . ' - eval failed: ' . v:exception)
    call Debug_Error('Expression: ' . a:expr[:100] . (len(a:expr) > 100 ? '...' : ''))
    throw v:exception
  endtry
endfunction
