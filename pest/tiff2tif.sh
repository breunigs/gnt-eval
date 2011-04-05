#!/bin/bash

# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: TIFF2TIF
#
# For the ease of coding PEST it requires all input image files to use
# the tif ending (instead of tiff)
# Call this script to correct it for you


echo -n "Please enter the path to the working directory that contains"
echo "the scanned images: "

read -e wrkdr

if [ -d $wrkdr ]; then
    cd $wrkdr
    rename -v 's/\.tiff$/.tif/' *.tiff
    exit 0
else
    echo "$wrkdr does not exist or is not a directory. Please try again"
    exit 1
fi
