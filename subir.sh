#!/bin/bash

#hugo
jekyll build
rsync -azP _site/* calcetines@nodriza.robertops.com:/home/calcetines/blog/

