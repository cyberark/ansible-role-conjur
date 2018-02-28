# Conjur Ansible Role

This Ansible role provides the ability to grant Conjur machine identity to a host.

Based on that identity, secrets can then be retrieved securely using the
[Summon](https://github.com/cyberark/summon) tool (installed on hosts with identities created by this role).

Additionally, the
[Conjur CLI](https://github.com/cyberark/conjur-cli), and the
[Conjur API](https://www.conjur.org/api.html)
can also be used to retrieve secrets from a host with Conjur identity.

## Installation

Install the Conjur role using the following command in your playbook directory:

```sh-session
$ ansible-galaxy install cyberark.conjur
```

## About Conjur Machine Identity

Machine identity is the primary innovation in Conjur.  A machine might be a node, a server, a container, an application, or others.  With Conjur, you can reliably identify machines, group them, manage them, and provide minimally required privileges. By establishing machine identities, your Ansible configurations can take advantage of powerful features of Conjur, including:

* Use policy to manage user, group, and machine access to secrets
* Express policy as code, which is declarative, reviewable, and idempotent
* DevOps teams manage secrets relevant to their own applications
* Easily rotate secrets, manually or automated on a schedule (Enterprise Conjur)
* Capture all activity in audit trails (Enterprise Conjur)

The Conjur integration with Ansible  provides a way for establishing machine identities with Ansible.

## Usage

A running Conjur service that is accessible from the Ansible host and target machines.
To use this role, Ansible 2.3.x.x is required.

The Conjur role provides a method to “Conjurize” or establish the identity of a remote node with Ansible.
Through integration with Conjur, the machine can then be granted least-privilege access
to retrieve the secrets it needs in a secure manner.
Providing a node with a Conjur Identity enables privileges to be granted by Conjur policies.

### Role Variables

* `conjur_appliance_url` `*`: URL of the running Conjur service
* `conjur_account` `*`: Conjur account name
* `conjur_host_factory_token` `*`: [Host Factory](https://developer.conjur.net/reference/services/host_factory/) token for
layer enrollment. This should be specified in the environment on the Ansible controlling host.
* `conjur_host_name` `*`: Name of the host being conjurized.
* `conjur_ssl_certificate`: Public SSL certificate of the Conjur endpoint
* `conjur_validate_certs`: Boolean value to indicate if the Conjur endpoint should validate certificates
* `summon.version`: version of Summon to install. Default is `0.6.6`.
* `summon_conjur.version`: version of Summon-Conjur provider to install. Default is `0.5.0`.

The variables marked with `*` are required fields. The other variables are required for running with an HTTPS Conjur endpoint,
but are not required if you run with an HTTP Conjur endpoint.

### Example Playbook

Configure a remote node with a Conjur identity and Summon:
```yml
- hosts: servers
  roles:
    - role: playbook.yml
      conjur_appliance_url: 'https://conjur.myorg.com/api',
      conjur_account: 'myorg',
      conjur_host_factory_token: "{{lookup('env', 'HFTOKEN')}}",
      conjur_host_name: "{{inventory_hostname}}"
```

The above playbook:
* Registers the host with Conjur, adding it into the layer specific to the provided host factory token.
* Creates two files used to identify the host and Conjur connection information.
* Installs Summon with the Summon Conjur provider for secret retrieval from Conjur.

### Summon & Service Managers
With Summon installed, using Conjur with a Service Manager (like SystemD) becomes a snap.  Here's a simple example of a SystemD file connecting to Conjur:
```ini
[Unit]
Description=DemoApp
After=network-online.target

[Service]
User=DemoUser
#Environment=CONJUR_MAJOR_VERSION=4
ExecStart=/usr/local/bin/summon --yaml 'DB_PASSWORD: !var staging/demoapp/database/password' /usr/local/bin/myapp
```
**Note**
When connecting to Conjur 4 (Conjur Enterprise), Summon requires the environment variable `CONJUR_MAJOR_VERSION` set to `4`. You can provide it by uncommenting the relevant line above.

The above example uses Summon to pull the password stored in `staging/myapp/database/password`, set it to an environment variable `DB_PASSWORD`, and provide it to the demo application process. Using Summon, the secret is kept off disk. If the service is restarted, Summon retrieves the password as the application is started. See the [Summon Github site](https://cyberark.github.io/summon/) for more details on using `summon`.

### Lookup Plugin (Ansible >= v2.5.0.0)

The lookup plugin uses the control node’s identity to retrieve secrets from Conjur and provide them to the relevant playbook. The control node has execute permission on all relevant variables. It retrieves values from Conjur at runtime.  The retrieved secrets are inserted by the playbook where needed before the playbook is passed to the remote nodes.

This approach provides a simple alternative to the Ansible Vault. With only minor changes to an existing playbook, you can leverage these Conjur features:

* The Conjur RBAC model provides users and groups with access to manage and rotate secrets (in contrast to sharing an encryption key).
* Moving secrets outside of Ansible Vault enables them to be used by a wide range of different systems.
* Enterprise Conjur provides automated rotators that you can easily configure with a few statements added to policy.

A disadvantage to the lookup plugin approach is that the control node requires access to all credentials fetched on behalf of the remote nodes, making the control node a potential high-value target.  In many production environments, a single source of privilege may not be acceptable. There is also a potential risk of accidentally leaking retrieved secrets to nodes.  All nodes targeted through a playbook will have access to secrets granted to that playbook.

Despite the control node being a single source of access, note the following:

* You can mitigate the risk with thoughtful network design and by paying extra attention to securing the control node.
* The solution does not store secrets on the control node.  The control node simply passes the values onto the remote nodes in a playbook through SSH, and the secrets disappear along with the playbook at the end of execution.

The lookup plugin has the additional advantage of being quite simple and quick to implement. It may be sufficient for smaller installations and for testing and development environments. Try this approach first to learn about Conjur and the Ansible conjur role.

*Note that by default the lookup plugin uses the Conjur 5 API to retrieve secrets. To use Conjur 4 API, set an environment CONJUR_VERSION="4".*

#### Lookup plugin example
Using environment variables:
```shell
export CONJUR_ACCOUNT="orgaccount"
export CONJUR_VERSION="4"
export CONJUR_APPLIANCE_URL="https://conjur-appliance"
export CONJUR_CERT_FILE="/path/to/conjur_certficate_file"
export CONJUR_AUTHN_LOGIN="host/host_indentity"
export CONJUR_AUTHN_API_KEY="host API Key"
```
Playbook
```yml
- hosts: servers
  tasks:
    - name: Retrieve secret with master identity
      vars:
        super_secret_key: {{ lookup('retrieve_conjur_variable', 'path/to/secret') }}
      shell: echo "Yay! {{super_secret_key}} was just retrieved with Conjur"
      register: foo
    - debug: msg="the echo was {{ foo.stdout }}"
```

### Testing

To run the tests:

```sh-session
$ cd tests
$ ./test.sh
```

### Dependencies

None

### Recommendations

* Add `no_log: true` to each play that uses sensitive data, otherwise that data can be printed to the logs.
* Set the Ansible files to minimum permissions. Ansible uses the permissions of the user that runs it.

## License

Apache 2
