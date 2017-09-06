#!/usr/bin/python

import ssl
import os
import re
import shlex
from ansible.module_utils.basic import *
from httplib import HTTPSConnection
from httplib import HTTPConnection
from base64 import b64encode
from netrc import netrc
from os import environ
from subprocess import Popen, PIPE
from time import time
from urllib import quote_plus
from urlparse import urlparse


class Token:
    def __init__(self, http_connection, id, api_key, account):
        self.http_connection = http_connection
        self.id = id
        self.api_key = api_key
        self.token = None
        self.refresh_time = 0
        self.account = account

    # Exchanges API key for an auth token, storing it base64 encoded within the
    # 'token' member variable. If it fails to obtain a token, the process exits.
    def refresh(self):
        authn_url = '/authn/{}/{}/authenticate'.format(quote_plus(self.account), quote_plus(self.id))
        self.http_connection.request('POST', authn_url, self.api_key)

        response = self.http_connection.getresponse()

        if response.status != 200:
            raise Exception('Failed to authenticate as \'{}\''.format(self.id))

        self.token = b64encode(response.read())
        self.refresh_time = time() + 5 * 60

    # Returns the value for the Authorization header. Refreshes the auth token
    # before returning if necessary.
    def get_header_value(self):
        if time() >= self.refresh_time:
            self.refresh()

        return 'Token token="{}"'.format(self.token)


# if the conf is not in the path specified, or if an exception is thrown while reading the conf file
# we don't exit as the conf might be in another path
def load_conf(conf_path):
    conf_path = os.path.expanduser(conf_path)

    if not os.path.isfile(conf_path):
        return {}

    try:
        config_map = {}
        lines = open(conf_path).read().splitlines()
        for line in lines:
            parts = line.split(': ')
            config_map[parts[0]] = parts[1]
        return config_map
    except:
        pass

    return {}


# if the identity is not in the path specified, or if an exception is thrown while reading the identity file
# we don't exit as the identity might be in another path
def load_identity(identity_path, appliance_url):
    identity_path = os.path.expanduser(identity_path)

    if not os.path.isfile(identity_path):
        return {}

    try:
        identity = netrc(identity_path)
        id, _, api_key = identity.authenticators('{}/authn'.format(appliance_url))
        if not id or not api_key:
            return {}

        return {"id": id, "api_key": api_key}
    except:
        pass

    return {}


def merge_dictionaries(*arg):
    ret = {}
    for a in arg:
        ret.update(a)
    return ret


class ConjurCommandModule(object):
    def __init__(self, module):
        self.module = module
        self.variables = module.params.get('variables')
        self.command = module.params.get('command')

    def execute(self):
        try:
            # Load Conjur configuration
            conf = merge_dictionaries(
                load_conf('/etc/conjur.conf'),
                load_conf('~/.conjurrc'),
                {
                    "account": environ.get('CONJUR_ACCOUNT'),
                    "appliance_url": environ.get("CONJUR_APPLIANCE_URL"),
                    "cert_file": environ.get('CONJUR_CERT_FILE')
                } if (environ.get('CONJUR_ACCOUNT') is not None and environ.get('CONJUR_APPLIANCE_URL')
                      is not None and environ.get('CONJUR_CERT_FILE') is not None)
                else {}
            )
            if not conf:
                raise Exception('Conjur configuration should be in environment variables or in one of the following paths: \'~/.conjurrc\', \'/etc/conjur.conf\'')

            # Load Conjur identity
            identity = merge_dictionaries(
                load_identity('/etc/conjur.identity', conf['appliance_url']),
                load_identity('~/.netrc', conf['appliance_url']),
                {
                    "id": environ.get('CONJUR_AUTHN_LOGIN'),
                    "api_key": environ.get('CONJUR_AUTHN_API_KEY')
                } if (environ.get('CONJUR_AUTHN_LOGIN') is not None and environ.get('CONJUR_AUTHN_API_KEY') is not None)
                else {}
            )
            if not identity:
                raise Exception('Conjur identity should be in environment variables or in one of the following paths: \'~/.netrc\', \'/etc/conjur.identity\'')

            if conf['appliance_url'].startswith('https'):
                    # Load our certificate for validation
                    ssl_context = ssl.create_default_context()
                    ssl_context.load_verify_locations(conf['cert_file'])
                    conjur_connection = HTTPSConnection(urlparse(conf['appliance_url']).netloc,
                                               context = ssl_context)
            else:
                    conjur_connection = HTTPConnection(urlparse(conf['appliance_url']).netloc)


            token = Token(conjur_connection, identity['id'], identity['api_key'], conf['account'])

            # filter conjur variables
            conjur_variables, non_conjur_variables = self.filter_conjur_variables()

            # retrieve secrets of the given variables from Conjur
            secrets = self.retrieve_secrets(conf, conjur_connection, token, conjur_variables)

            variables = merge_dictionaries(secrets, non_conjur_variables)

            env = self.add_variables_to_env(variables)

            # Execute subprocess with the additional environment variables
            return self.execute_command_with_new_env(env)

        except Exception as e:
            self.exit_with_error(e.args[0])

    def exit_with_error(self, msg):
        self.module.fail_json(**
                              {
                                  "failed": True,
                                  "msg": msg
                              }
                              )

    def retrieve_secrets(self, conf, conjur_https, token, variables):
        secrets = {}
        for k, v in variables.items():
            headers = {'Authorization': token.get_header_value()}
            url = '/secrets/{}/variable/{}'.format(conf['account'], quote_plus(v))

            conjur_https.request('GET', url, headers=headers)
            response = conjur_https.getresponse()

            if response.status != 200:
                raise Exception(
                    'Failed to retrieve variable \'{}\' with response status: {} {}'.format(v, response.status,
                                                                                            response.reason))
            secrets[k] = response.read()

        return secrets

    def filter_conjur_variables(self):
        regex = re.compile(r'(!var )(.*)')
        conjur_variables = dict([(k, regex.match(v).group(2)) for k, v in self.variables.items() if regex.match(v)])
        non_conjur_variables = dict([(k, v) for k, v in self.variables.items() if not regex.match(v)])
        return conjur_variables, non_conjur_variables

    def execute_command_with_new_env(self, env):
        process = Popen(shlex.split(self.command), env=env, stdout=PIPE, stderr=PIPE)
        stdout, stderr = process.communicate()

        if process.returncode != 0:
            return {"changed": False, "failed": True, "result": stdout, "stderr": stderr}
        else:
            return {"changed": False, "result": stdout}

    def add_variables_to_env(self, variables):
        env = os.environ.copy()
        for k, v in variables.items():
            env[k] = v

        return env


def main():
    module = AnsibleModule(
        argument_spec={
            "command": {"required": True, "type": "str"},
            "variables": {"required": False, "type": "dict"}
        }
    )

    result = ConjurCommandModule(module).execute()

    module.exit_json(**result)


if __name__ == '__main__':
    main()
