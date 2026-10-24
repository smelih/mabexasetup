sudo apt install git
git clone https://github.com/smelih/mabexasetup.git
sed -i 's/\r$//' mailcow_setup.sh
sudo ./mailcow_setup.sh
Mail server hostname (FQDN) : mail.sample.com.tr
Europe/Istanbul
1
