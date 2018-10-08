# osops-container-refresh

How to run:

Checkout to somewhere on bastion.
Update `openshift-ansible-private` symlink to your copy.
Execute script, it will immediately build and push.

$ `time ./ops-build-refresh-and-push-osohm-container.sh -e stg`

References:
* https://github.com/openshift/openshift-ansible-ops/blob/prod/ops_roles/config_runners/files/ops-build-and-push-osohm-container.sh
* https://jira.coreos.com/browse/SREO-100

