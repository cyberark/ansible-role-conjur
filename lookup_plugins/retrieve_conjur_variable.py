#!/usr/bin/python

from ansible.plugins.lookup import LookupBase
import os
from subprocess import Popen, PIPE
import json
import base64

class LookupModule(LookupBase):
    def retrieve_secrets(self, secretsyml, variables):
        system_id = variables.get('ansible_system', None)
        system_id = str(system_id).lower()

        executable_path = os.path.realpath(
            '/'.join([
                os.path.dirname(__file__),
                "../conjur-env/conjur-env_%s" % (system_id)
            ]))

        p = Popen([executable_path], env=dict(os.environ, SECRETSYML=secretsyml), stdout=PIPE, stderr=PIPE, shell=True)
        output, error = p.communicate()
        if p.returncode != 0:
            raise Exception("retrieve_secrets failed %d %s %s\n" % (p.returncode, output, error))

        return json.loads(base64.b64decode(output))


    def run(self, terms, inject=None, variables=None, **kwargs):
        # Ansible variables are passed via "variables" in ansible 2.x, "inject" in 1.9.x
        secretsyml = ''

        # generate secrets.yml
        for i, term in enumerate(terms):
            variable_name = term.split()[0]
            secretsyml += 'counter%03d: !var %s\n' % (i, variable_name)

        secrets = self.retrieve_secrets(secretsyml, (inject or variables))

        ordered_secrets = []
        keylist = secrets.keys()
        keylist.sort()
        for key in keylist:
            ordered_secrets.append(secrets[key])

        return ordered_secrets
