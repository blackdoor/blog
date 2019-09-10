---
layout: post
author: nathan
title: Log tracing with plain old Scala `Future`s
---

Log tracing (also known as request tracing, [distributed tracing](https://microservices.io/patterns/observability/distributed-tracing.html), or just [tracing](https://www.oreilly.com/library/view/distributed-systems-observability/9781492033431/ch04.html)) is the technique of tying multiple log events together to give a more comprehensive picture of an event in a system.
This is accomplished by generating a unique ID for each event that is sent with each log and used to correlate the logs together.  
The issue is that logging is a cross cutting concern and it's extremely unwieldy to pass this correlation ID as a parameter to every function and method that might need to produce a log.
Typically in syncronous application code this is solved with something like a [`ThreadLocal`](https://docs.oracle.com/javase/8/docs/api/java/lang/ThreadLocal.html) which allows the ID to be retrieved by any code running on the same thread without passing the value. Many synchronous libraries/frameworks ([Mapped Diagnostic Context in SLF4J](https://logback.qos.ch/manual/mdc.html), [Brave (used by Spring Cloud Sleuth)](https://github.com/openzipkin/brave), etc) use this technique. 
However, in asynchronous code this approach doesn't work because we have different parts of our code running on different threads in a pool. If you've used Twitter `Future`s with Zipkin you may have noticed that you have asynchronous code and working tracing, but that tracing breaks if you use Scala's `Future` instead of Twitter's. This is because Twitter's `Future`s do something called local context propagation that Scala's do not, and therefore some things do not work so well outside Twitter's ecosystem.

In this article we'll cover an example system with two services (using Akka HTTP and plain old Scala `Future`s) that does some logging. Then we'll add some performance monitoring to our logs. Finally we'll start using correlation IDs to tie everything together.

## Example System

Let's say we have a simple system with two services; a and b. Outside requests come in to a, which sends a random greeting to b, who simply logs the greeting and replies with thanks which a sends back to the external caller. 

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/6e075361327a0280c0af6dfcaa753e2bbb7fb08b/a/src/a/Service.scala"></script>

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/6e075361327a0280c0af6dfcaa753e2bbb7fb08b/b/src/b/Service.scala"></script>

Both services use a simple logging directive to record request information and how long the request took to complete.

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/6e075361327a0280c0af6dfcaa753e2bbb7fb08b/common/src/common/LoggingDirective.scala"></script>

If we do a simple `curl http://localhost:8080`

then we see that a logs
> [my-system-akka.actor.default-dispatcher-5] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 214ms

and b logs
> [my-system-akka.actor.default-dispatcher-6] INFO b.Service - a says 'Konnichiwa B'  
>[my-system-akka.actor.default-dispatcher-6] INFO common.LoggingDirective - responded to POST http://localhost:8081/ HTTP/1.1 in 27ms

Source code for the example and the rest of the article can be found [on github](https://github.com/kag0/scala-log-tracing).

## Timing

So far we have two running services, each with some basic logging. 

Now suppose we want to keep track of how much time the request spends in different parts of the system. 

We could tweak a's service to measure how long it takes to receive b's response.

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/d68a28b31f14c43142401f9c60de70749890fbb8/a/src/a/Service.scala"></script>

> [my-system-akka.actor.default-dispatcher-4] INFO a.Service - b took 211ms to respond  
> [my-system-akka.actor.default-dispatcher-4] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 221ms

This way we could get a fairly granular breakdown of what happened. We have the total time it took to serve the response to the caller, the time it took a to get a response back from b, and the time it took b to process the greeting from a.

The problem we have is that given many requests in parallel we have no way of knowing which log entries go together.
For example for 5 requests `a` logs

> [my-system-akka.actor.default-dispatcher-9] INFO a.Service - b took 220ms to respond  
[my-system-akka.actor.default-dispatcher-4] INFO a.Service - b took 222ms to respond  
[my-system-akka.actor.default-dispatcher-9] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 230ms  
[my-system-akka.actor.default-dispatcher-4] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 231ms  
[my-system-akka.actor.default-dispatcher-4] INFO a.Service - b took 223ms to respond  
[my-system-akka.actor.default-dispatcher-4] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 232ms  
[my-system-akka.actor.default-dispatcher-2] INFO a.Service - b took 224ms to respond  
[my-system-akka.actor.default-dispatcher-2] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 233ms  
[my-system-akka.actor.default-dispatcher-4] INFO a.Service - b took 224ms to respond  
[my-system-akka.actor.default-dispatcher-4] INFO common.LoggingDirective - responded to GET http://localhost:8080/ HTTP/1.1 in 233ms


and `b` logs

> [my-system-akka.actor.default-dispatcher-4] INFO b.Service - a says 'Zdravstvuyte B'  
[my-system-akka.actor.default-dispatcher-2] INFO b.Service - a says 'Grüß Gott B'  
[my-system-akka.actor.default-dispatcher-8] INFO b.Service - a says 'Sawubona B'  
[my-system-akka.actor.default-dispatcher-3] INFO b.Service - a says 'Cześć B'  
[my-system-akka.actor.default-dispatcher-3] INFO common.LoggingDirective - responded to POST http://localhost:8081/ HTTP/1.1 in 31ms  
[my-system-akka.actor.default-dispatcher-2] INFO common.LoggingDirective - responded to POST http://localhost:8081/ HTTP/1.1 in 31ms  
[my-system-akka.actor.default-dispatcher-4] INFO common.LoggingDirective - responded to POST http://localhost:8081/ HTTP/1.1 in 31ms  
[my-system-akka.actor.default-dispatcher-8] INFO common.LoggingDirective - responded to POST http://localhost:8081/ HTTP/1.1 in 31ms  
[my-system-akka.actor.default-dispatcher-9] INFO b.Service - a says 'Namaste B'  
[my-system-akka.actor.default-dispatcher-9] INFO common.LoggingDirective - responded to POST http://localhost:8081/ HTTP/1.1 in 1ms  


## Tracing

Now we can get into the meat of why you're reading this article. Let's add correlation IDs to all of our logs. We're going to use a Monix [`Local`](https://monix.io/api/3.0/monix/execution/misc/Local.html) which is like a thread local, but will be propagated to the new thread when we cross async boundaries.

To make the `Local` available globally we'll just put it in an object 

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/common/src/common/CorrelationId.scala"></script>

Next let's make a directive that will either use a correlation ID from a header in an incoming request (in the case of b) or generate a new one (in the case of a)

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/common/src/common/CorrelationIdDirectives.scala"></script>

To make the `Local` propagate correctly when we use futures we need to wrap the `ExecutionContext` used by Akka and our services. This basically means we'll create a Monix `TracingScheduler` from an `ExecutionContext` and use that when we create our `ActorSystem`.

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/common/src/common/HttpApp.scala"></script>

Now that we have everything set up, we can use `CorrelationId.local()` in our logs and know that we'll always get an ID unique to the current request.

Here's what that looks like in our logging directive and two services

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/common/src/common/LoggingDirective.scala"></script>

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/b/src/b/Service.scala"></script>

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/a/src/a/Service.scala"></script>

Now our `a` logs have

> [scala-execution-context-global-12] INFO a.Service - [0NnmzjUxbfk5OZG1kDzb2g] b took 245ms to respond  
[scala-execution-context-global-19] INFO a.Service - [oo4VS6CW0r7QPtSe2fzHxg] b took 245ms to respond  
[scala-execution-context-global-11] INFO a.Service - [mlyjVSbzq4-619HTgB5Wag] b took 246ms to respond  
[scala-execution-context-global-11] INFO common.LoggingDirective - [mlyjVSbzq4-619HTgB5Wag] responded to GET http://localhost:8080/ HTTP/1.1 in 255ms  
[scala-execution-context-global-12] INFO common.LoggingDirective - [0NnmzjUxbfk5OZG1kDzb2g] responded to GET http://localhost:8080/ HTTP/1.1 in 255ms  
[scala-execution-context-global-19] INFO common.LoggingDirective - [oo4VS6CW0r7QPtSe2fzHxg] responded to GET http://localhost:8080/ HTTP/1.1 in 255ms  
[scala-execution-context-global-15] INFO a.Service - [TaPN1vgI6e4sWJbejlGRXg] b took 248ms to respond  
[scala-execution-context-global-15] INFO common.LoggingDirective - [TaPN1vgI6e4sWJbejlGRXg] responded to GET http://localhost:8080/ HTTP/1.1 in 256ms  
[scala-execution-context-global-17] INFO a.Service - [7uB87b52T6Ij9gLQkbRYjA] b took 248ms to respond  
[scala-execution-context-global-17] INFO common.LoggingDirective - [7uB87b52T6Ij9gLQkbRYjA] responded to GET http://localhost:8080/ HTTP/1.1 in 257ms  

and `b` logs have 

> [scala-execution-context-global-13] INFO b.Service - [Zg8AQEaMwAD43krJ0upXAg] a says 'Namaskar B'  
[scala-execution-context-global-15] INFO b.Service - [Fm3vl3iwKwB3PFj2m0xf4g] a says 'Konnichiwa B'  
[scala-execution-context-global-18] INFO b.Service - [F5wxknwF86HYV93C8LZP-g] a says 'Shalom B'  
[scala-execution-context-global-12] INFO b.Service - [UpeEsDRGNUkMwIMTll06hA] a says 'Hola B'  
[scala-execution-context-global-18] INFO common.LoggingDirective - [F5wxknwF86HYV93C8LZP-g] responded to POST http://localhost:8081/ HTTP/1.1 in 29ms  
[scala-execution-context-global-12] INFO common.LoggingDirective - [UpeEsDRGNUkMwIMTll06hA] responded to POST http://localhost:8081/ HTTP/1.1 in 29ms  
[scala-execution-context-global-15] INFO common.LoggingDirective - [Fm3vl3iwKwB3PFj2m0xf4g] responded to POST http://localhost:8081/ HTTP/1.1 in 29ms  
[scala-execution-context-global-13] INFO common.LoggingDirective - [Zg8AQEaMwAD43krJ0upXAg] responded to POST http://localhost:8081/ HTTP/1.1 in 29ms  
[scala-execution-context-global-18] INFO b.Service - [8oZkANG1uvQUWinqRQkSXw] a says 'Hallo B'  
[scala-execution-context-global-18] INFO common.LoggingDirective - [8oZkANG1uvQUWinqRQkSXw] responded to POST http://localhost:8081/ HTTP/1.1 in 1ms

Perfect, now we can see which logs go together both on the same service and across services.   
The only thing left to do is aggregate logs from a and b into the same place. Stay tuned for an article on structured logging and log aggregation with tools like Loggly and Zipkin!

## Sidenotes

On rare occasion a third party library will return a `Future` without the local context. The Akka HTTP client's `Http().singleRequest` is one example of this. To work around this we can use this helper method to put the context back in the future.

<script src="https://gist-it.appspot.com/https://github.com/kag0/scala-log-tracing/blob/aeac5dbd17f1b8690c67de20beedab27f1e6e73e/common/src/common/package.scala"></script>
