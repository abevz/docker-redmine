service ssh start
sudo -HEu redmine ssh -o StrictHostKeyChecking=no -i ${REDMINE_INSTALL_DIR}/plugins/redmine_git_hosting/ssh_keys/redmine_gitolite_admin_id_rsa git@localhost info
