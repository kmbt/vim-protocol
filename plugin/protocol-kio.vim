if !get(g:, 'protocol_enable_kio', 1)
  finish
endif

augroup vim_protocol_internal_kio
  autocmd! *
  autocmd BufReadCmd  ftp://*  nested call protocol#handle_autocmd('kio', 'BufReadCmd')
  autocmd FileReadCmd ftp://*  nested call protocol#handle_autocmd('kio', 'FileReadCmd')
  autocmd SourceCmd   ftp://*  nested call protocol#handle_autocmd('kio', 'SourceCmd')

  autocmd BufReadCmd  ftp://*/    nested call protocol#handle_autocmd('kio', 'browse')
  autocmd BufReadPre  ftp://*/    let b:_protocol_cancel = 'kio'
augroup END
