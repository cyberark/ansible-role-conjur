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


Security Tradeoffs
------------------
With Ansible and security, there’s a couple of opportunities and tradeoffs to be made between the various approaches of integrating secrets into plays.  

**Simple (but less secure) Approach**

From a security perspective, Ansible (and Chef, Puppet, Salt Stack, etc.) suffer from a God Privilege problem. Because secrets are injected into plays (either with Ansible Vault or an external Vault), the Ansible host needs to be able to retrieve all secrets required to configure remote nodes. This approach highly favors the playbook writer and/or operator, in that secrets are compiled centrally and work just like variables. Unfortunately, the presence of a high value target like this in the network means great lengths need to be taken to secure the host. This approach requires a high level of automation and thoughtful network design.  

This role can provide a simple alternative to Ansible Vault by using the lookup plugin. This approach lets an organization:
* Removing a common encryption key while encrypted secrets at rest
* Simplify secret rotation/changing
* Manage user and group access to secrets

The Ansible host can be given execute permission on all relevant variables, and be used to retrieve secrets from Conjur at runtime.  This approach requires only minor changes in existing playbooks.

**The more robust approach**

The primary innovation Conjur brings is not secrets management, it’s machine identity.  Once we’re able to reliably identify machines, we can group them, and provide machines with minimal privilege.  

An alternative to design pattern to the God Privilege is to use identity to group and provide machines access to the minimal set of resources they need to perform their role.  This can be done by using the `conjur_identity` role to establish identity, then using the `conjur_application` resource to use each remote machine’s identity to retrieve the secrets it requires to operate.

The advantage to this approach is that it removes a machine (or machines) from having god privileges, thus reducing the internal attach surface.  This approach also enables an organization to take advantage of some of Conjur’s more powerful features, including:
* Policy as code, which is declarative, reviewable, and idempotent
* Audit trail
* Managed SSH access
* Enable teams to manage secrets relevant to their own applications

It is worth noting that moving identity out to remote machines will most likely require a small amount of rework of current playbooks.  We’ve tried to minimize this effort, and we believe that the effort will greatly benefit your organization in terms of flexibility and security moving forward.

**Recommendations**
* Add `no_log: true` to each play that uses sensitive data, otherwise that data can be printed to the logs.
* Set the Ansible files to minimum permissions. The Ansible uses the permissions of the user that runs it. 

License
-------

MIT
