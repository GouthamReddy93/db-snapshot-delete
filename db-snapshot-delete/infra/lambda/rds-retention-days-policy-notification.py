####
import json
import boto3
from datetime import datetime
from datetime import timedelta
import os
rds_mysql = {}
rds_postgress = {}
rds_oracle = {}
rds_mssql = {}

email_body_mysql = ""
email_body_postgress = ""
email_body_oracle = ""
email_body_mssql = ""

def lambda_handler(event, context):
    region = os.environ.get('AWS_REGION')
    accound_id = boto3.client('sts').get_caller_identity()['Account']
    client = boto3.client('rds')
    sns_client =  boto3.client('sns')
    snapshot = client.describe_db_snapshots(SnapshotType='manual')
    for i in snapshot['DBSnapshots']:
        Snapshot_ARN = i['DBSnapshotArn']
        response = client.list_tags_for_resource(ResourceName=Snapshot_ARN)
        taglist = response['TagList']
        tag_list = [d['Key'] for d in taglist]
        if 'support-group' in tag_list:
            if 'retention-day' in tag_list:
                Snapshot_name = i['DBSnapshotIdentifier']
                print ("Key found for {}".format(Snapshot_name))
            else:
                Snapshot_name_no = i['DBSnapshotIdentifier']
                print ("Key not found for {}".format(Snapshot_name_no))
                if (i['Engine'] == 'mysql') :
                    rds_mysql.update({i['DBSnapshotIdentifier'] : i['DBInstanceIdentifier'] })
                elif i['Engine'] == 'postgres':
                    rds_postgress.update({i['DBSnapshotIdentifier'] : i['DBInstanceIdentifier'] })
                elif i['Engine'] == 'oracle-ee':
                    rds_oracle.update({i['DBSnapshotIdentifier'] : i['DBInstanceIdentifier'] })
                elif (i['Engine'] == 'sqlserver-ex') or (i['Engine'] == 'sqlserver-se')  or (i['Engine'] == 'sqlserver-web'):
                    rds_mssql.update({i['DBSnapshotIdentifier'] : i['DBInstanceIdentifier'] })
                else:
                    print ("No DB Engine found")
                    
                    
    mysql_sns_arn = "arn:aws:sns:{}:{}:DB-MySQL-SNS".format(region,accound_id )
    mssql_sns_arn = "arn:aws:sns:{}:{}:DB-MSSQL-SNS".format(region,accound_id )
    postgress_sns_arn ="arn:aws:sns:{}:{}:DB-POSTGRESQL-SNS".format(region,accound_id )
    oracle_sns_arn = "arn:aws:sns:{}:{}:DB-ORACLE-SNS".format(region,accound_id ) 
                    
    Email_body  =  """
    ########## THIS IS A HARBINGER NOTIFICATION THAT MANUAL SNAPSHOTS HAVE NOT BEEN TAGGED WITH RETENTION_TIME VALUES ########################

    ########## YOU ARE RECEIVING THIS MESSAGE AS THESE INSTANCES ARE MANAGED BY CORETECH BILLING #############################################

 

    Untagged snapshot name list:

    """
    
    email_body_mysql = ""
    email_body_postgress = ""
    email_body_oracle = ""
    email_body_mssql = ""
    
    
    for kmysql, vmysql in rds_mysql.items():
        email_body_mysql += "Snapshotname = {} has been not been tagged(retention-day) for  RDSInstanceName = {} \n \n".format(kmysql,vmysql)
    email_body_mysql = Email_body + email_body_mysql
    
    
    for kpostgress, vpostgress in rds_postgress.items():
        email_body_postgress += " Snapshotname = {} has been not been tagged(retention-day) for RDSInstanceName = {} \n \n".format(kpostgress,vpostgress)
    email_body_postgress =  Email_body + email_body_postgress
    
    
    for koracle, voracle in rds_oracle.items():
        email_body_oracle += " Snapshotname = {}  has been not been tagged(retention-day) for RDSInstanceName = {}  \n \n".format(koracle,voracle)
    email_body_oracle = Email_body + email_body_oracle
    
    
    for kmssql, vmssql in rds_mssql.items():
        email_body_mssql +=" Snapshotname = {}  has been not been tagged(retention-day)  for RDSInstanceName = {} \n \n".format(kmssql,vmssql)
    email_body_mssql = Email_body +  email_body_mssql 
    
    
    
    print (email_body_mysql)
    print (email_body_postgress)
    print (email_body_oracle)
    print (email_body_mssql)


    if len(rds_mysql) > 0:
        sns_client.publish(
            TopicArn=mysql_sns_arn,
            Subject='Snapshots is Untagged with retention-day tag',
            Message= email_body_mysql
        )
   
    if len(rds_mssql) > 0:
        sns_client.publish(
            TopicArn=mssql_sns_arn,
            Subject='Snapshots is Untagged with retention-day tag',
            Message= email_body_mssql
     )
   
    if len(rds_postgress) > 0:
        sns_client.publish(
            TopicArn=postgress_sns_arn,
            Subject='Snapshots is Untagged with retention-day tag',
            Message= email_body_postgress
    )
   
    if len(rds_oracle) > 0:
        sns_client.publish(
            TopicArn=oracle_sns_arn,
            Subject='Snapshots is Untagged with retention-day tag',
            Message= email_body_oracle
    )

    rds_mysql.clear() 
    rds_postgress.clear()
    rds_oracle.clear()
    rds_mssql.clear()

