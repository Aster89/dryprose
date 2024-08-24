                      highlight CurrentWordCounterMany cterm=NONE term=bold ctermbg=red    ctermfg=white
                      highlight CurrentWordCounterSome cterm=NONE term=bold ctermbg=yellow ctermfg=black
                      highlight CurrentWordCounterFew  cterm=NONE term=bold ctermbg=black  ctermfg=green
autocmd ColorScheme * highlight CurrentWordCounterMany cterm=NONE term=bold ctermbg=red    ctermfg=white
autocmd ColorScheme * highlight CurrentWordCounterSome cterm=NONE term=bold ctermbg=yellow ctermfg=black
autocmd ColorScheme * highlight CurrentWordCounterFew  cterm=NONE term=bold ctermbg=black  ctermfg=green

augroup TrackCurrentlyInsertedWord | autocmd!
  autocmd InsertEnter *.tex call <SID>changeIsKeywordAndResetOnInsertLeave()
  autocmd InsertLeave *.tex call <SID>trymatchdelete()
  autocmd InsertEnter,TextChangedI,TextChangedP *.tex call <SID>hlmatchesAndShowStats(getline('.')->matchstr('\k\+\%.c\k*'))
augroup END

fun! s:changeIsKeywordAndResetOnInsertLeave()
  let oldiskeyword = &iskeyword
  set iskeyword=@
  augroup TrackCurrentlyInsertedWordRestoreIsKeyword | autocmd!
    exe 'autocmd InsertLeave *.tex set iskeyword=' . oldiskeyword
  augroup END
endf

fun! s:trymatchdelete()
  try
    call matchdelete(g:idWholeWord)
  catch
  endtry
  try
    call matchdelete(g:idPartialWord)
  catch
  endtry
endf

fun! s:number2color(length, matchesonthisline)
  if a:length < 3 || a:matchesonthisline == 0
    return 'CurrentWordCounterFew'
  elseif a:matchesonthisline < 2
    return 'CurrentWordCounterSome'
  else
    return 'CurrentWordCounterMany'
  endif
endf

fun! s:hlmatchesAndShowStats(word)
  if empty(a:word)
    call <SID>trymatchdelete()
    echo "\n"
  else
    let a = <SID>hlmatchesAndShowStatsImpl('\<' . a:word . '\>', len(a:word), 'g:idWholeWord')
    let b = <SID>hlmatchesAndShowStatsImpl(a:word, len(a:word), 'g:idPartialWord')
    " TODO: color the echo too, with `echohl`
    echo a.text . "\n" . b.text
  endif
endf

fun! s:hlmatchesAndShowStatsImpl(word, length, hlgId)
    " TODO Show stats in popup; can't do it now because of
    " https://github.com/vim/vim/issues/12925, so I'm using echo.
    let stats = <SID>computeStats(a:word)

    " For visual feedback of how many times the words as been used in the viewport
    let hlgroup = <SID>number2color(a:length, stats.matchesonthisline)
    " TODO: se il gruppo è quello verde, voglio usare il background (come per
    " giallo e rosso) per tutte le ripetizioni tranne la presente, e usare
    " solo il foreground per la presente.
    if exists(a:hlgId)
      call <SID>trymatchdelete()
      exe 'call matchadd(hlgroup, ' . "'" . '\c' . "'" . ' . a:word, 0,' . a:hlgId . ')'
    else
      exe 'let ' . a:hlgId . ' = matchadd(hlgroup, ' . "'" . '\c' . "'" . ' . a:word, 0, -1)'
    endif
    return #{ text: '(' . a:word . ') ' . (stats.nwordsbefore != -1 ? stats.nwordsbefore : 'many many') . ' WORDs ago, ' . stats.nwordsafter . ' WORDs forward',
           \ hlgroup: hlgroup }
endf

fun! s:computeStats(word)
  " Position of the character where the current keyword starts
  let [l2, c2] = searchpos('\c\%(\%(' . a:word . '\)\@=.\)\%(\%(' . a:word . '\)\@!.\)*\%.c', 'nWb')
  " Previous match (on current or preceding lines)
  try " to avoid E363
    let [l1, c1] = searchpos('\c' . a:word . '\%(\%(' . a:word . '\)\@!\_.\)\+\%(\%(' . a:word . '\)\@=.\)\%(\%(' . a:word . '\)\@!\_.\)*\%.c', 'nWb')
    " TODO calcola anche il numero di capoversi
    let nwordsbefore = getline(l1, l2)->join('\n')[c1-1:-(len(getline(l2)) - c2 + 2)]->split('\%(\k\@!.\)\+')->len()
  catch
    let [l1, c1] = [0, 0] " word used long long ago
    let nwordsbefore = -1
  endtry
  " Next match (on current or following lines)
  let [l3, c3] = searchpos('\c' . a:word, 'nWz')
  let nwordsafter = getline(l2, l3)->join('\n')[c2 + len(a:word):-(len(getline(l3)) - c3 + 2 - len(a:word))]->split('\%(\k\@!.\)\+')->len()

  let pos = screenpos(win_getid(), line('.'), col('.'))

  let matchesonthisline = searchcount(#{ maxcount: -1,  pattern: '\c\%.l\k\@<!' . a:word . '\+\k\@!'}).total - 1
  return #{ matchesonthisline: matchesonthisline,
          \ nwordsbefore: nwordsbefore,
          \ nwordsafter: nwordsafter,
          \ prevoccurrpos: [l1, c1],
          \ nextoccurrpos: [l3, c3]
          \ }
endf
