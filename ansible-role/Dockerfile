FROM ansible/ansible:ubuntu1604

RUN pip install testinfra ansible && mkdir -p /conjurinc/ansible-role-conjur/

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"
RUN apt-get update && apt-get -y install docker-ce

WORKDIR /conjurinc/ansible-role-conjur/
