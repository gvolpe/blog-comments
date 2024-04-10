---
layout: post
title:  "Scala 3: the missing compiler plugin"
date:   2022-11-20 10:45:00
categories: scala fp functional-programming tooling
github_comments_issueid: "19"
---

If you have read this post when it first came out and felt offended by its catchy title, let me apologize for it. It caused some controversy, so I decided to change the title completely to highlight more what this post was about in the first place. Hope this time folks read to the end before drawing any conclusion :)

---

[Scala 3](https://docs.scala-lang.org/scala3/new-in-scala3.html) has been around for a while now, but not many people are using it in production just yet. There's a lot of skepticism in the community when starting out a new project.

It is still a niche language, even though it has seen a lot of adoption in the past few years. Given its hybrid OOP-FP nature, there are "sub-communities" within the language, one of them being those that go FP all the way embraced by organizations such as [Typelevel](https://typelevel.org/), which has its own ecosystem of libraries.

## Tooling

From what I gathered from different folks, tooling and linting seem to be the biggest push-backs regarding Scala 3 adoption. Although tooling keeps on getting better every day when using [Metals](https://scalameta.org/metals/), it seems IntelliJ IDEA support is not quite there yet---you can follow its progress using the [Scala 3 tag](https://youtrack.jetbrains.com/issues?q=tag:%20%7BScala%203%7D).

As a Metals+NeoVim user myself, I am highly satisfied with the tooling support. Though, I must admit I don't use too many features besides completion, navigation and diagnostics.

Furthermore, new features such as significant whitespace and fewer braces only make it more difficult for tooling to get feature-parity with Scala 2.
 
The official site has a [Tooling Tour](https://docs.scala-lang.org/scala3/guides/migration/tooling-tour.html) page offering a status report of the different tools such as Sbt, Mill and Maven (the latter still unsupported).

## Linting

Linting has been neglected in Scala 3, that's the sad truth. Only in June this year [it has been made official](https://github.com/lampepfl/dotty/issues/15503), and it got assigned in August as a "semester project", but it may take a while until [this work](https://github.com/lampepfl/dotty/pull/16157) sees the light.

Anyway, I think linting features such as "unused variables" and "unused imports" are only a nice-to-have, so I can understand why this work was not prioritized.

However, there is one linting feature that has been blocking the FP community from taking this new version of the language more seriously: `-Wvalue-discard`.

It may seem insignificant, but this little feature can prevent massive bugs from reaching production in purely functional codebases. Here's an example that showcases its importance.

{% highlight scala %}
val program: IO[Unit] =
  IO.ref(List.empty[Int]).flatMap { ref =>
    IO.println("performing critical work")
    ref.set(List.range(0, 11))
  }
{% endhighlight %}

Suppose the `IO.println` does indeed perform critical work. We would be discarding that value, perhaps accidentally, and the Scala compiler won't help us fix this bug! This is extremely critical, and even seasoned functional programmers can forget to connect such values (e.g. via `*>` or `flatMap`).

{% highlight scala %}
sbt:demo> compile
[success] Total time: 0 s, completed Nov 20, 2022, 2:08:20 PM
{% endhighlight %}

This kind of code can be even harder to manually spot in larger codebases.

Scala 2 ships with `-Wvalue-discard` (formerly known as `-Ywarn-value-discard`), which would only emit a warning with the same code, but it is highly recommended to make it a fatal error via the `-Xfatal-warnings` flag (also present in Scala 3).

The [sbt-tpolecat](https://github.com/typelevel/sbt-tpolecat) plugin makes it easy for us to focus on writing code if we let it manage the configuration of such important flags, which can be further customized.

It is also worth noticing that there is a [draft PR](https://github.com/lampepfl/dotty/pull/15975) started by [Chris Birchall](https://github.com/cb372) sometime ago attempting to add support for `-Wvalue-discard` to the Scala 3 compiler, but it has unfortunately gone inactive.

Point in case, you may now understand why folks writing pure FP code are being skeptical about adopting Scala 3 in production systems! So, do we wait another year and see if it's finally ready by then?

### Give up all hope?

Thankfully, not. Meet the [Zerowaste](https://github.com/ghik/zerowaste) compiler plugin coming to the rescue! It detects unused expressions (non-Unit), and it works for all major Scala versions.

All we need is to add the plugin to our codebase as follows:

{% highlight scala %}
libraryDependencies += compilerPlugin("com.github.ghik" % "zerowaste" % "<version>" cross CrossVersion.full)
{% endhighlight %}

Together with enabling `sbt-tpolecat`, the example code no longer compiles.

{% highlight scala %}
sbt:demo> [info] compiling 6 Scala sources to /home/gvolpe/demo/target/scala-3.2.1/classes ...
[error] -- Error: /home/gvolpe/demo/src/main/scala/demo/Main.scala:12:6
[error] 12 |      IO.println("performing critical work")
[error]    |      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
[error]    |      discarded expression with non-Unit value
[error] one error found
[error] (Compile / compileIncremental) Compilation failed
[error] Total time: 1 s, completed Nov 20, 2022, 2:23:39 PM
{% endhighlight %}

Yes! Exactly what we all FP nerds have been waiting for :)

## Final thoughts

Although some features are still missing, **I absolutely love Scala 3** and promote its usage in production (we use it at work too). I even [wrote a book](https://leanpub.com/feda) that endorses this new version of the language.

Yes, it would be great if more linting features land in the Scala compiler. But until then, we can rely on the Zerowaste compiler plugin. Still, it could benefit from more testing! 

If you have a Scala 3 project, please do give it a try and report any issues you may find. We can help each other and grow as a community together :)

Finally, huge thanks to [Roman Janusz](https://github.com/ghik) (author of Zerowaste) for being the unsung Scala 3 FP hero!
