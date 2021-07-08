#!/usr/bin/env bash

REMOTE_DIR=/var/www/vhosts/temp                 ## Working dir ##
KEY=~/.ssh/id_rsa                               ## .pem file location for SSH connection##
FILE='vuse-mage2-build.tar.bz2'                 ## Generated TAR file##
site="dev"
site_opt="DEV"
dir_name=/var/www/vhosts/${site}1.vusevapor.example.com
#

echo -e "\n\n\t########################################"
echo -e "\t#CREATE BACKUP OF EXISTING SETUP #"
echo -e "\t########################################"
tar -cvf /var/www/vhosts/backup/bornvusemage2-$(date +%Y-%m-%d_%H%M%S).tar -T /var/www/vhosts/backuplist.txt
echo -e "\n##TODAY'S BACKUP IS CREATED##";
#CLEAN THE TARGET DIRECTORY
echo -e "\n##MOVED TO TEMP DIR"
cd /var/www/vhosts/temp
#find . \! -name 'vuse-mage2-build.tar.bz2' -delete
echo -e "\n##TARGET IS CLEANED##"
echo -e "\n\n\t##########################"
echo -e "\t#UNTAR THE LATEST CONTENT#"
echo -e "\t##########################"
echo -e "\n##REMOVING DIRECTORIES FROM  ${site_opt}  ENVIRONMENT"

cd $dir_name/app
echo -e "\n##REMOVE code and design/frontend/Born/vuse DIRs from ${site}.vusevapor.raimktg.com/app"
#rm -rf code design/frontend/*
echo -e "\n##CHECKING IF /var/www/vhosts/${site}.vusevapor.raimktg.com/app/code DIR was DELETED"
#ls $dir_name/app/code
echo -e "\n##CHECKING IF /var/www/vhosts/${site}.vusevapor.raimktg.com/app/design/frontend/Born/vuse DIR was DELETED"
#ls $dir_name/app/design/frontend/Born/vuse
#cd $dir_name/dev/tools
echo -e "\n##REMOVE grunt DIR from ${site}.vusevapor.raimktg.com/dev/tools"
#rm -rf grunt
### REMOVING THE DIR $dir_name/var/generation
echo -e "\n## REMOVING THE CONTENTS WITHIN DIRECTORY $dir_name/var/generation ##"
#rm -rf $dir_name/var/generation/*
echo -e "\n##MOVED TO TEMP DIR"
#cd /var/www/vhosts/temp
echo -e "\n##UNTARING FILE: $FILE"
#tar xvjf $FILE
echo -e "\n##COPYING /app/code to $dir_name/app/ "
#cp -r app/code $dir_name/app/
echo -e "\n##COPYING  app/design/frontend/Born to $dir_name/app/design/frontend/"
#cp -r app/design/frontend/* $dir_name/app/design/frontend/
echo -e "\n##COPYING dev/tools/grunt to $dir_name/dev/tools/"
#cp -r dev/tools/grunt $dir_name/dev/tools/
echo -e "\n##COPYING .editorconfig to $dir_name/editorconfig"
#cp .editorconfig $dir_name/.editorconfig
echo -e "\n##COPYING Gruntfile.js to $dir_name/Gruntfile.js"
#cp Gruntfile.js $dir_name/Gruntfile.js
echo -e "\n##COPYING auth.json to $dir_name/auth.json"
#cp auth.json $dir_name/auth.json
echo -e "\n##COPYING autocomplete.php to $dir_name/autocomplete.php"
#cp autocomplete.php $dir_name/autocomplete.php
echo -e "\n##COPYING autocomplete.php to $dir_name/pub/autocomplete.php"
#cp autocomplete.php $dir_name/pub/autocomplete.php
echo -e "\n##COPYING composer.json to $dir_name/composer.json"
#cp composer.json $dir_name/composer.json
echo -e "\n##COPYING composer.lock to $dir_name/composer.lock"
#cp composer.lock $dir_name/composer.lock
echo -e "\n##COPYING package-lock.json to $dir_name/package-lock.json"
#cp package-lock.json $dir_name/package-lock.json
echo -e "\n##COPYING package.json to $dir_name/package.json"
#cp package.json $dir_name/package.json
echo -e "\n##LATEST CONTENT IS AVAILABLE NOW HOST##"
#cd $dir_name
echo -e "\n##DELETING pub/static/frontend##"
#rm -rf pub/static/frontend
echo -e "\n##DELETING pub/static/adminhtm##"
#rm -rf pub/static/adminhtml
echo -e "\n##DELETING pub/static/_requirejs##"
#rm -rf pub/static/_requirejs
echo -e "\n##EXECUTING composer install --no-dev##"
#composer install --no-dev
echo -e "\n##EXECUTING MAGENTO UPGRADE##"
#php bin/magento setup:upgrade
echo -e "\n##EXECUTING MAGENTO COMPILE##"
#php bin/magento setup:di:compile
echo -e "\n##EXECUTING MAGENTO SETUP:STATIC-CONTENT:DEPLOY FOR Magento/backend##"
#php bin/magento setup:static-content:deploy --theme Magento/backend
echo -e "\n##EXECUTING MAGENTO SETUP:STATIC-CONTENT:DEPLOY FOR Retail/base##"
#php bin/magento setup:static-content:deploy en_US --area frontend --theme Retail/base
echo -e "\n##EXECUTING npm install##"
#npm install
echo -e "\n##EXECUTING grunt exec:vuse##"
#grunt exec:vuse
echo -e "\n##EXECUTING grunt less:vuse##"
#grunt less:vuse
echo -e "\n##EXECUTING MAGENTO SETUP:STATIC-CONTENT:DEPLOY FOR Born/vuse##"
#php bin/magento setup:static-content:deploy --theme Born/vuse
echo -e "\n##ENABLING MAGENTO CACHE##"
#php bin/magento cache:enable
echo -e "\n##COMMANDS COMPLETED on HOST##"
