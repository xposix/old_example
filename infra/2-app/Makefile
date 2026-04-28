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
GIT_ROOT:=$(shell git rev-parse --show-toplevel)

ifndef ENVIRONMENT_NAME
  $(error ENVIRONMENT_NAME variable is not set, this needs to be set to select an environment to deploy)
endif

ifeq ($(ENVIRONMENT_NAME), prod)
	ENVIRONMENT_TYPE:=$(ENVIRONMENT_NAME)
	ENVIRONMENT_FILE:=$(ENVIRONMENT_NAME)
	DEPLOYMENT_REPLICATION:=true
else ifeq (${ENVIRONMENT_NAME}, dev)
	ENVIRONMENT_TYPE:=$(ENVIRONMENT_NAME)
	ENVIRONMENT_FILE:=$(ENVIRONMENT_NAME)
	DEPLOYMENT_REPLICATION:=false
endif

export AWS_REGION := $(shell cat ../../env-common.tfvars | grep primary_region | awk '{print $$3}' | sed 's/"//g')
.PHONY: apply plan prep
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

prep:
	@echo
	@echo
	@echo "$(BOLD)$(BLUE)#################################$(RESET) BEGIN $(CURRENT_FOLDER) $(BOLD)$(BLUE)##################################$(RESET)"

operator-apply:
	@echo "$(YELLOW)Deploying ArangoDB Operator...$(RESET)"
	@OPERATOR_VERSION=$$(grep arango_db_k8s_operator_version ../../env-${ENVIRONMENT_FILE}.tfvars | awk '{print $$3}' | tr -d '"') ;\
	CLUSTER_NAME=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/eks_cluster/general/name" --query "Parameter.Value" --output text) ;\
	aws eks update-kubeconfig --name $${CLUSTER_NAME} --region $${AWS_REGION} ;\
	NAMESPACE=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/k8s_namespace/app/name" --query "Parameter.Value" --output text) ;\
	URLPREFIX=https://gitlab.com/arangodb/kube-arangodb/releases/download/$${OPERATOR_VERSION} ;\
	helm upgrade --install arangodb -n $${NAMESPACE} $${URLPREFIX}/kube-arangodb-$${OPERATOR_VERSION}.tgz  \
	--set DeploymentReplication.Create=${DEPLOYMENT_REPLICATION} \
	--set "operator.features.storage=true" \
	--set "operator.features.backup=true" \
	--set "operator.architectures={amd64,arm64}" \
	--set "deployment.spec.architecture=amd64"

init: prep ## Fulfills the Helm chart dependencies
	@cd client-app; helm dependency update

apply: prep init operator-apply ## Deploy the helm chart to the cluster
	echo "$(YELLOW)Deploying Client App...$(RESET)" ;\
	NAMESPACE=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/k8s_namespace/app/name" --query "Parameter.Value" --output text) ;\
	REDIS_PASSWORD=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/redis/database_credentials/password" --query "Parameter.Value" --output text) ;\
	CLIENT_APP_SSL_CERT_ARN=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/acm/client_app/cert_arn" --query "Parameter.Value" --output text) ;\
	CLIENT_APP_PRIMARY_DOMAIN=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/route53/client_app/primary_domain_name" --query "Parameter.Value" --output text) ;\
	CLIENT_APP_POD_ROLE_ARN=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/iam/client_app_role/arn" --query "Parameter.Value" --output text) ;\
	CLIENT_APP_IMAGE_VERSION=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/app/client-app/version" --query "Parameter.Value" --output text) ;\
	CELERY_IMAGE_VERSION=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/app/celery/version" --query "Parameter.Value" --output text) ;\
	DB_CREDENTIALS_SECRET_ARN=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/secret/rds_database_credentials/arn" --query "Parameter.Value" --output text) ;\
	GIT_SHA1=$$(git rev-parse HEAD) ;\
	cd client-app; helm upgrade --install client-app -n $${NAMESPACE} . \
		 -f ${GIT_ROOT}/env-${ENVIRONMENT_FILE}-values.yaml \
		 --set "clientApp.ingress.annotations.alb\.ingress\.kubernetes\.io/certificate-arn=$${CLIENT_APP_SSL_CERT_ARN}" \
		 --set "clientApp.ingress.annotations.external-dns\.alpha\.kubernetes\.io/hostname=$${CLIENT_APP_PRIMARY_DOMAIN}" \
		 --set "clientApp.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$${CLIENT_APP_POD_ROLE_ARN}" \
		 --set "clientApp.configurationSecretName=/$${ENVIRONMENT_NAME}/3rd_party/client_app/configuration" \
		 --set "clientApp.dbSecretArn=$${DB_CREDENTIALS_SECRET_ARN}" \
		 --set "redis.auth.enabled=true" \
		 --set "redis.auth.password=$${REDIS_PASSWORD}" \
		 --set "clientApp.image.tag=$${CLIENT_APP_IMAGE_VERSION}" \
		 --set "clientApp.podLabels.git_sha1=$${GIT_SHA1}" \
		 --set "celery.image.tag=$${CELERY_IMAGE_VERSION}" \
		 --set "celery.podLabels.git_sha1=$${GIT_SHA1}" \
		 --set "secretConfiguration.region_name=$${AWS_REGION}"
	@echo "$(BOLD)$(BLUE)##################################$(RESET) END $(CURRENT_FOLDER) $(BOLD)$(BLUE)################################## $(RESET)"

destroy: prep ## Destroy the Helm chart
	@NAMESPACE=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/k8s_namespace/app/name" --query "Parameter.Value" --output text) ;\
	CLUSTER_NAME=$$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/eks_cluster/general/name" --query "Parameter.Value" --output text) ;\
	aws eks update-kubeconfig --name $${CLUSTER_NAME} --region $${AWS_REGION} ;\
	helm delete client-app -n $${NAMESPACE};\
	echo "$(YELLOW)Sleeping for 60 seconds to allow for the client-app to be deleted before deleting the Arangodb Operator...$(RESET)" ;\
	sleep 60 ;\
	helm delete arangodb -n $${NAMESPACE}
	@echo "$(BOLD)$(BLUE)##################################$(RESET) END $(CURRENT_FOLDER) $(BOLD)$(BLUE)################################## $(RESET)"