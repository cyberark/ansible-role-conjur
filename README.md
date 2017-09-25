# ansible-role-conjur

This Ansible role provides the ability to grant Conjur machine identity to a host.

Based on that identity, secrets can then be retrieved securely using the
"retrieve_conjur_variable" lookup plugin or "summon-conjur module",
included in this role.

Additionally, [Summon](https://github.com/cyberark/summon), the
[Conjur CLI](https://github.com/cyberark/conjur-cli), and the
[Conjur API](https://www.conjur.org/api.html)
can also be used to retrieve secrets from a host with Conjur identity.

## Installation

Install the Conjur role using the following syntax:

```sh-session
$ ansible-galaxy install cyberark.conjur
```

## Requirements

### Usage

A running Conjur service that is accessible from the Ansible host and target machines.
To use this suite, ansible 2.3.x.x is required.

### Testing

We use [Molecule](https://github.com/metacloud/molecule#molecule) to test
Conjur's Ansible role, lookup plugin & module.

To run the tests:

1. Clone this project.
2. Create a Python virtualenv.
3. Install project requirements.

```sh-session
$ git clone https://github.com/cyberark/ansible-role-conjur.git
$ cd ansible-role-conjur
$ mkvirtualenv $(basename $PWD)
$ pip install -r requirements.txt -r requirements-dev.txt
```

### Dependencies

None

## "conjur" role

The Conjur role provides a method to “Conjurize” or establish the identity of a remote node with Ansible.
Through integration with Conjur, the machine can then be granted least-privilege access
to retrieve the secrets it needs in a secure manner.
Providing a node with a Conjur Identity enables privileges to be granted by Conjur policies.

### Role Variables

* configure-conjur-identity:
  * `conjur_appliance_url` `*`: URL of the running Conjur service
  * `conjur_account` `*`: Conjur account name
  * `conjur_host_factory_token` `*`: [Host Factory](https://developer.conjur.net/reference/services/host_factory/) token for
  layer enrollment
  * `conjur_host_name` `*`: Name of the host being conjurized.
  * `conjur_ssl_certificate`: Public SSL certificate of the Conjur endpoint
  * `conjur_validate_certs`: Boolean value to indicate if the Conjur endpoint should validate certificates

The variables marked with `*` are required fields. The other variables are required for running with an HTTPS Conjur endpoint,
but are not required if you run with an HTTP Conjur endpoint.


### Example Playbook

Configure a remote node with a Conjur identity:
```yml
- hosts: servers
  roles:
    - role: playbook.yml
      conjur_appliance_url: 'https://conjur.myorg.com/api',
      conjur_account: 'myorg',
      conjur_host_factory_token: "{{lookup('env', 'HFTOKEN')}}",
      conjur_host_name: "{{inventory_hostname}}"
```

## "retrieve_conjur_variable" lookup plugin

Conjur's `retrieve_conjur_variable` lookup plugin provides a means for retrieving secrets from Conjur for use in playbooks.
Note that as lookup plugins run in the Ansible host machine, the identity that will be used for retrieving secrets
are those of the Ansible host. Thus, the Ansible host requires god like privilege, essentially read access to every secret that a remote node may need.

The lookup plugin can be invoked in the playbook's scope as well as in a task's scope.

### Example Playbook

#### Playbook scope
```yml
- hosts: servers
  vars:
    super_secret_key: {{ lookup('retrieve_conjur_variable', 'path/to/secret') }}
  tasks:
    ...
```

#### Task scope
```yml
- hosts: servers
  tasks:
    - name: Retrieve secret with master identity
      vars:
        super_secret_key: {{ lookup('retrieve_conjur_variable', 'path/to/secret') }}
      shell: echo "Yay! {{super_secret_key}} was just retrieved with Conjur"
```

## "summon_conjur" module

The Conjur Module provides a mechanism for using a remote node’s identity to retrieve secrets that have been explicitly granted to it.
As Ansible modules run in the remote host, the identity used for retrieving secrets is that of the remote host.
This approach reduces the administrative power of the Ansible host and prevents it from becoming a high value target.

Moving secret retrieval to the node provides a maximum level of security. This approach reduces the security risk by
providing each node with the minimal amount of privilege required for that node. The Conjur Module also provides host level audit logging of secret retrieval. Environment variables are never written to disk.

The module receives variables and a command as arguments and, as in [Conjur's Summon CLI](https://www.conjur.org/integrations/summon.html),
provides an interface for fetching secrets from a provider and exporting them to a sub-process environment.

Note that you can provide both Conjur variables and non-Conjur variables, where in Conjur variables a `!var` prefix is required.


### Example Playbook
```yml
- hosts: webservers
  tasks:
    - name: Ensure app Foo is running
      summon_conjur:
        variables:
          - SECRET_KEY: !var /path/to/secret-key
          - SECRET_PASSWORD: !var /path/to/secret_password
          - NOT_SO_SECRET_VARIABLE: "{{lookup('env', 'SOME_ENVIRONMENT_VARIABLE')}}"
        command: rails s
```

The example above uses the variables defined in the `variables` block to map environment
variables to Conjur variables. This results in the following being
executed on the remote node:

```sh
$ SECRET_KEY=top_secret_key SECRET_PASSWORD=top_secret_password NOT_SO_SECRET_VARIABLE=some_environment_variable_value rails s
```

## Considerations

### "retrieve_conjur_variable" lookup plugin

As mentioned earlier, Retrieving secrets from Conjur with the Lookup Plugin gives the Ansible Controller host “god privileges”. 
This means the Ansible Controller host has read access to every secret that a remote node may need.
A node with god-privilege is a high value target within a network as it has access to the keys of the kingdom. A second
concern to keep in mind when using the Conjur Lookup Plugin is the inherent openness of variables. Secrets may be accidentally 
leaked to nodes affected by the playbook run.  

### "conjur" Module

The Conjur Module represents a departure from the traditional method of providing secrets to a remote machine and 
requires a rework of existing playbooks. Currently, there are limitations to the type of actions that can be called from the Conjur Module.
This may be addressed in the future.


Security Tradeoffs
------------------
There are a couple of security opportunities and tradeoffs between the various approaches of integrating secrets into plays with Ansible.

**Simple (But Less Secure) Approach**

From a security perspective, Ansible (and Chef, Puppet, Salt Stack, etc.) suffer from a God Privilege problem. 
Because secrets are injected into plays, either with an Ansible Vault or an external Vault, the Ansible host needs 
to retrieve all secrets required to configure remote nodes. This approach highly favors the playbook writer and/or 
operator because secrets are compiled centrally and work just like variables. However, the presence of a high value 
target like this in the network requires extra measures to secure the host. 
This approach requires a high level of automation and thoughtful network design.

This role can provide a simple alternative to the Ansible Vault by using the lookup plugin. This approach lets an organization:

* Removing a common encryption key while encrypted secrets at rest
* Simplify secret rotation/changing
* Manage user and group access to secrets

The Ansible host can be given execute permission on all relevant variables, and be used to retrieve secrets from Conjur at runtime.  This approach requires only minor changes in existing playbooks.

**The More Robust Approach**

Conjur’s primary innovation is not secrets management, it is machine identity. Once we are able to reliably identify machines, 
we can group them, and provide machines with minimal privileges.
An alternative design pattern to “god privileges” is to use an identity to group machines and provide access to the 
minimal set of resources they need to perform their role. This can be done by implementing the `conjur_identity` 
role to establish an identity and then implementing the `conjur_application` resource to use each remote machine’s identity to 
retrieve the secrets it requires to operate.

The advantage to this approach is that it removes “god privileges” from a machine (or machines) reducing the internal attach surface. 
This approach also enables an organization to take advantage of some of Conjur’s more powerful features, including:

* Policy as code, which is declarative, reviewable, and idempotent
* Enable teams to manage secrets relevant to their own applications
* Audit trail (Conjur Enterprise)

Moving identity to remote machines most likely will require some amount of rework of current playbooks. 
We’ve tried to minimize this effort, and we believe that the effort will greatly benefit your organization in terms 
of flexibility and security moving forward.


## Recommendations

* Add `no_log: true` to each play that uses sensitive data, otherwise that data can be printed to the logs.
* Set the Ansible files to minimum permissions. The Ansible uses the permissions of the user that runs it.


## License

Apache 2
