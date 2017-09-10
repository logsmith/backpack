#!/bin/bash

red=`tput setaf 1`
grn=`tput setaf 2`
blu=`tput setaf 4`
mag=`tput setaf 5`
lightblu=`tput setaf 6`
end=`tput sgr0`

echo "${lightblu}--------------------------------------------------------------------------${end}";


# Check to see if s3cmd is installed
type s3cmd >/dev/null 2>&1 || {
	echo >&2 "${red}I require s3cmd but it's not installed 😰 Run:${end}";
	echo "${lightblu}sudo apt-get install python-pip${end}"
	echo "${lightblu}sudo pip install s3cmd${end}"
	exit 1;
}

# Check to see if wp-cli is installed
type wp >/dev/null 2>&1 || {
	echo >&2 "${red}I require WP-CLI but it's not installed 😰 Run:${end}";
	echo "${lightblu}curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar${end}"
	echo "${lightblu}chmod +x wp-cli.phar${end}"
	echo "${lightblu}sudo mv wp-cli.phar /usr/local/bin/wp${end}"
	exit 1;
}

# cd to where THIS script is located
cd ${0%/*}
cd ../../../


# Example command
WPDBNAME=`cat active-config.php | grep DB_NAME | cut -d \' -f 4`;
BACKPACK_BUCKET_NAME=`cat active-config.php | grep BACKPACK_BUCKET_NAME | cut -d \' -f 4`
BACKPACK_BUCKET_REGION=`cat active-config.php | grep BACKPACK_BUCKET_REGION | cut -d \' -f 4`
BACKPACK_ACCESS_KEY=`cat active-config.php | grep BACKPACK_ACCESS_KEY | cut -d \' -f 4`
BACKPACK_SECRET_KEY=`cat active-config.php | grep BACKPACK_SECRET_KEY | cut -d \' -f 4`
BACKPACK_SLACK_WEBHOOK_URL=`cat active-config.php | grep BACKPACK_SLACK_WEBHOOK_URL | cut -d \' -f 4`

filename=$WPDBNAME'--'$(date  +"%Y-%m-%d--%H-%M")'.sql';

if [ -z $BACKPACK_BUCKET_NAME ]; then
	echo "${red}BACKPACK_BUCKET_NAME${end} missing from active wp-config file 🛠"
fi

if [ -z $BACKPACK_BUCKET_REGION ]; then
	echo "${red}BACKPACK_BUCKET_REGION${end} missing from active wp-config file 🛠"
fi

if [ -z $BACKPACK_ACCESS_KEY ]; then
	echo "${red}BACKPACK_ACCESS_KEY${end} missing from active wp-config file 🛠"
fi

if [ -z $BACKPACK_SECRET_KEY ]; then
	echo "${red}BACKPACK_SECRET_KEY${end} missing from active wp-config file 🛠"
fi

if [ -z $BACKPACK_SLACK_WEBHOOK_URL ]; then
	echo "${red}BACKPACK_SLACK_WEBHOOK_URL${end} missing from active wp-config file, slack notifications will not work 🛠"
fi

if [[ -z $BACKPACK_BUCKET_NAME || -z $BACKPACK_BUCKET_REGION || -z $BACKPACK_ACCESS_KEY || -z $BACKPACK_SECRET_KEY ]]; then
	echo "${red}--------------------------------------------------------------------------${end}";
	exit
fi

if [ ! -d "wp-content/backups" ]; then
	echo "${grn}Making new backup directory${end} 📂"
	echo "${grn}--------------------------------------------------------------------------${end}";
	mkdir wp-content/backups
fi


# Back up the WordPress database with WP-CLI
echo "${grn}Saving database backup${end} 💾"
wp db export wp-content/backups/auto-database-backup.sql --allow-root

# exit 1;

echo "${grn}Starting upload to S3${end} 📡"

s3cmd put wp-content/backups/auto-database-backup.sql s3://$BACKPACK_BUCKET_NAME/sql-backups/$filename --region=$BACKPACK_BUCKET_REGION --secret_key=$BACKPACK_SECRET_KEY --access_key=$BACKPACK_ACCESS_KEY --no-mime-magic && echo "${grn}Database upload complete${end} 🎉" || echo "${red}Error uploading to S3, please check credentials${end} ⛔️";


# s3cmd put wp-content/backups/auto-database-backup.sql s3://$BACKPACK_BUCKET_NAME/sql-backups/$filename --region=$BACKPACK_BUCKET_REGION --secret_key=$BACKPACK_SECRET_KEY --access_key=$BACKPACK_ACCESS_KEY

exit

echo "${grn}Starting upload media to S3${end} 📡"

s3cmd sync wp-content/uploads s3://$BACKPACK_BUCKET_NAME --region=$BACKPACK_BUCKET_REGION --secret_key=$BACKPACK_SECRET_KEY --access_key=$BACKPACK_ACCESS_KEY --no-mime-magic -q && echo "${grn}Media Library sync complete${end} 🎉" || echo "${red}Error uploading to S3, please check credentials${end} ⛔️";

echo "${lightblu}--------------------------------------------------------------------------${end}";

# Ping slack
if [ ! -z $SLACK_WEBHOOK_URL ]; then

	echo "${lightblue}Pinging Slack${end} ✉️"

    webhook_url=$SLACK_WEBHOOK_URL
    text="$WPDBNAME backed up!"
    channel="#backups"
    escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
    json="{\"channel\": \"$channel\", \"username\":\"backups\", \"text\": \"$escapedText\"}";
    curl -s -d "payload=$json" "$webhook_url";

	echo "${lightblu}--------------------------------------------------------------------------${end}";

fi
