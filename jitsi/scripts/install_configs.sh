#!/usr/bin/env bash
set -ex

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
conf_dir=$this_dir/../../config
jitsi_dir=~/docker-jitsi-meet
PATH=$PATH:/usr/local/bin

cp -r "$conf_dir"/jitsi $jitsi_dir/config
yq w -i $jitsi_dir/docker-compose.yml 'services.web.ports[+]' '81:81'
mv $jitsi_dir/env.example $jitsi_dir/.env

sed -i \
    -e "s/^#DISABLE_HTTPS=1/DISABLE_HTTPS=1/g" \
    -e "s#^CONFIG=.*#CONFIG=./config#g" \
    -e "s#^HTTP_PORT=.*#HTTP_PORT=80#g" \
    -e "s#^HTTPS_PORT=.*#HTTPS_PORT=443#g" \
    $jitsi_dir/.env

cd $jitsi_dir
bash ./gen-passwords.sh

sudo cp "$conf_dir"/jitsi.service /etc/systemd/system/