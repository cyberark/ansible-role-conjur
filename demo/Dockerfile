FROM ansible/ansible:ubuntu1604

MAINTAINER Conjur Inc

RUN export DEBIAN_FRONTEND=noninteractive && \
apt-get update && \
apt-get install -y curl && \
pip install --upgrade pip && \
pip install ansible

RUN mkdir -p /conjurinc/ansible

WORKDIR /conjurinc/ansible

COPY . /conjurinc/ansible