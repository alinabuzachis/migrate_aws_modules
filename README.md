# AWS modules migration script from community.aws to amazon.aws


## Usage
Create a GitHub personal access token to use in place of a password with the API and set it withing the username inside run.sh. In addition, please specify the name of the AWS module you want to migrate.
```bash
export GITHUB_TOKEN="Token ..."
export USERNAME="github username"
module_to_migrate=ec2_vpc_igw
```

Finally, run the script.
```bash
$ ./run.sh
```
