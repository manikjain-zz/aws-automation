# SSH Access - Ansible setup

The Ansible playbook here uses Github user public keys to create a user account on a set of EC2 machines.

Table of Contents
=================
* [Prerequisites](#prerequisites)
* [Run the playbook](#run-the-playbook)

## Prerequisities

1. Follow https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html to install the AWS EC2 collection to create a dynamic inventory.
2. Make sure `boto3` and `botocore` are installed. Install required Ansible roles: `ansible-galaxy install -r requirements.yml --force`
3. Add your AWS credentials to the `aws_ec2.yml` file.
4. Add any users who need access to `github_users` in `vars/main.yml` by specifying their github account name.
5. To remove any users who've been previously provided with access, add their usernames to `github_absent` in `vars/main.yml` and remove the same from `github_users`.

## Run the playbook

- Verify AWS inventory with `ansible-inventory --graph -i aws_ec2.yml`.
- Run the playbook: `ansible-playbook -i aws_ec2.yml  main.yml`. (the associated private key to access the EC2 servers would be required)
