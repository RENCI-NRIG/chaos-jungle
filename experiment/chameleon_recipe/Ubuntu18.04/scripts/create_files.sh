#!/bin/bash

for n in {1..1000}; do
	dd if=/dev/zero of=file$( printf %04d "$n" ).zero bs=1 count=1024
done