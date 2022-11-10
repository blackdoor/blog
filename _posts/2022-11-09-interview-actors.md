---
layout: post
author: nathan
title: Interview Sized Actors for State Control
---

The [actor model](https://en.wikipedia.org/wiki/Actor_model) provides several benefits for creating non-trivial programs. 
It provides control of state by localizing state changes, 
it facilitates error handling by creating heirarchies of actors which manage other actors,
it provides fast non-blocking concurrency by constraining communication to one-way message passing, 
and it enables location transparency (the ability to run the same code on one or multiple machines without needing to account for the distribution in logic code) by carrying those messages across network boundaries the same way they're carried across threads.  
I'll show you an actor implementation that focuses on state control and sacrifices other typical actor benefits (and how you can make up for them with other patterns) in order to be small enough to be used in an interview solution.

## Interview Prompt

Suppose an interviewer gave us this problem:

> Implement a banking system to run on one machine. 
> Users should be able to open an account, 
> deposit money,
> check their balance, 
> withdraw money (preventing any overdrafts), 
> pull money from another account,
> and close their account.
> Many users should be able to access the system at the same time.

From that last requirement we can tell that we're going to be dealing with some level of concurrency if we want to scale this system up.

## Why We Need State Control

We have some 

## Actor Implementation

## Interview Solution
