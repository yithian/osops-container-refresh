#!/usr/bin/env bash

set -vx

set -o errexit
set -o errtrace

HTUSER_FILE="openshift-ansible-private/private_vars/global/aws/openshiftops/prod/reg-aws/htpasswd_users.yml"

DOCKER_REGISTRY="registry.reg-aws.openshift.com:443" 
DOCKER_USER="ops-prod-push36"
HTUSER_FILE="openshift-ansible-private/private_vars/global/aws/openshiftops/prod/reg-aws/htpasswd_users.yml"
DOCKER_REG_API="https://api.reg-aws.openshift.com"
ENVIRONMENT=""

NOCACHE='--no-cache'

declare -a VALID_ENVS=('int' 'stg' 'prod')

function show_help() {
  echo "Fast refresh build and push oso-host-monitoring with this tool"
  echo
  echo "-c        The docker build will use cache instead of --no-cache, which is the default"
  echo "-e <env>  Environment to build for, will accept int, stg or prod"
}

function array_contains() {
  local array="$1[@]"
  local seeking=$2
  local in=1
 
  for element in "${!array}"; do
    if [[ $element == $seeking ]]; then
      in=0
      break
    fi
  done
  return $in
}

while getopts "h?e:pcs" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    e)  if array_contains VALID_ENVS ${OPTARG}
        then
          ENVIRONMENT=$OPTARG
        else
          error_msg "Invalid environment choice, select one from:  $(echo ${VALID_ENVS[@]})"
          exit 5
        fi
        ;;
    c)  NOCACHE=''
        ;;
    :)  fatal_error "Option -$OPTARG requires a parameter." >&2
        ;;
    *)  fatal_error "Option not recognized -$OPTARG" >&2
        ;;
    esac
done

if [[ -z ${ENVIRONMENT} ]]
then
  error_msg "Environment is a required option, please select one.\n"
  show_help
  exit 4
fi  

sudo docker build ${NOCACHE} -t registry.reg-aws.openshift.com:443/ops/oso-rhel7-host-monitoring:${ENVIRONMENT} -<<EOF
FROM registry.reg-aws.openshift.com:443/ops/oso-rhel7-host-monitoring:${ENVIRONMENT}
RUN yum-install-check.sh -y --disablerepo=* --enablerepo=ops-rpm \
        python-openshift-tools \
        python-openshift-tools-monitoring-pcp \
        python-openshift-tools-monitoring-docker \
        python-openshift-tools-monitoring-zagg \
        python-openshift-tools-monitoring-openshift \
        python-openshift-tools-ansible \
        python-openshift-tools-web \
        openshift-tools-scripts-cloud-aws \
        openshift-tools-scripts-cloud-gcp \
        openshift-tools-scripts-monitoring-pcp \
        openshift-tools-scripts-monitoring-docker \
        openshift-tools-scripts-monitoring-aws \
        openshift-tools-scripts-monitoring-gcp \
        openshift-tools-scripts-monitoring-openshift \
        openshift-tools-scripts-monitoring-autoheal \
    && yum clean all && rm -rf /var/cache/yum
RUN date > ~/refreshed_date
EOF

# get token for communication with registry and login with docker
DOCKER_PASS=$(python <<EOF
import yaml
with open('${HTUSER_FILE}', 'r') as f:
  users = yaml.load(f)
  for user in users['g_openshift_registry_htpasswd_users']:
    if user['username'] == "${DOCKER_USER}":
      print user['password']
EOF
)

oc login -u ${DOCKER_USER} -p ${DOCKER_PASS} ${DOCKER_REG_API}
sudo docker login -u ${DOCKER_USER} -p $(oc whoami -t) ${DOCKER_REGISTRY}

sudo docker push ${DOCKER_REGISTRY}/ops/oso-rhel7-host-monitoring:${ENVIRONMENT}

