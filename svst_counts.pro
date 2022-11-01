
colors = ['red', 'pink']
colors = ['dark green', 'green']
;colors = ['black', 'gray']
;colors = ['orange', 'yellow']

;; Read the data
counts_all = rd_tfile("svst_counts.all",/auto,/convert)
counts_ref = rd_tfile("svst_counts.ref",/auto,/convert)

;; They are in reverse order
counts_all = reverse(counts_all, 2)
counts_ref = reverse(counts_ref, 2)

;; Remove data from before 1985
indx = where(counts_all[0, *] ge 1985)
counts_all = counts_all[*, indx]
counts_ref = counts_ref[*, indx]

;mxx = max([counts_all[0, *], counts_ref[0, *]])
;mnx = min([counts_all[0, *], counts_ref[0, *]])
;mxy = max(counts_all[1, *])
;mny = 0

date = red_timestamp(/iso)+' CEST'

Npoints = n_elements(counts_all[0, *])
barnames = strarr(Npoints)+' '
for i = 0, Npoints-1 do if (counts_all[0, i]/5)*5 eq counts_all[0, i] then barnames[i] = strtrim(counts_all[0, i], 2)
barcoords = counts_all[0, *]


cgPS_Open, 'svst_counts.png'
;cgPS_Open, '~/svst_counts.ps'

cgbarplot, barcoords = barcoords, counts_all[1, *], color = colors[1] $
           , title = 'SST/SVST/ISP publications '+date, charsize = 1.5 $
           , barnames = barnames, /xstyle

cgbarplot, /over, barcoords = barcoords, counts_ref[1, *], color = colors[0]

location = [0.15, 0.85]
cglegend, title = ['Peer-reviewed journal articles', 'Other'] $
          , color = colors $
          , location = location $
          , vspace = 2 $
          , alignment = 0
cglegend, title = ['', ''] $
          , color = colors, thick = 30 $
          , location = location $
          , vspace = 2 $
          , alignment = 0

;; cgfixps didn't manage to rotate the seascape ps file to landscape
;; when I tested, so do it on the final png image instead.
cgPS_Close, /nofix, width = 1200
spawn, 'convert -trim -rotate "180" svst_counts.png svst_counts.png'
;spawn, 'convert -trim -rotate "180" svst_counts.ps svst_counts.ps'
spawn, 'convert svst_counts.png -resize 35% svst_counts_small.png'

exit
