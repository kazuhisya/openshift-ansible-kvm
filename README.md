# openshift-ansible-kvm

This repository contains Ansible playbooks for UPI installation of OpenShift 4 on KVM.

It supports both [OpenShift Container Platform 4(OCP4)](https://www.openshift.com/) and [OKD 4](https://www.okd.io/) deployments.

Note: This configuration is for disposable test and does not support production use.

## Requirements

- Workstation (or call it base node, control node...), The machine that runs Ansible. It is typically your laptop.
    - Tested on Fedora
    - Ansible >= 2.11
    - This node **is not** mandatory. You can run the script on a single KVM host if you want.
- KVM host
    - RHEL >= 8.2
    - CPU with at least 4 cores
    - Memory with at least 80 GB
        - It will work with about 64 GB with memory overcommit, but we don't recommend it.
    - Check [resource requirements](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.5/html/installing_on_bare_metal/installing-on-bare-metal#installation-requirements-user-infra_installing-bare-metal) for more details.

## Architecture

![openshift-ansible-kvm-architecture](docs/assets/openshift-ansible-kvm-architecture.png)

It can also be run with just the KVM host, without the workstation. (In that case, install Ansible on the KVM host)

## Quickstart

### Install ansible(and/or ansible-core) on your Workstation

```bash
$ sudo dnf install -y ansible
```

### Prepare KVM host

- Just install RHEL8
- Add ssh public key of the workstation to kvm host root user's `.ssh/authorized_keys`

### Make your settings

Create your settings based on the samples.
At least change the following settings are **required** .

- `vars/config.yml`
    - `kvm_host:`
        - `ip:` Your KVM host IP
        - `if:` Your KVM host IF name (e.g. `enp2s0f0` )
    - `openshift:`
        - `dist:` Select the distribution to deploy `ocp` or `okd`
        - `install_version:` openshift-install and openshift-client version
        - `coreos_version:` CoreOS version
        - `okd_*_sha256:` (okd only) FOCS does not provide sha256sum.txt, so you have to check and input it yourself from [the official website](https://getfedora.org/en/coreos/download?tab=metal_virtualized&stream=stable).
    - `key:`
        - `pullsecret`  : Get form [cloud.redhat.com](https://cloud.redhat.com/openshift/install/metal/user-provisioned)
        - `sshkey`      : Your ssh pub key
- `inventory/hosts`
    - `[kvm_host]`    : Your KVM host IP (or localhost)

```bash
$ cp vars/config.yml.sample vars/config.yml
$ cp inventory/hosts.sample inventory/hosts
```

### How to use the Persistent Volume Claims

Make sure to have set the provide storage feature flag before running the playbook.

- `vars/vm_settings.yml`
    - `ff_provision_storage`: `true`

Confirm that `nfs-subdir-external-provisioner` plugin is working correctly

```bash
 $ oc get storageclass
NAME         PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-client   cluster.local/nfs-subdir-external-provisioner   Retain          Immediate           true                   26m <=== the ngf-client class must be there

 $ oc get all -n nfs-subdir-external-provisioner
NAME                                                  READY   STATUS    RESTARTS   AGE
pod/nfs-subdir-external-provisioner-8b5cd6b78-nw4zf   1/1     Running   0          14s <==== This pod must be running

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nfs-subdir-external-provisioner   1/1     1            1           19s

NAME                                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/nfs-subdir-external-provisioner-8b5cd6b78   1         1         1       14s
replicaset.apps/nfs-subdir-external-provisioner-f64f74cfc   0         0         0       19s


```

Deploy an application requiring a Persistent Volume, and confirm it works

```bash
 $ oc get storageclass
NAME         PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-client   cluster.local/nfs-subdir-external-provisioner   Retain          Immediate           true                   26m

 $ oc apply -f tests/persistent-busybox.yml [-n <your-namespace]

 $ oc get pv -o wide [-n <your-namespace]
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                        STORAGECLASS   REASON   AGE   VOLUMEMODE
pvc-6142a868-ed9d-455e-b9f2-12badeceb9bc   1Mi        RWX            Retain           Bound    nfs-subdir-external-provisioner/test-claim   nfs-client              13m   Filesystem

 $ oc get pvc [-n <your-namespace]
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-claim   Bound    pvc-6142a868-ed9d-455e-b9f2-12badeceb9bc   1Mi        RWX            nfs-client     15m

 $ oc get pod demo-busybox-789874f84c-fzbm6  [-n <your-namespace]
NAME                            READY   STATUS    RESTARTS   AGE
demo-busybox-789874f84c-fzbm6   1/1     Running   0          17m

 $ oc get pod demo-busybox-789874f84c-fzbm6 [-n <your-namespace] -o yaml | grep volume -A3
    volumeMounts:
    - mountPath: /data/db
      name: voldb1
    [...]
--
  volumes:
  - name: voldb1
    persistentVolumeClaim:
      claimName: test-claim
```

### Run

```bash
$ ansible-playbook ./main.yml
```

## FAQ

### How do I connect to the OCP web console from the workstation?

You cannot access directly to NAT network of libvirtd from your workstation.
But you can access it using ssh port forwarding and socks5, for example.
 
```
[user@workstation] $ ssh root@KVM-HOST -ND 127.0.0.1:8888
```

Then add `127.0.0.1:8888` (socks5) to your browser's Proxy and access `https://console-openshift-console.apps.test.lab.local`.
Depending on your browser, you may need to enable the RemoteDNS option.
 
Other ways, you can use [sshuttle](https://fedoramagazine.org/use-sshuttle-to-build-a-poor-mans-vpn/).

### Something is wrong? - clean up environment

```bash
$ ansible-playbook ./03_cleanup.yml
```

### Missing some Ansible modules

If you use `ansible-core`, you may be missing some modules. In that case, please install the missing modules.

```bash
$ ansible-galaxy collection install ansible.posix
$ ansible-galaxy collection install community.general
$ ansible-galaxy collection install community.libvirt
```

### 

## Special Thanks

This project started with inspiration from openshift-fast-install. ( [the original version](https://github.com/konono/openshift-fast-install) and [the forked version](https://github.com/masaki-furuta/openshift-fast-install) )
