---
layout: post
author: nathan
title: An Advent of Scala
---

> note to readers: this is a pretty casual article. if you see something interesting (in the article or in the github implementation) that you'd like me to elaborate on, plese open a github issue or [contact me](https://nrktkt.tk#contact).

This year I decided to try to go through the [Advent of Code](https://adventofcode.com/2020). I didn't make it past day 10 before holiday chaos set in IRL... Still, I thought this could be an opportunity to explain how Scala can be used for problem solving.  
> For those who aren't aware, Advent of Code is 25 days of coding challenges just-for-fun, starting the first of December.  

Without further ado, I'll walk through a few days of challenges and point out elements of the language used along the way.  
All the days I have completed are available [here](https://github.com/tclostio/AOC2020/tree/nathan) and are implemented in vanilla Scala 2.13. 

# [Day 1: Report Repair](https://adventofcode.com/2020/day/1)

I won't go through describing the entire story and challenge of each day, but you can click on the header for the day to read the original prompt.

## Modelling the input

For each day, we need to read the input from a file and give it some structure. We'll call that part of the day "Modelling the input". 

Day 1's input is a file of numbers like 
```
1721
979
366
299
675
1456
```
where each line represents an amount in an expense report entry. I modeled it like this:

```scala
val input = 
  Source.fromResource("day1.txt")
    .getLines()
    .map(line => line.toInt)
```

### scala.io.Source

`Source` and `getLines()` is going to be our file-reading workhorse, it gives us a lazily evaluated stream of lines from the file (although never needed, this means that some of our solutions can run with constant memory).

### .map

The `map` method transforms each element of a collection and returns a new collection. Here we're taking each line in our collection of lines (our file) and turning it into an `Int`.

## Part one

We need to multiply two numbers in the list that add up to 2020.

Not ideal, but we're going to jump into the deep end with a feature that isn't the simplest, and also not the best fit here.  
![](https://media.giphy.com/media/huyWtUq1NsGsRFRY02/source.gif)

```scala 
def expenses2(entries: Seq[Int]) = 
  for {
    e1 <- entries
    e2 <- entries
    solution = e1 * e2 if e1 + e2 == 2020
  } yield solution
```

### [for-comprehension](https://docs.scala-lang.org/tour/for-comprehensions.html)

I won't go too in-depth into for-comprehensions. But in this case it's essentially like a more powerful nested for-each loop that you might find in other languages, except that it returns a value, and gives you the opportunity to filter out some of the input. So the above code is saying "multiply together all the pairs of values that add up to 2020 and discard the rest".

Unfortunately, while this is compact, it's not optimal. Because it examines every permutation of the entries, rather than every combination.

## Part two

In part two we need to find every triple of entries which adds to 2020, rather than each pair. While we could just add another line to the for-comprehension from part one, that inefficiency would be hard to swallow. So here we have an optimal recursive solution.  

```scala
def expenses3(entries: Seq[Int]) = {
  @tailrec
  def recurse(
    entries1: Seq[Int],
    entries2: Seq[Int],
    entries3: Seq[Int]
  ): Int = (entries1, entries2, entries3) match {
    // found the ones we're looking for, multiply the values and return
    case (e1 +: _ , e2 +: _ , e3 +: _  ) if e1 + e2 + e3 == 2020 => e1 * e2 * e3
    // we're advancing our inner-most loop
    case (es1     , es2     , _  +: es3) => recurse(es1, es2, es3)
    // we're advancing our middle loop
    case (es1     , _ +: es2,   Nil    ) => recurse(es1, es2, entries)
    // we're advancing our outer-most loop
    case (_ +: es1, Nil     ,    _     ) => recurse(es1, entries, entries)
  }

  recurse(entries, entries, entries)
}
```

We'll see a lot of problems in AoC that need this kind of "find a combination of n elements that meets this criteria" solution, so later I'll pull this functionality out into a helper that reduces problems like this to a one-liner.

### Nested methods

In this implementation, we can see that `recurse` is implemented inside the scope of `expenses3`. This is permitted in Scala to an arbitrary depth, and is useful when a helper method is needed so that the helper method isn't exposed in the same scope as `expenses3`.

### [Pattern matching](https://docs.scala-lang.org/tour/pattern-matching.html)

Pattern matching is similar to `switch` statements in other languages, but much more powerful.   
Pattern matching starts off with the `match` keyword. On the left hand side you have a value, and on the right you have possible cases for that value (so far just like a `switch` statement). However, pattern matchign doesn't fall through to the next case, only the matching case is ever executed.  
The true power of pattern matching is that it matches not only literals for each case, but actually allows you to deconstruct the value that you're matching.  
For example, `case (a, b, c)` is matching a case where the value is a three-tuple and `a`, `b`, and `c` now reference the values in the tuple.  
In our cases we see expressions like `e +: es`. In scala expressions, `+:` returns a sequence with a value prepended. ie. `1 +: 2 +: Nil` would return `Seq(1, 2)`. In a case statement it does the opposite to deconstruct a sequence. So in 
```scala
1 +: 2 +: 3 +: Nil match { case e +: es => ???}
``` 
`e` would be `1`, and `es` would be `Seq(2, 3)`.  
Pattern matching also allows for guards. Which we can see in our base (first) case. We not only require there to be three elements available, but also that those elements sum to 2020.

### [Tail recursion](https://en.wikipedia.org/wiki/Tail_call)

By adding the `@tailrec` annotation to a method, we're telling the compiler to fail if it can't apply tail call optimization (so that additional stack frames aren't created for each invocation) to our method. The compiler will still do this optimization without our annotation, but with the annotation it will guarantee the optimization is done.

# [Day 2: Password Philosophy](https://adventofcode.com/2020/day/2)

Phew, day one came out a little hairy. But now that you're here on day two we can admire a input parsing problem that Scala makes trivial.

## Modelling the input

We're given some list of passwords with corresponding policies
```
1-3 a: abcde
1-3 b: cdefg
2-9 c: ccccccccc
```
Which we can model as two numbers, a policy letter, and the password

```scala
val inputPattern = raw"(\d+)-(\d+) (\w): (\w+)".r

val input = Source.fromResource("day2.txt")
  .getLines()
  .map { 
    case inputPattern(lo, hi, char, pw) => (lo.toInt, hi.toInt, char.head, pw) 
  }
```

### [Regular expressions](https://docs.scala-lang.org/tour/regular-expression-patterns.html)

I've created a regular expression to parse the input
```scala
val inputPattern = raw"(\d+)-(\d+) (\w): (\w+)".r
```
I'll skip explaining the regex itself, but on either side of the string we have some things worth noting.  
`raw` is a string interpolator in scala which disables escape sequences. So we can write `\d` instead of `\\d`.  
`.r` compiles the preceding string into a regular expression.

In the flurry of features from day one I talked about pattern matching. One of the coolest features here is that regular expressions let you deconstruct a string in the pattern. So 
```scala
case inputPattern(lo, hi, char, pw)
```
takes our regex (which had four capture groups) and extracts the values in the capture groups.

## Part one

We need a method to check if a password is valid for a given rule.

```scala
def passwordValid(lo: Int, hi: Int, char: Char, pw: String) = {
  val count = pw.count(_ == char)
  lo <= count && count <= hi
}
```
Pretty straight forward, we need to know how many times a character occurs in a string.
```scala
pw.count(_ == char)
```
here `.count` takes a function from character to boolean (which has the type signature `Char => Boolean`) and returns the number of characters that return `true` for that function.  
The `_` is simply the wildcard function syntax that is a compact way to write `c => c == char`.

Then we want to see how many passwords in the list are valid
```scala
def countValid(
  passwords: Seq[(Int, Int, Char, String)], 
  validator: (Int, Int, Char, String) => Boolean
) = passwords.count(validator.tupled)
```
In the same way we counted how many characters a match in each password, we can also count how many passwords match in the list.   

`validator.tupled` is worth breaking down. It's simply a way to modify `validator` to work with the type of elements in `passwords`. This is a common Scala "gotcha", because if we look at the type of each element of `passwords` and the input type of `validator` they both appear to be `(Int, Int, Char, String)`. However `validator` is actually a function which accepts four parameters, while each element of `passwords` is one four-tuple. So `.tupled` takes an n-arity function and turns it into a unary function where the single parameter is a n-tuple.

Tying the two methods together, we just invoke `countValid(input, passwordValid)`.

## Part two

Same as part one, but they've changed how we're meant to validate the password.
```scala
def passwordValid2(lo: Int, hi: Int, char: Char, pw: String) = 
  pw(lo -1) == char ^ pw(hi -1) == char
```

in Scala you can use a collection as if it were an array (or python dict if you like), but with parens instead of brackets. And `String`s are effectively a sequence of `Char`s. So `pw(lo -1)` returns the character at index `lo -1`.

# [Day 4: Passport Processing](https://adventofcode.com/2020/day/4)

Jumping ahead (I thought I had an interesting solution for day 3, but not much unique to Scala) to day four, we run into the first of what I call the "annoying inputs". 

## Modelling the input

I say this is an annoying input because rather than each element (passport in this case) being separated by a new line, it's separated by two new lines and each field of the passport is separated by a space or new line.

```scala
val passportField = raw"(\w+):(.+)".r

val input = Source.fromResource("day4.txt")
  .mkString                                                // turn the whole file into a string
  .split(raw"\n\n")                                        // split into passports based on empty lines
  .map(_.split(raw"\s"))                                   // split passports into field:value pairs
  .map(_.map { case passportField(k, v) => k -> v }.toMap) // turn field value pairs into a map (shocker)
```

`mkString` is not the same as `toString` (like Java has). It calls `toString` on each element of a collection and concatenates all the results together.

## Part two

Field validation time

```scala
val hex = raw"^#\w{6}\Z".r
val eyeColors = Set("amb", "blu", "brn", "gry", "grn", "hzl", "oth")

object Int {
  // try to parse the string into an integer, don't match if it fails
  def unapply(str: String) = Try(str.toInt).toOption
}

def validatePassport(passport: Map[String, String]) = 
  passport
    .filter { // remove all fields that don't match constraints
      case ("byr", Int(yr)) => 1920 <= yr && yr <= 2002
      case ("iyr", Int(yr)) => 2010 <= yr && yr <= 2020
      case ("eyr", Int(yr)) => 2020 <= yr && yr <= 2030
      case ("hgt", s"${Int(cm)}cm") => 150 <= cm && cm <= 193
      case ("hgt", s"${Int(in)}in") => 59  <= in && in <= 76
      case ("hcl", hex())           => true
      case ("ecl", color)           => eyeColors.contains(color)
      case ("pid", id @ Int(_))     => id.length == 9
      case _ => false
    }
    .keySet == requiredFields // ensure all required fields remain
```

We've already seen a lot of features here, pattern matching in particular is nicely displayed at work.

### Extractor methods

In the patterns above I used an `Int` extractor to match strings that could be parsed as `Int`s. 
```scala
object Int {
  // try to parse the string into an integer, don't match if it fails
  def unapply(str: String) = Try(str.toInt).toOption
}
```
To see how this works we'll take a dive under the hood of pattern matching.

When matching a case, the compiler looks for an `unapply` method on the extractor (an object named `Int` in this case). It passes the value being tested to that method. If the method returns an `Option` with a value, then the match succeeds, otherwise it fails. So here `Try(str.toInt)` attempts to parse the string into an `Int` and `Try` catches any exception if it fails. Then `toOption` discards the exception and converts the `Try` to an `Option`.

### Pattern matching strings

Scala has handy string interpolation, by prefixing your string with `s` it tells the compiler to interpolate values that start with `$` or expressions inside `${...}`. eg.
```scala
val name = "world"
s"hello $name" // hello world
```

This works the opposite way in case statements as well, so
```scala
"hello world" match { 
  case s"hello $name" => name 
} // returns "world"
```

### Naming before extraction

We also have the line

```scala
case ("pid", id @ Int(_)) => id.length == 9
```

Here, the `@` lets us use the unextracted value as well as applying an extractor. So `id` contains the original string value, and `Int(_)` checks that that string will parse as an `Int` but throws away the the actual value.  
The entire line therefore says "return the number of digits in `id`, which is definitely a whole number".

# [Day 6: Custom Customs](https://adventofcode.com/2020/day/6)

## Modelling the input

Grab all the lines (individual responses), split groups on empty lines.

```scala
val input: Seq[Seq[String]] = 
  LazyList.from(
    Source.fromResource("day6.txt")
      .getLines()
  ).split("")
```

`LazyList` is a smart immutable stream that allows us to use the `split` method which is unavailable on the `Iterator` that `Source` gives us. 

## Part one

Simple set manipulation here

```scala
val questionsWithAnyYes = 
  input
    .map(group =>
      group
        .map(individual => individual.toSet)              // turn each individual's answers into a set
        .reduce((person1, person2) => person1 ++ person2) // union of the group's answers
        .size                                             // count the answers for the group
    )
    .sum 
```

I said previously that `String`s were basically sequences of `Char`s, so `individual.toSet` turns a `String` into a `Set` of characters.

`reduce` is a handy function that collapses a collection of values down to one value of the same type. Here it takes the union of the set of answers that each individual gave.

# [Day 9: Encoding Error](https://adventofcode.com/2020/day/9)

Remember I promised I'd make a one-liner out of day 1? Day 9 is the day of helpers, extracting re-usable concepts and leaving simple usages.

## The helpers

### `collectFirst2`

We saw on day one why this is useful, but let's break down a few built in scala methods that can be combined to explain what we have here. 

#### `filter`

`filter` applies a predicate (test) to each element in a collection and returns a collection containing only the elements which passed the test.

#### `collect`

`collect` combines `filter` with `map` (which I mentioned on day 1). It filters the collection and then transforms the remaining elements.

#### `find`

Like `filter`, but returns only the first element that matches the predicate.

#### `collectFirst`

A combination of `collect` and `find`, transforms and returns the first element that matches the predicate.

#### Partial functions

Not all functions are applicable for all inputs. Partial functions express functions which are only defined for some values of the input type. eg. division is not defined when the denominator is zero. `collect` uses partial functions to combine the predicate of `filter` with the transformation of `map`.  
You can use the `lift` method of a `PartialFunction[A, B]` to turn it into a `A => Option[B]`.

Finally our `collectFirst2`, which combines the first two elements of a list which meet a predicate.

```scala
def collectFirst2[B](f: PartialFunction[(A, A), B]) = {      
  @tailrec
  def recurse(
    entries1: Seq[A],
    entries2: Seq[A]
  ): Option[B] =  
    (entries1, entries2) match {
      case (e1 +: _, e2 +: _) if f.isDefinedAt(e1, e2) => f.lift(e1, e2)
      case (es1, _ +: es2) => recurse(es1, es2)
      case (_ +: es1, Nil) => recurse(es1, list)
      case _ => None
    }

  recurse(list, list)
}
```

### foldWhile

#### `fold`

`fold` is method like `reduce` which I mentioned earlier, but it allows you provide an initial element (useful in case the collection is empty).

#### `take`

`take` returns the first n elements of a collection and drops the rest.

#### `takeWhile`

Like `take`, but uses a predicate instead of a fixed number. So it returns elements until one doesn't match the predicate, then it drops everything after that.

Here `foldWhile` combines `fold` and `takeWhile` by folding elements as long as they meet a predicate and returning the accumulated value when an element is encountered which doesn't match the predicate.

```scala
@tailrec
def foldWhile[A, B](seq: Seq[A])(acc: B)(f: PartialFunction[(B, A), B]): B = 
  seq match {
    case head +: tail => 
      f.lift((acc, head)) match {
        case Some(b) => foldWhile(tail)(b)(f)
        case None    => acc
      }
    case Seq() => acc
  }
```

## Part one

With collectFirst2, part one becomes simple

```scala
def findFirstInvalid(preamble: Int, nums: Seq[Long]) = {
  def hasMatchingPair(num: Long, i: Int) = 
    nums
      .drop(i) // only include the preample-length numbers before this one
      .take(preamble)
      .collectFirst2 { case (a, b) if a + b == num => () }
      .isDefined

  nums
    .drop(preamble) // skip the preamble
    .zipWithIndex
    .collectFirst { case (num, i) if !hasMatchingPair(num, i) => num }
}
```

### `zipWithIndex`

Combines the elements of a sequence with their index.

## Part two

```scala
case class Acc(min: Long = Long.MaxValue, max: Long = 0, sum: Long = 0) {
  def :+(num: Long) = Acc(
    math.min(min, num), 
    math.max(max, num), 
    sum + num
  )
}

@tailrec
def findWeakness(invalidNum: Long, nums: Seq[Long]): Option[Long] = {
  val run = nums.iterator.foldWhile(Acc()) {
    case (acc, num) if acc.sum + num <= invalidNum => acc :+ num
  }

  if(run.sum == invalidNum) Some(run.min + run.max)
  else nums.tail match {
    case Seq() => None
    case tail  => findWeakness(invalidNum, tail)
  }
}
```

### Case classes

Case classes are one of the most used features in Scala. They provide an immutable container for your data, automatically generate extractors so you can pattern match against them, and provide an automatic `.equals` and `.toString`.  
Here I'm using a case class to accumulate statistics about the numbers I've encountered so far, as well as providing a home for the logic of adding a number to the accumulation.

# [Day 11: Seating System](https://adventofcode.com/2020/day/11)

I won't get into the implementation here unless someone asks for it, the only new Scala feature I used is unicode support.
```scala
def ⇖ = iterateDirection(_ ⬉)
```
You can use (almost) any unicode character as a variable or method name in Scala. This is rarely advisable in production, but I'm on vacation so...

# Conclusion

That's all for now. This was a rather hasty holiday post but I hope you learned at least one thing from it. Please do [contact me](https://nrktkt.tk#contact) or open a github issue if you'd like more explanation anywhere or coverage of how the actual logic of a solution works (whether it's one I touched on here or implemented on github).