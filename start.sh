#!/bin/bash

USERNAME=${USERNAME:-test}
PASSWORD=${PASSWORD:-testpassord}
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
WEBDAV_PORT=${WEBDAV_PORT:-20836}
SHARE_DIR="/share_data"
WEBDAV_AUTH_FILE="/etc/nginx/webdav.htpasswd"
WEBDAV_TMP_DIR="/tmp/nginx-webdav"

case "${WEBDAV_PORT}" in
    ''|*[!0-9]*)
        echo "Invalid WEBDAV_PORT: ${WEBDAV_PORT}" >&2
        exit 1
        ;;
esac

if (( WEBDAV_PORT < 1 || WEBDAV_PORT > 65535 )); then
    echo "WEBDAV_PORT must be between 1 and 65535" >&2
    exit 1
fi

echo "Creating user: ${USERNAME} (UID=${USER_UID}, GID=${USER_GID})"

groupadd -g "${USER_GID}" "${USERNAME}" 2>/dev/null || true
useradd -u "${USER_UID}" -g "${USER_GID}" -d "/home/${USERNAME}" -m -s /bin/bash "${USERNAME}" 2>/dev/null || true
printf '%s:%s\n' "${USERNAME}" "${PASSWORD}" | chpasswd

printf '%s\n%s\n' "${PASSWORD}" "${PASSWORD}" | smbpasswd -a -s "${USERNAME}"

mkdir -p "${SHARE_DIR}"
chown "${USER_UID}:${USER_GID}" "${SHARE_DIR}"

sed "s/__USERNAME__/${USERNAME}/g" /etc/samba/smb.conf.template > /etc/samba/smb.conf

echo "${USERNAME}" > /etc/vsftpd.userlist
sed -i "s|local_root=.*|local_root=${SHARE_DIR}|" /etc/vsftpd/vsftpd.conf

htpasswd -bc "${WEBDAV_AUTH_FILE}" "${USERNAME}" "${PASSWORD}"
chown "${USER_UID}:${USER_GID}" "${WEBDAV_AUTH_FILE}"
chmod 0600 "${WEBDAV_AUTH_FILE}"

mkdir -p \
    "${WEBDAV_TMP_DIR}/client_body" \
    "${WEBDAV_TMP_DIR}/proxy" \
    "${WEBDAV_TMP_DIR}/fastcgi" \
    "${WEBDAV_TMP_DIR}/uwsgi" \
    "${WEBDAV_TMP_DIR}/scgi"
chown -R "${USER_UID}:${USER_GID}" "${WEBDAV_TMP_DIR}"
chmod 0700 "${WEBDAV_TMP_DIR}"

sed \
    -e "s/__USERNAME__/${USERNAME}/g" \
    -e "s/__WEBDAV_PORT__/${WEBDAV_PORT}/g" \
    /etc/nginx/webdav.conf.template > /etc/nginx/nginx.conf

mkdir -p /run/samba
mkdir -p /run/nginx

nginx -t

echo "Starting Samba..."
/usr/sbin/smbd --daemon --no-process-group
/usr/sbin/nmbd --daemon --no-process-group

echo "Starting vsftpd..."
/usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &

echo "Starting Nginx WebDAV..."
/usr/sbin/nginx -g 'daemon off;' &
NGINX_PID=$!
sleep 1
if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
    echo "Nginx WebDAV failed to start" >&2
    exit 1
fi

echo "All services started. User: ${USERNAME}, Share: ${SHARE_DIR}, WebDAV port: ${WEBDAV_PORT}"
tail -f /var/log/samba/log.smbd 2>/dev/null || tail -f /dev/null
