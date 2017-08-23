ansible-role-conjur
=========

This role configures a host with a Conjur identity. Based on that identity, secrets
can be retrieved securely.

Installation
------------

The Conjur role can be installed using the following:

```sh
$ ansible-galaxy install cyberark.conjur
```

Requirements
------------

A running Conjur service accessible from the host machine and target machine.

Role Variables
--------------
* conjur_identity:
  * `conjur_url`: URL of the running Conjur service
  * `account`: Conjur account name
  * `host_factory_token`: [Host Factory](https://developer.conjur.net/reference/services/host_factory/) token for layer enrollment
  * `host_name`: Name of the host being conjurized.
  * `ssl_certificate`: Public SSL certificate of Conjur endpoint
  * `validate_certs`: yes

* conjur_ssh:
  * `ssh_enabled`: Configure Conjur SSH management, default `false`


Sane defaults are set in [defaults/main.yml](defaults/main.yml).

Dependencies
------------

None

Example Playbook
----------------

Configuring a remote node with a Conjur identity:
```yml
- hosts: servers
  roles:
    - role: conjur_identity
      account: 'myorg',
      conjur_url: 'https://conjur.myorg.com/api',
      host_factory_token: "{{lookup('env', 'HFTOKEN')}}",
      host_name: "{{inventory_hostname}}"
```

Provide secret retrieval:
```yml
- hosts: webservers
  vars:
    super_secret_key: {{ lookup('conjur', 'path/to/secret') }}
    max_clients: 200
  remote_user: root
  tasks:
    ...
```

Provide secret (Summon style):
```yml
- hosts: webservers
  tasks:
    - name: ensure app Foo is running
      conjur_application:
        run:
          command: rails s
          args:
            chdir: /foo/app
        variables:
          - SECRET_KEY: /path/to/secret-key
          - SECRET_PASSWORD: /path/to/secret_password
```
The above example uses the variables defined in `variables` block to map environment
variables to Conjur variables. The above case would result in the following being
executed on the remote node:
```sh
$ cd /foo/app && SECRET_KEY=topsecretkey SECRET_PASSWORD=topsecretpassword rails s
```
The `run` block can take the input of any Ansible module. This provides a simple
mechanism for applying credentials to a process based on that machine's identity.


License
-------

MIT
