---
layout: post
title:  "Context bound vs Implicit evidence: Performance"
date:   2019-03-12 10:28:00
categories: scala
comments: true
---

In a recent pull request review at work I suggested using context bound to declare effect capabilities instead of implicit values as this is what I see the most in OSS projects and it has also been my preference for a while. It makes the code look nicer even though the latter approach is equivalent. Context bound constraints get translated into implicits values at compile time.

#### Context bound

{% highlight scala %}
def p1[F[_]: Applicative: Console]: F[Unit] =
  Console[F].putStrLn("a") *>
    Console[F].putStrLn("b") *>
    Console[F].putStrLn("c")
{% endhighlight %}

#### Implicit values

{% highlight scala %}
def p2[F[_]](implicit ev: Applicative[F], c: Console[F]): F[Unit] =
  c.putStrLn("a") *>
    c.putStrLn("b") *>
    c.putStrLn("c")
{% endhighlight %}

Every time we call `Console[F]` what we are doing is invoking the "summoner" method normally defined as follows:

{% highlight scala %}
object Console {
  def apply[F[_]](implicit ev: Console[F]): Console[F] = ev
}
{% endhighlight %}

So the implicit value gets resolved at compile time only once but I've got a very good question:

> Is there any performance penalty introduced by the summoner?

And I thought I knew the answer... But I wasn't very sure so that was a call for examining the JVM bytecode and see the differences!

### JVM bytecode

Here's the bytecode generated for both `p1` and `p2`. Let's take a look at the differences.

#### Context bound program

{% highlight java %}
public <F extends java.lang.Object> F p1(cats.Applicative<F>, com.github.gvolpe.Console<F>);
  descriptor: (Lcats/Applicative;Lcom/github/gvolpe/Console;)Ljava/lang/Object;
  flags: ACC_PUBLIC
  Code:
    stack=4, locals=3, args_size=3
       0: getstatic     #56                 // Field cats/implicits$.MODULE$:Lcats/implicits$;
       3: getstatic     #56                 // Field cats/implicits$.MODULE$:Lcats/implicits$;
       6: getstatic     #61                 // Field com/github/gvolpe/Console$.MODULE$:Lcom/github/gvolpe/Console$;
       9: aload_2
      10: invokevirtual #65                 // Method com/github/gvolpe/Console$.apply:(Lcom/github/gvolpe/Console;)Lcom/github/gvolpe/Console;
      13: ldc           #67                 // String a
      15: invokeinterface #73,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      20: aload_1
      21: invokevirtual #77                 // Method cats/implicits$.catsSyntaxApply:(Ljava/lang/Object;Lcats/Apply;)Lcats/Apply$Ops;
      24: getstatic     #61                 // Field com/github/gvolpe/Console$.MODULE$:Lcom/github/gvolpe/Console$;
      27: aload_2
      28: invokevirtual #65                 // Method com/github/gvolpe/Console$.apply:(Lcom/github/gvolpe/Console;)Lcom/github/gvolpe/Console;
      31: ldc           #79                 // String b
      33: invokeinterface #73,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      38: invokeinterface #82,  2           // InterfaceMethod cats/Apply$Ops.$times$greater:(Ljava/lang/Object;)Ljava/lang/Object;
      43: aload_1
      44: invokevirtual #77                 // Method cats/implicits$.catsSyntaxApply:(Ljava/lang/Object;Lcats/Apply;)Lcats/Apply$Ops;
      47: getstatic     #61                 // Field com/github/gvolpe/Console$.MODULE$:Lcom/github/gvolpe/Console$;
      50: aload_2
      51: invokevirtual #65                 // Method com/github/gvolpe/Console$.apply:(Lcom/github/gvolpe/Console;)Lcom/github/gvolpe/Console;
      54: ldc           #84                 // String c
      56: invokeinterface #73,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      61: invokeinterface #82,  2           // InterfaceMethod cats/Apply$Ops.$times$greater:(Ljava/lang/Object;)Ljava/lang/Object;
      66: areturn
    LineNumberTable:
      line 10: 0
      line 11: 24
      line 10: 43
      line 12: 47
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      67     0  this   Lcom/github/gvolpe/summoner$;
          0      67     1 evidence$1   Lcats/Applicative;
          0      67     2 evidence$2   Lcom/github/gvolpe/Console;
  Signature: #49                          // <F:Ljava/lang/Object;>(Lcats/Applicative<TF;>;Lcom/github/gvolpe/Console<TF;>;)TF;
  MethodParameters:
    Name                           Flags
    evidence$1                     final
    evidence$2                     final
{% endhighlight %}

