import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '.molecule/ansible_inventory.yml').get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'

def test_retrieved_secret(host):
    secrets_file = host.file('conjur_secrets.txt')

    assert secrets_file.exists

    result = host.check_output("cat conjur_secrets.txt", shell=True)

    assert result == "ansible_master_secret_password"