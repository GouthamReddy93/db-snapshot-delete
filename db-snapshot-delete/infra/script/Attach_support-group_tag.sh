#!/bin/bash
CURRENTDATE=`date '+%Y%m%d'_'%H%M%S'`
ALL_SNAPSHOTS=ALL_SNAPSHOTS'_'$CURRENTDATE
LOG_FILE=Attach_tag_status'_'$CURRENTDATE.log
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
    else
         SNAPSHOT_ARN=`aws rds describe-db-snapshots --db-snapshot-identifier $i --query "DBSnapshots[*].{DBSnapshotArn: DBSnapshotArn}" --output text`
         aws rds add-tags-to-resource --resource-name $SNAPSHOT_ARN  --tags Key=support-group,Value=dig-tech-cts-cloud-db-support-team
         ATTACH_TAG_STATUS=$?
         if [ $ATTACH_TAG_STATUS -eq 0 ]
         then
               sleep 10
               SNAPSHOT_AVAILABLE_NEW_TAGS=`aws rds list-tags-for-resource --resource-name $SNAPSHOT_ARN --output text`
               RETENTION_DAY_TAG=`echo $SNAPSHOT_AVAILABLE_NEW_TAGS | grep -o retention-days`
               RETENTION_DAY_TAG_STATUS=$?
               if [ $RETENTION_DAY_TAG_STATUS -eq 0 ]
               then
                      echo "key=support-group(tag) and value=dig-tech-cts-cloud-db-support-team is successfully attached to the DBSnapshot =" $i
                      echo "key=support-group(tag) and value=dig-tech-cts-cloud-db-support-team is successfully attached to the DBSnapshot =" $i >> ${LOG_FILE}
               fi
        else
               echo "support-groups tag has not been added to DBSnapshot" $i
               echo "command is existed with status code =" $ATTACH_TAG_STATUS
         fi
     fi
               
done                      


