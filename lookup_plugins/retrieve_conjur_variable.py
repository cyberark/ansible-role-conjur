#!/usr/bin/python

import os.path
import ssl
from ansible.plugins.lookup import LookupBase
from base64 import b64encode
from httplib import HTTPSConnection
from httplib import HTTPConnection
from netrc import netrc
from os import environ
from time import time
from urllib import quote_plus
from urlparse import urlparse


class Token:
    def __init__(self, http_connection, id, api_key, account, version):
        self.http_connection = http_connection
        self.id = id
        self.api_key = api_key
        self.token = None
        self.refresh_time = 0
        self.account = account
        self.version = version

    # refresh
    # Exchanges API key for an auth token, storing it base64 encoded within the
    # 'token' member variable. If it fails to obtain a token, the process exits.
    def refresh(self):
        if self.version == "5":
            authn_url = '/authn/{}/{}/authenticate'.format(quote_plus(self.account), quote_plus(self.id))
        else:
            authn_url = '/api/authn/users/{}/authenticate'.format(quote_plus(self.id))
        self.http_connection.request('POST', authn_url, self.api_key)

        response = self.http_connection.getresponse()

        if response.status != 200:
            raise Exception('Failed to authenticate as \'{}\' with response status: {} {}'.format(self.id,
                                                                                                  response.status,
                                                                                                  response.reason))

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
        config_map = {}
        lines = open(conf_path).read().splitlines()
        for line in lines:
            if line == '---':
                continue
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


class LookupModule(LookupBase):
    def retrieve_secrets(self, conf, conjur_https, token, terms):

        secrets = []
        for term in terms:
            variable_name = term.split()[0]
            headers = {'Authorization': token.get_header_value()}

            if conf['version'] == "5":
                url = '/secrets/{}/variable/{}'.format(conf['account'], quote_plus(variable_name))
            else:
                url = '/api/variables/{}/value'.format(quote_plus(variable_name))

            conjur_https.request('GET', url, headers=headers)
            response = conjur_https.getresponse()
            if response.status != 200:
                raise Exception('Failed to retrieve variable \'{}\' with response status: {} {}'.format(variable_name,
                                                                                                        response.status,
                                                                                                        response.reason))

            secrets.append(response.read())

        return secrets

    def run(self, terms, variables=None, **kwargs):
        # Load Conjur configuration
        conf = merge_dictionaries(
            load_conf('/etc/conjur.conf'),
            load_conf('~/.conjurrc'),
            {
                "account": environ.get('CONJUR_ACCOUNT'),
                "appliance_url": environ.get("CONJUR_APPLIANCE_URL"),
                "cert_file": environ.get('CONJUR_CERT_FILE')
            } if (environ.get('CONJUR_ACCOUNT') is not None and environ.get('CONJUR_APPLIANCE_URL')
                  is not None and (environ.get('CONJUR_APPLIANCE_URL').startswith('https') is not True or environ.get('CONJUR_CERT_FILE') is not None))
            else {}
        )
        if not conf:
            raise Exception('Conjur configuration should be in environment variables or in one of the following paths: \'~/.conjurrc\', \'/etc/conjur.conf\'')

        # Load Conjur version
        if (environ.get('CONJUR_VERSION') is not None):
            conf['version'] = environ.get('CONJUR_VERSION')
        else:
            conf['version'] = "5"

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
        token = Token(conjur_connection, identity['id'], identity['api_key'], conf['account'], conf['version'])

        # retrieve secrets of the given variables from Conjur
        return self.retrieve_secrets(conf, conjur_connection, token, terms)
