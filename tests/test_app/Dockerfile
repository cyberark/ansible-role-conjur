FROM ubuntu:16.04

RUN apt-get update -y && apt-get install -y python
RUN apt-get update && apt-get install -y gcc build-essential
RUN apt-get install -y software-properties-common python-software-properties python3-software-properties
RUN add-apt-repository -y ppa:jonathonf/python-2.7 && apt-get update && apt-get install -y python2.7
RUN apt-add-repository -y ppa:brightbox/ruby-ng && apt-get update && apt-get install -y ruby2.4 ruby2.4-dev
RUN apt-get update && apt-get install -y sudo && rm -rf /var/lib/apt/lists/*

RUN gem install conjur-cli

RUN mkdir -p /usr/local/lib/summon
COPY summon-conjur.sh /usr/local/lib/summon
COPY summon /usr/local/bin
