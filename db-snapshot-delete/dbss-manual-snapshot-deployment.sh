#!/bin/bash
### Script Name: dbss-manual-snapshot-deployment.sh
_DEBUG="on"
function DEBUG_SCRIPT()
{
 [ "$_DEBUG" == "on" ] &&  $@
}

export VPCAlias="$1"
export BASE_DIR=$(pwd)
export DIR1=infra
export DIR2=${DIR1}/lambda
export FIRST_SM=${BASE_DIR}/${DIR1}/stack_master-$VPCAlias-dbss_manual_snapshot_deletion.yml
export LAMDA_UPLOAD_LOG=${BASE_DIR}/deployment_logs/${VPCAlias}_dbss_rds_hardening_lambda_upload.log
export EXEC_TRACE_FILE=${BASE_DIR}/deployment_logs/${VPCAlias}_dbss_manual_snapshot_deploy.log


export REGENSM=${BASE_DIR}/../bin/regensm.py

function logger(){
    if [ $# -eq 0 ] ; then
        while read data; do
            echo -e "$(date +%Y%m%dT%H:%M:%S)  ${data}" >> $EXEC_TRACE_FILE
            echo -e "$(date +%Y%m%dT%H:%M:%S)  ${data}"
        done
    else
        data="$@"
        echo -e "$(date +%Y%m%dT%H:%M:%S)  ${data}" >> $EXEC_TRACE_FILE
        echo -e "$(date +%Y%m%dT%H:%M:%S)  ${data}"
    fi
}

function read_output(){
    while read line
    do
        logger " ${line}"
    done < ${1}
}

#Function1 - Uploading the Lambda Functions
function dbss_lambda_upload(){
    logger " Uploading the rds-manual-snapshot-deletion lambda to S3"
    cd $BASE_DIR/$DIR2
    pwd
    logger "Executing lambda_export1=\$( uploads3.sh \"${VPCAlias}\" \"rds-manualsnapshot-deletion\" \"lambda/rds-manualsnapshot-deletion\" | tail -n 1 )"
    lambda_export1="$( bash uploads3.sh "${VPCAlias}" "rds-manualsnapshot-deletion" "lambda/rds-manualsnapshot-deletion" | tail -n 1 )"
    if [ $? -ne 0 ]; then echo "lambda_export1=$lambda_export1"; logger " exit 11"; exit 11; fi
    eval "${lambda_export1}"
    if [ $? -ne 0 ]; then echo "lambda_export1=$lambda_export1"; logger " exit 12"; exit 12; fi
    logger " Successfully uploaded rds-manual-snapshot-deletion  lambda to S3..."


    logger "Executing lambda_export2=\$(uploads3.sh \"${VPCAlias}\" \"rds-retention-days-policy-notification\" \"lambda/rds-retention-days-policy-notification\" | tail -n 1 )"
    lambda_export2="$( bash uploads3.sh "${VPCAlias}" "rds-retention-days-policy-notification" "lambda/rds-retention-days-policy-notification" | tail -n 1 )"
    if [ $? -ne 0 ]; then echo "lambda_export2=$lambda_export2"; logger " exit 13"; exit 13; fi
    eval "${lambda_export2}"
    if [ $? -ne 0 ]; then echo "lambda_export2=$lambda_export2"; logger " exit 14"; exit 14; fi
    logger " Successfully uploaded rds-retention-days-policy-notification lambda to S3..."
    cd $BASE_DIR
}

## Function2 , creating the Lambda function.
function dbss_lambda_rds_manualsnapshot_deletion_deploy(){
    logger " Deploying the  Stack which creates the Lambda function for Manual snapshot deletion"
    logger " Getting OS Details"
    cd $BASE_DIR/$DIR1
    python3 $REGENSM $FIRST_SM >${LAMDA_UPLOAD_LOG} 2>&1
    if [ $? -ne 0 ]; then
        read_output ${LAMDA_UPLOAD_LOG}
        logger " Unable to generate Stack_master.yml for basic Lambda stack, exiting the program. Check ${LAMDA_UPLOAD_LOG} for more details "
        exit 1
    fi
    read_output ${LAMDA_UPLOAD_LOG}
    logger " Successfully Generated the Stack_master.yml for Lambda Function..."
    stack_master status >>${LAMDA_UPLOAD_LOG} 2>&1
    if [ $? -ne 0 ]; then
        read_output ${LAMDA_UPLOAD_LOG}
        logger " Unable to deploy the basic Infra stack, exiting the program. Check ${LAMDA_UPLOAD_LOG} for more details "
        exit 1
    fi

    read_output ${LAMDA_UPLOAD_LOG}
    logger " Successfully Stack_master Status forLambda Function..."
    stack_master --yes apply --on-failure DELETE >>${LAMDA_UPLOAD_LOG} 2>&1
    if [ $? -ne 0 ]; then
        read_output ${BASIC_INFRA_LOG}
        logger " Unable to deploy the basic Infra stack, exiting the program. Check ${LAMDA_UPLOAD_LOG} for more details "
        exit 1
    fi
    read_output ${LAMDA_UPLOAD_LOG}
    logger " Successfully deployed the base Infra stack..."
    cd $BASE_DIR

}

if [[ "${DEBUG}" = "DEBUG" ]]; then
    DEBUG_SCRIPT echo "$(date +%Y%m$dT%H:%M:%S)  Enabling debugging for troubleshooting the issue"
    DEBUG_SCRIPT set -x
fi

echo "$(date +%Y%m%dT%H:%M:%S)   Executing the Lambda Upload to S3 "
dbss_lambda_upload
echo "$(date +%Y%m%dT%H:%M:%S)   Successfully Executed the Lambda Upload to S3"


echo  "$(date +%Y%m%dT%H:%M:%S)  Creating the Lambda function   "
dbss_lambda_rds_manualsnapshot_deletion_deploy
echo "$(date +%Y%m%dT%H:%M:%S)   Basic Lambda function Deployed  "
