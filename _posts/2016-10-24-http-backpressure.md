---
layout: post
author: nathan
title: Managing Back-Pressure in HTTP Service Systems with Circuit Breakers
---

Back-pressure is when a component in a system is under load and it communicates this to other components which depend on it. The circuit breaker design pattern allows system components to fail-fast when components on which it depends become unavailable. System components typically manifest load in one of two scenarios.  
First, a **slow component depends on a fast component**. This is the desirable easy case, the dependent component requests to another component and quickly gets a reply back. No amount of load on the dependent component will cause it or any other components to be bottlenecked by the dependency and the performance of the dependency will not degrade. No special handling is needed here, but the system should be ready if this ceases to be the case.  
Second, a **fast component depends on a slow component**. This becomes an issue when load which can be handled by the dependent component overloads the dependency. This is where we want the dependency to apply back-pressure to the dependent component so that it lessens the load on the dependency, preventing its performance from degrading.  

# Identifying load

How a component measures load is application dependent; a nonblocking server component might measure cycle time on the event loop, while a processing component might measure CPU usage. We'll introduce a simple hello world service (using spark framework in java) as our base component which uses CPU to detect load.

```java
public class HelloWorld {
    public static void main(String[] args) {
        get("/hello", (req, res) -> "Hello World");
    }
    
    private static OperatingSystemMXBean systemMx = ManagementFactory.getOperatingSystemMXBean();

    private static boolean isOverloaded(){
        return systemMx.getSystemLoadAverage() > 90;
    }
}
```

> note: you'll also want your system to be elastic, which means that when a moderate load has been reached (let's say 70% CPU in this case) more resources should be added to this component. In practice this probably means bringing up another instance of the component to share the load.

# Exerting back-pressure

In any case, once a component identifies that it is overloaded, it should fail-fast with an error message to inform the caller of the back-pressure.   
Our service simply returns a 500 with a primitive error:

```java
before((request, response) -> { if(isOverloaded()) halt(500, "backpressure"); });
get("/hello", (req, res) -> "Hello World");
```

# Handling back-pressure

## With a dependent component

Typically a request is initated by some other component which is expecting a response. If this is the case then as soon as the component detects back-pressure from its dependencies, it should fail-fast and exert back-pressure on the caller. 

Let's define a simple middle-man service which will need to handle the back pressure from the hello service.  

```java
public class MiddleMan {
    // assume the middle man also has some method of detecting load on itself like hello world does
    public static void main(String[] args) {
        get("/saywhat", (req, res) -> {
            HttpResponse<String> response = Unirest.get(helloServiceUrl + "/hello").asString();
            if(response.getStatus() == 200){
                return "Middleman says " + response.getBody();
            } else {
                res.status(500);
                return "Middleman says AAAAAGH";
            }
        });
    }
}
```

