---
layout: post
title:  "Parallel typeclass for Haskell"
date:   2020-04-20 21:58:00
categories: haskell parallel validation purescript scala
comments: true
---

As I'm preparing a talk about refinement types I will be giving this Thursday at the [Functional Tricity Meetup](https://www.meetup.com/FunctionalTricity/events/269763842/), and I've recently given a [similar talk](https://scala.love/gabriel-volpe-why-types-matter/) using the Scala language as well, I realized there is a missing typeclass in Haskell.

In the following sections, I will be providing examples and use cases for this typeclass to showcase why it would be great to have it in Haskell. Oh, yes... I love refinement types as well!

In Haskell, we have the [refined](https://hackage.haskell.org/package/refined) library and other more complex tools such as [Liquid Haskell](https://hackage.haskell.org/package/liquidhaskell).

### Refinement types

Refinement types give us the ability to define validation rules, or more commonly called *predicates*, at the type level. This means we get compile-time validation whenever the values are known at compile-time.

Say we have the following predicates and datatype:

{% highlight haskell %}
import Refined

type Age  = Refine (GreaterThan 17) Int
type Name = Refine NonEmpty Text

data Person = Person
  { personAge :: Age
  , personName :: Name
  } deriving Show
{% endhighlight %}

We can validate the creation of `Person` at compile-time using Template Haskell:

{% highlight haskell %}
me :: Person
me = Person $$(refineTH 32) $$(refineTH "Gabriel")
{% endhighlight %}

If the age was a number under 18, or the name was an empty string, then our program wouldn't compile. Isn't that cool?

Though, most of the time, we need to validate incoming data from external services, meaning *runtime validation*. Refined gives us a bunch of useful functions to achieve this, effectively replacing *smart constructors*. The most common one is defined as follows:

{% highlight haskell %}
refine :: Predicate p x => x -> Either RefineException (Refined p x)
{% endhighlight %}

We can then use this function to validate our input data.

{% highlight haskell %}
mkPerson :: Int -> Text -> Either RefineException Person
mkPerson a n = do
  age  <- refine a
  name <- refine n
  return $ Person age name
{% endhighlight %}

However, the program above will short-circuit on the first error, as any other Monad will do. It would be nice if we could validate all our inputs in parallel and accumulates errors, wouldn't it?

We can achieve this by converting our `Either` values given by `refine a` into `Validation`, use `Applicative` functions to compose the different parts, and finally converting back to `Either`.

{% highlight haskell %}
import Data.Validation

mkPerson :: Int -> Text -> Either RefineException Person
mkPerson a n = toEither $ Person
  <$> fromEither (refine a)
  <*> fromEither (refine n)
{% endhighlight %}

As we can see, it is a bit clunky, and this is a very repetitive task, which will only increase the amount of boilerplate in our codebase.

This seems to be the *status quo* around validation in Haskell nowadays, and it was the same in Scala. So it's kind of hard to realize we are missing what we don't know: the `Parallel` typeclass. I didn't know it was such a game changer until I started using it everywhere.

This is exactly what this typeclass does for us in other languages, via its helpful functions and instances. Unfortunately, it doesn't exist in Haskell, as far as I know... until now!

### Parallel typeclass

Let me introduce you to the `Parallel` typeclass, already present in [PureScript](https://pursuit.purescript.org/packages/purescript-parallel/4.0.0/docs/Control.Parallel.Class#t:Parallel) and [Scala](https://github.com/typelevel/cats/blob/master/core/src/main/scala/cats/Parallel.scala#L10):

{% highlight haskell %}
import Control.Natural ((:~>))

class (Monad m, Applicative f) => Parallel f m | m -> f, f -> m where
  parallel :: m :~> f
  sequential :: f :~> m
{% endhighlight %}

It defines a relationship between a `Monad` that can also be an `Applicative` with "parallely" behavior. That is, an `Applicative` instance that wouln't pass the monadic laws.

The most common relationship is the one given by `Either` and `Validation`. These two types are isomorphic, with the difference being that `Validation` has an `Applicative` instance that accumulate errors instead of short-circuiting on the first error.

So we can represent this relationship via *natural transformation* in a `Parallel` instance:

{% highlight haskell %}
instance Semigroup e => Parallel (Validation e) (Either e) where
  parallel   = NT fromEither
  sequential = NT toEither
{% endhighlight %}

In the same way, we can represent the relationship between `[]` and `ZipList`:

{% highlight haskell %}
instance Parallel ZipList [] where
  parallel   = NT ZipList
  sequential = NT getZipList
{% endhighlight %}

Now, all this ceremony only becomes useful if we define some functions based on `Parallel`. One of the most common ones is `parMapN` (or `parMap2` in this case, but ideally, it should be abstracted over its arity).

{% highlight haskell %}
parMapN
  :: (Applicative f, Monad m, Parallel f m)
  => m a0
  -> m a1
  -> (a0 -> a1 -> a)
  -> m a
parMapN ma0 ma1 f = unwrapNT sequential
  (f <$> unwrapNT parallel ma0 <*> unwrapNT parallel ma1)
{% endhighlight %}

Before we get to see how we can leverage this function with refinement types and data validation, we will define a type alias for our effect type and a function `ref`, which will convert `RefineException`s into a `[Text]`, since our error type needs to be a `Semigroup`.

{% highlight haskell %}
import Control.Arrow (left)
import Data.Text     (pack)
import Refined

type Eff a = Either [Text] a

ref :: Predicate p x => x -> Eff (Refined p x)
ref x = left (\e -> [pack $ show e]) (refine x)
{% endhighlight %}

In the example below, we can appreciate how this function can be used to create a `Person` instance with validated input data (it's a breeze):

{% highlight haskell %}
mkPerson :: Int -> Text -> Eff Person
mkPerson a n = parMapN (ref a) (ref n) Person
{% endhighlight %}

Our `mkPerson` is now validating all our inputs in parallel via an implicit round-trip `Either`/`Validation` given by our `Parallel` instance.

We can also use `parMapN` to use a different `Applicative` instance for lists without manually wrapping / unwrapping `ZipList`s.

{% highlight haskell %}
n1 = [1..5]
n2 = [6..10]

n3 :: [Int]
n3 = (+) <$> n1 <*> n2

n4 :: [Int]
n4 = parMapN n1 n2 (+)
{% endhighlight %}

Without `Parallel`'s simplicity, it would look as follows:

{% highlight haskell %}
n4 :: [Int]
n4 = getZipList $ (+) <$> ZipList n1 <*> ZipList n2
{% endhighlight %}

For convenience, here's another function we can define in terms of `parMapN`:

{% highlight haskell %}
parTupled
  :: (Applicative f, Monad m, Parallel f m)
  => m a0
  -> m a1
  -> m (a0, a1)
parTupled ma0 ma1 = parMapN ma0 ma1 (,)
{% endhighlight %}

In Scala, there's also an instance for `IO` and `IO.Par`, a newtype that provides a different `Applicative` instance, which allows us to use functions such as `parMapN` with `IO` computations to run them in parallel!

And this is only the beginning... There are so many other useful functions we could define!

For now, the code is presented in [this Github repository](https://github.com/gvolpe/types-matter) together with some other examples. Should there be enough interest, I might polish it and ship it as a library.

Let me know your thoughts!

Gabriel.
