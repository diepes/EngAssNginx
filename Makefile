# Modified from:
# Copyright 2016 Philip G. Porada
# https://github.com/pgporada/terraform-makefile/blob/master/Makefile
# Notes:
#   first command is used when running only make
#   @ runs command with no echo

.ONESHELL: # Applies to every target in the file!
.SHELL := /usr/bin/bash
.PHONY: apply destroy-backend destroy destroy-target plan-destroy plan plan-target prep
ENV?="dev"
#VARS="variables-$(ENV).tfvars"
VARS="terraform.tfvars"
CURRENT_FOLDER=$(shell basename "$$(pwd)")
MAKE_FOLDER=$$(pwd)
TERRAFORM_FOLDER="$$(pwd)/terraform"
TF_OUTPUT_URL=$(shell cd $(TERRAFORM_FOLDER); terraform output loadbalancerURL | tr -d '"')
SET_URL=$(eval URL=$(TF_OUTPUT_URL))
# S3_BUCKET="$(ENV)-$(REGION)-yourCompany-terraform"
# DYNAMODB_TABLE="$(ENV)-$(REGION)-yourCompany-terraform"
# WORKSPACE="$(ENV)-$(REGION)"
BOLD=$(shell tput bold)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
RESET=$(shell tput sgr0)

# Check for necessary tools
# ifeq (, $(shell which aws))
# 	$(error "No aws in $(PATH), go to https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html, pick your OS, and follow the instructions")
# endif
ifeq (, $(shell which jq))
	$(error "No jq in $(PATH), please install jq")
endif
ifeq (, $(shell which terraform))
	$(error "No terraform in $(PATH), get it from https://www.terraform.io/downloads.html")
endif

#1st entry used nothing after $ make
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo "MAKEFILE_LIST=$(MAKEFILE_LIST)"

set-env:
	@if [ -z $(ENV) ]; then \
		echo "$(BOLD)$(RED)ENV was not set - SET to \"dev\"$(RESET)"; \
		ENV:="dev"; \
		echo "ENV = $(ENV)"; \
		#ERROR=1; \
	fi
	@ #if [ -z $(REGION) ]; then \
	# 	echo "$(BOLD)$(RED)REGION was not set$(RESET)"; \
	# 	ERROR=1; \
	#  fi
	@if [ -z $(AWS_PROFILE) ] && ([ -z $(AWS_ACCESS_KEY_ID) ] || [ -z $(AWS_SECRET_ACCESS_KEY) ]); then \
		echo "$(BOLD)$(RED)AWS_PROFILE was not set. ${AWS_ACCESS_KEY_ID}$(RESET)"; \
		ERROR=1; \
	 fi
	@if [ ! -z $${ERROR} ] && [ $${ERROR} -eq 1 ]; then \
		echo "$(BOLD)Example usage: \`AWS_PROFILE=whatever ENV=demo REGION=us-east-2 make plan\`$(RESET)"; \
		exit 1; \
	 fi
	@if [ ! -f "$(TERRAFORM_FOLDER)/$(VARS)" ]; then \
		echo "$(BOLD)$(RED)Could not find variables file: $(TERRAFORM_FOLDER)/$(VARS)$(RESET)"; \
		exit 1; \
	 fi

prep: set-env ## Prepare a new workspace (environment) if needed, configure the tfstate backend, update any modules, and switch to the workspace
# 	@echo "$(BOLD)Verifying that the S3 bucket $(S3_BUCKET) for remote state exists$(RESET)"

# 	@echo "$(BOLD)Verifying that the DynamoDB table exists for remote state locking$(RESET)"
# 		echo "$(BOLD)$(GREEN)DynamoDB Table $(DYNAMODB_TABLE) exists$(RESET)"; \
# 	 fi
# 	@aws ec2 --profile=$(AWS_PROFILE) --region=$(REGION) describe-key-pairs | jq -r '.KeyPairs[].KeyName' | grep "$(ENV)_infra_key" > /dev/null 2>&1; \
# 	if [ $$? -ne 0 ]; then \
# 		echo "$(BOLD)$(RED)EC2 Key Pair $(ENV)_infra_key was not found$(RESET)"; \
# 		read -p '$(BOLD)Do you want to generate a new keypair? [y/Y]: $(RESET)' ANSWER && \
# 		if [ "$${ANSWER}" == "y" ] || [ "$${ANSWER}" == "Y" ]; then \
# 			mkdir -p ~/.ssh; \
# 			ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/$(ENV)_infra_key; \
# 			aws ec2 --profile=$(AWS_PROFILE) --region=$(REGION) import-key-pair --key-name "$(ENV)_infra_key" --public-key-material "file://~/.ssh/$(ENV)_infra_key.pub"; \
# 		fi; \
# 	  else \
# 		  echo "$(BOLD)$(GREEN)EC2 Key Pair $(ENV)_infra_key exists$(RESET)";\
# 	  fi
# 	@echo "$(BOLD)Configuring the terraform backend$(RESET)"
# 	@terraform init \
# 		-input=false \
# 		-force-copy \
# 		-lock=true \
# 		-upgrade \
# 		-verify-plugins=true \
# 		-backend=true \
# 		-backend-config="profile=$(AWS_PROFILE)" \
# 		-backend-config="region=$(REGION)" \
# 		-backend-config="bucket=$(S3_BUCKET)" \
# 		-backend-config="key=$(ENV)/$(CURRENT_FOLDER)/terraform.tfstate" \
# 		-backend-config="dynamodb_table=$(DYNAMODB_TABLE)"\
# 		-backend-config="acl=private"
# 	@echo "$(BOLD)Switching to workspace $(WORKSPACE)$(RESET)"
# 	@terraform workspace select $(WORKSPACE) || terraform workspace new $(WORKSPACE)

