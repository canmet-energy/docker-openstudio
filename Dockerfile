# Start creating the image with https://github.com/NREL/docker-openstudio/blob/380release/Dockerfile
# but with the specific version of 3.8.0

FROM ubuntu:20.04 AS base

MAINTAINER Nicholas Long nicholas.long@nrel.gov

# Set the version of OpenStudio when building the container. For example `docker build --build-arg
ARG OPENSTUDIO_VERSION=3.8.0
ARG OPENSTUDIO_VERSION_EXT=""
ARG OPENSTUDIO_DOWNLOAD_URL=http://openstudio-ci-builds.s3-website-us-west-2.amazonaws.com/PR-5217/OpenStudio-3.8.0%2B17d344f932-Ubuntu-20.04-x86_64.deb
ENV RC_RELEASE=TRUE
ENV OS_BUNDLER_VERSION=2.4.10
ENV RUBY_VERSION=3.2.2
ENV BUNDLE_WITHOUT=native_ext
# Install gdebi, then download and install OpenStudio, then clean up.
# gdebi handles the installation of OpenStudio's dependencies

# install locales and set to en_US.UTF-8. This is needed for running the CLI on some machines
# such as singularity.
RUN apt-get update && apt-get install -y \
        curl \
        gdebi-core \
        libsqlite3-dev \
        libssl-dev \ 
        libffi-dev \ 
        build-essential \
        zlib1g-dev \
        vim \ 
        git \
        locales \
        sudo \
    && echo "OpenStudio Package Download URL is ${OPENSTUDIO_DOWNLOAD_URL}" \
    && curl -SLO $OPENSTUDIO_DOWNLOAD_URL \
    && OPENSTUDIO_DOWNLOAD_FILENAME=$(ls *.deb) \
    # Verify that the download was successful (not access denied XML from s3)
    && grep -v -q "<Code>AccessDenied</Code>" ${OPENSTUDIO_DOWNLOAD_FILENAME} \
    && gdebi -n $OPENSTUDIO_DOWNLOAD_FILENAME \
    # Cleanup
    && rm -f $OPENSTUDIO_DOWNLOAD_FILENAME \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US en_US.UTF-8 \
    && dpkg-reconfigure locales

RUN apt update && apt install -y libyaml-dev ruby-full 
# RUN apt-get install ca-certificates 
RUN pwd
RUN curl -SLO -k https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.2.tar.gz \
    && tar -xvzf ruby-3.2.2.tar.gz \
    && cd ruby-3.2.2 \
    && ./configure \
    && make && make install 

RUN rm -rf ruby*
## Add RUBYLIB link for openstudio.rb
ENV RUBYLIB=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby
ENV ENERGYPLUS_EXE_PATH=/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/EnergyPlus/energyplus

# The OpenStudio Gemfile contains a fixed bundler version, so you have to install and run specific to that version
RUN gem install bundler -v $OS_BUNDLER_VERSION && \
    mkdir /var/oscli && \
    ls /usr/local && \
    cp /usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby/Gemfile /var/oscli/ && \
    cp /usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby/Gemfile.lock /var/oscli/ && \
    cp /usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby/openstudio-gems.gemspec /var/oscli/
WORKDIR /var/oscli
RUN bundle -v
RUN bundle _${OS_BUNDLER_VERSION}_ install --path=gems --without=native_ext --jobs=4 --retry=3

# Configure the bootdir & confirm that openstudio is able to load the bundled gem set in /var/gemdata
VOLUME /var/simdata/openstudio
WORKDIR /var/simdata/openstudio
RUN openstudio --loglevel Trace --bundle /var/oscli/Gemfile --bundle_path /var/oscli/gems --bundle_without native_ext  openstudio_version

# May need this for syscalls that do not have ext in path
RUN ln -s /usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT} /usr/local/openstudio-${OPENSTUDIO_VERSION}

ARG OPENSTUDIO_VERSION=3.8.0
ENV OPENSTUDIO_VERSION ${OPENSTUDIO_VERSION}

# Set up Display Environment. This optionally allows X11 connections
# if DISPLAY is passed as an argument.
ARG DISPLAY=local

ENV DISPLAY ${DISPLAY}

#Colors for output to make docker echo commands a bit more readable. 
ARG YEL='\033[0;33m'
ARG NC='\033[0m'

# ENV variables ensured to be available during /bin/sh shell installation.
# A more permanant solution will be set in .bashrc below.
ENV RUBYLIB /usr/local/openstudio-${OPENSTUDIO_VERSION}/Ruby

#Required Software and libraries.
## System Software
ARG SYSTEM_SOFTWARE=' \
	build-essential \ 
	ca-certificates \ 
	curl \ 
	gdebi-core \ 
	git \
	nano \ 
	wget '
	
## OpenStudio Dependant Libraries for Ubuntu 14.04 that gdebi does not satisfy
## in installation below.					
ARG OPENSTUDIOAPP_DEPS=' \
	libasound2	\
	libdbus-glib-1-2 \ 
	libfontconfig1 \
	libfreetype6 \ 
	libglu1 \ 
	libjpeg8 \
	libnss3 \
	libreadline-dev \ 
	libsm6 \
	libssl-dev \
	libxcomposite1 \
	libxcursor1 \ 
	libxi6 \
	libxml2-dev \ 
	libxtst6 \
	zlib1g-dev \ 
	libtool \ 
	autoconf'

#Remove Ruby installation files. Notice that the parent image nrel/openstudio:3.6.0 did not remove the files after the make install was completed. This triggered trivy security issue even if it would never be executed. 
RUN rm /ruby-2.7.2/ -fr 
RUN rm /OpenStudio-3.7.0+d5269793f1-Ubuntu-20.04-x86_64.deb -fr
RUN rm /ruby-2.7.2.tar.gz -fr

RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y
RUN apt-get update -y

# Need to set timezone for libxml2-dev package installation
# Export timezone
ENV TZ=US/Eastern

# Place timezone data /etc/timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#Install Software and libraries, install ruby, install OpenStudio, 
# set environment varialble and aliases for ruby and Openstudio. Create 
# bashrc prompt customization for git for users, and clean apt-get software list. 
RUN echo "$YEL*****Installing Software and deps using apt-get*****$NC" \ 
&& apt-get update && apt-get install -y --no-install-recommends \ 
	$SYSTEM_SOFTWARE \
	$OPENSTUDIOAPP_DEPS \
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

#Install Python
RUN apt update \
&& apt install software-properties-common -y \
&& add-apt-repository ppa:deadsnakes/ppa -y \
&& apt update \
&& apt install python3-pip -y \
&& apt update -y \
&& apt upgrade -y \
&& python3 -m pip install boto3 sqlalchemy sqlalchemy_utils sqlalchemy-aurora-data-api sqlalchemy-pagination

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

# Update Environment
RUN apt-get update -y\
&& apt-get upgrade -y \
&& apt-get update -y\
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
&& apt-get clean
