# CHANGELOG

## v0.5.0

- Summon and the Summon-Conjur provider are installed to retrieve credentials.

## v0.4.0

- `retrieve_conjur_variable` lookup plugin is now backwards-compatible with Conjur 4. Set the enviroment variable `CONJUR_VERSION=4` on the host machine to enable Conjur 4 support.

## v0.3.0

- Changed role name from `ansible-role-conjur` to `configure-conjur-identity`
- Added lookup plugin for retrieving Conjur secrets with Ansible host machine identity
- Added module for retrieving Conjur secrets with Ansible remote machine identity
- Added Molecule tests for role, lookup plugin & module
- Role, lookup plugin & module work with HTTP & HTTPS (with self-signed & CA certificates)

## 0.2.3

- `/etc/conjur.identity` is no longer symlinked from `/dev/shm`. This is too opinionated.

## 0.2.2

- Variable "conjur_host_factory_token" is no longer required when nodes are already conjurized

## 0.2.1

- Running the role on a node with Conjur identity no longer requests a new API key

## 0.2.0

- Adds support for Conjur SSH configuration (via Chef)

## 0.1.0
- Initial release
