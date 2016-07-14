let s:V = protocol#vital()
let s:File = s:V.import('System.File')
let s:Path = s:V.import('System.Filepath')
let s:Guard = s:V.import('Vim.Guard')
let s:Buffer = s:V.import('Vim.Buffer')
let s:Process = s:V.import('Vim.Process')

function! s:throw(msg) abort
  call protocol#throw(printf('kio: %s', a:msg))
endfunction
function! s:kioclient_copy(src_uri, target_uri) abort
  let options = get(a:000, 0, {})
  if !executable(g:protocol#kio#kioclient_exec)
    call s:throw(printf(
          \ '"%s" is not executable. Assign kioclient executable to g:protocol#kio#kioclient_exec.',
          \ g:protocol#kio#kioclient_exec,
          \))
  endif
  let args = [g:protocol#kio#kioclient_exec, "copy", "--overwrite", a:src_uri, a:target_uri]
  let result = s:Process.system(args, options)
  if s:Process.get_last_status()
    call s:throw(printf(
          \ 'Fail: %s%s',
          \ join(args, ' '),
          \ empty(result) ? '' : "\n" . result,
          \))
  endif
  return protocol#split_posix_text(result)
endfunction
function! s:kioclient_cat(uri) abort
  let options = get(a:000, 0, {})
  if !executable(g:protocol#kio#kioclient_exec)
    call s:throw(printf(
          \ '"%s" is not executable. Assign kioclient executable to g:protocol#kio#kioclient_exec.',
          \ g:protocol#kio#kioclient_exec,
          \))
  endif
  let command = "cat"
  let args = [g:protocol#kio#kioclient_exec, command, a:uri]
  let result = s:Process.system(args, options)
  return protocol#split_posix_text(result)
endfunction
function! s:kioclient_ls(uri) abort
  let options = get(a:000, 0, {})
  if !executable(g:protocol#kio#kioclient_exec)
    call s:throw(printf(
          \ '"%s" is not executable. Assign kioclient executable to g:protocol#kio#kioclient_exec.',
          \ g:protocol#kio#kioclient_exec,
          \))
  endif
  let command = "ls"
  let args = [g:protocol#kio#kioclient_exec, command, a:uri]
  let result = s:Process.system(args, options)
  return protocol#split_posix_text(result)
endfunction
function! protocol#kio#read(uri, ...) abort
  return s:kioclient_cat(a:uri)
endfunction
function! protocol#kio#write(uri, content, ...) abort
  try
  	let tempfilename = tempname()
    call writefile(a:content, tempfilename)
    call s:kioclient_copy(tempfilename, a:uri)
  finally
    call delete(tempfilename)
  endtry
endfunction
function! protocol#kio#is_writable(uri) abort
  return 1
endfunction
function! protocol#kio#SourceCmd(uri, ...) abort
  let cmdarg  = get(a:000, 0, v:cmdarg)
  let options = protocol#parse_cmdarg(cmdarg)
  let content = protocol#kio#read(a:uri)
  try
    let tempfile = tempname()
    call writefile(content, tempfile)
    execute printf('source %s', fnameescape(tempfile))
  finally
    if filereadable(tempfile)
      call delete(tempfile)
    endif
  endtry
endfunction
function! protocol#kio#FileReadCmd(uri, ...) abort
  call protocol#doautocmd('FileReadPre')
  if get(b:, '_protocol_cancel', '') !~# '^\%(kio\)\?$'
    return
  endif
  let options = get(a:000, 0, {})
  let content = protocol#kio#read(a:uri)
  call s:Buffer.read_content(content, options)
  call protocol#doautocmd('FileReadPost')
endfunction
function! protocol#kio#BufReadCmd(uri, ...) abort
  call protocol#doautocmd('BufReadPre')
  if get(b:, '_protocol_cancel', '') !~# '^\%(kio\)\?$'
    return
  endif
  let options = get(a:000, 0, {})
  let content = protocol#kio#read(a:uri)
  call s:Buffer.edit_content(content, options)
  setlocal noswapfile buftype=acwrite
  augroup vim_protocol_internal_kio_BufReadCmd
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call protocol#kio#BufWriteCmd(expand('<afile>'))
  augroup END
  call protocol#doautocmd('BufReadPost')
endfunction
function! protocol#kio#BufWriteCmd(uri, ...) abort
  call protocol#doautocmd('BufWritePre')
  if get(b:, '_protocol_cancel', '') !~# '^\%(kio\)\?$'
    return
  endif
  let options = get(a:000, 0, {})
  let guard = s:Guard.store('&binary')
  try
    set binary
    let content = getline(1, '$')
    call protocol#kio#write(a:uri, content)
    setlocal nomodified
  finally
    call guard.restore()
  endtry
  call protocol#doautocmd('BufWritePost')
endfunction

function! s:open(kiofile, filename, ...) abort
  let options = get(a:000, 0, {})
  let bufname = printf('%s%s', a:kiofile, a:filename)
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore+=BufReadCmd
    call s:Buffer.open(bufname, 'edit')
    call protocol#kio#BufReadCmd(bufname, options)
  catch /^protocol:/
    call protocol#handle_exception()
  finally
    call guard.restore()
  endtry
endfunction
function! protocol#kio#browse(kiofile, ...) abort
  let options = get(a:000, 0, {})
  " let content = s:unkio(['-Z', '-1', '--', kiofile])
  " echo kiofile
  let content = s:kioclient_ls(a:kiofile)
  " let content = filter(content, 'v:val !~# "/$"')
  let content = extend([
        \ printf('%s | Hit <Return> to open a file under the cursor', a:kiofile),
        \], content)
  call s:Buffer.edit_content(content, options)
  setlocal nomodifiable
  setlocal noswapfile nobuflisted nowrap
  setlocal buftype=nofile bufhidden=hide
  setlocal filetype=protocol-kio
  augroup vim_protocol_internal_kio_browse
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call protocol#kio#browse(b:_protocol_kio_filename)
  augroup END
  nnoremap <silent><buffer> <Plug>(protocol-kio-open)
        \ :<C-u>call <SID>open(expand('%'), getline('.'))<CR>
  nmap <buffer> <CR> <Plug>(protocol-kio-open)
endfunction


function! protocol#kio#define_highlight() abort
  highlight default link ProtocolKioComment Comment
endfunction
function! protocol#kio#define_syntax() abort
  syntax match ProtocolKioComment /\%^.*$/
endfunction

let protocol_kio_pattern = "{ftp,sftp,tar}://*"
"augroup vim_protocol_internal_kio_pseudo
  "autocmd! *
  exe join(["autocmd FileReadPre  ", protocol_kio_pattern, "* :"]):
  "autocmd FileReadPost ftp://* :
  exe join(["autocmd FileRead", buf_read_pre, " ";
  "autocmd BufReadPre   ftp://* :
  "autocmd BufReadPost  ftp://* :
  "autocmd BufWritePre  ftp://* :
  "autocmd BufWritePost ftp://* :
"augroup END

call protocol#define_variables('kio', {
      \ 'kioclient_exec': 'kioclient',
      \ 'kio_exec': 'kio',
      \ 'unkio_exec': 'unkio',
      \ 'cache_directory': '~/.cache/vim-protocol/kio',
      \})
