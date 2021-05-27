#!/bin/bash
export AWS_PROFILE=cashanalytics-development
./build.rb &&
. ~/bin/aws-mfa &&
\eb status $1
/usr/bin/time --format='%e sec' eb deploy --timeout 60 $1
