# OpenStack Terraform Web App Example
This repo contains a [Terraform](https://www.terraform.io/) plan that uses [the OpenStack Terraform provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs) to create instances and networks for a hypothetical web application with a database.

The resulting infrastructure is supposed to mimic a cloud deployment for a database-driven web application like WordPress. The deployment illustrates the configuration you need to create a platform that can scale horizontally at the load balancer layer, the web app layer, and the database layer. The deployment also limits access from the public Internet to a load balancer and to a jumpstation.

**This plan is made to run with the default configuration from the OpenStack Victoria release of [the OpenMetal On-Demand OpenStack Private Cloud platform](openmetal.io). You must change this plan to fit your cloud's configuration.**

## Before running

### Import OpenStack Credentials
Before you run this plan, you **must** either add your OpenStack credentials to the provider block in the plan or **import your admin-openrc.sh** file into your CLI environment. The OpenStack Terraform provider can pull OpenStack credentials and other information from environment variables.

### Match the Images, Security Groups, and other data to your defined values
My cloud configuration comes with flavors, images, security groups, and other resources pre-configured that are not found in the default OpenStack setup. **You must update the Terraform plan to refer to your cloud's flavors, images, security groups, etc. or the plan will fail to run.**

## What will you have when this runs?
This script will do the following steps:

1. Increase the quota for the `admin` project
2. Pull the IDs of various OpenStack resources into OpenStack
3. Create a router
4. Setup networks
5. Setup subnets
6. Create interfaces on the previously created router
7. Setup instances
8. Allocate floating IPs

The plan will create two networks - one for instances that would host a load balancer and web app instances and a second one for databases. Jumpstations are used to enter the network space and to move between networks.