tf-plan: prep ## Show what terraform thinks it will do
	@cd $(TERRAFORM_FOLDER); \
	terraform plan \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(VARS)"

tf-format: prep ## Rewrites all Terraform configuration files to a canonical format.
	@cd $(TERRAFORM_FOLDER); \
	terraform fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
tf-lint: ## Check for possible errors, best practices, etc in current directory!
	docker run --rm -v $(pwd)/$(TERRAFORM_FOLDER):/data:ro -t ghcr.io/terraform-linters/tflint --enable-plugin=aws --loglevel=info

# https://github.com/liamg/tfsec
tf-check-security:  ## Static analysis of your terraform templates to spot potential security issues.
	docker run --rm -it -v "$(TERRAFORM_FOLDER):/$(TERRAFORM_FOLDER):ro" aquasec/tfsec /$(TERRAFORM_FOLDER)

# @cd $(TERRAFORM_FOLDER); \
# tfsec .

tf-documentation: prep ## Generate README.md for a module
	docker run --rm --volume "$(TERRAFORM_FOLDER):/terraform-docs" -u $$(id -u) quay.io/terraform-docs/terraform-docs:0.16.0 markdown table /terraform-docs | tee $(TERRAFORM_FOLDER)/README.md
	echo "Updated $(TERRAFORM_FOLDER)/README.md"

tf-plan-target: prep ## Shows what a plan looks like for applying a specific resource
	@echo "$(YELLOW)$(BOLD)[INFO]   $(RESET)"; echo "Example to type for the following question: module.rds.aws_route53_record.rds-master"
	@cd $(TERRAFORM_FOLDER); \
	read -p "PLAN target: " DATA && \
		terraform plan \
			-lock=true \
			-input=true \
			-refresh=true \
			-var-file="$(VARS)" \
			-target=$$DATA

tf-plan-destroy: prep ## Creates a destruction plan.
	@cd $(TERRAFORM_FOLDER); \
	terraform plan \
		-input=false \
		-refresh=true \
		-destroy \
		-var-file="$(VARS)"

tf-output: prep ## terraform output variables.
	@cd $(TERRAFORM_FOLDER); \
	terraform output

    #URL != terraform output loadbalancerURL;

curl-lb:
	@$(SET_URL)
	if [ -z $(URL) ]; then \
		echo "$(BOLD)$(RED)Terraform output URL=$(URL) not set, run $ make apply$(RESET)"; \
		exit 1; \
	fi
	echo "curl -is http://$(URL)/instance-i"


tf-apply: prep ## Have terraform do the things. This will cost money.
	@cd $(TERRAFORM_FOLDER); \
	terraform apply \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(VARS)"

tf-destroy: prep ## Destroy the things
	@cd $(TERRAFORM_FOLDER); \
	terraform destroy \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(VARS)"

tf-destroy-target: prep ## Destroy a specific resource. Caution though, this destroys chained resources.
	@echo "$(YELLOW)$(BOLD)[INFO] Specifically destroy a piece of Terraform data.$(RESET)"; echo "Example to type for the following question: module.rds.aws_route53_record.rds-master"
	@cd $(TERRAFORM_FOLDER); \
	read -p "Destroy target: " DATA && \
		terraform destroy \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file=$(VARS) \
		-target=$$DATA

tf-destroy-backend: ## Destroy S3 bucket and DynamoDB table
	@if ! aws --profile $(AWS_PROFILE) dynamodb delete-table \
		--region $(REGION) \
		--table-name $(DYNAMODB_TABLE) > /dev/null 2>&1 ; then \
			echo "$(BOLD)$(RED)Unable to delete DynamoDB table $(DYNAMODB_TABLE)$(RESET)"; \
	 else
		echo "$(BOLD)$(RED)DynamoDB table $(DYNAMODB_TABLE) does not exist.$(RESET)"; \
	 fi
	@if ! aws --profile $(AWS_PROFILE) s3api delete-objects \
		--region $(REGION) \
		--bucket $(S3_BUCKET) \
		--delete "$$(aws --profile $(AWS_PROFILE) s3api list-object-versions \
						--region $(REGION) \
						--bucket $(S3_BUCKET) \
						--output=json \
						--query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" > /dev/null 2>&1 ; then \
			echo "$(BOLD)$(RED)Unable to delete objects in S3 bucket $(S3_BUCKET)$(RESET)"; \
	 fi
	@if ! aws --profile $(AWS_PROFILE) s3api delete-objects \
		--region $(REGION) \
		--bucket $(S3_BUCKET) \
		--delete "$$(aws --profile $(AWS_PROFILE) s3api list-object-versions \
						--region $(REGION) \
						--bucket $(S3_BUCKET) \
						--output=json \
						--query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" > /dev/null 2>&1 ; then \
			echo "$(BOLD)$(RED)Unable to delete markers in S3 bucket $(S3_BUCKET)$(RESET)"; \
	 fi
	@if ! aws --profile $(AWS_PROFILE) s3api delete-bucket \
		--region $(REGION) \
		--bucket $(S3_BUCKET) > /dev/null 2>&1 ; then \
			echo "$(BOLD)$(RED)Unable to delete S3 bucket $(S3_BUCKET) itself$(RESET)"; \
	 fi
