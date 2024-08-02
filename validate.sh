#!/bin/bash

for DIR in $1/*/; do
  COUNT=$(ls -1q $DIR | wc -l)
  echo $COUNT $DIR  
  for SUBDIR in $DIR/*/; do
    COUNT=$(ls -1q $SUBDIR | wc -l)
    echo "   " $COUNT $SUBDIR 
  done
done
