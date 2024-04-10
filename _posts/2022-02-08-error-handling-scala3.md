---
layout: post
title:  "Scala 3: Error handling in FP land"
date:   2022-02-08 17:45:00
categories: scala error-handling fp functional-programming
github_comments_issueid: "18"
---

### Table of contents

* [Introduction](#introduction)
* [Error types](#error-types)
  + [Union types to the rescue!](#union-types-to-the-rescue)
* [Error handling](#error-handling)
  + [Bottom layer](#bottom-layer)
  + [Middle layer](#middle-layer)
  + [Top layer](#top-layer)
* [Furthermore](#furthermore)
* [Conclusion](#conclusion)

### Introduction

Scala 3 introduces [union types](https://docs.scala-lang.org/scala3/reference/new-types/union-types.html). Straight from the official documentation, a union type `A | B` has as values all values of type `A` and also all values of type `B`.

So the following code snippet compiles performing an exhaustive pattern-matching.

{% highlight scala %}
def foo(x: Int | Long): Unit =
  x match
    case _: Int  => println("Int!!!")
    case _: Long => println("Long!!!")
{% endhighlight %}

However, you are not here for boring examples, are you? :)

### Error types

Union types are the perfect feature to model error types. In Scala 2, we could represent the presence of errors via the `Either` monad. E.g.

{% highlight scala %}
type Err = Either[UserNotFound, Unit]
{% endhighlight %}

However, if we want to model other errors, we can either get into [Shapeless' Coproducts](https://github.com/milessabin/shapeless/blob/70076c2/core/src/main/scala/shapeless/coproduct.scala) (fairly common during the Free Monad hype-era!) or into nested `Either`s (arghhh). E.g.

{% highlight scala %}
type Err = Either[Either[DuplicateStory, UserNotFound], Unit]
{% endhighlight %}

Though, as we usually work in some `F[_]` context, you can imagine things get only much more complicated and less ergonomic from here.

#### Union types to the rescue!

With union types, we can keep a single `Either` instead.

{% highlight scala %}
type Err = Either[DuplicateStory | UserNotFound, Unit]
{% endhighlight %}

Or we could eliminate the `Either` type altogether!

{% highlight scala %}
type Err = DuplicateStory | UserNotFound | Unit
{% endhighlight %}

Much nicer! Now, how do we get this to play nicely in the `F` context? Bear with me a little longer.

### Error handling

In my experience, error types are only desirable at the bottom layers. Most of the error handling should occur at the mid layers (business logic) where the errors are eliminated, or perhaps a few errors should be left for the top layers to handle.

To put these words into an example, let's say we work with a three-layer application.

#### Bottom layer

At the bottom level, we have an `UserStore` that interacts with a database.

{% highlight scala %}
trait UserStore[F[_]]:
  def fetch(id: UserId): F[Option[User]]
  def save(user: User): F[Either[DuplicateEmail | DuplicateUsername, Unit]]
{% endhighlight %}

Where the error types are subtypes of `Throwable` (this will make our lives easier).

{% highlight scala %}
import scala.util.control.NoStackTrace

case object DuplicateEmail extends NoStackTrace
type DuplicateEmail = DuplicateEmail.type

case object DuplicateUsername extends NoStackTrace
type DuplicateUsername = DuplicateUsername.type
{% endhighlight %}

If you have read my book [Practical FP in Scala](https://leanpub.com/pfp-scala), you know I am not a big fan of stack traces :)

#### Middle layer

Now at the middle layer, we might have our business logic, making calls to the `UserStore`, and perhaps to other components that interact with the outside world.

In the following mid layer, our aim is to handle all declared errors, so we pattern match on all cases.

{% highlight scala %}
def mid1[F[_]: Logger: MonadThrow](
    producer: Producer[F, String],
    userStore: UserStore[F]
): User => F[Unit] = user =>
  userStore.save.flatMap {
    case Right(_) =>
      producer.send(s"User $user persisted!")
    case Left(DuplicateEmail) =>
      Logger[F].error(s"Email ${user.email} already taken!")
    case Left(DuplicateUsername) =>
      Logger[F].error(s"Email ${user.email} already taken!")
  }
{% endhighlight %}

After `flatMap`ping the result of `save`, we can pattern-match on the possible values. The nice thing here is that the Scala compiler checks for exhaustivity, so we never miss a declared error, in case that changes in the future.

Sometimes, however, it happens that we are only interested in handling a subset of the errors, and whatever is added later should be handled at the top layers.

Let's say we only need to handle the `DuplicateEmail` error.

{% highlight scala %}
def mid2[F[_]: Logger: MonadThrow](
    producer: Producer[F, String],
    userStore: UserStore[F]
): User => F[Either[DuplicateUsername, Unit]] = user =>
  userStore.save.flatMap {
    case Right(_) =>
      producer.send(s"User $user persisted!").map(_.asRight)
    case Left(DuplicateEmail) =>
      Logger[F].error(s"Email ${user.email} already taken!").map(_.asRight)
    case Left(e) =>
      e.asLeft.pure[F]
  }
{% endhighlight %}

Any other error is caught in the last case, where we simply leave it unhandled.

This works, though, the ergonomics are not the best, as we need to manually call `asRight` and `asLeft` in different places. We can improve the UX with some custom extension methods.

{% highlight scala %}
def mid3[F[_]: Logger: MonadThrow](
    producer: Producer[F, String],
    userStore: UserStore[F]
): User => F[Either[DuplicateUsername, Unit]] = user =>
  userStore
    .save
    .rethrow
    .as(s"User $user persisted!")
    .recoverErrorWith {
      case DuplicateEmail =>
        Logger[F].error(s"Email ${user.email} already taken!")
    }
    .lift
{% endhighlight %}

First of all, `rethrow` eliminates the inner `Either`, giving us `F[Unit]`. Next, we handle the error we are interested in via `recoverErrorWith`. Both functions are defined by `ApplicativeError`.

Until here the resulting type remains `F[Unit]`. At last, the magic happens when we call `lift` and get `F[Either[DuplicateUsername, Unit]]` back!

So what is `lift`? It is a custom extension method defined as follows.

{% highlight scala %}
extension [F[_]: MonadThrow, A](fa: F[A])
  @nowarn
  def lift[E <: Throwable]: F[Either[E, A]] =
    fa.map(_.asRight[E]).recover { case e: E => e.asLeft }
{% endhighlight %}

UPDATE: [Vasil Vasilev](https://github.com/vasilmkd) discovered the existence of `attemptNarrow` from `ApplicativeError`, after having a quick chat about the differences between `lift` and `attempt`, which is exactly what this does.

The only difference, is that `attemptNarrow` requires a `ClassTag`, but that's not a problem :)

{% highlight scala %}
def lift[E <: Throwable: ClassTag]: F[Either[E, A]] =
  fa.attemptNarrow
{% endhighlight %}

We could use `attemptNarrow` directly, but if you get to the end of this post, you'll understand why I chose to keep the `lift` extension method instead.

Notice that for this to work, we need to either declare the function's return type or to indicate what types we expect when we call `lift`. E.g.

{% highlight scala %}
val f: IO[Unit] = IO.raiseError(Err1)

val g: IO[Either[Err1 | Err2, Unit]] = f.lift

val h = f.lift[Err1 | Err2]

g <-> h
f <-> g.rethrow <-> h.rethrow
{% endhighlight %}

Here's another way of doing the same without `rethrow` and `recoverErrorWith`.

{% highlight scala %}
def mid4[F[_]: Logger: MonadThrow](
    producer: Producer[F, String],
    userStore: UserStore[F]
): User => F[Either[DuplicateUsername, Unit]] = user =>
  userStore.save.flatMap {
    case Right(_) =>
      producer.send(s"User $user persisted!")
    case Left(DuplicateEmail) =>
      Logger[F].error(s"Email ${user.email} already taken!")
    case Left(e) =>
      e.raiseError
  }.lift
{% endhighlight %}

The only problem with the technique used in both `mid3` and `mid4`, is that we lose the error type information after a partial error handling and lifting. For instance, if we add another error to `UserStore[F]#save`, the compiler won't help us here.

Nevertheless, this is easily fixed by pattern matching on all the errors, but it might require some repetition regarding `raiseError`.

{% highlight scala %}
def mid5[F[_]: Logger: MonadThrow](
    producer: Producer[F, String],
    userStore: UserStore[F]
): User => F[Either[DuplicateUsername, Unit]] = user =>
  userStore.save.flatMap {
    case Right(_) =>
      producer.send(s"User $user persisted!")
    case Left(DuplicateEmail) =>
      Logger[F].error(s"Email ${user.email} already taken!")
    case Left(DuplicateUsername) =>
      e.raiseError
  }.lift
{% endhighlight %}

If we add another `FooError` type in the bottom layers, the compiler is going to catch it here for us, and all we need to go is to re-raise it.

{% highlight scala %}
case Left(FooError) =>
  e.raiseError
{% endhighlight %}

That's what I mean with the potential repetition regarding `raiseError`.

To conclude with this mid-layer section, let's just say that all of these error handling techniques are valid; only they have different trade-offs.

#### Top layer

At the top layer, is where we either handle the error or we let it crash. So here's the perfect place to use `rethrow` or `raiseError`s we don't care about.

In the following example, we do not care about any unhandled errors so we let it fail.

{% highlight scala %}
def top1(
    consumer: Consumer[IO, User],
    mid: User => IO[Either[DuplicateUsername, Unit]]
): IO[Unit] =
  consumer.receive.evalMap { user =>
    mid(user).rethrow *> consumer.ack
  }
{% endhighlight %}

If this is called by a library like Http4s, this will be translated into an HTTP response with code 500, for example.

Or we could do something about it.

{% highlight scala %}
def top2(
    consumer: Consumer[IO, User],
    mid: User => IO[Either[DuplicateUsername, Unit]]
): IO[Unit] =
  consumer.receive.evalMap { user =>
    mid(user).flatMap {
      case Right(_) => consumer.ack
      case Left(DuplicateUsername) =>
        logger.warn("Duplicate username") *> consumer.ack
    }.handlerErroWith { e =>
      logger.error(s"Unhandled $e, let it crash?") *> consumer.nack
    }
  }
{% endhighlight %}

Any unhandled errors will be logged and unacked (negative acknowledge).

### Furthermore

At the beginning of the post, when the idea of using union types for error modelling was introduced, it was hinted that we could eliminate the `Either` altogether. How about that?

Starting from the bottom layer, we can do this instead.

{% highlight scala %}
trait UserStore[F[_]]:
  def fetch(id: UserId): F[Option[User]]
  def save(user: User): F[DuplicateEmail | DuplicateUsername | Unit]
{% endhighlight %}

However, by doing so, we lose the `rethrow` ability, as we are no longer working with `Either`.

Challenge accepted! Let's introduce a `rethrowU` that works on union types.
{% highlight scala %}
extension [F[_]: MonadThrow, E <: Throwable, A](fa: F[E | A])
  def rethrowU: F[A] =
    fa.map(_.asEither).rethrow

extension [E <: Throwable, A](ut: E | A)
  @nowarn
  def asEither: Either[E, A] =
    ut match
      case e: E => Left(e)
      case a: A => Right(a)
{% endhighlight %}

In the same way, we can also introduce a `liftU`, defined in terms of `lift` under the same scope.

{% highlight scala %}
extension [F[_]: MonadThrow, A](fa: F[A])
  def liftU[E <: Throwable: ClassTag]: F[E | A] =
    lift.map(_.asUnionType)

extension [E, A](either: Either[E, A])
  def asUnionType: E | A =
    either match
      case Left(e: E)  => e
      case Right(a: A) => a
{% endhighlight %}

This is the reason why I kept the `lift` extension method instead of using `attemptNarrow`. However, I could have also named this `attemptNarrowU` instead of `liftU`, but I prefer the shorter names :)

Now we can rewrite the final `mid5` as follows.

{% highlight scala %}
def mid6[F[_]: Logger: MonadThrow](
    producer: Producer[F, String],
    userStore: UserStore[F]
): User => F[DuplicateUsername | Unit] = user =>
  userStore.save.flatMap {
    case () =>
      producer.send(s"User $user persisted!")
    case DuplicateEmail =>
      Logger[F].error(s"Email ${user.email} already taken!")
    case DuplicateUsername =>
      e.raiseError
  }.liftU
{% endhighlight %}

And the final `top2` as shown below.

{% highlight scala %}
def top3(
    consumer: Consumer[IO, User],
    mid: User => IO[DuplicateUsername | Unit]
): IO[Unit] =
  consumer.receive.evalMap { user =>
    mid(user).flatMap {
      case () => consumer.ack
      case DuplicateUsername =>
        logger.warn("Duplicate username") *> consumer.ack
    }.handlerErroWith { e =>
      logger.error(s"Unhandled $e, let it crash?") *> consumer.nack
    }
  }
{% endhighlight %}

### Conclusion

I think this error modeling and handling technique is very promising. I would probably still keep the `Either[E1 | E2, A`] model over `E1 | E2 | A`, but this blog post has demonstrated that both options are valid.

The code shown in this post hasn't been compiled, but I use the very same technique in the project of my [upcoming book](https://leanpub.com/feda), so you can have a look the [source code](https://github.com/gvolpe/trading/tree/main/modules/forecasts/src/main/scala/trading/forecasts) directly.

Let's also remind ourselves that the left side of `Either` representing errors is merely a social agreement. We could as well do it the other way around, but that would need different `Functor` / `Monad` instances, so it is not quite practical.

In the same way, we could agree that only the right hand-side type of a union type represents the successful value, and any other types on the left hand-side represent the errors. We could probably write typeclass instances that prove the lawfulness of such approach.

Error handling is always a hot topic in FP land, so don't take this as the *ultimate word*, but simply as a technique that can be exploited for our benefits :)

Cheers,
Gabriel.
