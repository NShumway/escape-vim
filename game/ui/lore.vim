" LORE Screen for Escape Vim
" Displays level lore and level selector

" ============================================================================
" State
" ============================================================================

let s:selected_level_idx = 0
let s:unlocked_levels = []
let s:lore_bufnr = -1

" ============================================================================
" Buffer Management
" ============================================================================

" Create or get the lore buffer
function! s:GetBuffer()
  let s:lore_bufnr = Util_GetScratchBuffer(s:lore_bufnr)
  return s:lore_bufnr
endfunction

" ============================================================================
" Rendering
" ============================================================================

" Render the LORE screen
function! Lore_Render()
  " Get unlocked levels
  let s:unlocked_levels = Save_GetUnlockedLevels()

  " Find index of current level
  let s:selected_level_idx = index(s:unlocked_levels, g:current_level_id)
  if s:selected_level_idx < 0
    let s:selected_level_idx = 0
  endif

  " Show sideport with commander quote
  call Sideport_Show()
  let l:quote = get(g:current_level_meta, 'quote', '')
  call Sideport_RenderLore(l:quote)

  " Render main content area
  call s:RenderMainArea()

  " Set up input handlers
  call s:SetupInput()
endfunction

" Render the main content area (lore text + level selector)
function! s:RenderMainArea()
  let l:bufnr = s:GetBuffer()
  let l:lines = []

  " Top spacing
  call add(l:lines, '')

  " Decorative line
  call add(l:lines, '    ' . repeat('═', 42))
  call add(l:lines, '')

  " Load and display lore text
  let l:lore_path = g:current_level_path . '/lore.txt'
  if filereadable(l:lore_path)
    let l:lore_lines = readfile(l:lore_path)
    for l:line in l:lore_lines
      call add(l:lines, '    ' . l:line)
    endfor
  else
    call add(l:lines, '    [Lore text not found]')
  endif

  call add(l:lines, '')
  " Decorative line
  call add(l:lines, '    ' . repeat('═', 42))
  call add(l:lines, '')
  call add(l:lines, '')

  " Level selector
  let l:manifest = eval(join(readfile('levels/manifest.vim'), ''))
  let l:save = Save_Load()
  let l:completed = get(l:save, 'completed_levels', [])

  let l:idx = 0
  for l:level_id in s:unlocked_levels
    " Find level info from manifest
    let l:title = 'Unknown'
    for l:entry in l:manifest
      if l:entry.id == l:level_id
        let l:title = l:entry.title
        break
      endif
    endfor

    " Build display line
    let l:prefix = (l:idx == s:selected_level_idx) ? '    > ' : '      '
    let l:check = (index(l:completed, l:level_id) >= 0) ? ' ✓' : ''
    call add(l:lines, l:prefix . 'LEVEL ' . l:level_id . ': ' . l:title . l:check)

    let l:idx += 1
  endfor

  call add(l:lines, '')
  if len(s:unlocked_levels) > 1
    call add(l:lines, '      j/k to select level, <Enter> to begin')
  else
    call add(l:lines, '      Press <Enter> to begin')
  endif
  call add(l:lines, '')

  " Set buffer content
  call setbufvar(l:bufnr, '&modifiable', 1)
  call deletebufline(l:bufnr, 1, '$')
  call setbufline(l:bufnr, 1, l:lines)
  call setbufvar(l:bufnr, '&modifiable', 0)

  " Switch to lore buffer in main window
  execute 'buffer ' . l:bufnr
  setlocal nomodifiable
  setlocal nonumber
  setlocal norelativenumber
  setlocal nocursorline
  setlocal nocursorcolumn
endfunction

" ============================================================================
" Input Handling
" ============================================================================

" Set up input handlers for LORE screen
function! s:SetupInput()
  " Block all keys, then allow only what we need
  call UI_BlockAll()
  call UI_AllowKeys({
        \ 'j': function('s:SelectNext'),
        \ 'k': function('s:SelectPrev'),
        \ '<CR>': function('s:StartLevel')
        \ })
  call UI_SetupQuit()
endfunction

" Select next level
function! s:SelectNext()
  if s:selected_level_idx < len(s:unlocked_levels) - 1
    let s:selected_level_idx += 1
    let l:level_id = s:unlocked_levels[s:selected_level_idx]
    call Game_LoadLevelMeta(l:level_id)
    call Lore_Render()
  endif
endfunction

" Select previous level
function! s:SelectPrev()
  if s:selected_level_idx > 0
    let s:selected_level_idx -= 1
    let l:level_id = s:unlocked_levels[s:selected_level_idx]
    call Game_LoadLevelMeta(l:level_id)
    call Lore_Render()
  endif
endfunction

" Start the selected level
function! s:StartLevel()
  let l:level_id = s:unlocked_levels[s:selected_level_idx]
  call Game_LoadLevelMeta(l:level_id)
  call GameTransition('GAMEPLAY')
endfunction
