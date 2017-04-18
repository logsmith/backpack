#!/bin/bash

cd ${0%/*}
cd ../

# Example command
WPDBNAME=`cat active-config.php | grep DB_NAME | cut -d \' -f 4`;
BUCKET_NAME=`cat active-config.php | grep S3_BACKUP_BUCKET_NAME | cut -d \' -f 4`
REGION=`cat active-config.php | grep S3_BACKUP_REGION | cut -d \' -f 4`
ACCESS_KEY=`cat active-config.php | grep S3_BACKUP_ACCESS_KEY | cut -d \' -f 4`
SECRET_KEY=`cat active-config.php | grep S3_BACKUP_SECRET_KEY | cut -d \' -f 4`
SLACK_WEBHOOK_URL=`cat active-config.php | grep S3_BACKUP_SLACK_WEBHOOK_URL | cut -d \' -f 4`

filename=$WPDBNAME'--'$(date  +"%Y-%m-%d--%H-%M");

# Back up the WordPress database with WP-CLI
wp db export wp-content/uploads/database-backup.sql --allow-root
# cat $BACKUPPATH/$WPDBNAME/$DATEFORM-$WPDBNAME.sql | gzip > $BACKUPPATH/$WPDBNAME/$DATEFORM-$WPDBNAME.sql.gz


# exit 1;


# exmaple of if and
# if [[ -n "$var" && -e "$var" ]] ; then


# need to capture /home/forge/www.atomicsmash.co.uk/current/scripts/backup.sh: line 30: s3cmd: command not found

if [ "$REGION" != "" ]; then

    s3cmd put wp-content/uploads/database-backup.sql s3://$BUCKET_NAME/sql-backups/$filename --region=$REGION --secret_key=$SECRET_KEY --access_key=$ACCESS_KEY --no-mime-magic

    rm wp-content/uploads/database-backup.sql;
    echo "SQL upload complete"


    s3cmd sync wp-content/uploads/* s3://$BUCKET_NAME --region=$REGION --secret_key=$SECRET_KEY --access_key=$ACCESS_KEY --no-mime-magic
    # s3cmd sync ../wp-content/uploads s3://$BUCKET_NAME --region=$REGION --secret_key=$SECRET_KEY --access_key=$ACCESS_KEY --no-mime-magic -q

    echo "Sync complete"

    # ping slack
    webhook_url=$SLACK_WEBHOOK_URL
    text="$WPDBNAME backed up!"
    channel="#backups"
    escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
    json="{\"channel\": \"$channel\", \"username\":\"backups\", \"text\": \"$escapedText\"}"
    curl -s -d "payload=$json" "$webhook_url"


fi
