" TODO: dare un nome. Ad esempio: DRYPROSE = don't repeat yourself text
                      highlight CurrentWordCounterMany cterm=NONE term=bold ctermbg=red    ctermfg=white
                      highlight CurrentWordCounterSome cterm=NONE term=bold ctermbg=yellow ctermfg=black
                      highlight CurrentWordCounterFew  cterm=NONE term=bold ctermbg=black  ctermfg=green
autocmd ColorScheme * highlight CurrentWordCounterMany cterm=NONE term=bold ctermbg=red    ctermfg=white
autocmd ColorScheme * highlight CurrentWordCounterSome cterm=NONE term=bold ctermbg=yellow ctermfg=black
autocmd ColorScheme * highlight CurrentWordCounterFew  cterm=NONE term=bold ctermbg=black  ctermfg=green

augroup TrackCurrentlyInsertedWord | autocmd!
  autocmd InsertEnter *.tex call <SID>changeIsKeywordAndResetOnInsertLeave()
  autocmd InsertLeave *.tex call <SID>trymatchdelete()
  autocmd TextChangedI,TextChangedP *.tex call <SID>hlmatchesAndShowStats(getline('.')->matchstr('\k\+\%.c\k*'))
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
    call matchdelete(g:idForTrackTextInsertion)
  catch
  endtry
endf

fun! s:number2color(word, matchesonthisline)
  if len(a:word) < 3 || a:matchesonthisline == 0
    return 'CurrentWordCounterFew'
  elseif a:matchesonthisline < 2
    return 'CurrentWordCounterSome'
  else
    return 'CurrentWordCounterMany'
  endif
endf

fun! s:hlmatchesAndShowStats(word)
  if !empty(a:word)
    " show stats in popup
    let stats = <SID>computeStats(a:word)
    "call popup_create("caio", #{line: stats.prevoccurrpos[0], col: stats.prevoccurrpos[1] }) " ma la posizione è assoluta!

    " For visual feedback of how many times the words as been used in the viewport
    let hlgroup = <SID>number2color(a:word, stats.matchesonthisline)
    " TODO: se il gruppo è quello verde, voglio usare il background (come per
    " giallo e rosso) per tutte le ripetizioni tranne la presente, e usare
    " solo il foreground per la presente.
    if exists('g:idForTrackTextInsertion')
      call <SID>trymatchdelete()
      call matchadd(hlgroup, '\c\<' . a:word . '\>', 0, g:idForTrackTextInsertion)
    else
      let g:idForTrackTextInsertion = matchadd(hlgroup, '\c\<' . a:word . '\>', 0, -1)
    endif
  endif
endf

fun! s:computeStats(word)
  let [l2, c2] = searchpos('\c\%(\%(\<' . a:word . '\>\)\@=.\)\%(\%(\<' . a:word . '\>\)\@!.\)*\%.c', 'nWb')
  try " to avoid E363
    let [l1, c1] = searchpos('\c\<' . a:word . '\>\%(\%(\<' . a:word . '\>\)\@!\_.\)\+\%(\%(\<' . a:word . '\>\)\@=.\)\%(\%(\<' . a:word . '\>\)\@!\_.\)*\%.c', 'nWb')
    " TODO calcola anche il numero di capoversi
    let nwordsbefore = getline(l1, l2)->join('\n')[c1-1:-(len(getline(l2)) - c2 + 2)]->split('\%(\\n\| \)\+')->len()
  catch
    let [l1, c1] = [0, 0] " word used long long ago
    let nwordsbefore = -1
  endtry
  let [l3, c3] = searchpos('\c\<' . a:word . '\>', 'nWz')
  let nwordsafter = getline(l2, l3)->join('\n')[c2 + len(a:word):-(len(getline(l3)) - c3 + 2 - len(a:word))]->split('\%(\\n\| \)\+')->len()

  let pos = screenpos(win_getid(), line('.'), col('.'))
  let text = '(' . a:word . ') ' . (nwordsbefore != -1 ? nwordsbefore : 'many many') . ' WORDs ago, ' . nwordsafter . ' WORDs forward'
  echo text
  " TODO https://github.com/vim/vim/issues/12925
  "call popup_create(text,
  "      \ #{ pos: 'botright',
  "      \ line: pos.row - 1,
  "      \ col: pos.col,
  "      \ moved: 'any' })

  let matchesonthisline = searchcount(#{ maxcount: -1,  pattern: '\c\%.l\k\@<!' . a:word . '\+\k\@!'}).total - 1
  return #{ matchesonthisline: matchesonthisline,
          \ nwordsbefore: nwordsbefore,
          \ nwordsafter: nwordsafter,
          \ prevoccurrpos: [l1, c1],
          \ nextoccurrpos: [l3, c3]
          \ }
endf

" TODO: Improving this logic clearly needs some study. Some thoughts:
"
"       - Whatever I do, it is affected by the fact that I write my notes in
"         PDF as well. This cannot be avoided, unless I mark my notes in a
"         textual way. (Which I'm partly doing, in the case of footnotes, as I start
"         them with `Enrico:` or `Mamma:`)
"
"       - I could set to zero the weight of words with length 1 or 2. This
"         clearly can be done in pure Vim.
"
"       - I could assign each repetition a weight equal to the inverse of the
"         offset with respect to the currently inserted word.
"
"       - However, I should exclude words not belonging to the printed text,
"         like LaTeX stuff. This means that I either have to
"
"               - apply some heuristic in Vim
"
"               - use some external utility to get the printed text. This
"                 poses several challenges:
"
"                       - Relying on the PDF (e.g. via `pdftotext -nodiag`)
"                         seems appealing, but it's applicable only to the
"                         PDF, so how do I apply it, if I haven't compiled the
"                         LaTeX file yet?
"
"                       - Even if I have written the file, I have to localize
"                         the current word in Vim in the PDF
"
"                       - Relying on the PDF means that, e.g., footnotes are
"                         interspersed with the pages, but that's not the
"                         order one reads the book
"
"       - Alternatively, I could run an LCS between the PDF and the Vim
"         buffer; the LCS will most likely consist of the text of the main
"         document, as other stuff, like footnotes, being out of order but
"         smaller than the pages, would likely be left out of the LCS. Then I
"         would compute the offsets between current word and its repetitions
"         within the LCS.
"
"               - This still has the problem of not being viable while I type
"
"               - A minor issue is that it can't be used within footnotes and
"                other boxes of text other than the main page's content
"
"       - All of the above would be most useful in a static case, i.e. the
"         document is written, and I want to know how frequently I've used
"         a word. On the other hand, in the dynamic case, i.e. while I'm
"         writing, I'm only interested in whether the word I'm currently
"         writing is too close to another repetion. A simple solution is to
"         consider just 1 repetition, the closest to word being written; after
"         all, if I'm being repetitive for the word I'm writing right now,
"         right where I'm writing it, why should I care whether or not I've
"         used that word a few pages before? And if I haven't been writing a
"         word since 2 pages, then I don't care if I also wrote it 4 pages
"         ago.