Now let's add a circuit breaker (I'll use [javaslang circuitbreaker](https://github.com/javaslang/javaslang-circuitbreaker)) around hello world and pass any back-pressure to the caller.   

```java
public static void main(String[] args) {
    CircuitBreakerRegistry circuitBreakerRegistry = CircuitBreakerRegistry.ofDefaults();

    get("/saywhat", (req, res) -> {
        CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("helloWorldBackpressure");
        if(circuitBreaker.isCallPermitted()){
            HttpResponse<String> response = Unirest.get(helloServiceUrl + "/hello").asString();
            if(response.getStatus() == 200){
                circuitBreaker.recordSuccess();
                return "Middleman says " + response.getBody();
            } else {
                res.status(500);
                if(response.getBody().equals("backpressure")){
                    circuitBreaker.recordFailure(new RuntimeException("got backpressure"));
                    return "backpressure";
                }
                return "Middleman says AAAAAGH";
            }
        } else {
            res.status(500);
            return "backpressure";
        }
    });
}
```

Now we can see that before we contact hello world, we check the status of the circuit breaker. If the circuit breaker has been tripped then we know hello world is exerting back-pressure. By not making the call while back-pressure is being exerted, we don't put any more load on hello world, allowing it to catch up on it's work and recover.

> note: we made a circuit breaker specifically for back-pressure and no others. In practice you will also want to add circuit breakers for other failures, such as timeouts or refused connections. When circuit breakers are activated for serious failures (timeout or dropped connection, not back-pressure) the system should raise alerts for its maintainers.

## Without a dependent component

### Where the caller is a user

If the component recieving back-pressure is a user interface, then you've reached the end of the dependency chain, you can simply alert the user that the system is currently unavailable. 

> whoa, but I don't want the system to be unavailable to the user!  

of course not. An earlier note mentioned elasticity. Making your components elastic will enable the system to increase capacity before back-pressure is exerted. However at some point the system may not be able to scale quickly enough or there will be no more resources avaliable to allocate. In this case it is better to quickly display an error to the user than to make them wait for a timeout followed by an error.

### With a fire-and-forget caller

In some cases a caller drops work off at the component and then leaves, not expecting a response to the work. Here as long as the work was successfully dropped off, the component must complete the work, even if one of its dependent components is exerting back-pressure. Such a component might look like this:

```java
public class WorkerMan {
    // assume the worker man also has some method of detecting load on itself like hello world does
    public static void main(String[] args) {
        BlockingQueue<String> q = new LinkedBlockingQueue<>();
        post("/say/:message", (req, res) -> {
            q.add(req.params("message"));
            return "I'll get right on that";
        });
        new Thread(() -> {
            while(true){
                String message = q.take();
                HttpResponse<String> response = Unirest.get(middlemanUrl + "/saywhat").asString();
                System.out.println(response.getBody() + " Workerman says " + message);
            }
        }).run();
    }
}
```

The caller drops off messages which the worker then processes later using middleman. So what do we do if middleman is exerting back-pressure and we can't use him to do our work?

#### Reschedule the work

One way or another the work needs to be done, and it can't be done right now, so we schedule for it to be done later. Depending on the system, there will be different ways to do this, but for us let's just leave the message on the queue and wait a bit.

```java
new Thread(() -> {
    while(true){
        CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("middlemanBackpressure");
        if(circuitBreaker.isCallPermitted()){
            String message = q.take();
            HttpResponse<String> response = Unirest.get(middlemanUrl + "/saywhat").asString();
            if(response.getStatus() == 200){
                circuitBreaker.recordSuccess();
                System.out.println(response.getBody() + " Workerman says " + message);
            } else {
                q.add(message);
                if(response.getBody().equals("backpressure"))
                    circuitBreaker.recordFailure(new RuntimeException("got backpressure"));
            }
        } else Thread.sleep(200);
    }
}).run();
```

Better, now we're reducing load on middleman and getting our work done later.

#### Exert back-pressure on the caller

Unfortunately, we still have a problem. If we continue to allow callers to drop off work then we risk eating up resources holding all the work, losing the work, or getting so behind on work that it takes an unacceptable amount of time for us to catch up to it all. So what do we do? Fail fast and exert back-pressure on the caller. We aren't able to let a caller know about back-pressure when we process their work, but we can let callers know about back-pressure when they drop off their work. If we control the input end of our queue, we can use the circuit breaker again:

```java
post("/say/:message", (req, res) -> {
    CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("middlemanBackpressure");
    if(circuitBreaker.isCallPermitted()){
        q.add(req.params("message"));
        return "I'll get right on that";
    } else {
        res.status(500);
        return "backpressure";
    }
});
```

This works well, back-pressure is now passed upstream and workerman is safe from being overloaded. However sometimes the component on the output end of the queue is not in control of the input end (common when using something like SQS or rabbitMQ), or the circuit breaker for the dependency is not available at the input end (we'll try to emulate this in our example). In this case it is better to bound the queue. This way work doesn't get backed up, and the queue will let the caller know that their work was not added if the queue is full. We might have something like this.

```java
int capacity = 20;
BlockingQueue<String> q = new SomeRemoteBlockingQueue<>(capacity);
if(q.offer(req.params("message"))){
    // looks good
} else {
    throw new RuntimeException("better do something with this backpressure");
}
```

Looks good, now we know when the queue is full that means we are receiving back-pressure.

# Conclusion

Now we have three components; they can operate under load, and will always respond quickly and intelligibly (although they may not have a successful response, because we didn't add anything to make them elastic).  
Obviously the code examples here are rather simple, and use a particular language and libraries; however the concepts are applicable in any language with any http server. 
