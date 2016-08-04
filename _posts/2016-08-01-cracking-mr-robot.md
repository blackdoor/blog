---
layout: post
author: trent
title: Hacking f_society
---

# Introduction

Mr. Robot is a show on AMC about a deeply disturbed hacker's attempts to thwart an oppressive oligarchical society headed by the omni-present "E Corp". Notably, it's one of the only
shows on telivision that actually attempts some degree of realism in its portrayal of "hacking", cracking, and exploits. Sure, 10 year IT veterans or security people will no doubt
laugh at the series of fortuitous events that allow the show's main character Elliot to be successful (including WEP security at a police station, single factor authentication on
virtually all systems, and laughably bad password complexity), but the show does some things right too. Shots of linux terms show the characters using real shell commands that actually
flow together and make sense, and the not-so-glamorous but more common side of cracking (social engineering, phishing attacks, etc) play a much greater role.

With that in mind, let's break a Mr. Robot themed VM together, and maybe learn a little something about webapp security along the way.

To get started, download the .ova from //vulnhub link here//, pop it into VirtualBox or VMWare (I prefer VirtualBox), and boot it up. The VM will grab a DHCP lease on boot. I recommend
creating your own virtual network and running both the Mr. Robot VM and your offense box on the same subnet.

# Information Gathering

To start, run an nmap scan on the subnet to find Mr. Robot's IP:

```shell
~# nmap -sV 192.168.100.0/24
```

-TC
