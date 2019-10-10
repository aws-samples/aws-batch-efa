# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

FROM amazonlinux:1
ENV USER efauser

RUN yum update -y 
RUN yum install -y which util-linux make tar.x86_64 iproute2 gcc-gfortran openssh-server openssh-client python27 python27-pip build-essential wget curl git wget pkg-config zip unzip libnl3-devel
RUN pip-2.7 install supervisor 

RUN useradd -ms /bin/bash $USER
ENV HOME /home/$USER

#####################################################
## SSH SETUP
ENV SSHDIR $HOME/.ssh
RUN mkdir -p ${SSHDIR} \
 && touch ${SSHDIR}/sshd_config \
 && ssh-keygen -t rsa -f ${SSHDIR}/ssh_host_rsa_key -N '' \
 && cp ${SSHDIR}/ssh_host_rsa_key.pub ${SSHDIR}/authorized_keys \
 && cp ${SSHDIR}/ssh_host_rsa_key ${SSHDIR}/id_rsa \
 && echo "    IdentityFile ${SSHDIR}/id_rsa" >> ${SSHDIR}/config \
 && echo "    StrictHostKeyChecking no" >> ${SSHDIR}/config \
 && echo "    UserKnownHostsFile /dev/null" >> ${SSHDIR}/config \
 && echo "    Port 2022" >> ${SSHDIR}/config \
 && echo 'Port 2022' >> ${SSHDIR}/sshd_config \
 && echo 'UsePrivilegeSeparation no' >> ${SSHDIR}/sshd_config \
 && echo "HostKey ${SSHDIR}/ssh_host_rsa_key" >> ${SSHDIR}/sshd_config \
 && echo "PidFile ${SSHDIR}/sshd.pid" >> ${SSHDIR}/sshd_config \
 && chmod -R 600 ${SSHDIR}/* \
 && chown -R ${USER}:${USER} ${SSHDIR}/

# check if ssh agent is running or not, if not, run
RUN eval `ssh-agent -s` && ssh-add ${SSHDIR}/id_rsa

#################################################
## EFA and MPI SETUP
RUN curl -O https://s3-us-west-2.amazonaws.com/aws-efa-installer/aws-efa-installer-1.5.0.tar.gz \
    && tar -xf aws-efa-installer-1.5.0.tar.gz \
    && cd aws-efa-installer \
    && ./efa_installer.sh -y --skip-kmod --skip-limit-conf --no-verify

RUN wget https://www.nas.nasa.gov/assets/npb/NPB3.3.1.tar.gz \ 
 && tar xzf NPB3.3.1.tar.gz
COPY make.def_efa /NPB3.3.1/NPB3.3-MPI/config/make.def
COPY suite.def    /NPB3.3.1/NPB3.3-MPI/config/suite.def

RUN cd /NPB3.3.1/NPB3.3-MPI \ 
  && make suite \
  && chmod -R 755 /NPB3.3.1/NPB3.3-MPI/

###################################################
## supervisor container startup

ADD conf/supervisord/supervisord.conf /etc/supervisor/supervisord.conf
ADD supervised-scripts/mpi-run.sh supervised-scripts/mpi-run.sh
RUN chmod 755 supervised-scripts/mpi-run.sh

EXPOSE 2022
ADD batch-runtime-scripts/entry-point.sh batch-runtime-scripts/entry-point.sh
RUN chmod 755 batch-runtime-scripts/entry-point.sh

CMD /batch-runtime-scripts/entry-point.sh
