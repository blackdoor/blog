---
layout: post
author: nathan
title: Interview Sized Actors for State Control
---

Lately I've been administering an interview question (not the one you'll see below, but with similar race condition concerns) which has gotten me thinking.
The question works well enough for checking a candidate's familiarity with the language (Java or Scala in this case) and their ability to reason. 
But due to race conditions, solutions are never close to something most candidates or I would be happy with in production. 
The closest solutions to something production ready (including my own reference implementation) will employ data structures or synchronization primitives that would block threads and cause slowdowns in modern non-blocking applications.  
I've come up with the below pattern based on the actor model after thinking a bit on what one could reasonably produce in the span of an interview.

The [actor model](https://en.wikipedia.org/wiki/Actor_model) provides several benefits for creating non-trivial programs. 
It provides control of state by localizing state changes, 
it facilitates error handling by creating heirarchies of actors which manage other actors,
it provides fast non-blocking concurrency by constraining communication to one-way message passing, 
and it enables location transparency (the ability to run the same code on one or multiple machines without needing to account for the distribution in logic code) by carrying those messages across network boundaries the same way they're carried across threads.  
I'll show you an actor implementation that focuses on state control and sacrifices other typical actor benefits (and how you can make up for them with other patterns) in order to be small enough to be used in an interview solution.

## Interview Prompt

Suppose an interviewer gave us this problem:

> Implement a banking system to run on one large machine. 
> Users should be able to open an account, 
> deposit money,
> check their balance, 
> withdraw money (preventing any overdrafts), 
> transfer money between accounts,
> and close their account.
> Many users should be able to access the system at the same time.

From that last requirement we can tell that we're going to be dealing with some level of concurrency if we want to scale this system up.

## Why We Need State Control

This system is basically a bunch of counters to track account balances. 
We're clearly going to run into double write issues here when those balances are accessed concurrently.
We can prove this to ourselves with a few lines on a multi-core machine

```scala
var x = 0

Await.ready(Future.sequence(
  for(_ <- 0 until 1000) yield {
    Future { x = x + 1 }
  }
), Duration.Inf)

println(x)
```

we increment a variable 1000 times in parallel and then check the variable's value after waiting for all the concurrent jobs to complete. 
Unfortunately this is never going to result in `x == 1000` because parallel threads will read the same value, both increment it, and both write it; resulting in one of the increments being lost.

The most immediate remedy is to reach for `java.util.concurrent.atomic.AtomicInteger` (or a `synchronized` block, or a Java standard library data structure oriented at concurrency), which will guaranteed that we do get the correct value. 
However it will cause head-of-line blocking in our thread pool leading to loss of performance.

So we can't naively manipulate our account balances from different threads, and we can't use old fashioned blocking solutions from Java[`*`](Footnotes). 

## Actor Implementation

We mentioned that one of the benefits of actors was state control, so let's see a mini actor system that can provide that for us. 

Let's start with a parent class for all our actors

```scala
trait Actor {
  protected def process(handler: => Unit): Unit
}
```

We can say that when we call `process` no code in `handler` will run at the same time as any other code passed to `process` for this actor. It's basically a non-blocking version of `synchronized` that will execute at some point in the future rather than right now.

Now the first half of what prevents our actor's state from being messed up by race conditons: a linear scheduler

```scala
object Actor {
  // scheduller
  val q = new LinkedBlockingQueue[() => Any]()
  (new Thread(() => {
    while (true) {
      val job = q.poll(10, MILLISECONDS)
      if (job != null) job()
    }
  })).start()
}
```

now we have a background thread that runs jobs submitted to a queue, but more importantly it does so one-by-one, meaning there can be no race conditions between jobs on the scheduler.

If you're still following along, then you are probably either thinking "Great, now we can do all our state manipulation in the scheduler and there will be no race conditions!", or you're thinking "You idiot. You can't just do all your state manipulations in the scheduler. You have just reduced performance down to one core".  
If you were thinking the former, you would be half right. 
If you were thinking the latter then you're totally right. Running all our state manipulations on one core is an unacceptable performance limitation.
However, that's not what we're going to do.

I called this background thread a scheduller instead of a worker for a reason.
The second half of what makes our actor work is going to be the actor's inbox. 
In a typical actor model the inbox would be a queue of messages waiting to be processed by the actor. 
In our system we're going skip the messages and use actions for the actor to run directly. 
Also we will use a conceptual queue rather than a data structure.

```scala
trait Actor {
  private var inbox: Future[Unit] = Future.successful(())
  // eventually safely apply some state change to the actor
  def process(handler: => Unit) = 
    // submit state change for scheduling
    Actor.q.offer(() => 
      // schedule the state change in the inbox
      inbox = inbox.andThen { case Success(_) => handler }
    )
}
```

Because per the `Future` scaladoc `inbox.andThen` 

> allows one to enforce that the callbacks are executed in a specified order 

we can chain `.andThen` invocations to keep a linear stream of state changes.
State changes across all actors can be split across multiple threads because `.andThen` takes an `ExecutionContext`, so all cores are fully utilized for state transformations.  
We use `=> Unit` to suspend the side effect of adding the state change to the actor's inbox and then only apply that side effect linearly on the scheduler.

### Did it work?

Back to our incrementing example

```scala
class Counter extends Actor {
  var i = 0
  def increment() = process { i = i + 1 }
}

val counter = new Counter

for(_ <- 0 until 1000) yield {
  Future { counter.increment }
}

Thread.sleep(1000)

println(counter.i)
```

looks good, we always get 1000 as the eventual actor state.

## Interview Solution

Now that we've prepped our actor concept (about 25 lines, plausible for the first portion of an interview), let's apply it to our interview problem. 

### Opening an account

First an actor for an account, simply keeping track of account balance

```scala
class Balance extends Actor {
  var balance = BigDecimal(0)
}
```

Then an actor for our entire bank, comprised of multiple accounts.

```scala
class Bank extends Actor {
  var accounts: Map[Int, Balance] = Map.empty
  var lastAccountNumber: Int = 0

  // open an account and return the new account number
  def openAccount(): Future[Int] = {
    val accountNumber = Promise[Int]
    process {
      accounts += (newAccountNumber -> new Balance)
      lastAccountNumber += 1    
      accountNumber.success(lastAccountNumber)
    }
    accountNumber.future
  }
}
```

Note that we probably want to know a) when the account creation is complete and b) what the new account number is. So we have a promise that will be completed when the actor is actually processing our message.

