

function parse_item, item

  struc = { firstline:item[0] }

  red_append, keys, 'firstline'
  values = list(item[0])
  
  ;; Remove first line and ending curly bracket
  cpos = where(strmatch(item,'}*'), Ncurly)
  if Ncurly gt 0 then titem = item[1:cpos-1] else titem = item
  
  tpos = [where(strmatch(titem,' *[a-z]* *=*'), Ntags), n_elements(titem)]

  for itag = 0, Ntags-1 do begin
     tagline = strjoin(titem[tpos[itag]:tpos[itag+1]-1], ' ') ; A single line
     tagline = strtrim(strcompress(tagline),2)                ; White space
     tagline = strmid(tagline,0,strlen(tagline)-1)            ; Remove final comma
     tagsplit = strsplit(tagline, '=', /extract)

     red_append, keys, strlowcase(strtrim(tagsplit[0], 2))
     values.add, strtrim(strjoin(tagsplit[1:*], '='), 2)

  endfor
  
  return, orderedhash(keys, values)
  
end

files = file_search('print-*.bbl', count = Nfiles)

years = strmid(files, 6, 4)
years = years[uniq(years, sort(years))]
Nyears = n_elements(years)



for iyear = 0, Nyears-1 do begin

   files = file_search('print-'+years[iyear]+'*.bbl', count = Nfiles)

   
   for ifile = 0, Nfiles-1 do begin

      file = files[ifile]

      splitfile = strsplit(file, '-.', /extract)

      xfile = strjoin(splitfile[1:-2], '-')+'.xml'
      bfile = red_strreplace(file_basename(file, '.bbl'), 'print','svst')+'.bib'
