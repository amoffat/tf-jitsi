#!/usr/bin/env bash
set -exu

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
jitsi_tf_dir=$this_dir/../jitsi/
base_tf_dir=$this_dir/../base/

. "$this_dir"/common.sh

# first let's deploy the base infrastructure (VPC, routing tables, etc)
cd "$base_tf_dir"

if [ ! -d "./terraform" ]; then
    terraform init
fi

set +e
terraform workspace select "$region"
if [ $? -ne 0 ]; then
    echo "Creating new region $region"
    set -e
    terraform workspace new "$region"
    terraform workspace select "$region"
fi
set -e

terraform apply -auto-approve

# now let's deploy an individual jitsi installation on a subdomain under the base infrastructure
cd "$jitsi_tf_dir"

if [ ! -d "./terraform" ]; then
    terraform init
fi

set +e
terraform workspace select "$subdomain"
if [ $? -ne 0 ]; then
    echo "Creating new client $subdomain"
    set -e
    terraform workspace new "$subdomain"
    terraform workspace select "$subdomain"
fi
set -e

terraform apply \
    -var region="$region" \
    -var tf_jitsi_branch="$tf_jitsi_branch" \
    -var jitsi_branch="$jitsi_branch" \
    -var instance_type="$instance_type" \
    -var dns_zone="$dns_zone" \
    -var cert="$cert_arn" \
    -auto-approve
