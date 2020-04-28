#!/usr/bin/env bash
set -exu

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
base_tf_dir=$this_dir/../base/

region=$1

cd "$base_tf_dir"

terraform workspace select "$region"
terraform destroy