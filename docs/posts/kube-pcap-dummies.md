---
date: 2020-09-30
authors: [nathan]
description: >
  Our new blog is built with the brand new built-in blog plugin. You can build
  a blog alongside your documentation or standalone
categories:
  - Blog
---

# Kubernetes Packet Capture for Dummies
<!-- more -->

Have you ever needed to analyze the traffic on your kube cluster? It's easier to do than you might think, and you might be surprised how much traffic you can get from inside a container.  
There are three steps; first get a shell inside a container on your cluster, then use tcpdump to capture network traffic, finally exfil the traffic to your local machine and inspect it with wireshark.

## Get a shell on your cluster

```
kubectl run \
-it \
--rm \
debug \
--restart=Never \
--image=ubuntu \
--overrides='{"kind":"Pod", "apiVersion":"v1", "spec": { \
  "hostNetwork":true, \
  "nodeName": "node1" \
}}'
```

let's break that down a bit

* `-it` - get an interactive terminal once the pod starts
* `--rm` - delete the pod once the process completes
* `--image=ubuntu` - use the ubuntu base image
* setting `hostNetwork` to `true` ensures we use have access to the instance's network if
* setting `nodeName` is optional, but if you want you can use it to determine which node your pod will run on

## Capture network traffic

```
apt-get update && apt-get install -y net-tools tcpdump
tcpdump -w dump.pcap
```

Install tcpdump and run it to dump network traffic to a file. If needed, [additional parameters](https://www.tcpdump.org/manpages/tcpdump.1.html) can be used to filter what should be captured. A handy one is `'tcp port 80'`.

## Analyze

Download your traffic dump using 

```
kubectl cp myNamespace/debug:/dump.pcap dump.pcap
```

where debug is the name of the pod we started for our shell.

Then just open `dump.pcap` with wireshark and explore!
