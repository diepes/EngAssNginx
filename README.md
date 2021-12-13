# EngAssNginx
Nginx terraform deployment to AWS

# Overview
  1. Git repo, ./http dir served by Nginx on deployment through terraform.
  1. AWS LB setup for plain http/80  for demo.  (For tls/https, need dns + cert)
  1. AWS LB setup for dual use Nginx + MonitorAPI,  Nginx - default and api mapped to path /api on same LB url.
  1. Hardening 
     - ec2 private ip, no ssh key
     - SG limited to SG LB inbound.
     - only https outbound for container load
     - additional IPTABLES rules to limit inbound to local RFC1918 ips, port 80 & 82 Nginx+API.
     - Further hardening recommendations below.
# Deployment
 
 1. In Linux or WSL2 Linux , and utilities 
    1. Utilities needed.
       - terraform > v1
       - git
       - curl, jq (optional)

 1. git clone https://github.com/diepes/EngAssNginx.git
    * For testing, might be better to fork repo, checkout fork,
        and update terraform.tfvars gitrepo

 1. Set aws credentials as environment variables.

         export AWS_ACCESS_KEY_ID=AK...67
         export AWS_SECRET_ACCESS_KEY=qOW......NN
         printenv | grep AWS  
     * verify with $ `aws sts get-caller-identity`

 1. Review terraform.tfvars, and edit as needed

         cat terraform/terraform.tfvars     
     * Note: 
         * if gitbranch / repo changed, remember to create branch with same name.

 1. Deploy to AWS, webserver and content under html
 
        cd EngAssNginx/terraform
        terraform init
        # First deploy vpc and subnets
        terraform apply --target module.vpc
        # Now deploy everyting.
        terraform apply

  1. The output of the terraform script should provide the aws LB url, open in browser.

         export URL=$(terraform output loadbalancerURL)|tr -d '"';echo "URL=$URL"
         echo "URL=$URL"
         # export URL="nginx-server......ap-southeast-2.elb.amazonaws.com"
         curl -is http://$URL/
         curl -is http://$URL/resources.log
         curl -is http://$URL/api
         curl -is http://$URL/api/doc

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

 1. SSL cert + Domain name
 1. ASG > 1 instance. (Rolling updates)
 1. Split out monitoring from main LB.
 1. PrivateLink s3 - docker pull (Remove Nat GW's)
 1. WAF on LB, or CloudFront+WAF

# Exercise (Infra)

## Use Ansible and/or Terraform to automate the process of creating an AWS EC2 instance and
complete the following tasks:
 1. The deployment should take AWS credentials and AWS region as input parameters.
    - Done. Set env vars. AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY
 2. A VPC with the required networking, don't use the default VPC.
    - Done
 3. Provision a “t2.micro” EC2 instance, with an OS of your choice.
    - Done (ASG - auto replace on LB health failure)
 4. Change the security group of the instance to ensure its security level.
    - Done: Ingress only LB tcp/80 and tcp/82 and limit to LB sg.
       - Setup SSM role to connect to instance for debug etc. through AWS console
       - Outound only allow https to pull container.
          - Pull nginx container from public.ecr.aws.
          - Future AWS PrivateGW s3.
 5. Change the OS/Firewall settings of the started instance to further enhance its security level.
    - Done.  IPTABLES, INPUT policy DROP, limit to rfc1918 ip's. 
 6. Install Docker CE.
    - Done. Part of instance launch.
 7. Deploy and start a NGINX docker container in the EC2 instance.
    - Done. Part of instance launch, setup as systemd service.
 8. Deploy a script (or multiple scripts) on the EC2 instance to complete the following subtasks:
    - Log the health status and resource usage of the NGINX container every 10 seconds into a log file.
      - Done- /var/log/resource.log
         - Update with cronjob - git pull every 5min, allow web update.
    - Write a REST API using any choice of programming language which is you are familiar with and read from the above log file able to a basic search. (Provide us an example use of your API using curl or any REST client)
      - Done. Python  see http://<lb url>/api/doc

 9. A README.md describing what you've done as well as steps explaining how to run the infrastructure automation and execute the script(s).
    - Done see above.

 10. Describe any risks associated with your application/ eployment.
     - Risks:
       1. dos - single vm, no scaling or CDN
          - deploy behind CDN, e.g. cloudfront
          - can ajust the ASG counters to run multiple web servers.
          - add WAF.
       1. Instance crash/hang
          - mitigated by using ASG to launce instance.  
          - If LB detects problem with instance a new one is launched.  Should recover in under 5min
       1. http - plain http, clear text - should be https, with dns etc.
          - Done for demo.  Just need to add dns and cert to LB.
          - deploy behind lb / cloudfront with ssl terminated on cloudfront / lb,
          - certificate in aws certstore, thus no pvt key on server.
          - if required encrypt traffic between ec2-container(nginx) and lb, with selfsigned long lived certificate
       1. deployment down time 
          - any change to the terraform deployment result in recreation of intance.
          - mostly mitigated by using ASG with rolling upd.
          - asg will have to be >=2 instance, as logic is stop then start new.
       1. deployment down time due to breaking html content changes.
          - add pipeline and some testing.
       1. downtime due to AZ outage or vm outage, single instance in single az
          - use more than one instance multi az (Just require more ASG instances)
          - asg will already launc new instance if an AZ fails.
          - if only static content, consider using s3 + cloudfront for the content hosting
  
       1. The monitoring API, should not be exposed through public URL.
          - Only done for demo, no internal monitoring.
       1. add AWS WAF on LB, or Cloudfront.
       1. run docker container as non root user.
       1. run api python script as container.
### Bonus Points
 1. Show the result of the resource.log on a webpage served from the NGINX server
   if you have any questions about the assignment feel free to reach out to us.
    - Done 
          http://$URL/resource.log   
          export URL=$( terraform output loadbalancerURL |tr -d '"'); echo "URL=$URL"
          # And / or
          curl -s -X "GET"  -H "accept: application/json" \
            "http://$URL/api/logs/searchtime/?start=$(date +%s --date='1 minutes ago')&end=$(date +%s)" |jq -c '.[]' 

The END.
