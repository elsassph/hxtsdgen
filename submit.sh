#!/bin/sh
rm -f haxelib.zip
zip -r haxelib.zip src haxelib.json README.md
haxelib submit haxelib.zip
