#!/bin/bash
# custom_data.sh — NFS Gateway first-boot script
# Terraform vars: ${storage_account} ${vault_name} ${domain_fqdn} ${netbios} ${realm} ${force_group}

set -euo pipefail

LOG=/root/custom_data.log
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t custom-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "NOTE: custom-data start: $(date -Is)"

# -- Section 1: Update OS and Install Packages --

echo "NOTE: [packages] running apt-get update"
apt-get update -y
export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [packages] installing AD/NFS/Samba dependencies"
apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim nfs-common \
    winbind libpam-winbind libnss-winbind stunnel4
echo "NOTE: [packages] done"

# -- Section 2: Install Azure CLI --

echo "NOTE: [az-cli] adding Microsoft apt repo"
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [signed-by=/etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" \
    | tee /etc/apt/sources.list.d/azure-cli.list
apt-get update -y
echo "NOTE: [az-cli] installing azure-cli"
apt-get install -y azure-cli
echo "NOTE: [az-cli] done"

# -- Section 3: Install aznfs Helper --

echo "NOTE: [aznfs] adding Microsoft apt repo"
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes \
  -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/ubuntu/22.04/prod jammy main" \
  | sudo tee /etc/apt/sources.list.d/aznfs.list
echo "aznfs aznfs/enable_autoupdate boolean true" | sudo debconf-set-selections
apt-get update -y
echo "NOTE: [aznfs] installing aznfs"
apt-get install -y aznfs
echo "NOTE: [aznfs] done"

# -- Section 4: Mount NFS --

echo "NOTE: [nfs] storage account: ${storage_account}"
echo "NOTE: [nfs] creating /nfs mount point"
mkdir -p /nfs
echo "${storage_account}.file.core.windows.net:/${storage_account}/nfs /nfs aznfs vers=4.1,defaults 0 0" | \
  sudo tee -a /etc/fstab > /dev/null
echo "NOTE: [nfs] fstab entry written for /nfs"
systemctl daemon-reload
echo "NOTE: [nfs] mounting /nfs"
mount /nfs
echo "NOTE: [nfs] /nfs mounted successfully"

echo "NOTE: [nfs] creating /nfs/home, /nfs/data, /nfs/rlibs"
mkdir -p /nfs/home
mkdir -p /nfs/data
mkdir -p /nfs/rlibs

echo "NOTE: [nfs] symlinking /home -> /nfs/home"
mv /home /home.local
ln -s /nfs/home /home
echo "NOTE: [nfs] done"

# -- Section 5: Join Active Directory Domain --

echo "NOTE: [auth] logging in with managed identity"
for i in {1..10}; do
  az login --identity --allow-no-subscriptions && break
  echo "NOTE: [auth] managed identity not ready, attempt $i/10 — retrying in 15s"
  sleep 15
done
echo "NOTE: [auth] managed identity login complete"

echo "NOTE: [auth] fetching admin-ad-credentials from vault: ${vault_name}"
secretsJson=$(az keyvault secret show --name admin-ad-credentials --vault-name ${vault_name} --query value -o tsv)
echo "NOTE: [auth] secret fetched, extracting password"
admin_password=$(echo "$secretsJson" | jq -r '.password')
echo "NOTE: [auth] password length: ${#admin_password}"
admin_username="${netbios}\\Admin"

echo "NOTE: [domain-join] domain: ${domain_fqdn}"
echo "NOTE: [domain-join] username: $admin_username"
echo "NOTE: [domain-join] running realm join"
echo -e "$admin_password" | sudo /usr/sbin/realm join --membership-software=samba \
    -U "$admin_username" ${domain_fqdn} --verbose
echo "NOTE: [domain-join] realm join complete"

# -- Section 6: Configure SSSD --

echo "NOTE: [sssd] patching sssd.conf"
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf
echo "NOTE: [sssd] sssd.conf patched"

touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

echo "NOTE: [sssd] enabling mkhomedir and restarting services"
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd
sudo systemctl restart ssh
echo "NOTE: [sssd] done"

# -- Section 7: Configure Samba --

echo "NOTE: [samba] stopping sssd temporarily"
sudo systemctl stop sssd

echo "NOTE: [samba] writing smb.conf"
cat <<EOT > /tmp/smb.conf
[global]
workgroup = ${netbios}
security = ads

strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes

passdb backend = tdbsam

printing = cups
printcap name = cups
load printers = yes
cups options = raw

kerberos method = secrets and keytab

template homedir = /home/%U
template shell = /bin/bash
#netbios

create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${force_group}

realm = ${realm}

idmap config ${realm} : backend = sss
idmap config ${realm} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999

min domain uid = 0
winbind use default domain = yes
winbind normalize names = yes
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = yes
winbind enum users = yes
winbind cache time = 30
idmap cache time = 60

[homes]
comment = Home Directories
browseable = No
read only = No
inherit acls = Yes

[nfs]
comment = Mounted NFS area
path = /nfs
read only = no
guest ok = no
EOT

sudo cp /tmp/smb.conf /etc/samba/smb.conf
sudo rm /tmp/smb.conf

echo "NOTE: [samba] injecting NetBIOS hostname"
head /etc/hostname -c 15 > /tmp/netbios-name
value=$(</tmp/netbios-name)
export netbios="$${value^^}"
sudo sed -i "s/#netbios/netbios name=$netbios/g" /etc/samba/smb.conf

echo "NOTE: [samba] writing nsswitch.conf"
cat <<EOT > /tmp/nsswitch.conf
passwd:     files sss winbind
group:      files sss winbind
automount:  files sss winbind
shadow:     files sss winbind
hosts:      files dns myhostname
bootparams: nisplus [NOTFOUND=return] files
ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files sss
netgroup:   files sss
publickey:  nisplus
aliases:    files nisplus
EOT

sudo cp /tmp/nsswitch.conf /etc/nsswitch.conf
sudo rm /tmp/nsswitch.conf

echo "NOTE: [samba] restarting winbind, smb, nmb, sssd"
sudo systemctl restart winbind smb nmb sssd
echo "NOTE: [samba] done"

# -- Section 8: Grant Sudo to AD Admin Group --

echo "NOTE: [sudo] granting linux-admins passwordless sudo"
sudo echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/10-linux-admins
echo "NOTE: [sudo] done"

# -- Section 9: Permissions and Home Directories --

echo "NOTE: [homedir] setting HOME_MODE to 0700 in login.defs"
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

echo "NOTE: [homedir] creating /etc/skel/nfs symlink"
ln -s /nfs /etc/skel/nfs

echo "NOTE: [homedir] seeding home directories for test users"
su -c "exit" rpatel || true
su -c "exit" jsmith || true
su -c "exit" akumar || true
su -c "exit" edavis || true

echo "NOTE: [homedir] setting NFS directory ownership and permissions"
chgrp ${force_group} /nfs || true 
chgrp ${force_group} /nfs/data || true
chgrp ${force_group} /nfs/rlibs || true
chmod 2775 /nfs 
chmod 2775 /nfs/rlibs
chmod 2770 /nfs/data
chmod 700 /home/*

echo "NOTE: [homedir] cloning repo to /nfs"
cd /nfs
git clone https://github.com/mamonaco1973/azure-rstudio-cluster.git || true
chmod -R 775 azure-rstudio-cluster || true
chgrp -R rstudio-users azure-rstudio-cluster || true
chown -R ubuntu:ubuntu /home/ubuntu || true
echo "NOTE: [homedir] done"

echo "NOTE: custom-data complete: $(date -Is)"
