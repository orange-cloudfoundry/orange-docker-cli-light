FROM ubuntu:16.04
USER root

#--- Update image and install tools packages
ARG DEBIAN_FRONTEND=noninteractive
ENV INIT_PACKAGES="ca-certificates apt-utils wget sudo" \
    TOOLS_PACKAGES="openssh-server openssl supervisor git-core s3cmd bash-completion curl unzip vim less mlocate nano silversearcher-ag colordiff" \
    NET_PACKAGES="net-tools iproute2 iputils-ping netcat dnsutils apt-transport-https tcpdump mtr-tiny" \
    DEV_PACKAGES="python-pip python-setuptools python-dev build-essential libxml2-dev libxslt1-dev libpq-dev libsqlite3-dev libmysqlclient-dev libssl-dev zlib1g-dev" 

RUN apt-get update && apt-get install -y --no-install-recommends ${INIT_PACKAGES} && \
    apt-get update && apt-get install -y --no-install-recommends ${TOOLS_PACKAGES} ${NET_PACKAGES} ${DEV_PACKAGES} && \
    apt-get upgrade -y && apt-get clean && apt-get autoremove -y && apt-get purge && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*


#--- Setup SSH access, secure root login (SSH login fix. Otherwise user is kicked off after login) and create user
ENV CONTAINER_LOGIN="bosh" CONTAINER_PASSWORD="welcome"
ADD scripts/supervisord scripts/check_ssh_security scripts/disable_ssh_password_auth /usr/local/bin/
ADD supervisord/sshd.conf /etc/supervisor/conf.d/
ADD scripts/homedir.sh /etc/profile.d/
RUN echo "root:`date +%s | sha256sum | base64 | head -c 32 ; echo`" | chpasswd && \
    sed -i 's/PermitRootLogin without-password/PermitRootLogin no/g' /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd /var/log/supervisor && \
    chmod 755 /usr/local/bin/supervisord /usr/local/bin/check_ssh_security /usr/local/bin/disable_ssh_password_auth /etc/profile.d/homedir.sh && \
    sed -i 's/.*\[supervisord\].*/&\nnodaemon=true\nloglevel=debug/' /etc/supervisor/supervisord.conf && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    useradd -m -g users -G sudo -s /bin/bash ${CONTAINER_LOGIN} && echo "${CONTAINER_LOGIN}:${CONTAINER_PASSWORD}" | chpasswd && \
    sed -i "s/<username>/${CONTAINER_LOGIN}/g" /usr/local/bin/supervisord && \
    sed -i "s/<username>/${CONTAINER_LOGIN}/g" /usr/local/bin/check_ssh_security && \
    sed -i "s/<username>/${CONTAINER_LOGIN}/g" /usr/local/bin/disable_ssh_password_auth && \
    echo "${CONTAINER_LOGIN} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${CONTAINER_LOGIN} && \
    chage -d 0 ${CONTAINER_LOGIN} && ln -s /tmp /home/${CONTAINER_LOGIN}/tmp && \
    chown -R ${CONTAINER_LOGIN}:users /home/${CONTAINER_LOGIN} && chmod 700 /home/${CONTAINER_LOGIN} && \
    mkdir -p /data && chown ${CONTAINER_LOGIN}:users /data && \
    rm -fr /tmp/*

#--- Launch supervisord daemon
EXPOSE 22
CMD /usr/local/bin/supervisord
