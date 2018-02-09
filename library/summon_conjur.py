#!/usr/bin/python

import os
import shlex
from ansible.module_utils.basic import *
from subprocess import Popen, PIPE
import json
import base64

class ConjurCommandModule(object):
    def __init__(self, module):
        self.module = module
        self.secretsyml = module.params.get('secretsyml')
        self.command = module.params.get('command')

    def execute(self):
        try:
            secrets = self.retrieve_secrets()

            env = self.add_variables_to_env(secrets)

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

    def retrieve_secrets(self):
        p = Popen(['/etc/conjur-env'], env=dict(os.environ, SECRETSYML=self.secretsyml), stdout=PIPE, stderr=PIPE, shell=True)
        output, error = p.communicate()
        if p.returncode != 0:
            raise Exception("retrieve_secrets failed %d %s %s\n" % (p.returncode, output, error))

        return json.loads(base64.b64decode(output))

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
            "secretsyml": {"required": True, "type": "str"}
        }
    )

    result = ConjurCommandModule(module).execute()

    module.exit_json(**result)


if __name__ == '__main__':
    main()
