#!/bin/bash

###################################################################################################
# Check if run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

###################################################################################################
# Config
os_code=$(lsb_release -cs)
total_ram=$(( $(free | awk '/^Mem:/{print $2}') / 1024 ))

public_ip="$(dig +short myip.opendns.com @resolver1.opendns.com)"

# For php
php_avg_ram=96
pm_max_child=$(( $total_ram * 3 / 4 / $php_avg_ram ))

pm_min_spare=1
pm_max_spare=3
pm_start=2

if [ $pm_max_child > 5 ]; then
	pm_min_spare=$(( $pm_max_child / 5 ))
	pm_max_spare=$(( $pm_max_child / 2 ))
	pm_start=$(( $pm_min_spare + ( ( $pm_max_spare - $pm_min_spare ) / 2 ) ))
fi


ubuntu_user='ubuntu'
phpversion='8.0'
nodeversion='14'
database='mariadb'
db_password='1q2w3e4r5t@X'
phpmyadmin='y'
pma_auth_acc=$ubuntu_user
pma_auth_pass='1q2w3e4r5t@X'
pma_folder=$( date +%s | openssl enc -base64 | sed 's/[^a-zA-Z0-9]//g' )
redis='y'
certbot='y'
supervisor='y'

echo -e "\n---------------------------------------------------------------------------------------"
echo "WHAT SHOULD BE INSTALLED?"


read -r -p "What is ubuntu account name? [$ubuntu_user]: " response
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	ubuntu_user=$response
fi

read -r -p "Which PHP version do you want to install? [7.0, 7.1, 7.2, 7.3, 7.4, 8.0] [default: $phpversion] " response
response=${response,,}
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	phpversion=$response
fi

read -r -p "Which database do you want to install? [mariadb, mysql, no] [default: $database]: " response
response=${response,,}
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	database=$response
fi

if [ "$database" != "no" ] && [ "$database" != "n" ]; then
	read -r -p "Database password: [$db_password]: " response
	if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
		db_password=$response
	fi


	read -r -p "Do you want to install phpmyadmin: [y, n] [default: $phpmyadmin]" response
	response=${response,,}
	if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
		phpmyadmin=$response
	fi

	if [ $phpmyadmin == 'y' ]; then
		pma_auth_acc=$ubuntu_user
		read -r -p "What is account for phpmyadmin basic authentication? [$pma_auth_acc]: " response
		if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
			pma_auth_acc=$response
		fi

		read -r -p "What is password for phpmyadmin basic authentication? [$pma_auth_pass]: " response
		if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
			pma_auth_pass=$response
		fi

		read -r -p "What is name of folder for phpmyadmin? (http://$public_ip/folder_name/phpmyadmin) [$pma_folder]: " response
		if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
			pma_folder=$response
		fi
	fi
else
	phpmyadmin='n'
fi

read -r -p "Do you want to install redis database? [y/n] [default $redis] " response
response=${response,,}
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	redis=$response
fi

read -r -p "Do you want to install certbot? [y/n] [default $certbot] " response
response=${response,,}
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	certbot=$response
fi

read -r -p "Do you want to install supervisor? [y/n] [default $certbot] " response
response=${response,,}
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	supervisor=$response
fi

