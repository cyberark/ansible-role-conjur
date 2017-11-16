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

    result = host.check_output("cat conjur_env.txt", shell=True)

    assert "RETRIEVED_PASSWORD=target_secret_password" in result \
           and  "ANOTHER_RETRIEVED_PASSWORD=another_target_secret_password" in result \
           and "LOCAL_VARIABLE=local_variable_value" in result
