#!/bin/bash
sh scripts/clean.sh && \
sh scripts/pack.sh && \
haxelib install hxtsdgen.zip && \
haxe test.hxml && \
node test/index.js && \
sh scripts/clean.sh
# node test/index.js packages.txt
