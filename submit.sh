#!/bin/sh
rm -f haxelib.zip
zip -r haxelib.zip src extraParams.hxml haxelib.json README.md
haxelib submit haxelib.zip
