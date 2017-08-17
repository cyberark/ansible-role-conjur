FROM ubuntu:14.04

MAINTAINER Conjur Inc

RUN export DEBIAN_FRONTEND=noninteractive && \
		apt-get update && \
    apt-get install -y curl

RUN mkdir -p /conjurinc/ansible

WORKDIR /conjurinc/ansible

COPY . /conjurinc/ansible