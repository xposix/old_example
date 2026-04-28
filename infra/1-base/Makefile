# Copyright 2016 Philip G. Porada
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


CURRENT_FOLDER=$(shell basename "$$(pwd)")
BOLD=$(shell tput bold)
BLACK=$(shell tput setaf 0)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
BLUE=$(shell tput setaf 4)
WHITEBG=$(shell tput setab 7)
RESET=$(shell tput sgr0)

SHELL:=/bin/bash

ifndef ENVIRONMENT_NAME
  $(error ENVIRONMENT_NAME variable is not set, this needs to be set to select an environment to deploy)
endif

ifeq ($(ENVIRONMENT_NAME), prod)
	ENVIRONMENT_TYPE:=$(ENVIRONMENT_NAME)
	ENVIRONMENT_FILE:=$(ENVIRONMENT_NAME)
else ifeq (${ENVIRONMENT_NAME}, dev)
	ENVIRONMENT_TYPE:=$(ENVIRONMENT_NAME)
	ENVIRONMENT_FILE:=$(ENVIRONMENT_NAME)
endif

.PHONY: apply plan prep
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

prep:
	@echo
	@echo
	@echo "$(BOLD)$(BLUE)#################################$(RESET) BEGIN $(CURRENT_FOLDER) $(BOLD)$(BLUE)##################################$(RESET)"

init: prep ## Initialises Terraform on this directory.
	@rm -rf .terraform
	terraform init ${EXTRA_INIT_FLAGS} \
		-lock=true \
		-backend-config="bucket=exampleco-tfstate-local-projects-${ENVIRONMENT_TYPE}" \
		-backend-config="key=gitlab.com/example_org/client-app/${ENVIRONMENT_NAME}/1-base/terraform.tfstate" \
		-input=false
	@echo
	@echo "$(BLUE)##################################$(RESET) END $(CURRENT_FOLDER) $(BOLD)$(BLUE)################################## $(RESET)"

.upgrade-providers:
	@rm -f .terraform.lock.hcl
	terraform providers lock -platform=darwin_amd64 -platform=linux_amd64 -platform=darwin_arm64

init-upgrade: .upgrade-providers init ## Forces an init with updated Terraform providers
	@echo "Remember to commit the new .terraform.lock.hcl file"

plan: init prep ## Show what terraform thinks it will do
	terraform plan \
		-lock=true \
		-input=false \
		-var-file="../../env-common.tfvars" \
		-var-file="../../env-${ENVIRONMENT_FILE}.tfvars" \
		-var="environment_name=${ENVIRONMENT_NAME}" \
		-var="environment_type=${ENVIRONMENT_TYPE}" \
		-compact-warnings \
		-refresh=true
	@echo "$(BOLD)$(BLUE)##################################$(RESET) END $(CURRENT_FOLDER) $(BOLD)$(BLUE)################################## $(RESET)"

apply: init prep ## Have terraform do the things. This will cost money.
	terraform apply -auto-approve \
		-lock=true \
		-var-file="../../env-common.tfvars" \
		-var-file="../../env-${ENVIRONMENT_FILE}.tfvars" \
		-var="environment_name=${ENVIRONMENT_NAME}" \
		-var="environment_type=${ENVIRONMENT_TYPE}" \
		-compact-warnings \
		-refresh=true
	@echo "$(BOLD)$(BLUE)##################################$(RESET) END $(CURRENT_FOLDER) $(BOLD)$(BLUE)################################## $(RESET)"

destroy: init prep ## Destroys all the resources created/managed by this code.
	-terraform state rm 'kubernetes_namespace.exampleco'
	terraform destroy -auto-approve \
		-lock=true \
		-var-file="../../env-common.tfvars" \
		-var-file="../../env-${ENVIRONMENT_FILE}.tfvars" \
		-var="environment_name=${ENVIRONMENT_NAME}" \
		-var="environment_type=${ENVIRONMENT_TYPE}" \
		-compact-warnings \
		-refresh=true
	@echo "$(BOLD)$(BLUE)##################################$(RESET) END $(CURRENT_FOLDER) $(BOLD)$(BLUE)################################## $(RESET)"
