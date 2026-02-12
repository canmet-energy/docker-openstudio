#Set version of Ubuntu base image


ARG DOCKER_OPENSTUDIO_VERSION=3.11.0
FROM nrel/openstudio:$DOCKER_OPENSTUDIO_VERSION

ARG OPENSTUDIO_VERSION=3.11.0
ARG LOCAL_NRCAN=''
ENV OPENSTUDIO_VERSION=${OPENSTUDIO_VERSION}

LABEL author="Nicholas Long nicholas.long@nrel.gov"
# Set up Display Environment. This optionally allows X11 connections
# if DISPLAY is passed as an argument.
ARG DISPLAY=local

ENV DISPLAY=${DISPLAY}

#Colors for output to make docker echo commands a bit more readable. 
ARG YEL='\033[0;33m'
ARG NC='\033[0m'

# ENV variables ensured to be available during /bin/sh shell installation.
# A more permanant solution will be set in .bashrc below.
ENV RUBYLIB=/usr/local/openstudio-${OPENSTUDIO_VERSION}/Ruby

# Required Software and libraries.
# System Software
ARG SYSTEM_SOFTWARE=' \
	build-essential \ 
	ca-certificates \ 
	curl \ 
	gdebi-core \ 
	git \
	nano \ 
	wget '

RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y
RUN apt-get update -y

# Need to set timezone for libxml2-dev package installation
# Export timezone
ENV TZ=US/Eastern

# Place timezone data /etc/timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Add certificate files if on the NRCan network
# Note the asterisk wildcard which copies the file only if it exists
COPY cacert.pem* /usr/local/lib/ruby/3.2.0/rubygems/ssl_certs/index.rubygems.org/
COPY nrcan_azure_amazon.crt* /usr/local/share/ca-certificates
RUN if [ -n "$LOCAL_NRCAN" ] ; then \
		cp /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates_orig.crt \
		&& sudo update-ca-certificates; \
	fi

# Install Software and libraries, install ruby, install OpenStudio, 
# set environment varialble and aliases for ruby and Openstudio. Create 
# bashrc prompt customization for git for users, and clean apt-get software list. 
RUN echo "$YEL*****Installing Software and deps using apt-get*****$NC" \ 
&& apt-get update && apt-get install -y --no-install-recommends $SYSTEM_SOFTWARE \
&& echo  "$YEL******Customizing bash shell*****$NC"	\
&& touch /etc/user_config_bashrc && chmod 755 /etc/user_config_bashrc \
&& echo "$YEL******Set root env configuration by adding script to /root/.bashrc*****$NC" \
&& echo 'source /etc/user_config_bashrc' >> ~/.bashrc \
&& echo  "$YEL******Adding E+ to path*****$NC"	\
&& echo 'export PATH="/usr/EnergyPlus:$PATH"' >> /etc/user_config_bashrc \
&& echo  "$YEL******Adding OpenStudio libs to RUBYLIB*****$NC"	\
&& echo "export RUBYLIB=/usr/local/openstudio-$OPENSTUDIO_VERSION/Ruby:/usr/Ruby" >> /etc/user_config_bashrc \
&& echo "export ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}/EnergyPlus/energyplus" >> /etc/user_config_bashrc \
&& echo  "$YEL******Aliasing OpenStudioApp so it can run anywhere.*****$NC"	\
&& echo 'alias OpenStudioApp=/usr/local/bin/OpenStudioApp' >> /etc/user_config_bashrc \
&& echo  "$YEL******Adding Git colors to bash prompt*****$NC"	\
&& echo 'source /usr/lib/git-core/git-sh-prompt' >> /etc/user_config_bashrc \
&& echo 'red=$(tput setaf 1) && green=$(tput setaf 2) && yellow=$(tput setaf 3) &&  blue=$(tput setaf 4) && magenta=$(tput setaf 5) && reset=$(tput sgr0) && bold=$(tput bold)' >> /etc/user_config_bashrc \ 
&& echo PS1=\''\[$magenta\]\u\[$reset\]@\[$green\]\h\[$reset\]:\[$blue\]\w\[$reset\]\[$yellow\][$(__git_ps1 "%s")]\[$reset\]\$'\' >> /etc/user_config_bashrc \
&& echo "$YEL*****Installing nokogiri gems on root. Needs to be run under bash *****$NC" \
&& /bin/bash -c "source /etc/user_config_bashrc && gem install -N nokogiri -v 1.13.10" 
RUN echo "$YEL*****Setting gem folder to be accessible by users *****$NC" \
&& echo chmod -R 777 /usr/local/lib/ruby/gems \
&& echo "$YEL*****Adding regular user called osdev and add to sudo group*****$NC" \
&& useradd -m osdev && echo "osdev:osdev" | chpasswd \
&& adduser osdev sudo \
&& echo "$YEL*****Clean up apt*****$NC" \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
&& apt-get clean

#Install unzip
RUN apt update\
&& apt-get install unzip -y

#Install AWS tools
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
&& unzip awscliv2.zip \
&& ./aws/install

USER osdev
RUN echo "$YEL*****Set user osdev env configuration by adding script to /home/osdev/.bashrc*****$NC"
RUN echo 'source /etc/user_config_bashrc' >> ~/.bashrc
RUN echo "$YEL*****Keeping default user as root for now to ensure compatibility*****$NC"
USER root

# Mount and set cwd
VOLUME /var/simdata/openstudio
WORKDIR /var/simdata/openstudio
CMD [ "/bin/bash" ]

RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Delete certificate files if on the NRCan network
RUN if [ -n "$LOCAL_NRCAN" ] ; then \
		rm /usr/local/lib/ruby/3.2.0/rubygems/ssl_certs/index.rubygems.org/cacert.pem \
		&& cp /etc/ssl/certs/ca-certificates_orig.crt /etc/ssl/certs/ca-certificates.crt \
		&& rm /etc/ssl/certs/ca-certificates_orig.crt \
		&& rm /usr/local/share/ca-certificates/nrcan_azure_amazon.crt; \
	fi

# Update Environment
RUN apt-get update -y\
&& apt-get upgrade -y \
&& apt-get update -y\
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
&& apt-get clean
