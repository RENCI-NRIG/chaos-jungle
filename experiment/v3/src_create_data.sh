#!/bin/bash
set -ux
. ./test_env.sh

#create src data in run folder $1: ${RUN_DIR}
rm -f `pwd`/src_create_data_done
rm -rf ${SITE_DIR}/run*
mkdir -p $1
cp -r ${TEMPLATE_DIR} $1/
echo $1 > `pwd`/src_create_data_done