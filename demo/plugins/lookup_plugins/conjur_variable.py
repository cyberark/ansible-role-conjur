#!/usr/bin/python

import os.path
import ssl
import yaml
from ansible.plugins.lookup import LookupBase
from base64 import b64encode
from httplib import HTTPConnection
from netrc import netrc
from os import environ
from sys import stderr
from time import time
from urllib import quote_plus
from urlparse import urlparse


def exit_error(err):
    stderr.write(err)
    exit(1)


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
        authn_url = '/authn/%s/%s/authenticate' % (quote_plus(self.account), quote_plus(self.id))
        self.http_connection.request('POST', authn_url, self.api_key)

        response = self.http_connection.getresponse()

        if response.status != 200:
            exit_error('Failed to authenticate as \'%s\'' % (self.id))

        self.token = b64encode(response.read())
        self.refresh_time = time() + 5 * 60

    # get_header_value
    # Returns the value for the Authorization header. Refreshes the auth token
    # before returning if necessary.
    def get_header_value(self):
        if time() >= self.refresh_time:
            self.refresh()

        return 'Token token="%s"' % (self.token)


def load_conf(conf_path):
    conf_path = os.path.expanduser(conf_path)

    if not os.path.isfile(conf_path):
        return {}

    with open(conf_path, 'r') as conf_file:
        try:
            return yaml.load(conf_file)
        except yaml.YAMLError as e:
            exit_error(e)


def load_identity(identity_path, appliance_url):
    identity_path = os.path.expanduser(identity_path)

    if not os.path.isfile(identity_path):
        return {}

    try:
        identity = netrc(identity_path)
        id, _, api_key = identity.authenticators('{}/authn'.format(appliance_url))
        if not id or not api_key:
            return {}

        return dict(id=id, api_key=api_key)
    except:
        pass

    return {}


# merge_dict
# Merges all key values in a variable list of dictionaries
def merge_dict(*arg):
    ret = {}
    for a in arg:
        trimmed_dict = dict((k, v) for k, v in a.iteritems() if v)
        ret = dict(ret.items() + trimmed_dict.items())
    return ret


class LookupModule(LookupBase):
    def run(self, terms, variables, **kwargs):

        # Load Conjur configuration
        conf = merge_dict(load_conf('/etc/conjur.conf'),
                          load_conf('~/.conjurrc'),
                          dict(
                              account = environ.get('CONJUR_ACCOUNT'),
                              appliance_url = environ.get("CONJUR_APPLIANCE_URL"),
                              cert_file = environ.get('CONJUR_CERT_FILE')
                          ))

        os.system('echo conf: %s >> /tmp/conjur_variable.txt' % conf)

        if not conf:
            exit_error('Failed to load a Conjur configuration.\n'
                       'Make sure a configuration exists at environment variables or at either of the following paths:\n'
                       '~/.conjurrc'
                       '/etc/conjur.conf\n')

        # Load Conjur identity
        identity = merge_dict(
            load_identity('/etc/conjur.identity', conf['appliance_url']),
            load_identity('~/.netrc', conf['appliance_url']),
            dict(
                api_key = environ.get('CONJUR_AUTHN_API_KEY'),
                id = environ.get('CONJUR_AUTHN_LOGIN')
            ))

        os.system('echo identity: %s >> /tmp/conjur_variable.txt' % identity)

        if not identity:
            exit_error('Failed to load a Conjur identity.\n'
                       'Make sure an identity exists at environment variables or at either of the following paths:\n'
                       '~/.netrc' 
                       '/etc/conjur.identity\n')

        # Load our certificate for validation
        # ssl_context = ssl.create_default_context()
        # ssl_context.load_verify_locations(conf['cert_file'])

        conjur_https = HTTPConnection(urlparse(conf['appliance_url']).netloc)
        # todo orenbm: change to https

        token = Token(conjur_https, identity['id'], identity['api_key'], environ.get('CONJUR_ACCOUNT'))

        ret = []
        for term in terms:
            variable_name = term.split()[0]
            headers = {'Authorization': token.get_header_value()}
            url = '/secrets/%s/variable/%s' % (conf['account'], quote_plus(variable_name))

            conjur_https.request('GET', url, headers=headers)
            response = conjur_https.getresponse()

            if response.status == 200:
                ret.append(response.read())

        return ret
