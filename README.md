# Conjur Ansible Role

This Ansible role provides the ability to grant Conjur machine identity to a host. Based on that identity, secrets can then be retrieved securely using the [Summon](https://github.com/cyberark/summon) tool (installed on hosts with identities created by this role).

## Required Reading

* To learn more about Conjur, give it a [try](https://www.conjur.org/get-started/try-conjur.html)
* To learn more about how Conjur can be integrated with Ansible, visit the [Integration Documentation](https://www.conjur.org/integrations/ansible.html)
* To learn more about Summon, the tool that lets you execute applications with secrets retrieved from Conjur, visit the [Summon Webpage](https://cyberark.github.io/summon/)
* To learn more about other ways you can integrate with Conjur, visit our pages on the [CLI](https://developer.conjur.net/cli), [API](https://developer.conjur.net/clients), and [Integrations](https://www.conjur.org/integrations/)

## Installation

Install the Conjur role using the following command in your playbook directory:

```sh-session
$ ansible-galaxy install cyberark.conjur
```

## Requirements

* A running Conjur service that is accessible from the target nodes.
* Ansible >= 2.3.0.0

## Usage

The Conjur role provides a method to “Conjurize” or establish the Conjur identity of a remote node with Ansible. The node can then be granted least-privilege access to retrieve the secrets it needs in a secure manner.

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

The variables marked with `*` are required fields. The other variables are required for running with an HTTPS Conjur endpoint, but are not required if you run with an HTTP Conjur endpoint.

### Example Playbook

Configure a remote node with a Conjur identity and Summon:
```yml
- hosts: servers
  roles:
    - role: cyberark.conjur
      conjur_appliance_url: 'https://conjur.myorg.com/api',
      conjur_account: 'myorg',
      conjur_host_factory_token: "{{lookup('env', 'HFTOKEN')}}",
      conjur_host_name: "{{inventory_hostname}}"
```

This example:
* Registers the host with Conjur, adding it into the layer specific to the provided host factory token.
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

The above example uses Summon to retrieve the password stored in `staging/myapp/database/password`, set it to an environment variable `DB_PASSWORD`, and provide it to the demo application process. Using Summon, the secret is kept off disk. If the service is restarted, Summon retrieves the password as the application is started.

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
