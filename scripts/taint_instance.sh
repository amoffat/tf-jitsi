#!/usr/bin/env bash
set -exu

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
jitsi_tf_dir=$this_dir/../jitsi/
subdomain=$1

terraform taint -state="$jitsi_tf_dir"/terraform.tfstate.d/"$subdomain"/terraform.tfstate aws_instance.jitsi