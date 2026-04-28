# Everything @makefile

CURRENT_FOLDER=$(shell basename "$$(pwd)")
BOLD=$(shell tput bold)
BLACK=$(shell tput setaf 0)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
BLUE=$(shell tput setaf 4)
WHITEBG=$(shell tput setab 7)
RESET=$(shell tput sgr0)

.PHONY: apply plan init

ifndef ENVIRONMENT_NAME
  $(error ENVIRONMENT_NAME variable is not set, this needs to be set to select an environment to deploy)
endif

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

header:
	@echo "$(BOLD)$(GREEN)##################################################################################################################$(RESET)"
	@echo "                                                    $(BOLD)$(YELLOW)$(CURRENT_FOLDER)$(RESET)"
	@echo "$(BOLD)$(GREEN)##################################################################################################################$(RESET)"

init: ## Performs a Terraform Init across all the infra directory
	@make -C infra/1-base init
	@make -C infra/2-app init

init-upgrade: ## Performs a Terraform init-upgrade across all the accounts
	make -C infra/1-base init-upgrade

plan: ## Inits and Plans for changes (mostly Terraform code)
	@make -C infra/1-base plan

apply: header ## Inits and Deploys all the changes in Terraform and Serverless
	@make -C infra/1-base apply
	@make -C infra/2-app apply

destroy: header ## Destroy everything deployed by this repo
	@make -C infra/2-app destroy
	@make -C infra/1-base destroy

