FROM alpine:latest

RUN apk update && \
    apk add --no-cache \
    samba \
    samba-common-tools \
    vsftpd \
    bash \
    shadow

COPY smb.conf /etc/samba/smb.conf.template
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY vsftpd.pam /etc/pam.d/vsftpd
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 21 139 445 40000-40100

CMD ["/start.sh"]
