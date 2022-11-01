
files = file_search('node*.html', count = Nfiles)

for ifile = 0, Nfiles-1 do begin

   print, files[ifile]
   spawn, 'cat '+files[ifile], contents

   pos = where(strmatch(contents, '*<TITLE>*([0-9]*+[0-9]*+[0-9]*=[0-9]*)</TITLE>*'), Nmatch)

   if Nmatch eq 0 then continue

   title = contents[pos]
   title = strreplace(title, '<TITLE>', '')
   title = strreplace(title, '</TITLE>', '')
   print, title


   if strmatch(title, '*Not yet published*') then begin
      year = 'unpublished'
   endif else begin
      year = strmid(title, 18, 4)
   endelse

   ;; Name of the output file
   xfile = year+'.xml'
   
   print, 'In, out: ', files[ifile], ' ', xfile
   
   openw, lun, xfile, /get_lun

endfor                          ; ifile

years = strmid(files, 6, 4)
years = years[uniq(years, sort(years))]
Nyears = n_elements(years)

for iyear = 0, Nyears-1 do begin

   files = file_search('print-'+years[iyear]+'*.bbl', count = Nfiles)

   
   for ifile = 0, Nfiles-1 do begin

      file = files[ifile]

      splitfile = strsplit(file, '-.', /extract)

      xfile = strjoin(splitfile[1:-2], '-')+'.xml'

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

      ipos = [ipos, n_elements(bbl)]

      for iitem = 0, Nitems-1 do begin

         
         
         bblitem = bbl[ipos[iitem]+1:ipos[iitem+1]-2]
         
         ;; Extract the link if any
         uindx = where(strmatch(bblitem, '*\\url{*'), Nurl, complement = tindx)
         if Nurl gt 0 then begin
            url = bblitem[uindx[0]]
            url = (strsplit(url, '{}', /extract))[1]
            bblitem = bblitem[tindx]
         endif else url = ''
         

         ;; Extract the item text
         text = strjoin(bblitem, ' ')
         text = strreplace(text, '\newblock ', '', n = 100)
         text = strreplace(text, '\em ', '', n = 100)
         text = strreplace(text, '{', '', n = 100)
         text = strreplace(text, '}', '', n = 100)
         text = strreplace(text, '--', '-', n = 100)
         text = strreplace(text, '~', '', n = 100)
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