;      print, file,' ', xfile, ' ', bfile

      if file_modtime(bfile) lt file_modtime(xfile) then continue
      
      print, 'In and out: ', file, ' ', xfile
      
      openw, lun, xfile, /get_lun

      case splitfile[2] of
         'ref' : descstring = 'Refereed ISP publications '+years[iyear]
         'sci' : descstring = 'Other science publications '+years[iyear]
         else  : descstring = 'Other publications '+years[iyear]
      endcase
      
      printf, lun, '<?xml version="1.0"?>'
      printf, lun, '<rss version="2.0">'
      printf, lun, '  <channel>'
      printf, lun, '    <title>'+descstring+'</title>'
      printf, lun, '    <link>https://www.isf.astro.se/publications/database/</link>'
      printf, lun, '    <description>'+descstring+'</description>'

      spawn, 'cat '+file, bbl
      ipos = where(strmatch(bbl, '*bibitem*'), Nitems)
      if Nitems eq 0 then continue

      spawn, 'cat '+file_basename(red_strreplace(file, 'print-', 'svst-'), '.bbl')+'.bib', bib
      ipos_bib = where(strmatch(bib, '@*'), Nitems_bib)
      red_append, ipos_bib, n_elements(bib) ; Ending the last item
      if Nitems_bib ne Nitems then stop

      ipos = [ipos, n_elements(bbl)]

      for iitem = 0, Nitems-1 do begin
         
         bibtag = (strsplit(bbl[ipos[iitem]], '{}', /extract))[1]
         
         bblitem = bbl[ipos[iitem]+1:ipos[iitem+1]-2]
         
         url = ''               ; default
         
         if strmatch(bibtag, '[0-9]*') then begin
            ;; The bibtag is an ADS tag, construct the url?
            url = 'https://ui.adsabs.harvard.edu/abs/'+bibtag+'/abstract'
            url = red_strreplace(url, '&', '%26', n = 10)
         endif

         if url eq '' then begin
            ;; Extract an arxiv or urn.kb.se url from the note field?
            uindx = where(strmatch(bblitem, '*\\url{*'), Nurl, complement = tindx)
            if Nurl gt 0 then begin
               url = bblitem[uindx[0]]
               url = (strsplit(url, '{}', /extract))[1]
               bblitem = bblitem[tindx]
            endif 
         endif

         
         ;; Alternatives possible by looking up bibtag in the bib
         ;; file:
         
         if url eq '' then begin
            iii = where(strmatch(bib[ipos_bib], '*{'+bibtag+','), Nmatch)
            if Nmatch eq 1 then begin
               bibitem = bib[ipos_bib[iii]:ipos_bib[iii+1]-1]
        
               taghash = parse_item(bibitem)

               ;; Use the adsurl field?
               if taghash.haskey('adsurl') then begin
                  url = red_strreplace(taghash['adsurl'], '"', '', n = 2)
                  url = red_strreplace(url, '&', '%26', n = 10)
               endif
               
               if url eq '' then begin
                  ;; Extract a DOI url?
                  if taghash.haskey('doi') then begin
                     doi = red_strreplace(taghash['doi'], '"', '', n = 2)
                     url = 'https://doi.org/'+doi
                  endif
               end
               
               ;; if url eq '' then begin
               
               ;;     Extract any url from url, note, howpublished fields

               ;; end
               
            endif
         endif
         
         ;; Remove link to arxiv from bblitem so we don't get
         ;; it into the text.
         pos = where(strmatch(bblitem, '*arxiv.org/abs*'), Nwhere)
         if Nwhere gt 0 then bblitem[pos] = ''

         ;; Extract the item text
         text = strtrim(strjoin(bblitem, ' '), 2)

         ;; Remove some TeX constructs
         text = strreplace(text, '\newblock', '', n = 100)
         text = strreplace(text, '\protect', '', n = 100)
         text = strreplace(text, '\textrm', '', n = 100)
         text = strreplace(text, '\textsc', '', n = 100)
         text = strreplace(text, '\sc', '', n = 100)
         text = strreplace(text, '\em ', '', n = 100)

         ;; Greater than and less than are in the way for xml.
         text = strreplace(text, '<', '&lt;', n = 100)
         text = strreplace(text, '>', '&gt;', n = 100)

         ;; Acute accent
         chars = ['a', 'c', 'e', 'i', 'o', 'u']
         for j = 0, 1 do begin
            if j then chars = strupcase(chars)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, "\'"+chars[i], chars[i]+'&#x301;', n = 100)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, "\'{"+chars[i]+'}', chars[i]+'&#x301;', n = 100)
         endfor
         
         ;; Grave accent
         chars = ['a', 'e']
         for j = 0, 1 do begin
            if j then chars = strupcase(chars)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, "\`"+chars[i], chars[i]+'&#x301;', n = 100)
         endfor
         
         ;; Umlaut
         chars = ['a', 'e', 'u', 'o']
         for j = 0, 1 do begin
            if j then chars = strupcase(chars)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, '\"'+chars[i], chars[i]+'&#x308;', n = 100)
         endfor
         
         ;; Tilde ~
         chars = ['a', 'n', 'o']
         for j = 0, 1 do begin
            if j then chars = strupcase(chars)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, '\~'+chars[i], chars[i]+'&#x342;', n = 100)
         endfor
         
         ;; Caron \v
         chars = ['c', 'e', 'i', 's']
         ;; General
         unicode_caron = '&#x2C7;'
         for j = 0, 1 do begin
            if j then chars = strupcase(chars)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, '\v '+chars[i], chars[i]+unicode_caron, n = 100)
            for i = 0, n_elements(chars)-1 do $
               text = strreplace(text, '\v{'+chars[i]+'}', chars[i]+unicode_caron, n = 100)
         endfor
         ;; Explicit, because the general mechanism doesn't seem to
         ;; work properly
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'C'+unicode_caron, '&#x10C;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'c'+unicode_caron, '&#x10D;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'E'+unicode_caron, '&#x11A;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'e'+unicode_caron, '&#x11B;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'I'+unicode_caron, '&#x1CF;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'i'+unicode_caron, '&#x1D0;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 'S'+unicode_caron, '&#x160;', n = 100)
         for i = 0, n_elements(chars)-1 do text = strreplace(text, 's'+unicode_caron, '&#x161;', n = 100)
         
         
         ;; Greek
         red_append, gnum, '393' & red_append, greek, 'Gamma'
         red_append, gnum, '394' & red_append, greek, 'Delta'
         red_append, gnum, '398' & red_append, greek, 'Theta'
         red_append, gnum, '39B' & red_append, greek, 'Lambda'
         red_append, gnum, '39E' & red_append, greek, 'Xi'
         red_append, gnum, '3A0' & red_append, greek, 'Pi'
         red_append, gnum, '3A3' & red_append, greek, 'Sigma'
         red_append, gnum, '3A6' & red_append, greek, 'Phi'
         red_append, gnum, '3A8' & red_append, greek, 'Psi'
         red_append, gnum, '3A9' & red_append, greek, 'Omega'
         red_append, gnum, '3B1' & red_append, greek, 'alpha'
         red_append, gnum, '3B2' & red_append, greek, 'beta' 
         red_append, gnum, '3B3' & red_append, greek, 'gamma'   
         red_append, gnum, '3B4' & red_append, greek, 'delta'   
         red_append, gnum, '3B5' & red_append, greek, 'epsilon'  
         red_append, gnum, '3B6' & red_append, greek, 'zeta'  
         red_append, gnum, '3B7' & red_append, greek, 'eta'     
         red_append, gnum, '3B8' & red_append, greek, 'theta'   
         red_append, gnum, '3B9' & red_append, greek, 'iota'   
         red_append, gnum, '3BA' & red_append, greek, 'kappa'   
         red_append, gnum, '3BB' & red_append, greek, 'lambda'   
         red_append, gnum, '3BC' & red_append, greek, 'mu'   
         red_append, gnum, '3BD' & red_append, greek, 'nu'   
         red_append, gnum, '3BE' & red_append, greek, 'xi'   
         red_append, gnum, '3BF' & red_append, greek, 'omicron'   
         red_append, gnum, '3C0' & red_append, greek, 'pi'   
         red_append, gnum, '3C1' & red_append, greek, 'rho'   
         red_append, gnum, '3C2' & red_append, greek, 'varsigma'   
         red_append, gnum, '3C3' & red_append, greek, 'sigma'   
         red_append, gnum, '3C4' & red_append, greek, 'tau'   
         red_append, gnum, '3C5' & red_append, greek, 'upsilon'   
         red_append, gnum, '3C6' & red_append, greek, 'varphi'   
         red_append, gnum, '3C7' & red_append, greek, 'chi' ; ?
         red_append, gnum, '3C8' & red_append, greek, 'psi'   
         red_append, gnum, '3C9' & red_append, greek, 'omega'   
         red_append, gnum, '3D0' & red_append, greek, 'varbeta' ; ?
         red_append, gnum, '3D1' & red_append, greek, 'vartheta'   
