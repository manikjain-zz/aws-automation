# AWS automation
This project demonstrates provisioning automation and management of infrastructure in AWS via Terraform, Ansible scripts.

Table of Contents
=================
* [Prerequisites](#prerequisites)
* [About the project](#about-the-project)
  * [AWS Automation via Terraform](#aws-automation-via-terraform)
* [Run the script](#run-the-script)

## Prerequisites:
1. Terraform (> v0.13.5) must be installed on your machine to run `main.tf`.
2. Ansible (> v2.9) must be installed on your machine to run the playbook inside `ssh_access/` directory.
3. Update the `shared_credentials_file` with your AWS credentials file path inside `main.tf`.

## About the project

### AWS Automation via Terraform

- Creates a VPC with both a public and private subnet.
- Launches an ec2 instance, inside the public subnet of the VPC, and
installs apache on it via bootstrapping.
- Adds a NAT gateway and an Internet gateway to the VPC.
- Creates a load balancer in the public subnet of the VPC.
- Adds the ec2 instance, under the load balancer.
- Creates an auto scaling group with minimum size of 1 and maximum size of 3 with the load
balancer created previously.
- Add an instance under the auto scaling group. (Uses an AMI created
out of the previously provisioned instance which has apache installed on it)
- Uses a life cycle policy with the following parameters:
scale in : CPU utilization > 80%
scale out : CPU Utilization < 60%
- Automates via Ansible granting/revoking of SSH access to a group of servers instances for a new developer.

## Run the script
1. Run `terraform apply` inside this directory to apply the changes as described above in your AWS infrastructure.

