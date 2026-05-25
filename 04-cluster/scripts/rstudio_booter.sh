#!/bin/bash
# rstudio_booter.sh — RStudio VMSS first-boot script
# Terraform vars: ${storage_account} ${vault_name} ${domain_fqdn} ${force_group}

set -euo pipefail

LOG=/root/rstudio_booter.log
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t rstudio-booter -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "NOTE: rstudio-booter start: $(date -Is)"

# -- Section 1: Mount NFS --

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

echo "NOTE: [nfs] creating /nfs/home and /nfs/data"
mkdir -p /nfs/home
mkdir -p /nfs/data
echo "${storage_account}.file.core.windows.net:/${storage_account}/nfs/home /home aznfs vers=4.1,defaults 0 0" | \
  sudo tee -a /etc/fstab > /dev/null
echo "NOTE: [nfs] fstab entry written for /home"
systemctl daemon-reload
echo "NOTE: [nfs] mounting /home"
mount /home
echo "NOTE: [nfs] /home mounted successfully"

# -- Section 2: Join Active Directory Domain --

echo "NOTE: [auth] logging in with managed identity"
for i in {1..20}; do
  az login --identity --allow-no-subscriptions && break
  echo "NOTE: [auth] managed identity not ready, attempt $i/10 — retrying in 15s"
  sleep 15
done
echo "NOTE: [auth] managed identity login complete"

echo "NOTE: [auth] fetching admin-ad-credentials from vault: ${vault_name}"
for i in {1..20}; do
  secretsJson=$(az keyvault secret show --name admin-ad-credentials --vault-name ${vault_name} --query value -o tsv 2>/dev/null) && break
  echo "NOTE: [auth] vault not ready, attempt $i/10 — retrying in 15s"
  sleep 15
done
echo "NOTE: [auth] secret fetched, extracting password"
admin_password=$(echo "$secretsJson" | jq -r '.password')
echo "NOTE: [auth] password length: $${#admin_password}"
admin_username="Admin"

echo "NOTE: [domain-join] domain: ${domain_fqdn}"
echo "NOTE: [domain-join] username: $admin_username"
echo "NOTE: [domain-join] running realm join"
echo -e "$admin_password" | sudo /usr/sbin/realm join -U "$admin_username" \
    ${domain_fqdn} --verbose
echo "NOTE: [domain-join] realm join complete"

# -- Section 3: Enable Password Authentication for AD Users --

echo "NOTE: [sshd] enabling PasswordAuthentication"
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
echo "NOTE: [sshd] done"

# -- Section 4: Configure SSSD for AD Integration --

echo "NOTE: [sssd] patching sssd.conf"
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf
sudo sed -i 's/^access_provider = ad$/access_provider = simple\nsimple_allow_groups = ${force_group}/' /etc/sssd/sssd.conf
echo "NOTE: [sssd] sssd.conf patched"

echo "NOTE: [sssd] configuring /etc/skel"
ln -s /nfs /etc/skel/nfs
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority
echo "NOTE: [sssd] /etc/skel configured"

echo "NOTE: [sssd] enabling mkhomedir"
sudo pam-auth-update --enable mkhomedir
echo "NOTE: [sssd] restarting ssh, sssd, rstudio-server"
sudo systemctl restart ssh
sudo systemctl restart sssd
sudo systemctl restart rstudio-server
sudo systemctl enable rstudio-server
echo "NOTE: [sssd] services restarted"

# -- Section 5: Grant Sudo Privileges to AD Admin Group --

echo "NOTE: [sudo] granting linux-admins passwordless sudo"
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-linux-admins
echo "NOTE: [sudo] done"

# -- Section 6: Enforce Home Directory Permissions --

echo "NOTE: [homedir] setting HOME_MODE to 0700 in login.defs"
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs
echo "NOTE: [homedir] done"

# -- Section 7: Configure R Library Paths --

echo "NOTE: [rlibs] writing Rprofile.site"
cat <<'EOF' | sudo tee /usr/lib/R/etc/Rprofile.site > /dev/null
local({
  userlib <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(userlib)) {
    dir.create(userlib, recursive = TRUE, showWarnings = FALSE)
  }
  nfs <- "/nfs/rlibs"
  .libPaths(c(userlib, nfs, .libPaths()))
})
EOF
echo "NOTE: [rlibs] setting rstudio-admins group on /nfs/rlibs"
chgrp rstudio-admins /nfs/rlibs
echo "NOTE: [rlibs] done"

echo "NOTE: rstudio-booter complete: $(date -Is)"
