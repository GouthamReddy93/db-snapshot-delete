#!/bin/bash
#     --------------------------------------------------------------------------------------------
#                   -=- Attach_retention_tag.sh-=-
#
#     ---------------------------------------------------------------------------------------------
#     OBJECT:   To attach retention-days(tag) with by default value(35 days) to existing snapshot.
#    -----------------------------------------------------------------------------------------------
#
#     Execution : ./Attach_retention_tag.sh
#
#     ---------------------------------------------------------------------------------------------
#
#     Version: 1.0
#     ---------------------------------------------------------------------------------------------

CURRENTDATE=`date '+%Y%m%d'_'%H%M%S'`
ALL_SNAPSHOTS=ALL_SNAPSHOTS'_'$CURRENTDATE
LOG_FILE=Attach_tag_status'_'$CURRENTDATE.log
export LOG_FILE
export ALL_SNAPSHOTS
aws rds describe-db-snapshots --query "DBSnapshots[?SnapshotType=='manual'].{Snapshortname: DBSnapshotIdentifier}" --output text >> $ALL_SNAPSHOTS
for i in `cat $ALL_SNAPSHOTS`
do
        SNAPSHOT_ARN=`aws rds describe-db-snapshots --db-snapshot-identifier $i --query "DBSnapshots[*].{DBSnapshotArn: DBSnapshotArn}" --output text`
        SNAPSHOT_AVAILABLE_TAGS=`aws rds list-tags-for-resource --resource-name $SNAPSHOT_ARN --output text`
        SUPPORTGROUP_TAG=`echo $SNAPSHOT_AVAILABLE_TAGS | grep -o support-group`
        SUPPORTGROUP_TAG_STATUS=$?
        if [ $SUPPORTGROUP_TAG == "support-group" ] 2>/dev/null
        then
                echo  $SUPPORTGROUP_TAG " tag is present for DBsnapshot =" $i
                RETENTION_TAG=`echo $SNAPSHOT_AVAILABLE_TAGS | grep -o retention-days`
                RETENTION_TAG_STATUS=$?
                if [ $RETENTION_TAG == "retention-days" ] 2>/dev/null
                then
                         echo  $RETENTION_TAG "is present for DBSnapshot =" $i
                else
                        SNAPSHOT_ARN=`aws rds describe-db-snapshots --db-snapshot-identifier $i --query "DBSnapshots[*].{DBSnapshotArn: DBSnapshotArn}" --output text`
                        aws rds add-tags-to-resource --resource-name $SNAPSHOT_ARN  --tags Key=retention-days,Value=35
                        ATTACH_TAG_STATUS=$?
                        if [ $ATTACH_TAG_STATUS -eq 0 ]
                        then
                                sleep 10
                                SNAPSHOT_AVAILABLE_NEW_TAGS=`aws rds list-tags-for-resource --resource-name $SNAPSHOT_ARN --output text`
                                RETENTION_DAY_TAG=`echo $SNAPSHOT_AVAILABLE_NEW_TAGS | grep -o retention-days`
                                RETENTION_DAY_TAG_STATUS=$?
                                if [ $RETENTION_DAY_TAG_STATUS -eq 0 ]
                                then
                                        echo "key=retention-days(tag) and value=35 is successfully attached to the DBSnapshot =" $i
                                        echo "key=retention-days(tag) and value=35 is successfully attached to the DBSnapshot =" $i >> ${LOG_FILE}
                                fi
                        else
                                echo "retention-days tag has not been added to DBSnapshot" $i
                                echo "command is existed with status code =" $ATTACH_TAG_STATUS
                        fi
                fi
        else
                echo  "support-group tag not found for DB snapshot" $i
        fi
done
