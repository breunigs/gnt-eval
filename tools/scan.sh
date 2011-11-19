#!/bin/sh

# check all required programs are available
hash scanadf 2>&- || { echo >&2 "Could not find \"scanadf\". Ensure that \"sane\" is installed."; exit 1; }
hash pnmtotiff 2>&- || { echo >&2 "Could not find \"pnmtotiff\". Ensure that \"netpbm\" is installed."; exit 1; }
hash convert 2>&- || { echo >&2 "Could not find \"pnmtotiff\". Ensure that \"imagemagick\" or \"graphicsmagick-imagemagick-compat\" are installed."; exit 1; }

# start scanning
if [ "$1" = "" ]; then
	while  [ 1 ]; do
		count=$(ls -1 | wc -l)
		final=$(( $count * 2 + 1 ))
		scanadf \
			--buffermode=yes \
			--stapledetect=yes \
			--rollerdeskew=yes \
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

nn=$(echo $1 | sed -r 's/.*\_([0-9]+).*/\1/')
n=$(( $nn - 1 ))


pnmtotiff -lzw "foo_${nn}.pnm" > "foo_${nn}.tif"
rm "${1}"

rem=$(( $nn % 2 ))

if [ $rem -eq 0 ]; then
	newid=$(( $nn / 2 ))
	zeroid=$(printf "%06d" $newid)
	convert "foo_${n}.tif" "foo_${nn}.tif" -adjoin "scanned_${zeroid}.tif"
	rm "foo_${n}.tif" "foo_${nn}.tif"
fi

