;; Make a crossref.bib file with alternate bib items using the arXiv
;; tags as cite key.



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

files = file_search('svst.bib', count = Nfiles)

if Nfiles eq 0 then stop

openw, olun, 'crossref.bib', /get_lun

for ifile = 0, Nfiles-1 do begin

   infile = files[ifile]
   
   spawn, 'cat '+infile, filecontents
   Nlines = n_elements(filecontents)

   ipos = where(strmatch(filecontents, '@*'), Nitems)
   if Nitems eq 0 then stop

;   ipos2 = where(strmatch(filecontents, ' @*'), Nitems2)
;   if Nitems2 gt 0 then begin
;      red_append, ipos, ipos2
;      ipos = ipos[sort(ipos)]
;      Nitems = n_elements(ipos)
;   endif

   red_append, ipos, Nlines     ; Ending the last item

   
   for iitem = 0, Nitems-1 do begin

      item = filecontents[ipos[iitem]:ipos[iitem+1]-1]

      taghash = parse_item(item)


      if taghash.haskey('adsurl') then begin

         ;; If there is an "adsurl" tag, extract the arXiv tag and
         ;; construct an alternate bibitem.

         arXivtag = (strsplit(taghash['adsurl'], '/', /extract))[-1] 
         arXivtag = strmid(arXivtag, 0, strlen(arXivtag)-1) ; Remove trailing quote
         splitfirst = strsplit(taghash['firstline'], '{', /extract)
         oldtag = strmid(splitfirst[1], 0, strlen(splitfirst[1])-1) ; Remove trailing comma
         
         printf, olun, splitfirst[0] + '{' + arXivtag + ', crossref = {'+oldtag+'}}'
         
      endif 
           
   endfor                       ; iitem
   
endfor                          ; ifile


free_lun, olun



end
