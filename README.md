Conjur Role
=========

This role configures a host with a Conjur identity. Based on that identity, secrets
can be retrieved securely.


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
    super_secret_key: {{ lookup('conjur', 'path/to/secret')}} 
    max_clients: 200
  remote_user: root
  tasks:
    ...
```


License
-------

MIT
