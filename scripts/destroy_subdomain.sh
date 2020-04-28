#!/usr/bin/env bash
set -exu

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
jitsi_tf_dir=$this_dir/../jitsi/

. "$this_dir"/common.sh

cd "$jitsi_tf_dir"

terraform workspace select "$subdomain"

terraform destroy \
    -var region="$region" \
    -var tf_jitsi_branch="$tf_jitsi_branch" \
    -var jitsi_branch="$jitsi_branch" \
    -var instance_type="$instance_type" \
    -var dns_zone="$dns_zone" \
    -var cert="$cert_arn"