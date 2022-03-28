#!/bin/bash

# Copyright (c) Microsoft Corporation. All rights reserved.
#
# Licensed under Microsoft Incubation License Agreement:

#
# The below steps will deploy the Akri demo. It will stand up a virtual machine,
# run two simulated "udev" camera devices on it, and forward a local port to
# the remote port running a webapp to show the two cameras. If all goes well,
# you should be able to browse http://localhost:50000/ and see the demo in action.
#

# estimated time for completion: 18 minutes
echo "start deploy.sh"

## PARAMETERS

SUBSCRIPTION="" # subscription used for the deployment
LOCATION="eastus" # location used for the deployment
PREFIX="" # short string prepended to some resource names to make them unique
ALIAS="" # used as a tag on the resource group to identity its owner

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

# SOURCE FILES

# PREQUISITES

# if using Windows Subsystem for Linux (WSL), you MIGHT need to do the below to allow
# 'chmod' on the ssh keys that will be created - the private key needs to be created
# with '644' (i.e. rw-r--r) to connect to the virtual machine on Azure.
# https://stackoverflow.com/questions/46610256/chmod-wsl-bash-doesnt-work
# sudo vi /etc/wsl.conf
#  [automount]
#  options = "metadata"

# create the ssh keys used by the virtual machine
# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys
# https://stackoverflow.com/questions/43235179/how-to-execute-ssh-keygen-without-prompt
echo "create keys"
ssh-keygen -q -t rsa -N '' -f ${KEY_NAME} <<< y >/dev/null 2>&1
# https://stackoverflow.com/questions/9270734/ssh-permissions-are-too-open-error
# https://stackoverflow.com/questions/4411457/how-do-i-verify-check-test-validate-my-ssh-passphrase

## SET AZ DEFAULTS

echo "set azure defaults"
az account set -s ${SUBSCRIPTION}
az configure --defaults group=${RESOURCE_GROUP}

## CREATE RESOURCE GROUP

echo "create resource group"
az group create -l ${LOCATION} -n ${RESOURCE_GROUP} --tags alias=${ALIAS}

## CREATE VM

# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-cli
echo "create virtual machine"
az vm create \
  --resource-group ${RESOURCE_GROUP} \
  --name ${VM_NAME} \
  --image ${VM_IMAGE} \
  --size ${VM_SIZE} \
  --authentication-type ssh \
  --admin-username ${VM_USER_NAME} \
  --ssh-key-values "${KEY_NAME}.pub" \
  --public-ip-sku Standard

## Get the virtual machine's public ip address
public_ip=$(az vm show -d -g ${RESOURCE_GROUP} -n ${VM_NAME} --query publicIps -o tsv)
public_ip=$(echo $public_ip | tr -dc '[[:print:]]')  # remove non-printable characters
echo "virtual machine's public ip address: ${public_ip}"

## Install initial dependencies (e.g. kernel modules) on the virtual machine.
echo "install initial dependencies"
# https://stackoverflow.com/questions/305035/how-to-use-ssh-to-run-a-local-shell-script-on-a-remote-machine
ssh ${VM_USER_NAME}@${public_ip} -i ${KEY_NAME} -o "StrictHostKeyChecking no" <<'ENDSSH'
sudo apt update
sudo apt -y install linux-modules-extra-azure
sudo apt -y install linux-headers-$(uname -r)
sudo apt -y install linux-modules-extra-$(uname -r)
sudo reboot now
ENDSSH

sleep 30

## Install additional dependencies (e.g. v4l2loopback kernel module, akri, streaming application)
echo "install additional dependencies"
ssh ${VM_USER_NAME}@${public_ip} -i ${KEY_NAME} -o "StrictHostKeyChecking no" <<'ENDSSH'
sudo apt -y install dkms
curl http://deb.debian.org/debian/pool/main/v/v4l2loopback/v4l2loopback-dkms_0.12.5-1_all.deb -o v4l2loopback-dkms_0.12.5-1_all.deb
sudo dpkg -i v4l2loopback-dkms_0.12.5-1_all.deb
sudo modprobe v4l2loopback exclusive_caps=1 video_nr=1,2
ls /dev/video*
sudo apt-get install -y \
    libgstreamer1.0-0 gstreamer1.0-tools gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good gstreamer1.0-libav
mkdir camera-logs
sudo gst-launch-1.0 -v videotestsrc pattern=ball ! "video/x-raw,width=640,height=480,framerate=10/1" ! avenc_mjpeg ! v4l2sink device=/dev/video1 > camera-logs/ball.log 2>&1 &
sudo gst-launch-1.0 -v videotestsrc pattern=smpte horizontal-speed=1 ! "video/x-raw,width=640,height=480,framerate=10/1" ! avenc_mjpeg ! v4l2sink device=/dev/video2 > camera-logs/smpte.log 2>&1 &
curl -sfL https://get.k3s.io | sh -
sudo addgroup k3s-admin
sudo adduser $USER k3s-admin
sudo usermod -a -G k3s-admin $USER
sudo chgrp k3s-admin /etc/rancher/k3s/k3s.yaml
sudo chmod g+r /etc/rancher/k3s/k3s.yaml
sudo su - $USER
kubectl get node
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo apt install -y curl
curl -L https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
export AKRI_HELM_CRICTL_CONFIGURATION="--set kubernetesDistro=k3s"
helm repo add akri-helm-charts https://project-akri.github.io/akri/
helm install akri akri-helm-charts/akri \
    $AKRI_HELM_CRICTL_CONFIGURATION \
    --set udev.discovery.enabled=true \
    --set udev.configuration.enabled=true \
    --set udev.configuration.name=akri-udev-video \
    --set udev.configuration.discoveryDetails.udevRules[0]='KERNEL=="video[0-9]*"' \
    --set udev.configuration.brokerPod.image.repository="ghcr.io/project-akri/akri/udev-video-broker"
kubectl get akric -o yaml
kubectl apply -f https://raw.githubusercontent.com/project-akri/akri/main/deployment/samples/akri-video-streaming-app.yaml
ENDSSH

## Get streaming application port
ret_val=$(ssh ${VM_USER_NAME}@${public_ip} -i ${KEY_NAME} -o "StrictHostKeyChecking no" kubectl get service/akri-video-streaming-app --output=json)
# https://stackoverflow.com/questions/47939901/jq-how-to-match-one-of-array-and-get-sibling-value
node_port=$(echo $ret_val | jq -r '.["spec"]["ports"][] | select(.name == "http").nodePort')
echo "application port: ${node_port}"

## RETURN

echo "finished"
echo "you may now see the demo by forwarding your local port:"
echo "ssh ${VM_USER_NAME}@$public_ip -i ${KEY_NAME} -o \"StrictHostKeyChecking no\" -L 50000:localhost:${node_port}"
echo "and browsing:"
echo "http://localhost:50000/"
exit 0 # success

## DELETE RESOURCE GROUP WHEN NO LONGER NEEDED

# az group delete -n ${RESOURCE_GROUP} --no-wait
# az group show -n ${RESOURCE_GROUP} # verify