#!/bin/bash
export AWS_PROFILE=cashanalytics-development
./build.rb &&
. ~/bin/aws-mfa &&
\eb status
\eb deploy