#### Implicit values program

{% highlight java %}
public <F extends java.lang.Object> F p2(cats.Applicative<F>, com.github.gvolpe.Console<F>);
  descriptor: (Lcats/Applicative;Lcom/github/gvolpe/Console;)Ljava/lang/Object;
  flags: ACC_PUBLIC
  Code:
    stack=4, locals=3, args_size=3
       0: getstatic     #56                 // Field cats/implicits$.MODULE$:Lcats/implicits$;
       3: getstatic     #56                 // Field cats/implicits$.MODULE$:Lcats/implicits$;
       6: aload_2
       7: ldc           #90                 // String 1
       9: invokeinterface #73,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      14: aload_1
      15: invokevirtual #77                 // Method cats/implicits$.catsSyntaxApply:(Ljava/lang/Object;Lcats/Apply;)Lcats/Apply$Ops;
      18: aload_2
      19: ldc           #92                 // String 2
      21: invokeinterface #73,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      26: invokeinterface #82,  2           // InterfaceMethod cats/Apply$Ops.$times$greater:(Ljava/lang/Object;)Ljava/lang/Object;
      31: aload_1
      32: invokevirtual #77                 // Method cats/implicits$.catsSyntaxApply:(Ljava/lang/Object;Lcats/Apply;)Lcats/Apply$Ops;
      35: aload_2
      36: ldc           #94                 // String 3
      38: invokeinterface #73,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      43: invokeinterface #82,  2           // InterfaceMethod cats/Apply$Ops.$times$greater:(Ljava/lang/Object;)Ljava/lang/Object;
      48: areturn
    LineNumberTable:
      line 15: 0
      line 16: 18
      line 15: 31
      line 17: 35
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      49     0  this   Lcom/github/gvolpe/summoner$;
          0      49     1 evidence$3   Lcats/Applicative;
          0      49     2     c   Lcom/github/gvolpe/Console;
  Signature: #49                          // <F:Ljava/lang/Object;>(Lcats/Applicative<TF;>;Lcom/github/gvolpe/Console<TF;>;)TF;
  MethodParameters:
    Name                           Flags
    ev                             final
    c                              final
{% endhighlight %}

