#!/bin/bash

docker build -t blog .
docker run --rm -it -p 8000:8000 -v ${PWD}:/docs blog