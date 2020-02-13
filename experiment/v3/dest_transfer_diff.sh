#!/bin/bash
set -ux
. ./test_env.sh

#$1: ${S_IP}
#$2: ${run }
#$3: ${logfile}
#$4: ${DIFF_OUTPUT}
#$5: ${iter}
echo $1 $2 $3 $4 $5
ROOT_DIR=`pwd`

rm -rf ${IRIS_DIR}/{1}/run*
wget -P ${IRIS_DIR} -r -m --no-parent -R "index.html*" http://${1}/run${2}/ > ${ROOT_DIR}/${3} 2>&1
diff -qr ${TEMPLATE_DIR} ${IRIS_DIR}/${1}/run${2}/$(basename ${TEMPLATE_DIR}) > ${ROOT_DIR}/${4} 2>&1
rm -rf ${IRIS_DIR}/${1}/run${2}
echo $1 $2 $3 $4 $5 > ${ROOT_DIR}/${2}_${5}_transfer_diff_done
