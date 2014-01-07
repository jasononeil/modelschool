#!/bin/sh

libname='modelschool'
rm -f "${libname}.zip"
zip -r "${libname}.zip" haxelib.json src LICENSE.txt README.md
echo "Saved as ${libname}.zip"
