#!/bin/bash

# Check to see if s3cmd is installed
type s3cmd >/dev/null 2>&1 || { echo >&2 "I require s3cmd but it's not installed."; exit 1; }

# cd to where THIS script is located
cd ${0%/*}
cd ../../../

# Example command
WPDBNAME=`cat active-config.php | grep DB_NAME | cut -d \' -f 4`;
BUCKET_NAME=`cat active-config.php | grep BACKPACK_S3_BUCKET_NAME | cut -d \' -f 4`
REGION=`cat active-config.php | grep BACKPACK_S3_REGION | cut -d \' -f 4`
ACCESS_KEY=`cat active-config.php | grep BACKPACK_S3_ACCESS_KEY | cut -d \' -f 4`
SECRET_KEY=`cat active-config.php | grep BACKPACK_S3_SECRET_KEY | cut -d \' -f 4`
SLACK_WEBHOOK_URL=`cat active-config.php | grep BACKPACK_S3_SLACK_WEBHOOK_URL | cut -d \' -f 4`

filename=$WPDBNAME'--'$(date  +"%Y-%m-%d--%H-%M");

# Back up the WordPress database with WP-CLI
wp db export ../backups/auto-database-backup.sql --allow-root

# exit 1;

# exmaple of if and
# if [[ -n "$var" && -e "$var" ]] ; then


# need to capture /home/forge/www.atomicsmash.co.uk/current/scripts/backup.sh: line 30: s3cmd: command not found

if [ "SLACK_WEBHOOK_URL" != "" ]; then

    s3cmd put ../backups/auto-database-backup.sql s3://$BUCKET_NAME/sql-backups/$filename --region=$REGION --secret_key=$SECRET_KEY --access_key=$ACCESS_KEY --no-mime-magic

    # rm wp-content/uploads/database-backup.sql;
    echo "SQL upload complete"

    s3cmd sync ../backups/* s3://$BUCKET_NAME --region=$REGION --secret_key=$SECRET_KEY --access_key=$ACCESS_KEY --no-mime-magic
    # s3cmd sync ../wp-content/uploads s3://$BUCKET_NAME --region=$REGION --secret_key=$SECRET_KEY --access_key=$ACCESS_KEY --no-mime-magic -q

    echo "Sync complete"

    # ping slack
    # ASTODO: Check to see if slack creds are available
    webhook_url=$SLACK_WEBHOOK_URL
    text="$WPDBNAME backed up!"
    channel="#backups"
    escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
    json="{\"channel\": \"$channel\", \"username\":\"backups\", \"text\": \"$escapedText\"}"
    curl -s -d "payload=$json" "$webhook_url"

fi
