#!/bin/sh

# how many pages should be put in one TIF file? This is a temporary
# hack to allow sheets with more than two pages, a proper solution
# needs indiviual barcodes and auto-detect per sheet of paper. Must
# be an even number.
size=2

# check all required programs are available
hash scanadf 2>&- || { echo >&2 "Could not find \"scanadf\". Ensure that \"sane\" is installed."; exit 1; }
hash pnmtotiff 2>&- || { echo >&2 "Could not find \"pnmtotiff\". Ensure that \"netpbm\" is installed."; exit 1; }
hash convert 2>&- || { echo >&2 "Could not find \"pnmtotiff\". Ensure that \"imagemagick\" or \"graphicsmagick-imagemagick-compat\" are installed."; exit 1; }

# start scanning
if [ "$1" = "" ]; then
	while  [ 1 ]; do
		count=$(ls -1 | wc -l)
		final=$(( $count * $size + 1 ))
		# --rollerdeskew=yes     # inactive for now to test if scanner performs better
		scanadf \
			--buffermode=yes \
			--stapledetect=yes \
			--df-length=yes \
			--df-thickness=yes \
			-x 210 \
			-y 297 \
			--page-width 210 \
			--page-height 297 \
			--source 'ADF Duplex' \
			--mode lineart \
			--resolution 300 \
			-o 'foo_%d.pnm' \
			-S "$0" \
			--start-count "${final}"
		echo "Continue? (Press Enter or hit CTRL-C to abort)"
		read
	done
fi

curr=$(echo $1 | sed -r 's/.*\_([0-9]+).*/\1/')

pnmtotiff -lzw "foo_${curr}.pnm" > "foo_${curr}.tif"
rm "${1}"

rem=$(( $curr % $size ))

if [ $rem -eq 0 ]; then
	newid=$(( $curr / $size ))
	zeroid=$(printf "%06d" $newid)
	n=$size
	files=""
	while [ "$n" -gt "0" ]; do
		n=$(( $n - 1 ))
		id=$(( $curr - $n ))
		files="${files} foo_${id}.tif"
	done
	convert $files -adjoin "scanned_${zeroid}.tif"
	rm $files
fi