So the bytecode generated for the context bound approach has a few extra calls to `getstatic` and `invokevirtual` but what does this actually mean? Find below the definition given by [Wikipedia](https://en.wikipedia.org/wiki/Java_bytecode_instruction_listings):

- `getstatic`: get a static field value of a class, where the field is identified by field reference in the constant pool index (indexbyte1 << 8 + indexbyte2)
- `invokevirtual`: invoke virtual method on object objectref and puts the result on the stack (might be void); the method is identified by method reference index in constant pool (indexbyte1 << 8 + indexbyte2)

So, is it slower? How can we know? There's only one way...

### Benchmark it all!

When not sure about some performance question / issue, benchmark your code. Benchmarking is not easy but fortunately in the JVM we have a fantastic tool: [Java Microbenchark Harness](https://openjdk.java.net/projects/code-tools/jmh/) or `JMH` for short.

Here are the simple benchmarks I wrote, calling each method thousand times via `replicateA` and measuring the throughput:

{% highlight scala %}
import cats.Id
import cats.implicits._
import org.openjdk.jmh.annotations._

class benchmarks {

  @Benchmark
  @BenchmarkMode(Array(Mode.Throughput))
  def contextBoundSummoner(): Unit = p1[Id].replicateA(1000).void

  @Benchmark
  @BenchmarkMode(Array(Mode.Throughput))
  def evidenceSummoner(): Unit = p2[Id].replicateA(1000).void

}
{% endhighlight %}

And these are the results, running with 20 iterations, 5 warm-up iterations, 1 fork and 1 thread:

{% highlight bash %}
sbt> jmh:run -i 20 -wi 5 -f1 -t1
[info] Benchmark              Mode  Cnt      Score     Error  Units
[info] contextBoundSummoner  thrpt   20  15777.375 ± 593.111  ops/s
[info] evidenceSummoner      thrpt   20  17302.136 ± 442.127  ops/s
{% endhighlight %}

### Conclusion

The difference is small enough to not be a performance concern so I would still recommend using the context bounds approach but remember to benchmark and deeply analyze your code before jumping to conclusions!

### Update

After publishing it on [Twitter](https://twitter.com/volpegabriel87/status/1105330247086399488) I've got good feedback and some suggestions so here's the update.

#### Macro-based summoner: imp

[Chris Birchall](https://twitter.com/cbirchall) shared this interesting macro-based project named [imp](https://github.com/non/imp) by [Erik Osheim](https://twitter.com/d6) and I ran the same analysis with it.

First of all, the summoner was changed accordingly using the `summon` macro.

{% highlight scala %}
object Console {
  import imp.summon
  import language.experimental.macros

  def apply[F[_]: Console]: Console[F] = macro summon[Console[F]]
}
{% endhighlight %}

And here are the results of the benchmarks, running 20 iterations like before:

{% highlight bash %}
sbt> jmh:run -i 20 -wi 5 -f1 -t1
[info] Benchmark              Mode  Cnt      Score     Error  Units
[info] contextBoundSummoner  thrpt   20  14881.788 ± 626.458  ops/s
[info] evidenceSummoner      thrpt   20  15039.118 ± 411.016  ops/s
{% endhighlight %}

The macro-based solution was faster as it claims to be. The scores are almost identical and that's because the *JVM bytecode generated by both methods are exactly the same!* And effectively running the benchmarks more times gives similar results and sometimes the winner is the classic `evidenceSummoner`. So we can safely claim that both methods `p1` and `p2` are exactly the same for the JVM.

FWIW someone else [have run benchmarks](https://github.com/DarkDimius/imp-bench) on `imp` before. They're slightly different though.

#### @inline final

[Pavel Khamutou](https://twitter.com/pkhamutou) suggested adding the `@inline` keyword to the summoner and I have also made it `final` so here's how it looks like:

{% highlight scala %}
object Console {
  @inline final def apply[F[_]](implicit ev: Console[F]): Console[F] = ev
}
{% endhighlight %}

Unfortunately the generated JVM bytecode was the same as without trying to inline it so the benchmark results were very similar to the first results.

#### `-opt:l:inline` & `-opt-inline-from:**` compiler flags

[Kaidax](https://twitter.com/kaidaxofficial) suggested turning on the inliner compiler flags as described in this [Lightbend blog post](https://developer.lightbend.com/blog/2018-11-01-the-scala-2.12-2.13-inliner-and-optimizer/index.html). At first I didn't see any results but after being pointed out on Reddit by [/u/zzyzzyxx](https://www.reddit.com/user/zzyzzyxx) that I was doing it wrong (thanks!), I tried once again and the bytecode was effectively changed.

The calls to `invokevirtual` have been removed and a bunch of extra instructions have been added.

{% highlight java %}
public <F extends java.lang.Object> F p1(cats.Applicative<F>, com.github.gvolpe.Console<F>);
  descriptor: (Lcats/Applicative;Lcom/github/gvolpe/Console;)Ljava/lang/Object;
  flags: ACC_PUBLIC
  Code:
    stack=4, locals=3, args_size=3
       0: getstatic     #56                 // Field cats/implicits$.MODULE$:Lcats/implicits$;
       3: getstatic     #56                 // Field cats/implicits$.MODULE$:Lcats/implicits$;
       6: getstatic     #61                 // Field com/github/gvolpe/Console$.MODULE$:Lcom/github/gvolpe/Console$;
       9: ifnonnull     14
      12: aconst_null
      13: athrow
      14: aload_2
      15: ldc           #63                 // String a
      17: invokeinterface #69,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      22: aload_1
      23: invokevirtual #73                 // Method cats/implicits$.catsSyntaxApply:(Ljava/lang/Object;Lcats/Apply;)Lcats/Apply$Ops;
      26: getstatic     #61                 // Field com/github/gvolpe/Console$.MODULE$:Lcom/github/gvolpe/Console$;
      29: ifnonnull     34
      32: aconst_null
      33: athrow
      34: aload_2
      35: ldc           #75                 // String b
      37: invokeinterface #69,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      42: invokeinterface #78,  2           // InterfaceMethod cats/Apply$Ops.$times$greater:(Ljava/lang/Object;)Ljava/lang/Object;
      47: aload_1
      48: invokevirtual #73                 // Method cats/implicits$.catsSyntaxApply:(Ljava/lang/Object;Lcats/Apply;)Lcats/Apply$Ops;
      51: getstatic     #61                 // Field com/github/gvolpe/Console$.MODULE$:Lcom/github/gvolpe/Console$;
      54: ifnonnull     59
      57: aconst_null
      58: athrow
      59: aload_2
      60: ldc           #80                 // String c
      62: invokeinterface #69,  2           // InterfaceMethod com/github/gvolpe/Console.putStrLn:(Ljava/lang/Object;)Ljava/lang/Object;
      67: invokeinterface #78,  2           // InterfaceMethod cats/Apply$Ops.$times$greater:(Ljava/lang/Object;)Ljava/lang/Object;
      72: areturn
    StackMapTable: number_of_entries = 3
      frame_type = 255 /* full_frame */
        offset_delta = 14
        locals = [ class com/github/gvolpe/summoner$, class cats/Applicative, class com/github/gvolpe/Console ]
        stack = [ class cats/implicits$, class cats/implicits$ ]
      frame_type = 255 /* full_frame */
        offset_delta = 19
        locals = [ class com/github/gvolpe/summoner$, class cats/Applicative, class com/github/gvolpe/Console ]
        stack = [ class cats/implicits$, class cats/Apply$Ops ]
      frame_type = 88 /* same_locals_1_stack_item */
        stack = [ class cats/Apply$Ops ]
    LineNumberTable:
      line 10: 0
      line 34: 14
      line 10: 14
      line 11: 26
      line 34: 34
      line 11: 34
      line 10: 47
      line 12: 51
      line 34: 59
      line 12: 59
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      73     0  this   Lcom/github/gvolpe/summoner$;
          0      73     1 evidence$1   Lcats/Applicative;
          0      73     2 evidence$2   Lcom/github/gvolpe/Console;
  Signature: #49                          // <F:Ljava/lang/Object;>(Lcats/Applicative<TF;>;Lcom/github/gvolpe/Console<TF;>;)TF;
  MethodParameters:
    Name                           Flags
    evidence$1                     final
    evidence$2                     final
{% endhighlight %}

The benchmark results show that it has effectively been optimized:

{% highlight bash %}
sbt> jmh:run -i 20 -wi 5 -f1 -t1
[info] Benchmark             Mode  Cnt      Score     Error  Units
[info] contextBoundSummoner  thrpt   20  16330.873 ± 462.765  ops/s
[info] evidenceSummoner      thrpt   20  15768.175 ± 587.291  ops/s
{% endhighlight %}

#### Benchmarking machine

The benchmarks have run on a Ubuntu 18.04 LTS, 16 GB RAM and Intel® Core™ i7-8550U CPU @ 1.80GHz × 8 machine on Java Oracle™ 8:

{% highlight bash %}
Java(TM) SE Runtime Environment (build 1.8.0_161-b12)
Java HotSpot(TM) 64-Bit Server VM (build 25.161-b12, mixed mode)
{% endhighlight %}

#### Source code

Try it out yourself: https://github.com/gvolpe/summoner-benchmarks

### Conclusion #2

The conclusion remains the same. Context bound constraints are my favorite and as demonstrated have very little overhead. Using the macro-based solution is interesting but if you really care about that level of performance maybe the JVM isn't what you're looking for? :)

***Thank you all for your amazing feedback!***
