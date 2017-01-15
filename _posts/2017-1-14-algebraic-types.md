---
layout: post
author: nathan
title: Algebraic Data Types in Java
---

Many languages, especially functional ones, make use of algebraic data types. That is, types that have fixed and well known subtypes or implementations. Most languages have some keyword to allow the developer to prevent new implementations of the class from being made. One example would be the `sealed` keyword on scala traits, which prevents the trait from being implemented anywhere except for in the file where it was declared.  
Java does not have any keywords like this, but it's a common misconception that algebraic data types can't be made in java. Java can have algebraic data types, and in fact it's quite simple and doesn't require anything released in recent versions.  
Simply put: all we need are abstract classes with private constructors and static inner classes. A quick example:

```java
public abstract class Bool {
    private Bool(){}
    public abstract boolean value();
    
    public static final class True extends Bool {
        public boolean value(){
            return true;
        }
    }
    public static final class False extends Bool {
        public boolean value(){
            return false;
        }
    }
}
```

A `Bool` can now be either `Bool.True` or `Bool.False`. No class outside of `Bool` can subclass `Bool` because of the `private` scope of the constructor, and there can be no instance of `Bool` itself since it is `abstract`.  
One more thing that we did, but didn't have to do in this example is make `True` and `False` `final` classes. This allows us to say that `Bool` either *is* `True` or *is* `False` rather than what we would say if we didn't have `final`, which is that `Bool` either is *a* `True` or is *a* `False`.

If you're not familiar with algebraic data types, you may be asking why we would want to do this in the first place, or why we didn't implement `Bool` as an `Enum`. The reason we didn't use an enum is that unlike our simple example above many algebraic data types have a different structure between their subclasses, an enum however has the same structure between every possible value. To illustrate this better, I'll implement a haskell style immutable linked list with some methods.

```java
public abstract class List<T> implements Iterable<T> {
	private List(){}

	public static <T> List<T> of(T... elements){
		List<T> list = new Nil<>();
		for(int i = elements.length; i --> 0;){
			list = new Cons<>(elements[i], list);
		}
		return list;
	}

	public abstract int size();
	public abstract boolean contains(T that);
	public abstract <B> List<B> map(Function<T, ? extends B> mapper);

	public static class Cons<T> extends List<T> {
		public final T head;
		public final List<T> tail;

		public Cons(T head, List<T> tail){
			this.head = head;
			this.tail = tail;
		}

		public int size() {
			return 1 + tail.size();
		}

		public boolean contains(T that) {
			return head.equals(that) || tail.contains(that);
		}

		public <B> List<B> map(Function<T, ? extends B> mapper) {
			return new Cons<>(mapper.apply(head), tail.map(mapper));
		}

		public String toString(){
			return head + ", " + tail;
		}
	}

	public static class Nil<T> extends List<T>{
		public int size() { return 0; }
		public boolean contains(T that) { return false; }
		public <B> List<B> map(Function<T, ? extends B> mapper) { return new Nil<>(); }
	}
}
```

Not too bad, but implementing each method in the subclasses did make us write a lot, and we haven't implemented `iterator()` for `Iterable` yet, since it doesn't lend itself well to recursion. So let's toss a `match(Function<Cons<T>, B>)` method in there which will make it easier for us to access each type without using `instanceof` and a cast. We'll use a java 8 `Optional` (which itself would be good to implement as an algebraic data type, see the end of the post for what that would look like) to help us with `match`. `match` will return empty for `Nil`, and return the application of a function on itself for `Cons`, and with that we'll move the implementations of our methods up into `List` and implement `iterator()`. 

> __note:__ Usually with inheritance you want to move your logic and implementations down lower in the inheritance tree, you want your higher classes to define behavior and your lower classes to implement it, and you don't want higher classes to be concerned with what kinds of implementations there are. Algebraic data types on the other hand are the opposite. Since the implementations are fixed and we know exactly what they are, there's no problem.

```java
public abstract class List<T> implements Iterable<T>{
	private List(){}

	public static <T> List<T> of(T... elements){
		List<T> list = new Nil<>();
		for(int i = elements.length; i --> 0;){
			list = new Cons<>(elements[i], list);
		}
		return list;
	}

	public abstract <B> Optional<B> match(Function<Cons<T>, B> f);

	public int size(){
		return match(thiz ->
				1 + thiz.tail.size()
		).orElse(
				0
		);
	}

	public boolean contains(T that){
		return match(thiz ->
				that.equals(thiz.head) || thiz.tail.contains(that)
		).orElse(
				false
		);
	}

	public <B> List<B> map(Function<T, ? extends B> mapper){
		return match(thiz ->
				(List<B>) new Cons<>(mapper.apply(thiz.head), thiz.tail.map(mapper))
		).orElse(
				new Nil<>()
		);
	}

	public Iterator<T> iterator() {
		List<T> outer = this;
		return new Iterator<T>() {
			List<T> inner = outer;
			public boolean hasNext() {
				return inner instanceof Cons;
			}
			public T next() {
				T ret = inner.match(thiz -> thiz.head)
						.orElseThrow(() -> new NoSuchElementException("Nil has no elements"));
				inner = inner.tail();
				return ret;
			}
		};
	}

	public List<T> tail(){
		return match(thiz ->
				thiz.tail
		).orElse(
				this
		);
	}

	public static class Cons<T> extends List<T> {
		public final T head;
		public final List<T> tail;

		public Cons(T head, List<T> tail){
			this.head = head;
			this.tail = tail;
		}

		public <B> Optional<B> match(Function<Cons<T>, B> f) {
			return Optional.of(f.apply(this));
		}

		public String toString(){
			return head + ", " + tail;
		}
	}

	public static class Nil<T> extends List<T>{
		public <B> Optional<B> match(Function<Cons<T>, B> f){ return Optional.empty(); }
		public String toString(){ return "Nil";	}
	}
}
```

As previously mentioned, here's how `Optional` might look as an algebraic data type as well (only the methods we used were included, but would likely include many more).

```java
public abstract class Option<T> {
	private Option(){}

	public abstract T orElse(T that);
	public abstract T orElseThrow(Exception t) throws Exception;

	public static class Some<T> extends Option<T> {
		public final T value;

		public Some(T value){
			this.value = value;
		}
		
		public T orElse(T that) {return value;}
		public T orElseThrow(Exception t) {return value;}
	}

	public static class None<T> extends Option<T> {
		public T orElse(T that) {return that;}
		public T orElseThrow(Exception t) throws Exception {throw t;}
	}
}
```

