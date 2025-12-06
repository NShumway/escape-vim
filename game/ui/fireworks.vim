" FIREWORKS Screen for Escape Vim
" Full-screen victory animation

" ============================================================================
" State
" ============================================================================

let s:firework_frame = 0
let s:firework_frames = []
let s:firework_bufnr = -1

" Victory banner (ASCII art)
let s:victory_banner = []
call add(s:victory_banner, '        ██╗   ██╗██╗ ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗██╗')
call add(s:victory_banner, '        ██║   ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝██║')
call add(s:victory_banner, '        ██║   ██║██║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝ ██║')
call add(s:victory_banner, '        ╚██╗ ██╔╝██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝  ╚═╝')
call add(s:victory_banner, '         ╚████╔╝ ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║   ██╗')
call add(s:victory_banner, '          ╚═══╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝')

" ============================================================================
" Frame Generation
" ============================================================================

" Generate random star positions
function! s:GenerateStars(count, width, height)
  let l:stars = []
  for i in range(a:count)
    let l:x = rand() % a:width
    let l:y = rand() % a:height
    call add(l:stars, [l:x, l:y])
  endfor
  return l:stars
endfunction

" Generate a firework burst pattern
function! s:GenerateBurst(x, y)
  let l:lines = []
  " Simple burst pattern
  call add(l:lines, {'x': a:x, 'y': a:y - 2, 'char': '|'})
  call add(l:lines, {'x': a:x - 2, 'y': a:y - 1, 'char': '\'})
  call add(l:lines, {'x': a:x + 2, 'y': a:y - 1, 'char': '/'})
  call add(l:lines, {'x': a:x - 4, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x - 3, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x - 2, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x - 1, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x, 'y': a:y, 'char': '*'})
  call add(l:lines, {'x': a:x + 1, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x + 2, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x + 3, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x + 4, 'y': a:y, 'char': '─'})
  call add(l:lines, {'x': a:x - 2, 'y': a:y + 1, 'char': '/'})
  call add(l:lines, {'x': a:x + 2, 'y': a:y + 1, 'char': '\'})
  call add(l:lines, {'x': a:x, 'y': a:y + 2, 'char': '|'})
  return l:lines
endfunction

" Generate a single animation frame
function! s:GenerateFrame(frame_num, width, height)
  " Initialize empty canvas
  let l:canvas = []
  for i in range(a:height)
    call add(l:canvas, repeat(' ', a:width))
  endfor

  " Add random stars (different each frame for twinkle effect)
  let l:star_count = 15 + (a:frame_num % 3) * 5
  for i in range(l:star_count)
    let l:x = (a:frame_num * 7 + i * 13) % a:width
    let l:y = (a:frame_num * 11 + i * 17) % (a:height - 15)
    if l:y >= 0 && l:y < a:height && l:x >= 0 && l:x < a:width
      let l:line = l:canvas[l:y]
      let l:canvas[l:y] = strpart(l:line, 0, l:x) . '*' . strpart(l:line, l:x + 1)
    endif
  endfor

  " Add 2-3 firework bursts at different positions per frame
  let l:burst_count = 2 + (a:frame_num % 2)
  for i in range(l:burst_count)
    let l:bx = 15 + ((a:frame_num * 23 + i * 31) % (a:width - 30))
    let l:by = 5 + ((a:frame_num * 17 + i * 19) % 10)
    let l:burst = s:GenerateBurst(l:bx, l:by)
    for l:point in l:burst
      let l:px = l:point.x
      let l:py = l:point.y
      if l:py >= 0 && l:py < a:height && l:px >= 0 && l:px < a:width
        let l:line = l:canvas[l:py]
        let l:canvas[l:py] = strpart(l:line, 0, l:px) . l:point.char . strpart(l:line, l:px + 1)
      endif
    endfor
  endfor

  " Add victory banner in center
  " Calculate banner_x once using first line to ensure consistent alignment
  let l:banner_y = (a:height / 2) - 3
  let l:banner_x = (a:width - strdisplaywidth(s:victory_banner[0])) / 2
  if l:banner_x < 0
    let l:banner_x = 0
  endif
  for l:idx in range(len(s:victory_banner))
    let l:banner_line = s:victory_banner[l:idx]
    let l:y = l:banner_y + l:idx
    if l:y >= 0 && l:y < a:height
      let l:canvas[l:y] = strpart(repeat(' ', l:banner_x), 0, l:banner_x) . l:banner_line
    endif
  endfor

  return l:canvas
endfunction

" Pre-generate all animation frames
function! s:GenerateAllFrames()
  let s:firework_frames = []
  let l:width = &columns
  let l:height = &lines - 1  " Leave room for command line

  for i in range(6)
    call add(s:firework_frames, s:GenerateFrame(i, l:width, l:height))
  endfor
endfunction

" ============================================================================
" Buffer Management
" ============================================================================

function! s:GetBuffer()
  let s:firework_bufnr = Util_GetScratchBuffer(s:firework_bufnr)
  return s:firework_bufnr
endfunction

" ============================================================================
" Animation Control
" ============================================================================

" Start the fireworks animation
function! Fireworks_Start()
  " Hide sideport for full-screen effect
  call Sideport_Hide()

  " Generate frames
  call s:GenerateAllFrames()

  " Switch to fireworks buffer
  let l:bufnr = s:GetBuffer()
  execute 'buffer ' . l:bufnr

  " Configure display
  setlocal nomodifiable
  setlocal nonumber
  setlocal norelativenumber
  setlocal nocursorline
  setlocal nocursorcolumn

  " Block all input during animation (timed screen, no interaction needed)
  call UI_BlockAll()
  call UI_SetupQuit()

  " Start animation using tick system (5 ticks = 250ms at 50ms/tick)
  let s:firework_frame = 0
  call s:RenderFrame()
  call Tick_Subscribe('fireworks:animation', function('s:AnimateFrame'), 5)
endfunction

" Render current frame
function! s:RenderFrame()
  if s:firework_frame >= len(s:firework_frames)
    return
  endif

  let l:bufnr = s:GetBuffer()
  let l:frame = s:firework_frames[s:firework_frame]

  call setbufvar(l:bufnr, '&modifiable', 1)
  call deletebufline(l:bufnr, 1, '$')
  call setbufline(l:bufnr, 1, l:frame)
  call setbufvar(l:bufnr, '&modifiable', 0)

  redraw!
endfunction

" Animate to next frame (tick callback)
" @param tick: current tick number
" @return: 1 to stay subscribed
function! s:AnimateFrame(tick)
  let s:firework_frame = (s:firework_frame + 1) % len(s:firework_frames)
  call s:RenderFrame()
  return 1
endfunction
