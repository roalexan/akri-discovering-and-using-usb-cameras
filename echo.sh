#!/bin/bash

# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

#
# The below steps will deploy the Akri demo. It will stand up a virtual machine,
# run two simulated "udev" camera devices on it, and forward a local port to
# the remote port running a webapp to show the two cameras. If all goes well,
# you should be able to browse http://localhost:50000/ and see the demo in action.
#

# estimated time for completion: 18 minutes
echo "start deploy.sh"

## PARAMETERS

SUBSCRIPTION="$1" # subscription used for the deployment
LOCATION="$2" # location used for the deployment, e.g. eastus
PREFIX="$3" # short string prepended to some resource names to make them unique
ALIAS="$4" # used as a tag on the resource group to identity its owner

echo "parameters:"
echo "SUBSCRIPTION: ${SUBSCRIPTION}"
echo "LOCATION: ${LOCATION}"
echo "PREFIX: ${PREFIX}"
echo "ALIAS: ${ALIAS}"

## VARIABLES

RESOURCE_GROUP="${PREFIX}usbcamerademorg" # name of the new resource group to create
VM_NAME="${PREFIX}usbcamerademovm"
# https://askubuntu.com/questions/1263020/what-is-the-azure-vm-image-urn-for-ubuntu-server-20-04-lts
# syntax: publisher:offer:sku:version (shown in vm arm template)
VM_IMAGE="Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest" # Ubuntu Server 20.04 LTS - Gen 2
# VM_IMAGE="Canonical:UbuntuServer:18_04-lts-gen2:latest" # Ubuntu Server 20.04 LTS - Gen 2
# https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/
# VM_SIZE="standard_ds3_v2" # Standard DS3 v2 (4 vcpus, 14 GiB memory)
VM_SIZE="standard_ds4_v2" # Standard DS4 v2 (8 vcpus, 28 GiB memory)
VM_USER_NAME="azureuser" # login user name of the virtual machine
KEY_NAME="sshkey"

echo "variables:"
echo "RESOURCE_GROUP: ${RESOURCE_GROUP}"
echo "VM_NAME: ${VM_NAME}"
echo "VM_IMAGE: ${VM_IMAGE}"
echo "VM_SIZE: ${VM_SIZE}"
echo "VM_USER_NAME: ${VM_USER_NAME}"
echo "KEY_NAME: ${KEY_NAME}"

## RETURN

echo "finished"
exit 0 # success

## DELETE RESOURCE GROUP WHEN NO LONGER NEEDED

# az group delete -n ${RESOURCE_GROUP} --no-wait
# az group show -n ${RESOURCE_GROUP} # verify