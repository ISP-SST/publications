;; To be run once.

;; Filter the svst-*.bib files to make useful links for all (or at
;; least most) bibitems.

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

files = file_search('svst*bib', count = Nfiles)

for ifile = 0, Nfiles-1 do begin

   infile = files[ifile]
   outfile = 'tmp_'+infile

   openw, olun, outfile, /get_lun
   
   spawn, 'cat '+infile, filecontents
   Nlines = n_elements(filecontents)


   ipos = [where(strmatch(filecontents, '@*'), Nitems), Nlines]
   
   for iitem = 0, Nitems-1 do begin

      item = filecontents[ipos[iitem]:ipos[iitem+1]-1]

      taghash = parse_item(item)

            
      if taghash.haskey('note') then begin
         ;; Remove "note" items that are just one of the strings
         ;; "xerox", "hardcopy", "no_hardcopy", "offprint" or
         ;; "preprint". Or remove concatenations (with #) with any of
         ;; those strings.
         
         stop
      endif

      if taghash.haskey('adsurl') then begin

         ;; If there is an "adsurl" tag, copy it to the "note" tag
         ;; surrounded with \url{}.

         url = '"\url{' + taghash['adsurl'] + '}"'
         if taghash.haskey('note') then begin
            ;; Add to the note
            taghash['note'] += ' # ' + url
         endif else begin
            ;; Create a new note
            taghash['note'] = url
         endelse

      endif else begin
      
         ;; Otherwise, (unless the "note" tag is already a adsurl type
         ;; url) construct urls from a "doi" tag, if avaliable.

         if taghash.haskey('doi') then begin

            url = '"\url{http://dx.doi.org/' + taghash['doi']+ '}"'
            
            if taghash.haskey('note') then begin
               ;; Add to the note
               taghash['note'] += ' # ' + url
            endif else begin
               ;; Create a new note
               taghash['note'] = url
            endelse

         endif
         
      endelse
      
      stop

      if taghash.count() eq 0 then continue

      keys = taghash.keys()
      for ikey = 0, taghash.count()-1 do begin

         line = keys[ikey] + ' = ' + taghash[keys[ikey]]
         printf, olun, line
         
      endfor                    ; ikey
      printf, olun, '}'
      printf, olun
      
   endfor                       ; iitem
   
   stop
   
   free_lun, olun
   
endfor                          ; ifile



end