;        red_append, gnum, '3D2' & red_append, greek, 'Υ'   
;        red_append, gnum, '3D3' & red_append, greek, 'Ύ'   
;        red_append, gnum, '3D4' & red_append, greek, 'Ϋ'   
         red_append, gnum, '3D5' & red_append, greek, 'phi'   
         red_append, gnum, '3D6' & red_append, greek, 'varpi' ; ?   
;        red_append, gnum, '3D7' & red_append, greek, 'ϗ'   
;        red_append, gnum, '3D8' & red_append, greek, 'Ϙ'   
;        red_append, gnum, '3D9' & red_append, greek, 'ϙ'   
;        red_append, gnum, '3DA' & red_append, greek, 'Ϛ'   
;        red_append, gnum, '3DB' & red_append, greek, 'varsigma' ; ? 
         red_append, gnum, '3F1' & red_append, greek, 'varrho' ; ?
         for i = 0, n_elements(greek)-1 do text = strreplace(text, '\'+greek[i], '&#x'+gnum[i]+';', n = 100)

         ;; Other accented characters
         text = strreplace(text, "Å",      '&#x0C5;',  n = 100)
         text = strreplace(text, "å",      '&#x0E5;',  n = 100)
         text = strreplace(text, "é",      'e&#x301;', n = 100)
         text = strreplace(text, "í",      'i&#x301;', n = 100)
         text = strreplace(text, "\'\i",   'i&#x301;', n = 100)
         text = strreplace(text, "\'{\i}", 'i&#x301;', n = 100)

         
         ;; Symbols
         text = strreplace(text, '\&',  '&amp;',   n = 100)    ; &
         text = strreplace(text, '\ae', '&#xe6;',  n = 100)    ; æ
         text = strreplace(text, '\aa', '&#x0E5;', n = 100)    ; å
         text = strreplace(text, '\AA', '&#x0C5;', n = 100)    ; Å
         text = strreplace(text, '\o',  '&#x0F8;', n = 100)    ; ø
         text = strreplace(text, '\O',  '&#x0D8;', n = 100)    ; Ø
         text = strreplace(text, '^\circ', '&deg;', n = 100)   ; degree
         ;;         text = strreplace(text, '', '', n = 100)

         ;; Subscripts and superscripts
         for i = 0, 9 do text = strreplace(text, '^'+strtrim(i, 2), '&#x207'+strtrim(i, 2)+';', n = 100)
         for i = 0, 9 do text = strreplace(text, '_'+strtrim(i, 2), '&#x208'+strtrim(i, 2)+';', n = 100)

         ;; Other symbols, punctuation, etc.
         text = strreplace(text, '``',     '&ldquo;', n = 200)
         text = strreplace(text, "''",     '&rdquo;', n = 200)
         text = strreplace(text, '---',    '&mdash;', n = 200)
         text = strreplace(text, '--',     '&ndash;', n = 200)
         text = strreplace(text, '~',      '&nbsp;',  n = 200)
         text = strreplace(text, '\ ',     ' ',       n = 200)
         text = strreplace(text, '\#',     '#',       n = 200)
         text = strreplace(text, '\prime', "'",       n = 200)
         
         ;; Final cleaning
         text = strreplace(text, '{', '',  n = 200)
         text = strreplace(text, '}', '',  n = 200)
         text = strreplace(text, '$', '',  n = 200)
         text = strreplace(text, '^', '',  n = 200)
         text = strreplace(text, '\!', '', n = 200)

         text = strcompress(text)

         printf, lun, '    <item>'
         printf, lun, '      <title>'+text+'</title>'
         printf, lun, '      <link>'+url+'</link>'
         printf, lun, '      <description></description>'
         printf, lun, '    </item>'

      endfor                    ; iitem

      printf, lun, '  </channel>'
      printf, lun, '</rss>'
      
      free_lun, lun
      
   endfor                       ; ifile

   
endfor                          ; iyear

end 

