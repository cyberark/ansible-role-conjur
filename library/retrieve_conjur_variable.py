#!/usr/bin/python

import os.path
import ssl
from ansible.module_utils.basic import *
from httplib import HTTPSConnection
from httplib import HTTPConnection
from netrc import netrc
from os import environ
from urlparse import urlparse
import yaml
from urllib import quote_plus
from base64 import b64encode
from time import time


class Token:
    def __init__(self, http_connection, id, api_key, account):
        self.http_connection = http_connection
        self.id = id
        self.api_key = api_key
        self.token = None
        self.refresh_time = 0
        self.account = account

    # refresh
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

    # get_header_value
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
        with open(conf_path, 'r') as conf_file:
            return yaml.load(conf_file)
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


class ConjurVariableModule(object):
    def __init__(self, module):
        self.module = module
        self.variables = module.params.get('variables')

    def exit_with_error(self, msg):
        self.module.fail_json(**
            {
                "failed": True,
                "msg": msg
            }
        )


    def retrieve_secrets(self, conf, conjur_https, token):
        secrets = {}
        for k, v in self.variables.items():
            headers = {'Authorization': token.get_header_value()}
            url = '/secrets/{}/variable/{}'.format(conf['account'], quote_plus(v))

            conjur_https.request('GET', url, headers=headers)
            response = conjur_https.getresponse()

            if response.status != 200:
                raise Exception('Failed to retrieve variable \'{}\' with response status: {} {}'.format(v, response.status, response.reason))

            secrets[k] = response.read()

        return secrets


    def execute(self):

        try:
            # Load Conjur configuration
            # todo - is it ok to have the identity in more than one place? Do we want to change this? If not, what are the priorities?
            conf = merge_dictionaries(
                load_conf('/etc/conjur.conf'),
                load_conf('~/.conjurrc')
            )
            if not conf:
                if environ.get('CONJUR_ACCOUNT') is not None and environ.get('CONJUR_APPLIANCE_URL') is not None and environ.get('CONJUR_CERT_FILE') is not None:
                    conf = {
                        "account": environ.get('CONJUR_ACCOUNT'),
                        "appliance_url": environ.get("CONJUR_APPLIANCE_URL"),
                        "cert_file": environ.get('CONJUR_CERT_FILE')
                    }
                else:
                    self.exit_with_error('Conjur configuration should be in environment variables or in one of the following paths: \'~/.conjurrc\', \'/etc/conjur.conf\'')

            # Load Conjur identity
            # todo - is it ok to have the conf in more than one place? Do we want to change this? If not, what are the priorities?
            identity = merge_dictionaries(
                load_identity('/etc/conjur.identity', conf['appliance_url']),
                load_identity('~/.netrc', conf['appliance_url'])
            )
            if not identity:
                if environ.get('CONJUR_AUTHN_LOGIN') is not None and environ.get('CONJUR_AUTHN_API_KEY') is not None:
                    identity = {
                        "id": environ.get('CONJUR_AUTHN_LOGIN'),
                        "api_key": environ.get('CONJUR_AUTHN_API_KEY')
                    }
                else:
                    self.exit_with_error('Conjur identity should be in environment variables or in one of the following paths: \'~/.netrc\', \'/etc/conjur.identity\'')

            if conf['appliance_url'].startswith('https') is True:
                    # Load our certificate for validation
                    ssl_context = ssl.create_default_context()
                    ssl_context.load_verify_locations(conf['cert_file'])
                    conjur_connection = HTTPSConnection(urlparse(conf['appliance_url']).netloc,
                                               context = ssl_context)
            else:
                    conjur_connection = HTTPConnection(urlparse(conf['appliance_url']).netloc)


            token = Token(conjur_connection, identity['id'], identity['api_key'], conf['account'])

            # retrieve secrets of the given variables from Conjur
            secrets = self.retrieve_secrets(conf, conjur_connection, token)

        except Exception as e:
            self.exit_with_error(e.args[0])

        return {"changed": False, "secrets": secrets}


def main():
    module = AnsibleModule(
        argument_spec = {
            "variables": { "required": False, "type": "dict"}
        }
    )

    result = ConjurVariableModule(module).execute()

    module.exit_json(**result)


if __name__ == '__main__':
    main()
