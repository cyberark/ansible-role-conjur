# ansible-role-conjur 

This Ansible Conjur integration  provides the ability to grant Conjur machine identity to Ansible nodes.

Based on that identity, Ansible can securely retrieve secrets stored in an existing Conjur appliance.  Conjur policy manages Ansible access to the secrets. 

Summary usage information: 

  * The role name for playbooks is `configure-conjur-identity`.
  * The lookup plugin name is `retrieve_conjur_variable`.
  * The role installs the lookup plugin and  [Summon](https://github.com/cyberark/summon) with the summon-conjur provider. 

Additionally, you can use the
[Conjur CLI](https://github.com/cyberark/conjur-cli)  and the
[Conjur API](https://www.conjur.org/api.html)
 to retrieve secrets from a host with Conjur identity.
 
  * <a href="#overview">Overview</a>
  * <a href="#requirements">Requirements</a> 
  * <a href="#install">Installation</a>
  * <a href="#usage-proc">Usage Procedures</a>
  * <a href="#example-lookup">Lookup Plugin Example</a>
  * <a href="#summon-example">Summon Example</a>
  * <a href="#recommend">Recommendations</a>
  * <a href="#license">License</a>

## <a id="overview">Overview</a>


### <a id="machine-identity">About Conjur Machine Identity</a>

Machine identity is a central innovation in Conjur.  With Conjur, you can reliably identify machines, and then group them, manage them, and provide minimally required privileges. By establishing machine identities on Ansible nodes, your Ansible configurations can take advantage of powerful features of Conjur, including:

* Use policy to manage user, group, and machine access to secrets  
* Express policy as code, which is declarative, reviewable, and idempotent
* DevOps teams manage secrets relevant to their own applications
* Easily rotate secrets, manually or automated on a schedule (Enterprise Conjur) 
* Capture all activity in audit trails (Enterprise Conjur)

This integration provides a way for establishing Conjur machine identities on Ansible nodes, enabling the nodes to securely retrieve secrets from Conjur.  


### <a id="options">Implementation Options</a>

The  Ansible Conjur role offers two methods for fetching secrets from a Conjur appliance: 

* Conjur Lookup Plugin: Control node fetches secrets 
* Summon/summon-conjur: Remote nodes can fetch their own secrets
    
Both approaches are supported for Enterprise Conjur (v4) and Open Source Conjur (v5).

#### Lookup Plugin: Control node fetches secrets
 
The Conjur lookup plugin uses the control node’s identity to retrieve secrets from Conjur and provide them to the relevant playbook. The control node has execute permission on all relevant variables. It retrieves values from Conjur at runtime.  The retrieved secrets are inserted by the playbook where needed before the playbook is passed to the remote nodes.  

This approach provides a simple alternative to the Ansible Vault. With only minor changes to an existing playbook, you can leverage these Conjur features: 

* The Conjur RBAC model provides users and groups with access to manage and rotate secrets (in contrast to sharing an encryption key).
* Moving secrets outside of Ansible Vault enables them to be used by a wide range of different systems. 
* Enterprise Conjur provides automated rotators that you can easily configure with a few statements added to policy.

Because the lookup plugin requires access to all credentials fetched on behalf of the remote nodes, the control node becomes a potential high-value target.  In many production environments, a single source of privilege may not be acceptable. There is also a potential risk of accidentally leaking retrieved secrets to nodes.  All nodes targeted through a playbook will have access to secrets granted to that playbook.  

However, you can mitigate the above risk with thoughtful network design and by paying extra attention to securing the control node.  The solution does not store secrets on the control node.  The control node simply passes the values onto the remote nodes in a playbook through SSH, and the secrets disappear along with the playbook at the end of execution. 

The lookup plugin has the additional advantage of being quite simple and quick to implement. It may be sufficient for smaller installations and for testing and development environments. Try this approach first to learn about Conjur and the Ansible conjur role. 
  
#### Summon/summon-conjur: Remote nodes fetch their own secrets  

**Compatibility: Conjur 4 and 5**

Using Summon, you can establish machine identity on the remote nodes, and manage access to only the secrets that each node needs. With this approach, you can grant access in more granular levels,  enforcing least privilege principles. Each remote node’s identity is used to retrieve secrets that have been explicitly granted to it. 

The CyberArk Summon tool provides an interface for fetching secrets from a provider and exporting them to a sub-process environment. Summon uses  providers to fetch secrets from different source types. The summon-conjur provider fetches secrets from Conjur.  

 Summon provides application credentials, such as SSH credentials,  without writing those secrets to disk. It can be used with services (like Systemd). In addition, you can provide both Conjur variables and non-Conjur variables through Summon. For Conjur variables, a `!var` prefix is required in the variable definition.

Using Summon requires only minor reworking of current playbooks to establish machine identities and group resources.  Summon must be installed on the remote nodes, and an additional, easy-to-construct secrets file is required to define the secrets to fetch.
 
## <a id="requirements">Requirements</a>

### Requirements for Using the Ansible Conjur Integration

* A running Conjur appliance that is accessible from the Ansible host and target machines.(??is it more appropriate to say Ansible Control and Remote Nodes?)  Supported versions are: 

   * Enterprise Conjur (v4.?.?.? and later)
   * Open Source Conjur (v5.x)
     * Hosted Conjur is a hosted version of Open Source Conjur. You can quickly get a hosted Conjur instance running for evaluation purposes. Visit the [hosted Conjur page](https://www.conjur.org/get-started/try-conjur.html) to sign up.
       
* Ansible 2.3.x.x or later is required.

 

### Requirements for Testing

To run the tests:
??what tests are we talking about? what is being tested? that the install went ok, or that there is an acceptable conjur running? or is this standard OpenSource jargon?

```sh-session
$ git clone https://github.com/cyberark/ansible-role-conjur.git
$ cd ansible-role-conjur/tests
$ ./test.sh
```

### Dependencies

None

## <a id="install">Installation</a>

Install the Conjur role on your Ansible Control node using the following command:

```sh-session
$ ansible-galaxy install cyberark.conjur
```

Install the Conjur role on Ansible remote nodes to install Summon???? 

??are there any additional installation instructions for getting the summon/summon-conjur installed?  I think we should provide that here. 

## <a id="usage-proc">Usage Procedures</a>

* <a href="#create-policy">1-Create and Load Policy on Conjur</a>
* <a href="#host-factory">2-Generate a Host Factory Token</a>
* <a href="#conjur-role">3-Use Conjur Role to Create Machine Identities</a>
* <a href="#define-variables">4-Define Application Variables in Conjur</a>
* <a href="#use-lookup">5-Use Lookup Plugin to retrieve secrets from Conjur</a>
<br>
or
<br>
* <a href="#use-summon">5-Use Summon to retrieve secrets from Conjur</a>



### <a id="create-policy">1-Create and Load Policy on Conjur</a>




Create and load Conjur policy with the following declared resources:             

  * Policy:  Policy id values that identify your Ansible environments.   
  * Human users and grants: Declared groups and users for each Ansible policy id, with role grants.  Grants at this level give privileges to human users to update policy under the policy id.  
  * Layer containing a Host Factory. The layer represents the machine identities that will be created for Ansible hosts. You can Machine identities in a layer are a type of user. (machine users).
  * Layer grants. The layer containing the host factory must be a member of a group that has read and execute (fetch) access to secrets in Conjur.
  * Application policy: Each application requires policy declaring   variables (secrets) that the application requires from Conjur. The application policy also defines access to those secrets (which users and layers can read, execute, and update the secret values). We recommend using a separate policy file per application.  

See <a href="#example-policy-files">Example Policy Files</a> for files to use as a template and the commands to load them. 
  
### <a id="host-factory">2-Generate Host Factory Tokens</a> 
 
A Host Factory token is a temporary secret, required only to establish a machine identity. For more information, see [Host Factory](https://developer.conjur.net/reference/services/host_factory/).

To generate the token, use either Conjur CLI or Conjur API. Here are guidelines for the parameters:  

  *  **time to live**: For Ansible use cases, a short time span (e.g., 5 minutes) for the token's viability is adequate and recommended.  The token is used in the role configuration to establish Conjur machine identities on Ansible nodes.  When the identity is established, the token value is no longer needed.  Typically, a token is required only when you set up a new Ansible node.
  *  **ip subnet**: For added security,  supply the ip subnet of the server that is sending the request for a token. The token is not generated if a request is sent from a different subnet. 
  * **namespace**: Specify the Conjur policy id for which you are creating a Host Factory token. You need a separate token for each policy id.
  
  
##### Using the Conjur CLI: 

For testing purposes, generate Host Factory tokens using the Conjur CLI. Save the returned token value (e.g., as an environment variable) for inserting into the playbook later.  
  

``` 
$ conjur hostfactory tokens create --duration-minutes=5 --cidr 10.0.1.0/24 staging 
$ conjur hostfactory tokens create --duration-minutes=5 --cidr 10.0.1.0/24 production
``` 

##### Using the Conjur API: 

In a secure production environment, you might want to use an API call from Ansible deployment software (for example, a tool like  Cloudformation). Configure your software to insert the token value into the playbook in the `conjur_host_factory_token` parameter under the `configure-conjur-identity` role.      
 
```
 
 ?? example  would be useful 
```


### <a id="conjur-role">3-Use Conjur Role to Create Machine Identities  </a> 

The role creates Conjur machine identities on Ansible nodes. The first time a playbook runs, the role places identity files on the node. In subsequent runs, the role verifies the identity information.

Once a node has a Conjur identity, it can act as a host factory, registering hosts with Conjur.

##### Role Name

The role name is `configure-conjur-identity`.  
 
##### Role Variables

The role uses these variables:

  * `conjur_account` 
  
      Required. The organization account assigned during Conjur appliance installation. If you are using a hosted Conjur instance for a proof of concept, the account is typically your email address.
      
  * `conjur_appliance_url` 
     
      Required. The URL of the Conjur appliance that you are connecting to. ???Is the /api at end of url required or not? 
      
  * `conjur_host_factory_token`
  
      Required. The generated HF token.
      
  * `conjur_host_name` 
  
      Required. The name of the Ansible node that you want to give a Conjur machine identity to.
       
  * `conjur_ssl_certificate`
  
       Required with an HTTPS Conjur endpoint; optional for HTTP. The public SSL certificate of the Conjur endpoint.
      
  * `conjur_validate_certs`
   
      Required with an HTTPS Conjur endpoint; optional for HTTP. Boolean value to indicate if the Conjur endpoint should validate certificates. ??is this true false or 0 / 1 or does it matter? 


##### Example Role Configuration


```
roles:
    - role: configure-conjur-identity
      conjur_account: demo-policy
      conjur_appliance_url: "https://conjur.example.com/api"
      conjur_host_factory_token: ""
      conjur_host_name: "ansible_host1"
      
```       

??There are various differences between the example that was in the readme and Jason's example.I went with Jason's demo example on most. BUT: Is there anything with versions (of Ansible or conjur) that would make these things matter: comma's after every line under role, the ordering of the variable names, different format for URL, actually, I went with the orig full url there: rather than //conjur:3000.

### <a id="define-variables">4-Define Application Variables </a>

1. Applications must be written to accept secrets from variables passed by the playbook on startup.
2. In Conjur application policy, declare each  secret as a Conjur variable. 
3. In Conjur application policy, give read and execute grants for the variables to the appropriate layer. 
    *  For the lookup plugin, the Ansible control node needs access to secrets.
    *  For Summon, the appropriate Ansible remote nodes need access to secrets for the applications they are running.
     
4. Assign values to the variables. You can use the CLI, the API, or the UI (Enterprise Conjur only) to set variable values. 
 
### <a id="use-lookup">5-Use the Lookup Plugin to Retrieve Secrets</a>



**Compatibility: Conjur 4, Conjur 5**

*Note that by default the lookup plugin uses the Conjur 5 API to retrieve secrets. To use Conjur 4 API, set an environment variable CONJUR_VERSION="4".*

Use the`retrieve_conjur_variable` lookup plugin in playbook tasks or scope.

??Does the CONJUR_VERSION env variable apply to Summon usage also? 

#### Example Shell environment variables

```shell
export CONJUR_ACCOUNT="orgaccount"
**export CONJUR_VERSION="4"**
export CONJUR_APPLIANCE_URL="https://conjur-appliance"
export CONJUR_CERT_FILE="/path/to/conjur_certficate_file"
export CONJUR_AUTHN_LOGIN="host/host_indentity"
export CONJUR_AUTHN_API_KEY="host API Key"
```

 

##### Example Playbook scope  


```yml
- hosts: servers
  vars:
    super_secret_key: "{{ lookup('retrieve_conjur_variable', 'path/to/secret') }}"
  tasks:
    ...
```

#### Example Playbook Task
```yml
- hosts: servers
  tasks:
    - name: Retrieve secret with master identity
      vars:
        super_secret_key: "{{ lookup('retrieve_conjur_variable', 'path/to/secret') }}"
      shell: echo "Yay! {{super_secret_key}} was just retrieved with Conjur"
      register: foo
    - debug: msg="the echo was {{ foo.stdout }}"

```
### <a id="use-summon">5-Use Summon to Retrieve Secrets from Conjur</a>

??? We need  to add the "how-to" here.  For an   example,  we can point to the tutorial or blog that is happening.   But we still need instructions here to describle: 

 1.   do they need to install anything on the remote nodes?
 2.   How to invoke summon in the playbook. 
 3.    a secrets file description, which i can probably get from PCF. 
 

## <a id="example-lookup">Lookup Plugin Example</a> 

This example sets up two Ansible environments: staging and production.  Ansible fetches secrets from Conjur for applications running in either environment.   

#### <a id="example-policy-files">Create and Load Example Policy Files</a>     

You can copy and use the following set of .yml files as a template. 

 **ansible-policy.yml** 
   
```
 #  Create production and staging namespaces.
 
  - !policy
    id: staging
  - !policy 
    id: production  
```

 
**ansible-layer.yml**

```
# Create a layer that includes a Host Factory. 
# Load this file under each Ansible policy namespace.
# This layer is a placeholder for your Ansible machines. 

- !policy
  id: ansible-layer  ??I changed this to ansible-layer  
  body: 
  - !layer

  - !host-factory
    layer: [ !layer ]
```

**ansible-users.yml**

```

# Create a security_ops group and add a human user. 
# This ensures that you have a person who can set secret values.


- !group security_ops

- !user
  id: marcel.calisto

- !grant
  role: !group security_ops
  members:
    - !user marcel.calisto
    
# Create other groups and add users to them. 
  ?I feel like we need another group with users. there are no members in the secrets-managers group anywhere. Or can we delete secrets-managers? and just have secrets-users for the layer
```


**ansible-grants.yml**
 

```
# Give permission for the Ansible host layer to retrieve all secrets.  
# Give permission for the security ops team to set secret values.

/* ansible_grants.yml
- !grant
  member: !layer ansible
  roles: 
    - !group staging/foo/secrets-users
    - !group production/foo/secrets-users
   
- !grant
  member: !group security_ops
  roles: 
    - !group staging/foo/secrets-managers
    - !group production/foo/secrets-managers
```

**applications/foo.yml**

```
# We recommend one policy file per application. 
# The separation is an easy way to organize required variables and  
# to assign read and update permissions per application. 

- !policy
  id: foo ??should the id be applications/foo  
  body:
    - &variables
      - !variable database/username
      - !variable database/password

  - !group secrets-users
  - !group secrets-managers

/* Grant permissions for accessing the secret values. 
/* The ansible-grants.yml policy, above,  added the Ansible hosts into the secrets-users group. 
/* The following lines give the hosts permission to access the secrets for this application. 
/* secrets-users can read and execute variable values.
/* read=see the value; execute=fetch the value. 

  - !permit
    resource: *variables
    privileges: [ read, execute ] 
    role: !group secrets-users

/* secrets-managers can update variable values.  
  - !permit
    resource: *variables
    privileges: [ update ]
    role: !group secrets-managers

 /* secrets-managers also have all privileges of secrets-users  
  - !grant
    member: !group secrets-managers
    role: !group secrets-users


```
 
Use the following Conjur commands to load the above policy files: 


  ?  theory Question: are we creating two policy namespaces  that sit under root, or a sibling of root? 
  
  ??I don't understand why we want to suggest replacing what they may already have out there. It makes it sound like they can't run ansible in conjunction with anything else. 
 
 ??I had renamed the policy file to ansible_policy.yml, and the user.yml to ansible-user.yml.  Does that mess up anything? Can we keep the rename?  
  



For Open Source Conjur (v5): 

```
 $ conjur policy load --replace root ansible-policy.yml # load namespaces, replacing the current ones
 $ conjur policy load root ansible-users.yml # load root users & groups
 $ conjur policy load root ansible_grants.yml 

?I added commands for the layer file. (There are a lot of them...would it be better to combine the files so not such a long list of commands to load?)  I had renamed it to ansible-layer. Below, loading into each namespace, OK?


$ conjur policy load staging ansible-layer.yml
$ conjur policy load production ansible-layer.yml
$ conjur policy load staging applications/foo.yml 
$ conjur policy load production applications/foo.yml 

```

For Enterprise Conjur (v4): 

?Since we are saying we support both, and goal is to eliminat confusion, it's not that hard to supply both command sets.  Did I get them right? Do we need --replace in first two commands or not?
  

```
$ conjur policy load root --as-group security_admin ansible-policy.yml 
$ conjur policy load root --as-group security_admin ansible-users.yml
$ conjur policy load root --as-group security_admin ansible_grants.yml 

$ conjur policy load --namespace staging --as-group security_admin ansible-layer.yml
$ conjur policy load --namespace production --as-group security_admin ansible-layer.yml

$ conjur policy load --namespace staging --as-group security_admin applications/foo.yml 
$ conjur policy load --namespace production --as-group security_admin applications/foo.yml 
```

#### Generate Host Factory Token 

 
The following commands use the Conjur CLI to generate host factory tokens, one for each Ansible environment.   You could save the returned values in environment variables for later insertion into the playbook.

``` 
$ conjur hostfactory tokens create --duration-minutes=5 --cidr 10.0.1.0/24 staging 
$ conjur hostfactory tokens create --duration-minutes=5 --cidr 10.0.1.0/24 production
```

#### Use Conjur Role to Create Machine Identities

You can set up two separate playbooks for the two environments, or use environment variables as shown below to manage both environments.   

The machine identities become members of the layers that you created in the application policy files. Their access to secrets is managed through the policy files.

??Just checking, does the below work in Conjur 4?

```
- hosts: myapp-{{ lookup('env', 'APP_ENV') }}
  vars:
    app_environment: "{{ lookup('env', 'APP_ENV') }}"
  roles:
    - role: configure-conjur-identity
      conjur_account: demo-policy
      conjur_appliance_url: "http://conjur.example.com/api"
      conjur_host_factory_token: "{{lookup('env', 'HFTOKEN')}}"
      conjur_host_name: "{{ ansible_hostname }}"
```

 

##### Simple Application 

??I don't think we have an application for the lookup plugin. Would be nice but probably ok without it. Up to you. 

##### Load Variable Values

 We already loaded the policy that declares variables for an application called foo (the `application/foo.yml` policy file). We loaded that policy   under both the staging and production policy spaces, so the following variables are declared in Conjur for both environments.
 

 
 ```
 body:
    - &variables
      - !variable database/username
      - !variable database/password
 ```   
   
We now need to load values into those variables:   
 ?please review commands
 
 ```
$ conjur variable values add staging/database/username oracle-admin
$ conjur variable values add staging/database/password admin-pw
$ conjur variable values add production/database/username oracle-prod-admin 
$ conjur variable values add production/database/password  sedfs524ielsf$al 

 ```
	 

##### Playbook

Here is the entire playbook for retrieving a database username and password for an application named foo, using the `retrieve-conjur-variable` lookup plugin.  

??needs review - i hobbled it from other stuff. It's supposed to call the lookup plugin for an appliation calle foo, that needs two secrets from Conjur (db user and passwrd)  
?? foo is used in first and last statements; probably not good.   
 
 

```yml
- hosts: foo-{{ lookup('env', 'APP_ENV') }}
  vars:
    app_environment: "{{ lookup('env', 'APP_ENV') }}"
  roles:
    - role: configure-conjur-identity
      conjur_account: demo-policy
      conjur_appliance_url: "http://conjur.example.com/api"
      conjur_host_factory_token: "{{lookup('env', 'HFTOKEN')}}"
      conjur_host_name: "{{ ansible_hostname }}"

- hosts: servers
  tasks:
    - name: Retrieve secret 
      vars:
        super_secret_username: {{ lookup('retrieve_conjur_variable', 'APP_ENV'/database/username') }}
        super_secret_passwd: {{ lookup('retrieve_conjur_variable', 'APP_ENV'/database/password') }}
      shell: echo "Passing database creds to your application" 
      register: foo
```

## <a id="summon-example">Summon Example</a> 

?? later. maybe a pointer to a blog.    
 
## <a id="recommend">Recommendations</a>

* Add `no_log: true` to each play that uses sensitive data, otherwise that data can be printed to the logs.
* Set the Ansible files to minimum permissions. The Ansible uses the permissions of the user that runs it.



## <a id="license">License</a>

Apache 2
