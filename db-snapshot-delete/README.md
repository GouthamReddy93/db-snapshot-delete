Components Of the Automation:

    1.  RDS-manualsnapshot-deletion Lambda - > To Remove the Manual Snapshot 
    2.  Rds-retention-days-policy-notification Lambda -> Notify the user, Snapshot doesn't tag with require tag.


Functionality :

    1. Code will first check tag "support-group" is attached to the rds manual snapshot or not.
    2. If and only if “support-group” tag is attached to the snapshot, then it will check the next tag "retention-day", which basically contain number of retention days (i.e. 30, 45 , N days) for that particular snapshot.
    3. So function will take the value of retention days parameter and check the condition for deletion.
    4. If deletion condition is fulfilled then it will proceed to delete the snapshot, otherwise not.
    5. Finally it will send notification to DL which will contain information of deleted snapshot name and parent instance name.


Deployment :

    DBSS Lambda Manual Snapshot Deletion Deployment
    How to execute - > 

         dbss-manual-snapshot-deployment.sh $VPCAlias
    **** This is for high level understanding only. Read the Deep dive section if doing a new deplyment. *****

    dbss-manual-snapshot-deployment.sh script has 2 major function. Each fucntion deploying a particular component.

        1. dbss_lambda_upload  -> Uploads the lambda scripts to S3 bucket for both the lambda function.
        2. dbss_lambda_rds_manualsnapshot_deletion_deploy -> Deploy 2 lambda function for this deployment
    
    ******Deep dive into each function and the stacks executed. *********

    1. dbss_lambda_upload -->  Uploading Lambda files to S3 bucket for Manual snapshot deletion and notification lambda.
    The below shell script uploads the lambda function to S3 bucket .
    
        uploads3.sh "${VPCAlias}" "rds-manualsnapshot-deletion" "lambda/rds-manualsnapshot-deletion"
        uploads3.sh "${VPCAlias}" "rds-retention-days-policy-notification" "lambda/rds-retention-days-policy-notification"
    
    2. dbss_lambda_rds_manualsnapshot_deletion_deploy -> Create a new stack_master file under /infra as stack_master-${VPCAlias}1a.yml. Example - infra/stack_master-pilot-dbss_manual_snapshot_deletion.yml -- > Created for Lab env.

    Update the Account number, UAI , VPCAlias, Region in each stack_master file that is created.
    The below stack are a part stack_master-${VPCAlias}1a.yml

        1. dbss-rds-manual-snapshot-deletion.yml - > Deploy Manual Snapshot deletion lambda and notification lambda.
    
    


    

