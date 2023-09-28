---
date: 2018-12-16
authors: [nathan]
description: >
  Our new blog is built with the brand new built-in blog plugin. You can build
  a blog alongside your documentation or standalone
categories:
  - Blog
---

# Web app front ends for people who don't want to have to continually re-learn front end

> If you're a javscript/front end developer who follows the latest sophisticated frameworks, or a lead with a team of rockstar front end developers looking to build the best app your designer can conceive of; then this isn't for you.
<!-- more -->

Not every tool and technology is right for every task or situation. These are the driving goals for the approach outlined below

1. Simplicity
	* Minimize the number of dependencies / imports
	* Minimize prerequisite knowledge
	* Minimize code complexity
2. Stability
	* Dependencies / imports used should still be maintained years from now, and should have very few breaking changes in that time
3. Scalability
	* In performance, the number of active users should not impact the front end itself
	* In functionality (if not design), we can implement an interface to work with a modern back-end API (we could implement amazon, but not lucidchart)

With that said, some context on the range of front end's out there

### GLAMP
The Good old LinuxApacheMysqlPhp stack. This isn't strictly LAMP, but generally anything which renders dynamic data into HTML on the back end and returns it to the browser.

* Synchronous
	* What's shown to the user is driven by a user interaction resulting in loading new pages 
* Server side rendering
#### Pros
* Can be very performant on low end devices since there is little or no javascript running
* Pages with data from many sources may load faster because of better network performance between the front end server and the data sources compared to the browser and the back end / data sources
#### Cons
* Performance scales poorly, because pages cannot be cached
* New content requires a page reload

### SPA
The modern Single Page Application is largely script driven. 

* Asynchronous 
	* What's shown on to the user is driven by user interaction or programmatic event resulting in scripts changing some content on the current page
* Client side rendering
	* Little or no HTML is delivered to the browser. Rather, javscript creates all the elements on the page (granted, some modern frameworks support server side rendering for the initial state, and are script driven after that).

#### Pros
* Most frameworks provide powerful two-way data binding to template and update what's on the page at any time without reloading
* Feels more like a traditional desktop application 
* Static scripts can be hosted on a CDN and scale well
#### Cons
* May perform poorly on lower end devices due to being script driven
* First load may be slower due to the entire app needing to be sent at once
* Mix of versioning, technologies, and compatibility can result in complicated build processes with polyfilling, transpiling, and dependency resolution

### Somewhere in the middle
What we'll cover today.
* (mostly) Synchronous
* Client side rendering
	* Static HTML is delivered to the browser, but a small script provides the data for the dynamic content
#### Pros
* Performs well across a range of devices
* Static parts of pages can be cached and hosted on a CDN
* Simplicity reduces learning curve
#### Cons
* New or refreshed content is accessed by a page reload, but that shouldn't be as much of a problem as it is with server side rendering since most of the page is cached

## Solution

So what are we actually talking about? In short it's two (three) dependencies:
### Bootstrap
Bootstrap makes it easy to quickly set up the style and layout of a page. It's been around since 2011 and hasn't changed too radically since then, but it has grown an abundance of documentation, community support, and usage guides. If you were inclined you could swap this out with any other library that does styling and layout like Google's material design for web. 
### jQuery 
jQuery is a transitive dependency from bootstrap, we'll only really use it directly to DRY up parts of our pages like headers and footers. 
> This requires import of the full jQuery library as opposed to the slim version required by boostrap. To optimize performance we could use handlebars partials instead of jQuery for the headers and footers.

When it comes to web libraries that are widely used, stable, and not going anywhere there is nothing that comes close to jQuery.
### Handlebars
From its readme:
> Handlebars.js is an extension to the [Mustache templating language](http://mustache.github.com/) created by Chris Wanstrath. Handlebars.js and Mustache are both logicless templating languages that keep the view and the code separated like we all know they should be.

Since 2012 handlebars has been the go-to javascript templating library. We'll use it to populate the parts of our pages which contain dynamic content (and very importantly, it will take care of escaping data to prevent code injection).
### fetch
Goodbye XMLHttpRequest! 
I know I said three dependencies, but fetch is built into the browser making it a very reliable choice and technically not a dependency.

> note: fetch is not supported in internet explorer, so if you need to support legacy browsers you'll want to use [github's fetch polyfil](https://github.com/github/fetch)

### The pattern

The pattern is very simple
1. Make a page for each view using bootstrap
2. Use handlebars to template out the portions containing dynamic content
3. When the page loads, use fetch to retrieve data from the back end
4. Populate the template with the data and inject it into the page

## Example

You can see a demo of a typical app with login built this way [here](https://kag0.github.io/handlestrap) (log in with any username and password).

Content pages [like this one](https://github.com/kag0/handlestrap/blob/master/whosits.html) are very simple at just over 60 lines long.

> Closing note: in contrast to the example app, you will want to precompile your handlebars templates. This will allow your pages to load much faster since the templates don't need to be compiled on each page load. All you need to do is include the precompiled templates in a script tag. You can see the same example app with precompiled templates [here](https://github.com/kag0/handlestrap/blob/precompile/whosits.html).

## Resources

https://htmldom.dev - see how to do simple to advanced functionality in vanilla JS
