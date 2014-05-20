#! /bin/bash
if [ "$(id -u)" != "0" ]; then
	echo "Listen, Pal! Once doesn't simply walk in and set up a server. You gotta know your roots. Try using sudo."
	exit
fi

# add a sources file to /etc/apt/sources.list.d/ (http://www.webmin.com/deb.html)
echo -e "deb http://download.webmin.com/download/repository sarge contrib\ndeb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib\n" >/tmp/webmin.list
cp /tmp/webmin.list /etc/apt/sources.list.d/
rm /tmp/webmin.list

# add the apt-get key as well
wget -O /tmp/jcameron-key.asc http://www.webmin.com/jcameron-key.asc
apt-key add /tmp/jcameron-key.asc
rm /tmp/jcameron-key.asc

# run apt-get update and upgrade
apt-get update
apt-get -y upgrade

# install webmin
apt-get -y install webmin

# add dotdeb php5 packages
echo -e "deb http://packages.dotdeb.org squeeze all\ndeb-src http://packages.dotdeb.org squeeze all\n" > /tmp/dotdeb.list
cp /tmp/dotdeb.list /etc/apt/sources.list.d/
rm /tmp/dotdeb.list

#add apt-get key for dotdeb
wget -O /tmp/dotdeb.gpg http://www.dotdeb.org/dotdeb.gpg
cat /tmp/dotdeb.gpg | apt-key add -

# install relevant servers and programs
apt-get -y install apache2 php5 php5-cgi php-pear php5-gd php5-curl php5-fpm libapache2-mod-fastcgi mysql-server mysql-client postfix proftpd alpine git mercurial unzip

# setup PEAR Mail for older sites
pear install mail
pear install Net_SMTP
pear install Auth_SASL
pear install mail_mime

# make sure we have mysql driver loaded for php5
apt-get -y install php5-mysql

# create and edit a conf for php5-fpm
echo -e "<IfModule mod_fastcgi.c> \n AddHandler php5-fcgi .php \n Action php5-fcgi /php5-fcgi \n Alias /php5-fcgi /usr/lib/cgi-bin/php5-fcgi \nFastCgiExternalServer /usr/lib/cgi-bin/php5-fcgi -socket /var/run/php5-fpm.sock -pass-header Authorization \n </IfModule> \n" > /tmp/php5-fpm.conf
cp /tmp/php5-fpm.conf /etc/apache2/conf-available/
rm /tmp/php5-fpm.conf


# enable new mods and config 
a2enmod actions fastcgi alias rewrite
a2enconf php5-fpm

# Restart apache
service apache2 restart

# leave a friendly reminder to create a user and prevent root from SSH access
echo -e "\n#####################################\n\nThat should get you started. I recommend that you create a user a user and disable root access via ssh.\n"

AGAIN=true
ARTICLE='an'
ADMINCOUNT=0

while $AGAIN; do
	read -p "Would you like to create $ARTICLE user? [y/N] " REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		
		read -p "Wonderful. Let me have the username for this user? " USER
		adduser $USER

		ASADMIN=''
		read -p "Is this user an admin? [y/N] " ADMINUSER
		if [[ $ADMINUSER =~ ^[Yy]$ ]]; then
			usermod -a -G sudo $USER
			ASADMIN=' as an admin'
			ADMINCOUNT=`expr $ADMINCOUNT + 1`
		fi
		
		echo "User $USER has been added to the system$ASADMIN."
		ARTICLE='another'

	else
		echo "OK...Sure. Have it your way. I didn't really want to do it anyway."	
		AGAIN=false
	fi
	
done

if [[ ADMINCOUNT > 0 ]]; then
	
	echo -e "It appears you created $ADMINCOUNT user(s). Since you have done this, it is advised that you disable root access to the SSH server\n#### WARNING ####\nIf you do this, make sure that you have an admin user setup with sudo access."
	read -p "Would you like to disable root access now? [y/N] " DISABLEROOT
	if [[ $DISABLEROOT =~ ^[yY]$ ]]; then
		echo -e "OK. I can open the file for you, but you'll have to edit it - I'm not going to do all the work for you. In order to do this find the line option \nPermitRootLogin\nuncomment it if commented out and set it's value to 'no'."
		read -p "Press the enter key when ready."

		# open the editor
		vim /etc/ssh/sshd_config < `tty` > `tty`

		# restart the service. Strangely this doesn't break the current ssh connection
		echo -e "\nOK. I hope you didn't screw it up. Restarting the SSH server"
		service ssh restart

		echo -e "\n"

	fi
	
fi

echo -e "Good going buddy. We're all done here. It's very likely you will need to restart the server. Now is an opportune time.\nShould you choose to. Simply type: reboot\nAfter that you'll want to log into webmin (https://<ip_address>:10000/) and lock down the firewall.\nEnjoy!"
