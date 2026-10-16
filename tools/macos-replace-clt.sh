#!/usr/bin/env bash

set -eu

for path in /Library/Developer/CommandLineTools/usr/bin/*
do
	file="$(basename "${path}")"
	bin="/usr/bin/${file}"
	if [ -f "${bin}" ]
	then
		rm "${bin}"
		ln -s "${path}" "${bin}"
	fi
done