### Deposit money

This is easy, the same as our simple counter actor.

On our balance actor

```scala
def deposit(amount: Int) = process { balance += amount }
```

```scala
def deposit(account: Int, amount: Int): Unit = process(
  accounts.get(account).foreach(_.deposit(amount))
)
```

### Check balance

This is the simplest operation of all, since there is no guarantee that the balance will stay the same after the caller has asked for it, there's no need to wait for pending state transformations to be applied before returning the balance.

On our bank

```scala
def checkBalance(account: Int): Option[BigDecimal] = 
    accounts.get(account).map(_.balance)
```

### Withdraw funds

Here's where the actor really shines. We need to decrease an account balance without going below 0. 
This means reading state, making a decision, and then updating the state. 
A classic opportunity for concurrency issues.

```scala
def withdraw(amount: BigDecimal): Future[Boolean] = {
  val fundsAvailable = Promise[Boolean]
  process(
    if (state >= amount) {
      fundsAvailable.successful(true)
      balance -= amount
    } else fundsAvailable.successful(false)
  )
  fundsAvailable.future
}
```

Here we return `true` if there were enough funds available and the balance was decreased, or `false` if not enough funds were available.   
Withdrawing as much as possible and returning the amount that was available would also be a reasonable solution.

### Transfer money

Transfer is tricky, we need to ensure that

