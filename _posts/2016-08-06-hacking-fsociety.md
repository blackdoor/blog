---
layout: post
author: trent
title: Hacking f_society.
---

# Introduction
Mr. Robot is a show on AMC about a disturbed hacker attempting to thwart an omni-present
oligarchy while at the same time trying to suppress a dark alter-ego modeled after his
own father.

Notably, the show tries to portray "hacking" realistically (inasmuch as it can without entire episodes
dedicated to watching Elliot pore over the documentation of a specific vulnerable version
of httpd running on Windows Server 2000), and I appreciate it. Well, mostly.

With that in mind, let's break a Mr. Robot themed VM together, and maybe learn something
about webapp security along the way.

Download the .ova from [vulnhub](https://www.vulnhub.com/entry/mr-robot-1,151/), pop it
in your favorite virtualization software (hard to go wrong with VirtualBox), and boot it up.
The Mr. Robot VM grabs a DHCP lease on boot, and I'd recommend running it and your offense
box on the same virtual subnet.

# Recon / Scanning
First, let's scan the subnet to find Mr. Robot's VM.

```shell
root@bento:~# nmap -A 10.0.2.0/24
Starting Nmap 7.01 ( https://nmap.org ) at 2016-08-03 23:48 PDT

Nmap scan report for 10.0.2.5
Host is up (0.00052s latency).
Not shown: 997 filtered ports
PORT    STATE  SERVICE  VERSION
22/tcp  closed ssh
80/tcp  open   http     Apache httpd
|_http-server-header: Apache
|_http-title: Site doesn't have a title (text/html).
443/tcp open   ssl/http Apache httpd
|_http-server-header: Apache
|_http-title: Site doesn't have a title (text/html).
| ssl-cert: Subject: commonName=www.example.com
| Not valid before: 2015-09-16T10:45:03
|_Not valid after:  2025-09-13T10:45:03
MAC Address: 08:00:27:6C:39:39 (Oracle VirtualBox virtual NIC)
Device type: general purpose
Running: Linux 3.X
OS CPE: cpe:/o:linux:linux_kernel:3
OS details: Linux 3.10 - 3.19
Network Distance: 1 hop

TRACEROUTE
HOP RTT     ADDRESS
1   0.52 ms 10.0.2.5
```


From the scan, we can see the VM is probably serving some sort of web-service.
Before we investigate this further, however, let's run some more scans and see
if we can dig up anything else.

```shell
root@bento:~# nikto -host 10.0.2.5
- Nikto v2.1.6
---------------------------------------------------------------------------
+ Target IP:          10.0.2.5
+ Target Hostname:    10.0.2.5
+ Target Port:        80
---------------------------------------------------------------------------
+ OSVDB-3092: /admin/: This might be interesting...
+ OSVDB-3092: /license.txt: License file found may identify site software.
+ /admin/index.html: Admin login page/section found.
+ /wp-login/: Admin login page/section found.
+ /wordpress/: A Wordpress installation was found.
+ /wp-admin/wp-login.php: Wordpress login found
+ /blog/wp-login.php: Wordpress login found
+ /wp-login.php: Wordpress login found
```

Our nikto scan turns up a bunch of interesting directories, including what looks like
an admin portal for a WordPress site. Definitely worth checking out.

Navigating to the VMs IP in Firefox yields the following page:

![]({{ site.baseurl }}/assets/img/mr_robot.webm)

None of the commands on this page are particularly interesting. What is interesting,
however, is the site's robots.txt file, which contains this:

![]({{ site.baseurl }}/assets/img/robots.png)

And just like that, we have the first flag.

-TC
