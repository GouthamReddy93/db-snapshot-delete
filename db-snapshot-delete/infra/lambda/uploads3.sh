#!/bin/bash
#sh uploads3.sh pilot "rds-manualsnapshot-deletion rds-retention-days-policy-notification" "lambda/rds-manualsnapshot-deletion lambda/rds-retention-days-policy-notification"
# This script will ONLY manage creation of lambda zip files and upload then to S3 bucket, if needed.

[ -z "$1" ] && echo "ERROR: Must specify VPCAlias as first input param" >&2 && exit 1
[ -z "$2" ] && echo "ERROR: Must specify zip filename(s) as second input param (i.e. \"rds-manualsnapshot-deletion rds-retention-days-policy-notification\")" >&2 && exit 2
[ -z "$3" ] && echo "ERROR: Must specify S3 key(s) of zip file(s) as third input param (i.e. \"lambda/rds-manualsnapshot-deletion lambda/rds-retention-days-policy-notification\")" >&2 && exit 2

export VPCAlias="$1"
TEMP_DIR='tempdir'
export OLD_ZIP="${TEMP_DIR}/universal-existing.zip"
declare -a ZIP_FNAMES=(${2})
declare -a S3PREFIXES=(${3})

LOOP=0
for ZIP_FNAME in "${ZIP_FNAMES[@]}"; do
    export ZIP_FNAME="${ZIP_FNAME}"
    export S3PREFIX=$(echo "${S3PREFIXES[$LOOP]}")
    export NEW_ZIP="${TEMP_DIR}/${ZIP_FNAME}.zip"


        echo "Make sure all required env vars are set" >&2
        for VAR in VPCAlias TEMP_DIR ZIP_FNAME OLD_ZIP NEW_ZIP S3PREFIX
        do
        eval VALUE=\$$VAR
        [ -z "$VALUE" ] && echo "ERROR: Must define a value for variable $VAR" && exit 201
        done

        echo "Make sure we have all the required executables" >&2
        for REQ in zip unzip sed grep tar tr; do
        which $REQ >/dev/null 2>&1
        [ 0 -ne $? ] && echo "ERROR: Failed to find required binary/script $REQ in path $PATH" >&2 && exit 203
        done

        echo "Get the name of the 'code' bucket from the CF exports" >&2
        QueryBody="Exports[?Name==\`s3:${VPCAlias}:code:name\`].Value[]"
        S3BUCKET=$( aws cloudformation list-exports --query "$QueryBody | [0]" --output text | grep -v 'None' )
        [ -z "$S3BUCKET" ] && echo "ERROR: Could not obtain the name of the 'code' bucket from the CF exports" >&2 && exit 204
        
        BUILD_NUM="0"
        BUILD_FILE="build.number"
        rm -f ${BUILD_FILE}

        # is there a file by that name in S3 ?
        echo "Pull down (an eventually existing) file from s3://${S3BUCKET}/${S3PREFIX}/${BUILD_FILE}" >&2
        OUTP=$( aws s3 --no-progress cp "s3://${S3BUCKET}/${S3PREFIX}/${BUILD_FILE}" . 2>&1 )
        [ 0 -ne $? ] && echo $OUTP | grep -q 'fatal error: SSL validation failed for https' >&2 && echo "Aborting due to..." && echo "$OUTP" && exit 205
        echo $OUTP | grep -v 'fatal error: An error occurred (404) when calling the HeadObject operation' >&2
        
        # read its content
        [ -r ${BUILD_FILE} ] && BUILD_NUM=$(cat ${BUILD_FILE})
        

        # is there a file by that name in S3 ?
        S3KEY="${S3PREFIX}/${BUILD_NUM}/${ZIP_FNAME}.zip"
        mkdir -p "${TEMP_DIR}"
        echo "Pull down (an eventually existing) file from s3://${S3BUCKET}/${S3KEY}" >&2
        OUTP=$( aws s3 --no-progress cp "s3://${S3BUCKET}/${S3KEY}" ${OLD_ZIP} 2>&1 )
        echo $OUTP | grep -v 'fatal error: An error occurred (404) when calling the HeadObject operation' >&2
        echo "Create a zip file" >&2
        zip -r -q -u -y ${NEW_ZIP}  ${ZIP_FNAME}.py
        bUploadNewZip=1
        # has the code changed ?
        if [ -e ${OLD_ZIP} ]; then
                CURRENT_FOLDER=$(pwd)
                mkdir -p "${TEMP_DIR}/old" "${TEMP_DIR}/new"
                cd "${CURRENT_FOLDER}/${TEMP_DIR}/old"; unzip -o -q "${CURRENT_FOLDER}/${OLD_ZIP}"; cd "${CURRENT_FOLDER}"
                cd "${CURRENT_FOLDER}/${TEMP_DIR}/new"; unzip -o -q "${CURRENT_FOLDER}/${NEW_ZIP}"; cd "${CURRENT_FOLDER}"
                diff -r "${TEMP_DIR}/old" "${TEMP_DIR}/new" >&2
                if [ 0 -eq $? ]; then
                echo "Content of new and old zip files appear to be the same" >&2
                bUploadNewZip=0
        else
                echo "We will need to upload new zip to S3 code bucket" >&2
        fi
        else
        echo "Skipped comparison of current and new code" >&2
    fi

        # do we need to upload new docker file to S3?
    if [ 1 -eq $bUploadNewZip ]; then
        
        PREV_BUILD_NUM=$( expr $BUILD_NUM - 1 )
        S3KEY="${S3PREFIX}/${PREV_BUILD_NUM}/${ZIP_FNAME}"
        OLD_S3="s3://${S3BUCKET}/${S3KEY}"

        BUILD_NUM=$( expr $BUILD_NUM + 1 )
        echo "$BUILD_NUM" > ${BUILD_FILE}
        S3KEY="${S3PREFIX}/${BUILD_NUM}/${ZIP_FNAME}"
        NEW_S3="s3://${S3BUCKET}/${S3KEY}.zip"

        echo "Upload the new zip to s3://${S3BUCKET}/${S3KEY}" >&2
        aws s3 --no-progress cp "${NEW_ZIP}" "${NEW_S3}" --sse >&2
        ERR=$?
        if [ 0 -ne $ERR ]; then
                echo "Failed to copy new zip to S3. Exit code is $ERR. Aborting ..." >&2
                [ "1" != "$CONTINUE_ON_COPY_ERROR" ] && exit $ERR || echo "Not aborting since CONTINUE_ON_COPY_ERROR is 1" >&2
        fi

        aws s3 --no-progress cp "${BUILD_FILE}" "s3://${S3BUCKET}/${S3PREFIX}/${BUILD_FILE}" --sse >&2
        ERR=$?
        if [ 0 -ne $ERR ]; then
                echo "Failed to copy ${BUILD_FILE} to S3. Exit code is $ERR. Aborting ..." >&2
                [ "1" != "$CONTINUE_ON_COPY_ERROR" ] && exit $ERR || echo "Not aborting since CONTINUE_ON_COPY_ERROR is 1" >&2
        fi
        
        if [ $PREV_BUILD_NUM -gt 2 ]; then
                 PREV_BUILD_NUM=$( expr $BUILD_NUM - 2 )
                 S3KEY="${S3PREFIX}/${PREV_BUILD_NUM}/${ZIP_FNAME}"
                 OLD_S3="s3://${S3BUCKET}/${S3KEY}.zip"
                 echo "Delete old s3 file ${OLD_S3} ..." >&2
                 aws s3 rm "${OLD_S3}" >&2
        fi

    else
        echo "Skipped upload of new zip to S3" >&2
        fi
    rm -rf "${TEMP_DIR}"
    rm -f ${BUILD_FILE}
        LOOP=$( expr $LOOP + 1 )
done