* no changes are made if the source account has insufficient funds
* the destination account will definitely receive the funds if they are withdrawn from the source account

We can do this with a multi-phase transfer. 
First we'll put a hold on the destination account to ensure that it isn't closed while we work. 
Then we can try to withdraw money from the source account.
Finally we can remove the hold on the destination account and deposit the money at the same time.

On our balance actor

```scala
var pendingTransfers = Map.empty[UUID, BigDecimal]
def initiateTransfer(amount: BigDecimal): Future[UUID] = {
  val result = Promise[UUID]
  val id = UUID.randomUUID
  process { 
    pendingTransfers += (id -> amount)
    result.success(id)
  }
  result.future
}

def finalizeTransfer(id: UUID, abort: Boolean) = 
  process {
    val amount = pendingTransfers.get(id)
    pendingTransfers -= id
    if(!abort) balance += amount.getOrElse(0)
  }
```

on our bank actor

```scala
def transfer(amount: BigDecimal, from: Int, to: Int) = {
  val destination = accounts(from)
  for {
    id <- destination.initiateTransfer(amount)
    fundsAvailable <- accounts.get(to).map(_.withdraw(amount))
                              .getOrElse(Future.successful(false))
    _ = destination.finalizeTransfer(id, !fundsAvailable)
  } {}
}
```

### Closing account

Closing the account is simple as well, we just want to make sure the account isn't carrying a balance.

```scala
// returns true if the account exists and was closed
def closeAccount(account: Int): Future[Boolean] = {
  val result = Promise[Boolean]
  process {
    if (accounts.get(account).exists(_.balance == 0)) {
      accounts -= account
      result.success(true)
    } else result.success(false)
  }
  result.future
}
```

The nice thing to note here is that actors are garbage collected. There is no need for the user or actor runtime (our scheduler) to explicitly kill actors since we gave up location transparency and don't refer to actors by address.

## Other Uses

### Publish / Subscribe

## Improvements

Since we're talking about the scope of an interview, I left a few things that we would not want to carry into production code. These could be discussion points at the end of an interview.

### Integrate `Promise` usage

In some methods we wanted to know when the operation was complete or what the outcome was.
That was done a bit tediously with `Promise`s inside and outside of `process`.
We could just make that part of `Actor` to help us out.

```scala
def process[A](handler: => A): Future[A] = {
  val result = Promise[A]
  // submit state change for scheduling
  Actor.q.offer(() => 
    // schedule the state change in the inbox
    inbox = inbox.andThen { case Success(_) => result.success(handler) }
  )
  result.future
}
```

then our withdraw example could simply be 

```scala
def withdraw(amount: BigDecimal): Future[Boolean] =
  process(
    if (state >= amount) {
      balance -= amount
      true
    } else false
  )
```

This does come with a risk though. 
When actors call one another's methods it's OK to return a future directly to their caller, but they MUST not modify any of their own state or call other actor methods in the callbacks of a future. 
Doing so could delay processing of other messages for that actor or cause state changes outside of our scheduler.

### Public `var`

Actors were implemented with state as public `var`s. In actual code we would want to be more intentional about what state is available outside the actor, and to ensure it is read-only. 
For example in our balance actor we would want the balance to be read-only and require calling a specific method to mutate. 

```scala
class Balance extends Actor {
  private var _balance = BigDecmimal(0)
  def balance = _balance
  def deposit(amount: Int) = process { _balance += amount }
}
```

This is simple object-oriented programming stuff.

### Scheduler thread

The scheduler runs in a `while(true)` loop, we'll want a way to shut it down.

```scala
object Actor {
  private var running = true
  ...
  (new Thread(() => {
    while (running) {
      ...
    }
  })).start()

  def shutdown() = running = false
}
```

## Footnotes

`*` No, loom won't help here. Entering a synchronized block pins the virtual thread to the carrier thread and prevents other virtual threads from proceeding on that carrier thread. 
