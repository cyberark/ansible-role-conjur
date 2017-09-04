import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '.molecule/ansible_inventory.yml').get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_is_conjurized(host):
    identity_file = host.file('/etc/conjur.identity')

    assert identity_file.exists
    assert identity_file.user == 'root'

    conf_file = host.file('/etc/conjur.conf')

    assert conf_file.exists
    assert conf_file.user == 'root'


def test_whoami(host):
    result = host.check_output("conjur authn whoami", shell=True)

    assert result == \
        "{\"account\":\"cucumber\"," \
        "\"username\":\"host/conjur_conjurized-container\"}"


def test_retrieve_secret_with_cli(host):
    result = host.check_output("conjur variable value ansible/target-password", shell=True)

    assert result == "target_secret_password"

def test_retrieve_secret_with_summon(host):
    result = host.check_output('/conjurinc/ansible/summon.sh && cat secret.txt', shell=True)

    assert result == "target_secret_password"
