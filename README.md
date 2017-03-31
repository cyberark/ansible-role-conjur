ansible-role-conjur
=========

Configures Conjur identity and SSH access management on machines.
The [conjur](https://github.com/conjur-cookbooks/conjur) Chef cookbook is downloaded and run to set up Conjur SSH.

Note that this is a work in progress and should not be used yet!

Requirements
------------

A Conjur endpoint to retrieve identities from.

Role Variables
--------------

* `conjur_account`: Conjur account
* `conjur_appliance_url`: Conjur endpoint
* `conjur_host_factory_token`: [Host Factory](https://developer.conjur.net/reference/services/host_factory/) token for layer enrollment
* `conjur_ssl_certificate`: Public SSL certificate of Conjur endpoint
* `conjur_host_name`: Name of the host being conjurized.
* `conjur_validate_certs`: yes

* `conjur_ssh_enable`: Configure Conjur SSH management, default `false`
* `conjur_ssh_cookbook_version`: Version of the 'conjur' cookbook to use
* `conjur_ssh_cookbook_url`: URL to download the cookbook tarball from
* `conjur_ssh_chef_version`: Version of Chef to install
* `conjur_ssh_chef_url`: URL to download Chef from
* `conjur_ssh_chef_checksum`: SHA256 checksum of the Chef package

Sane defaults are set in [defaults/main.yml](defaults/main.yml).

Dependencies
------------

None

Example Playbook
----------------

```yml
- hosts: servers
  roles:
     - role: conjur
       conjur_account: 'myorg',
       conjur_appliance_url: 'https://conjur.myorg.com/api',
       conjur_host_factory_token: "{{lookup('env', 'HFTOKEN')}}",
       conjur_ssl_certificate: "{{lookup('file', '~/conjur-myorg.pem')}}",
       conjur_host_name: "{{inventory_hostname}}"
       conjur_ssh_enable: yes
```


License
-------

MIT
