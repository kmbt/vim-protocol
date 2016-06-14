if !get(g:, 'protocol_enable_kio', 1)
  finish
endif

let protocol_kio_pattern = "{ftp,sftp,tar}://*"
augroup vim_protocol_internal_kio
  autocmd! *
  exe join(["autocmd BufReadCmd ", protocol_kio_pattern, "  nested call protocol#handle_autocmd('kio', 'BufReadCmd')"])
  exe join(["autocmd FileReadCmd ", protocol_kio_pattern, " nested call protocol#handle_autocmd('kio', 'FileReadCmd')"])
  exe join(["autocmd SourceCmd ",  protocol_kio_pattern, " nested call protocol#handle_autocmd('kio', 'SourceCmd')"])

  "autocmd BufReadCmd  ftp://*/    nested call protocol#handle_autocmd('kio', 'browse')
  "autocmd BufReadPre  ftp://*/    let b:_protocol_cancel = 'kio'
augroup END
