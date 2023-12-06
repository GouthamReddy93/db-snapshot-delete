import json
import boto3
from datetime import datetime
from datetime import timedelta
import os
delete_rds_postgress = {}
delete_rds_mysql = {}
delete_rds_oracle = {}
delete_rds_mssql = {}

def lambda_handler(event, context):
    region = os.environ.get('AWS_REGION')
    accound_id = boto3.client('sts').get_caller_identity()['Account']
    client = boto3.client('rds')
    sns_client =  boto3.client('sns')
    DBSnapshot = client.describe_db_snapshots(SnapshotType='manual')
    for i in DBSnapshot['DBSnapshots']:
        Snapshot_ARN = i['DBSnapshotArn']
        response = client.list_tags_for_resource(ResourceName=Snapshot_ARN)
        DBtaglist = response['TagList']
        DBrday = response['TagList']
        for tag in DBtaglist:
            if (tag['Key'] == 'support-group') and (tag['Value'] == 'dig-tech-cts-cloud-db-support-team'):
                for num in DBrday:
                    if 'retention-day' in num['Key']:
                        retentionday = num['Value']
                        if not retentionday:
                            print (" retention-day is present but value doesn't exist")
                        else:
                            day = int(retentionday)
                            now = datetime.now() - timedelta(days= day)
                            date = now.strftime("%Y-%m-%d")
                            Snapshot_date = i['SnapshotCreateTime']
                            Snapshot_date = Snapshot_date.strftime("%Y-%m-%d")
                            if Snapshot_date < date:
                                Snapshot_name = i['DBSnapshotIdentifier']
                                Snapshot_status = i['Status']
                                Snapshot_type = i['SnapshotType']
                                Snapshot_instance = i['DBInstanceIdentifier']
                                snapshotremove = client.delete_db_snapshot( DBSnapshotIdentifier=Snapshot_name )
                                if snapshotremove['DBSnapshot']['Status'] == 'deleted':
                                    print("We have deleted the {} RDS Snapshot".format(Snapshot_name,Snapshot_instance,Snapshot_date ))
                                    print("We have deleted the {} RDS Snapshot which is created on {} of instance {} ".format(Snapshot_name,Snapshot_instance,Snapshot_date ))
                                    if snapshotremove['DBSnapshot']['Engine'] == 'mysql':
                                        delete_rds_mysql.update({snapshotremove['DBSnapshot']['DBSnapshotIdentifier'] : [snapshotremove['DBSnapshot']['DBInstanceIdentifier'] , day ]})
                                    elif snapshotremove['DBSnapshot']['Engine'] == 'postgres':
                                        delete_rds_postgress.update({snapshotremove['DBSnapshot']['DBSnapshotIdentifier'] : [snapshotremove['DBSnapshot']['DBInstanceIdentifier'] , day ]})
                                    elif snapshotremove['DBSnapshot']['Engine'] == 'oracle-ee':
                                        delete_rds_oracle.update({snapshotremove['DBSnapshot']['DBSnapshotIdentifier'] : [snapshotremove['DBSnapshot']['DBInstanceIdentifier'] , day ]})
                                    elif (snapshotremove['DBSnapshot']['Engine'] == 'sqlserver-ex') or (snapshotremove['DBSnapshot']['Engine'] == 'sqlserver-se') or (snapshotremove['DBSnapshot']['Engine'] == 'sqlserver-web'):
                                        delete_rds_mssql.update({snapshotremove['DBSnapshot']['DBSnapshotIdentifier'] : [snapshotremove['DBSnapshot']['DBInstanceIdentifier'] , day ]})
                                    else:
                                        print ("No DB Engine found")
                                    
    
                                        
    mysql_sns_arn = "arn:aws:sns:{}:{}:DB-MySQL-SNS".format(region,accound_id )
    mssql_sns_arn = "arn:aws:sns:{}:{}:DB-MSSQL-SNS".format(region,accound_id )
    postgress_sns_arn ="arn:aws:sns:{}:{}:DB-POSTGRESQL-SNS".format(region,accound_id )
    oracle_sns_arn = "arn:aws:sns:{}:{}:DB-ORACLE-SNS".format(region,accound_id )                                
    
    print (delete_rds_mssql)
                                   
    email_body = """
#####THIS IS A NOTIFICATION FOR THE DELETED MANUAL  SNAPSHOTSTRIGGERED AS PART OF INFRASTRUCTURE COST OPTIMIZATIONS ##############
##### YOU ARE RECEIVING THIS MESSAGE AS THESE INSTANCES ARE MANAGEDBY CORETECH BILLING #########\n
    """
    
    mysql_deleted_snapshot = ""
    postgress_deleted_snapshot = ""
    oracle_deleted_snapshot = ""
    mssql_deleted_snapshot = ""
    
    
    email_footer = """
##########PLEASE REMEMBER TO TAG YOUR MANUAL SNAPSHOT RESOURCES WITHRETENTION_TIME TAG VALUES TO RETAIN THEM####################
#######PLEASE GET IN TOUCH WITH <SUPPORT-DL-NAME> OR <ASADULLAH.NASRULLAH@GE.COM> IFYOU HAVE QUESTIONS ABOUT THIS NOTIFICATION#########\n\n\n\n
    """                             


    for kmysql, vmysql in delete_rds_mysql.items():
        mysql_deleted_snapshot += " Snapshotname = {} of has been deleted of RDSInstanceName = {} (Retention was set to : {}) \n \n".format(kmysql,vmysql[0], vmysql[1])
    
    email_body_mysql = email_body + mysql_deleted_snapshot + email_footer
    


    for kpostgress, vpostgress in delete_rds_postgress.items():
        postgress_deleted_snapshot += " Snapshotname = {} has been deleted of   RDSInstanceName = {} (Retention was set to : {}) \n \n".format(kpostgress,vpostgress[0],vpostgress[1])
    email_body_postgress =  email_body + postgress_deleted_snapshot + email_footer

  
    
    for koracle, voracle in delete_rds_oracle.items():
        oracle_deleted_snapshot +=  " Snapshotname = {}  has been deleted of RDSInstanceName = {} (Retention was set to : {}) \n \n ".format(koracle,voracle[0],voracle[1])
    email_body_oracle = email_body + oracle_deleted_snapshot + email_footer 
    


    for kmssql, vmssql in delete_rds_mssql.items():
        mssql_deleted_snapshot += " Snapshotname = {}  has been deleted RDSInstanceName = {} (Retention was set to : {}) \n \n".format(kmssql,vmssql[0],vmssql[1])
    email_body_mssql = email_body + mssql_deleted_snapshot + email_footer

    
    print(email_body_mysql)
    print(email_body_postgress)
    print(email_body_oracle)
    print(email_body_mssql)
    
    if len(delete_rds_mysql) > 0:
        sns_client.publish(
            TopicArn=mysql_sns_arn,
            Subject='Deleted RDS snapshot for Mysql databases',
            Message= email_body_mysql
        )
   
    if len(delete_rds_mssql) > 0:
        sns_client.publish(
            TopicArn=mssql_sns_arn,
            Subject='Deleted RDS snapshot for MSSQL databases',
            Message= email_body_mssql
     )
   
    if len(delete_rds_postgress) > 0:
        sns_client.publish(
            TopicArn=postgress_sns_arn,
            Subject='Deleted RDS snapshot for Postgres databases',
            Message= email_body_postgress
    )
   
    if len(delete_rds_oracle) > 0:
        sns_client.publish(
            TopicArn=oracle_sns_arn,
            Subject='Deleted RDS snapshot for Oracle databases',
            Message= email_body_oracle
    )

    delete_rds_mysql.clear()
    delete_rds_mssql.clear()
    delete_rds_postgress.clear()
    delete_rds_oracle.clear()


