#!/bin/bash

if [ "$1"  ]
then
    git submodule init
    git submodule update
    cd nlutils
    ant
fi

