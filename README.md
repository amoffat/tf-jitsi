# tf-jitsi

I wanted to deploy Jitsi under a subdomain on AWS in 5 minutes, so I built this. Give it a try.

# What you'll need

* Terraform installed (Download it [here](https://www.terraform.io/downloads.html))
    * Terraform is an industry-grade, declarative, IaC (Infrastructure as Code) tool.
* An AWS account (Sign up [here](https://portal.aws.amazon.com/billing/signup#/start))
    * The Terraform files describes the Jitsi infrastructure as AWS resources.
* The name of an SSH keypair on AWS (Create one [here](http://console.aws.amazon.com/ec2/v2/home#KeyPairs:))
    * When our EC2 instance is started, AWS will give the default user this key, so you can connect with SSH.
* An existing Route53 hosted zone for your domain (Create one [here](https://console.aws.amazon.com/route53/home#hosted-zones:))
    * Our Jitsi deployment will be set up on a subdomain in the hosted zone for your domain. Terraform will create the
    subdomain DNS records in this hosted zone.
* The ARN of a **star** SSL certificate on AWS (Create one [here](http://console.aws.amazon.com/acm/home))
    * All tf-jitsi deployments serve their web traffic over TLS, so we need an SSL certificate.
    * It has to be a star certificate because tf-jitsi allows multiple subdomain deployments under a single domain. 

That's it!

# Deploying

1. Set your config variables by editing `scripts/common.sh`
    1. Set `subdomain` to be the subdomain you wish your installation to appear under, for example `test`.
    1. Set `region` to be the AWS region. I use `us-west-2`. See the [full list](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions).
    1. Change the `instance_type` to a machine with the power you want. See the [full list](https://www.ec2instances.info/).
    1. Set `dns_zone`. It will look like `Z4T3BDVSEN6BC`
    1. Set `cert_arn`. It will start with `arn:aws:acm:`
    1. If you wish to use non-standard branches, change `jitsi_branch` and `tf_jitsi_branch`.
        * `jitsi_branch` controls which branch of [docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet) is deployed to the EC2 instance.
        * `tf_jitsi_branch` controls which branch of **this repo** is deployed to the EC2 instance.
1. Run `scripts/provision_subdomain.sh`. This will
    * Initialize Terraform, if it hasn't been already,
    * Create or select a region-based workspace for the base infrastructure.
    * Deploy the base infrastructure.
    * Create or select a subdomain-based workspace for the jitsi infrastructure.
    * Deploy the jitsi infrastructure.
   
And wait while Terraform spins up your infrastructure. When the instance has been brought up, you'll see the
following output:

```
Outputs:

domain = test.myjitsiserver.com.
public_ip = 18.246.106.105
```

This is where you can access your Jitsi installation. **The server is still setting up though, however, so give it a
few minutes before hitting the url.** It typically takes around 5 minutes before the url will be live.


# Teardown

## An individual Jitsi subdomain

This will teardown an individual subdomain but leave up the common infrastructure that other subdomains may be relying
on.

1. Run `scripts/destroy_subdomain.sh`
1. Examine the output to ensure that the resources listed are indeed what you want to destroy.
1. When ready, type "yes" and press return.

## The region-based infrastructure

This will teardown the common infrastructure for a particular region.

1. Run `scripts/destroy_base.sh <region_name>`
1. Examine the output to ensure that the resources listed are indeed what you want to destroy.
1. When ready, type "yes" and press return.

# What is tf-jitsi doing?

* Create the base infrastructure
    * VPC with CIDR 10.0.0.0/16
    * Routing table
    * Single subnet with CIDR 10.0.0.0/16, public IPs enabled
* Create jitsi infrastructure
    * EC2 instance
    * NIC security group
        * Ingress: 443, 80, 81, 22, 4443 (jitsi videobridge), 1000 (jitsi videobridge)
    * Network Load Balancer (NLB) using provided cert
        * TLS 443 -> TCP 80
        * TCP 80 -> TCP 81
    * Route53 alias record mapped for subdomain mapped to NLB
* Provision the jitsi EC2 instance
    * Pull [docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet)
    * Pull tf-jitsi onto EC2 instance
    * Overrides some basic configs
        * Disables HTTPS, as we'll handle that with the NLB
        * Opens port 81 for HTTP traffic
        * nginx.conf change to redirect port 81 to port 80
        * Generates jitsi component passwords, per their readme
    * Installs a jitsi.service systemd unit
    * Enable and start the jitsi.service

# Cost

TBD. This depends on your instance type and the amount of **outbound** traffic, which AWS bills at $0.09/GB. Your
bandwidth depends on your participants as well, both the number and the browsers that they use, as some browsers use
simulcast (resulting in more efficient bandwidth usage), while others don't.

# Terraform Architecture

There's two Terraform modules: "base" and "jitsi". I structured it this way because I wanted the flexibility to create
multiple subdomain deployments using a common infrastructure. This meant that the base had to be separately managed TF
state.

## Base module

The "base" module provides common infrastructure for many installations of "jitsi" modules. It creates a *per-region*
workspace (eg: "us-west-2") for its Terraform state. This means you can have multiple base infrastructures in
different regions. A per-region base infrastructure is required as you cannot link compute resources to subnets outside
of your region.

## Jitsi module

The "jitsi" module provides an individual installation of Jitsi under a subdomain. It creates *per-subdomain* workspaces
for its Terraform state. This means you can have multiple Jitsi installations, under different subdomains, under a
common hostname, all sharing the common "base" module infrastructure. For example, you could have:

* `server1.myjitsiserver.com`
* `server2.myjitsiserver.com`
* `server3.myjitsiserver.com`

And each of these subdomains is running on separate hardware provisioned with tf-jitsi.

# Development

If you plan to customize tf-jitsi, there's a few tricks you can use.

## Use a branch

You can specify custom branches in `scripts/common.sh`.

## Tainting an instance

If you are rapidly iterating on tf-jitsi changes, and you just want to re-deploy the EC2 instance without touching the
rest of the infrastructure, you can use `terraform taint` via the `scripts/taint_instance.sh` script. This will mark
the EC2 instance resource as "tainted", so the next time you run `scripts/provision_subdomain.sh`, that particular
resource (and any of its dependencies) will be re-created, while leaving alone much of the other infrastructure.

# Debugging the EC2 instance

## Connecting

`ssh -i ~/.ssh/your_ssh_keypair.pem ec2-user@ip`

## Things to check

### Did the [cloud-init](https://cloudinit.readthedocs.io/en/latest/) succeed?

* `less /var/log/cloud-init-output.log`
* `less /var/log/cloud-init.log`

### Is the `jitsi.service` running?

`systemctl status jitsi`

It should say "active (running)"

### What do the logs from the service say?

`journalctl -u jitsi`

### Are the containers running?

`docker ps` should list running containers for the following images:

* `jitsi/jicofo`
* `jitsi/jvb`
* `jitsi/web`
* `jitsi/prosody`

### Are my local services listening?

`curl -I http://localhost:81` should show:

```
HTTP/1.1 301 Moved Permanently
Server: nginx
Date: Tue, 28 Apr 2020 15:14:09 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
```

`curl -I http://localhost` should show:

```
HTTP/1.1 200 OK
Server: nginx
Date: Tue, 28 Apr 2020 15:14:15 GMT
Content-Type: text/html
Connection: keep-alive
```