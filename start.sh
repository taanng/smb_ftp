#!/bin/bash

USERNAME=${USERNAME:-test}
PASSWORD=${PASSWORD:-testpassord}
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
SHARE_DIR="/share_data"

echo "Creating user: ${USERNAME} (UID=${USER_UID}, GID=${USER_GID})"

groupadd -g ${USER_GID} ${USERNAME} 2>/dev/null || true
useradd -u ${USER_UID} -g ${USER_GID} -d /home/${USERNAME} -m -s /bin/bash ${USERNAME} 2>/dev/null || true
echo "${USERNAME}:${PASSWORD}" | chpasswd

printf "${PASSWORD}\n${PASSWORD}\n" | smbpasswd -a -s ${USERNAME}

mkdir -p ${SHARE_DIR}
chown ${USERNAME}:${USERNAME} ${SHARE_DIR}

sed "s/__USERNAME__/${USERNAME}/g" /etc/samba/smb.conf.template > /etc/samba/smb.conf

echo "${USERNAME}" > /etc/vsftpd.userlist
sed -i "s|local_root=.*|local_root=${SHARE_DIR}|" /etc/vsftpd/vsftpd.conf

mkdir -p /run/samba

echo "Starting Samba..."
/usr/sbin/smbd --daemon --no-process-group
/usr/sbin/nmbd --daemon --no-process-group

echo "Starting vsftpd..."
/usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &

echo "All services started. User: ${USERNAME}, Share: ${SHARE_DIR}"
tail -f /var/log/samba/log.smbd 2>/dev/null || tail -f /dev/null
