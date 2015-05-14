set title ""

set key invert reverse bottom outside
set key autotitle columnheader
set key samplen 2 spacing 1 font ",12"

set auto x
set xtics nomirror rotate by -45 scale 0
set style data histogram
set style histogram rowstacked gap 100
set offset -0.3,-0.3,0,0
set style fill solid border -1
set boxwidth 0.75

set terminal png noenhanced size 1000
set output "famous_peeps.png"
plot 'famous_peeps.dat' using 2:xtic(1), for [i=3:22] '' using i
