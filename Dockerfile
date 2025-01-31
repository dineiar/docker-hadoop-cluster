# ██████╗  ██████╗ █████╗
# ██╔══██╗██╔════╝██╔══██╗
# ██║  ██║██║     ███████║
# ██║  ██║██║     ██╔══██║
# ██████╔╝╚██████╗██║  ██║
# ╚═════╝  ╚═════╝╚═╝  ╚═╝
# DEPARTAMENTO DE ENGENHARIA DE COMPUTACAO E AUTOMACAO
# UNIVERSIDADE FEDERAL DO RIO GRANDE DO NORTE, NATAL/RN
#
# (C) 2023 CARLOS M D VIEGAS
#
# This Dockerfile creates an image of Apache Hadoop 3.3.5 and Apache Spark 3.3.2
#

# Import base image
FROM ubuntu:22.04

# Update system and install required packages (silently)
#RUN sed -i -e 's/http:\/\/archive\.ubuntu\.com\/ubuntu\//mirror:\/\/mirrors\.ubuntu\.com\/mirrors\.txt/' /etc/apt/sources.list
RUN sed --in-place --regexp-extended "s/(\/\/)(archive\.ubuntu)/\1br.\2/" /etc/apt/sources.list
RUN apt-get update && apt-get install -y sudo ssh vim nano openjdk-11-jdk-headless python3.9 net-tools iputils-ping dos2unix

# Create symbolic link to make 'python' be recognized as a system command
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Get username and password from build arguments
ARG USER
ARG PASS
ENV USERNAME "${USER}"
ENV PASSWORD "${PASS}"

# Creates spark user, add to sudoers 
RUN adduser --disabled-password --gecos "" ${USERNAME}
RUN echo "${USERNAME}:${PASSWORD}" | chpasswd
RUN usermod -aG sudo ${USERNAME}
USER ${USERNAME}

# Set working dir
ENV MYDIR /home/${USERNAME}
WORKDIR ${MYDIR}

# Configure Hadoop enviroment variables
ENV HADOOP_HOME "${MYDIR}/hadoop"
ENV HADOOP_CONF_DIR "${HADOOP_HOME}/etc/hadoop"
ENV SPARK_HOME "${HADOOP_HOME}/spark"

# Copy all files from local folder to container, except the ones in .dockerignore
COPY . .

# Set permissions
RUN echo "${PASSWORD}" | sudo -S chown "${USERNAME}:${USERNAME}" -R ${MYDIR}

# Extract Hadoop to container filesystem
# Download Hadoop 3.3.5 from Apache servers (if needed)
ENV FILENAME hadoop-3.3.5.tar.gz
RUN if [ ! -e $FILENAME ]; then wget --no-check-certificate https://dlcdn.apache.org/hadoop/common/$(echo "$FILENAME" | sed "s/\.tar\.gz$//")/$FILENAME; fi
RUN tar -zxf $FILENAME -C ${MYDIR} && rm -rf $FILENAME
RUN ln -sf hadoop-3* hadoop

# Extract Spark to container filesystem
# Download Spark 3.3.2 from Apache server (if needed)
ENV FILENAME spark-3.3.2-bin-hadoop3.tgz
RUN if [ ! -e $FILENAME ]; then wget --no-check-certificate https://dlcdn.apache.org/spark/$(echo "$FILENAME" | sed -E 's/^spark-([0-9]+\.[0-9]+\.[0-9]+).*/spark-\1/')/$FILENAME; fi
RUN tar -zxf $FILENAME -C ${HADOOP_HOME} && rm -rf $FILENAME
RUN ln -sf ${HADOOP_HOME}/spark-3*-bin-hadoop3 ${SPARK_HOME}

# Optional (convert charset from UTF-16 to UTF-8)
RUN dos2unix config_files/*

# Load environment variables into .bashrc file
RUN cat config_files/bashrc >> .bashrc
RUN echo "export HDFS_NAMENODE_USER=\"$USERNAME\"" >> .bashrc

# Copy config files to Hadoop config folder
RUN cp config_files/core-site.xml ${HADOOP_CONF_DIR}/
RUN cp config_files/hadoop-env.sh ${HADOOP_CONF_DIR}/
RUN cp config_files/hdfs-site.xml ${HADOOP_CONF_DIR}/
RUN cp config_files/mapred-site.xml ${HADOOP_CONF_DIR}/
RUN cp config_files/workers ${HADOOP_CONF_DIR}/
RUN cp config_files/yarn-site.xml ${HADOOP_CONF_DIR}/
RUN chmod 0755 ${HADOOP_CONF_DIR}/*.sh

# Copy config files to Spark config folder
RUN cp config_files/spark-defaults.conf ${SPARK_HOME}/conf
RUN cp config_files/spark-env.sh ${SPARK_HOME}/conf
RUN chmod 0755 ${SPARK_HOME}/conf/*.sh

# Configure ssh for passwordless access
RUN mkdir -p ./.ssh && cat config_files/ssh_config >> .ssh/config && chmod 0600 .ssh/config
RUN ssh-keygen -q -N "" -t rsa -f .ssh/id_rsa
RUN cp .ssh/id_rsa.pub .ssh/authorized_keys && chmod 0600 .ssh/authorized_keys

# Run 'bootstrap.sh' script on boot
RUN chmod 0700 bootstrap.sh
CMD ${MYDIR}/bootstrap.sh ${USERNAME} ${PASSWORD}
