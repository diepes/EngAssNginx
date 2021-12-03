# EngAssNginx
Nginx terraform deployment to AWS
# ToDo
 1. remove ssh from sg
 
# Exercise (Infra)
Use Ansible and/or Terraform to automate the process of creating an AWS EC2 instance and
complete the following tasks:
1. The deployment should take AWS credentials and AWS region as input parameters.
2. A VPC with the required networking, don't use the default VPC.
3. Provision a “t2.micro” EC2 instance, with an OS of your choice.
4. Change the security group of the instance to ensure its security level.
5. Change the OS/Firewall settings of the started instance to further enhance its security
level.
6. Install Docker CE.
7. Deploy and start a NGINX docker container in the EC2 instance.
8. Deploy a script (or multiple scripts) on the EC2 instance to complete the following subtasks:
a. Log the health status and resource usage of the NGINX container every 10 seconds
into a log file.
b. Write a REST API using any choice of programming language which is you are familiar
with and read from the above log file able to a basic search. (Provide us and
example use of your API using curl or any REST client)
9. A README.md describing what you've done as well as steps explaining how to run the
infrastructure automation and execute the script(s).
10. Describe any risks associated with your application/deployment.
Bonus Points
1. Show the result of the resource.log on a webpage served from the NGINX server
if you have any questions about the assignment feel free to reach out to us.

# Prerequisites
  1. install terraform commandline util >=v1.0.11
     * https://www.terraform.io/downloads.html
  2. aws user and access keys, IAM users should belong to AdminUsers
     * Set env variables with correct credentials e.g.
     ```
     export AWS_ACCESS_KEY_ID=<aws-access-id>
     export AWS_SECRET_ACCESS_KEY=<aws-secret>
     export AWS_DEFAULT_REGION=ap-southeast-2
     ```
     verify with ```aws sts get-caller-identity```

# Infra deployment
   1. cd terraform
   2. terraform init
   3. terraform apply