read -r -p "Which nodejs do you want to install? [14, 16, no] [default: $nodeversion]: " response
response=${response,,}
if [ "$response" != "" ] && [ ${#response} -ne 0 ]; then
	nodeversion=$response
fi

echo -e "\n---------------------------------------------------------------------------------------"
echo "UPDATE & UPGRADE"

apt -y update
# apt -y upgrade

echo -e "\n---------------------------------------------------------------------------------------"
echo "UTILITIES"
apt-get -y install expect sed git zip




echo -e "\n---------------------------------------------------------------------------------------"
echo "MYSQL"

if [ "$database" != "no" ] && [ "$database" != "n" ]; then

	if [ "$database" == "mysql" ]; then
		apt-get -y install mysql-server mysql-client

		secure_mysql=$(expect -c "
set timeout 5
spawn mysql_secure_installation

expect -exact \"Press y|Y for Yes, any other key for No: \"
send \"y\r\"

expect -exact \"Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG: \"
send \"1\r\"

expect -exact \"New password: \"
send \"$db_password\r\"

expect -exact \"Re-enter new password: \"
send \"$db_password\r\"

expect -exact \"Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) : \"
send \"y\r\"

expect -exact \"Remove anonymous users? (Press y|Y for Yes, any other key for No) : \"
send \"y\r\"

expect -exact \"Disallow root login remotely? (Press y|Y for Yes, any other key for No) : \"
send \"y\r\"

expect -exact \"Remove test database and access to it? (Press y|Y for Yes, any other key for No) : \"
send \"y\r\"

expect -exact \"Reload privilege tables now? (Press y|Y for Yes, any other key for No) : \"
send \"y\r\"

expect eof
")

		echo "${secure_mysql}"

		mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_password';FLUSH PRIVILEGES;"


	else
		apt-get install -y mariadb-server

		apt-get install -y mariadb-client

		secure_mysql=$(expect -c "
set timeout 5
spawn mysql_secure_installation

expect -exact \"Enter current password for root (enter for none): \"
send \"$db_password\r\"

expect -exact \"Change the root password? \[Y/n] \"
send \"n\r\"

expect -exact \"Remove anonymous users? \[Y/n] \"
send \"Y\r\"

expect -exact \"Disallow root login remotely? \[Y/n] \"
send \"Y\r\"

expect -exact \"Remove test database and access to it? \[Y/n] \"
send \"Y\r\"

expect -exact \"Reload privilege tables now? \[Y/n] \"
send \"y\r\"

expect eof
")

		echo "${secure_mysql}"

		mysql -e "GRANT ALL PRIVILEGES on *.* to 'root'@'localhost' IDENTIFIED BY '$db_password';FLUSH PRIVILEGES;"

	fi

	# Enable remote access
	sed -i 's/^bind-address/#bind-address/g' /etc/mysql/my.cnf

	service mysql restart
fi



echo -e "\n---------------------------------------------------------------------------------------"
echo "NGINX & PHP"

add-apt-repository -y ppa:ondrej/php
apt -y update

#nginx
apt-get -y install nginx

if [ $phpversion = "7.3" ]; then
    sudo apt-get -y install nginx php7.3 php7.3-mysql php7.3-fpm php7.3-mbstring php7.3-xml php7.3-curl php7.3-zip  php7.3-gmp php7.3-intl php7.3-cli php7.3-xmlrpc php7.3-gd php7.3-imagick php7.3-recode php7.3-tidy php7.3-imap
    sudo apt-get -y install libmcrypt-dev
    sudo pecl install mcrypt-1.0.2
else
    if [ $phpversion = "7.2" ]; then
        apt-get -y install nginx php7.2 php7.2-mysql php7.2-fpm php7.2-mbstring php7.2-xml php7.2-curl php7.2-zip php7.2-gd php7.2-gmp php7.2-intl  php7.2-cli php7.2-xmlrpc php7.2-gd php7.2-imagick php7.2-recode php7.2-tidy php7.2-imap
        update-alternatives --set php /usr/bin/php7.2
        sudo apt-get -y install gcc make autoconf libc-dev pkg-config
        sudo apt-get -y install php7.2-dev
        sudo apt-get -y install libmcrypt-dev
        sudo pecl install mcrypt-1.0.1 <<<''
    else
        if [ $phpversion = "7.1" ]; then
    	      apt-get -y install php7.1 php7.1-mysql php7.1-fpm php7.1-mbstring php7.1-xml php7.1-curl php7.1-zip php7.1-gd php7.1-gmp php7.1-intl php7.1-bcmath php7.1-mcrypt
    	      update-alternatives --set php /usr/bin/php7.1
        else
            if [ $phpversion = "7.4" ]; then
    	        apt-get -y install nginx php7.4 php7.4-mysql php7.4-fpm php7.4-mbstring php7.4-xml php7.4-curl php7.4-zip php7.4-gd  php7.4-bcmath php7.4-intl php7.4-cli php7.4-xmlrpc  php7.4-imagick php7.4-common php7.4-dev php7.4-imap php7.4-opcache php7.4-soap  unzip php7.4-gmp
    	      	update-alternatives --set php /usr/bin/php7.4
	    else
		if [ $phpversion = "8.0" ]; then
    	            apt-get -y install nginx php8.0 php8.0-mysql php8.0-fpm php8.0-mbstring php8.0-xml php8.0-curl php8.0-zip php8.0-gd  php8.0-bcmath php8.0-intl php8.0-cli php8.0-xmlrpc  php8.0-imagick php8.0-common php8.0-dev php8.0-imap php8.0-opcache php8.0-soap  unzip php8.0-gmp
    	      	    update-alternatives --set php /usr/bin/php8.0
	        else    
	            apt-get -y install nginx php7.0 php7.0-mysql php7.0-fpm php7.0-mbstring php7.0-xml php7.0-curl php7.0-mcrypt php7.0-zip php7.0-gd php7.0-bcmath php7.0-gmp
	            update-alternatives --set php /usr/bin/php7.0
		fi
	    fi
        fi
    fi
fi


sed -i 's/^upload_max_filesize.*$/upload_max_filesize = 32M/g' /etc/php/$phpversion/fpm/php.ini
sed -i 's/^post_max_size.*$/post_max_size = 36M/g' /etc/php/$phpversion/fpm/php.ini
sed -i 's/^memory_limit.*$/memory_limit = 256M/g' /etc/php/$phpversion/fpm/php.ini
sed -i 's/^max_execution_time.*$/max_execution_time = 120/g' /etc/php/$phpversion/fpm/php.ini

sed -i "s/^pm.max_children.*$/pm.max_children = $pm_max_child/g" /etc/php/$phpversion/fpm/pool.d/www.conf
sed -i "s/^pm.start_servers.*$/pm.start_servers = $pm_start/g" /etc/php/$phpversion/fpm/pool.d/www.conf
sed -i "s/^pm.min_spare_servers.*$/pm.min_spare_servers = $pm_min_spare/g" /etc/php/$phpversion/fpm/pool.d/www.conf
sed -i "s/^pm.max_spare_servers.*$/pm.max_spare_servers = $pm_max_spare/g" /etc/php/$phpversion/fpm/pool.d/www.conf

sed -i 's/client_max_body_size.*$//g' /etc/nginx/nginx.conf
sed -i 's/fastcgi_read_timeout.*$//g' /etc/nginx/nginx.conf
sed -i 's/^http {.*$/http {\n\tclient_max_body_size 36M;\n\tfastcgi_read_timeout 120;/g' /etc/nginx/nginx.conf

service php$phpversion-fpm restart
service nginx restart



echo -e "\n---------------------------------------------------------------------------------------"
echo "phpMyAdmin"

nginx_pma=''
if [ $phpmyadmin == 'y' ]; then
	export DEBIAN_FRONTEND=noninteractive
		debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
		debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $db_password"
		debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $db_password"
		debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $db_password"
		debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none"
	apt-get install -y phpmyadmin

	mkdir -p /var/www/html/$pma_folder
	ln -s /usr/share/phpmyadmin /var/www/html/$pma_folder

	pass=$(echo "$pma_auth_pass" | openssl passwd -1 -stdin)
	tee /etc/nginx/auth_pass > /dev/null <<EOF
$pma_auth_acc:$pass
EOF

	nginx_pma=$( cat <<EOF
        location /$pma_folder/phpmyadmin {
                auth_basic "Admin Login";
                auth_basic_user_file /etc/nginx/auth_pass;
        }
EOF
)

	if [ $database == "mariadb" ]; then
		mysql -u root -p"$db_password" < /usr/share/phpmyadmin/sql/create_tables.sql
		mysql -u root -p"$db_password" -e "CREATE USER 'phpmyadmin'@'localhost' IDENTIFIED BY '$db_password';GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin'@'localhost'; FLUSH PRIVILEGES;"
	fi

fi

echo -e "\n---------------------------------------------------------------------------------------"
echo "CONFIG WEB SERVER"

mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default_backup

tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /var/www/html;

        index index.php index.html index.htm index.nginx-debian.html;

        server_name _;

        location / {
                try_files \$uri \$uri/ /index.php?\$query_string;
        }

$nginx_pma

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php$phpversion-fpm.sock;
        }

        location ~ /\.ht {
                deny all;
        }
}
EOF

adduser $ubuntu_user www-data
chown -R www-data:www-data /var/www
chmod -R g+rw /var/www

service nginx restart

echo -e "\n---------------------------------------------------------------------------------------"
echo "COMPOSER"
cd ~
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/bin/composer
sudo chmod +x /usr/bin/composer
# apt-get -y install composer


echo -e "\n---------------------------------------------------------------------------------------"
echo "REDIS"

if [ $redis == 'y' ]; then
	apt-get install -y build-essential tcl
	cd /tmp
	curl -O http://download.redis.io/redis-stable.tar.gz
	tar xzvf redis-stable.tar.gz
	cd redis-stable
	make
	make install

	mkdir /etc/redis
	cp /tmp/redis-stable/redis.conf /etc/redis
	sed -i "s/^supervised.*$/supervised systemd/g" /etc/redis/redis.conf
	sed -i "s/^dir .*$/dir \/var\/lib\/redis/g" /etc/redis/redis.conf

	tee /etc/systemd/system/redis.service > /dev/null <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF

	adduser --system --group --no-create-home redis
	mkdir /var/lib/redis
	chown redis:redis /var/lib/redis
	chmod 770 /var/lib/redis

	systemctl enable redis
	service redis restart
fi


echo -e "\n---------------------------------------------------------------------------------------"
echo "Certbot"
if [ $redis == 'y' ]; then
	snap install core; snap refresh core
	snap install --classic certbot
	ln -s /snap/bin/certbot /usr/bin/certbot
fi


echo -e "\n---------------------------------------------------------------------------------------"
echo "Supervisor"

if [ $supervisor == 'y' ]; then
	apt-get install -y supervisor
fi


echo -e "\n---------------------------------------------------------------------------------------"
echo "NodeJS"
if [ $nodeversion == '14' ]; then
	curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
	apt-get install -y nodejs
	curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
	echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
	apt-get update && apt-get install yarn
	
fi

if [ $nodeversion == '16' ]; then
	curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
	apt-get install -y nodejs
	curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
	echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
	apt-get update && apt-get install yarn
fi

