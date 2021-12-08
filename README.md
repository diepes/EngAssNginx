# EngAssNginx
Nginx terraform deployment to AWS

# Deployment

 1. In Linux or WSL2 Linux , and utilities 
    1. Utilities needed.
       - terraform > v1
       - git
       - curl, jq (optional)

 1. git clone https://github.com/diepes/EngAssNginx.git
    * For testing, might be better to fork repo, checkout fork, and update terraform.tfvars gitrepo

 1. Set aws credentials as environment variables.

         export AWS_ACCESS_KEY_ID=AK...67
         export AWS_SECRET_ACCESS_KEY=qOW......NN
         export AWS_DEFAULT_REGION=ap-southeast-2
         printenv | grep AWS  
     * verify with $ `aws sts get-caller-identity`

 1. Review terraform.tfvars, and edit as needed

         cat terraform/terraform.tfvars     
     * Note: if gitbranch changed, remember to create branch with same name.

 1. Deploy to AWS, webserver and content under html
 
        cd EngAssNginx/terraform
        terraform init
        terraform apply

  1. The output of the terraform script should provide the aws LB url, open in browser.

         export URL=$( terraform output | grep -oP '(?<=loadbalancerURL = ").+(?=")' )
         echo "URL=$URL"
         # export URL="nginx-server......ap-southeast-2.elb.amazonaws.com"
         curl -is http://$URL/
         curl -is http://$URL/resources.log
         curl -is http://$URL/api/log/

         curl -s -X "GET"  -H "accept: application/json" \
                  "http://$URL/api/logs/searchtime/?start=$(date +%s --date='1 minutes ago')&end=$(date +%s)" \
                  | jq -c '.[]' 

  1. Update website

         edit html/index.html
         git add .
         git commit -m "Updated html/index.html"
         git push
         curl http:/$URL/api/update-website

         # Reload web page should be visible in <5 min

# ToDo

 1. remove ssh access from sg - for production deployment. Maybe add ssm access ?
 2. terraform/ec2-userdata.yaml  chainge branche from "test" to "main" git checkout
 3. remove terraform/asg+lb.tf if not planning to use it.

# Exercise (Infra)
<details>
Use Ansible and/or Terraform to automate the process of creating an AWS EC2 instance and
complete the following tasks:
1. The deployment should take AWS credentials and AWS region as input parameters.
2. A VPC with the required networking, don't use the default VPC.
   - Done
3. Provision a “t2.micro” EC2 instance, with an OS of your choice.
   - Done
4. Change the security group of the instance to ensure its security level.
   ToDo: remove SSH access,  use git pull, rather than ansible deploy
5. Change the OS/Firewall settings of the started instance to further enhance its security
level.
   - 
6. Install Docker CE.
7. Deploy and start a NGINX docker container in the EC2 instance.
8. Deploy a script (or multiple scripts) on the EC2 instance to complete the following subtasks:
   a. Log the health status and resource usage of the NGINX container every 10 seconds into a log file.
      Done- /var/log/resource.log
   b. Write a REST API using any choice of programming language which is you are familiar
      with and read from the above log file able to a basic search. (Provide us and
      example use of your API using curl or any REST client)

9. A README.md describing what you've done as well as steps explaining how to run the
infrastructure automation and execute the script(s).

10. Describe any risks associated with your application/deployment.
  - Risks:
      1. dos - single vm, no scaling or CDN
         - deploy behind CDN, e.g. cloudfront
      1. http - plain http, clear text - should be https, with dns etc.
         - deploy behind lb / cloudfront with ssl terminated on cloudfront / lb, certificate in aws certstore, thus no pvt key on server.
         - if required encrypt traffic between ec2-container(nginx) and lb, with selfsigned long lived certificate
      1. deployment down time - any change to the terraform deployment result in destroy and recreation of intance, and i change.
         - ip can be fixed with just adding reserved-ip
         - deployment downtime due to ec2 replacement with asg and rolling update policy + LB
      1. deployment down time due to html content changes.
      1. downtime due to AZ outage or vm outage, single instance in single az
         - use more than one instance multi az
         - if only static content, consider using s3 + cloudfront for the content hosting

Bonus Points
1. Show the result of the resource.log on a webpage served from the NGINX server
   if you have any questions about the assignment feel free to reach out to us.
   Done /resource.log
</details>



The END.
