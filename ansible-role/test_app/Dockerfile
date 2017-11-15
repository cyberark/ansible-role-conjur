FROM ubuntu:trusty

MAINTAINER Jason Vanderhoof <jason.vanderhoof@cyberark.com>

RUN apt-get update -y && apt-get install -y python
RUN apt-get update && apt-get install -y gcc build-essential software-properties-common python-software-properties python3-software-properties
RUN apt-add-repository -y ppa:brightbox/ruby-ng && apt-get update && apt-get install -y ruby2.4 ruby2.4-dev

RUN gem install conjur-cli

RUN mkdir -p /usr/local/lib/summon
COPY summon-conjur.sh /usr/local/lib/summon
COPY summon /usr/local/bin
