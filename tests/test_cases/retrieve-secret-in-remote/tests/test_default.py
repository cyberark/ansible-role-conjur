import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '/conjurinc/ansible-role-conjur/tests/inventory.tmp').get_hosts('testapp')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'

def test_retrieved_secret(host):
    conjur_env_file = host.file('conjur_env.txt')

    assert conjur_env_file.exists

    assert conjur_env_file.contains("RETRIEVED_PASSWORD=target_secret_password")
    assert conjur_env_file.contains("EXAMPLE_CONJUR_MAJOR_VERSION=4")
    assert conjur_env_file.contains("ANOTHER_RETRIEVED_PASSWORD=another_target_secret_password")
    assert conjur_env_file.contains("LOCAL_VARIABLE=cucumber")
