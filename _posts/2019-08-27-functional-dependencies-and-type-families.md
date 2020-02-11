---
layout: post
title:  "Functional Dependencies & Type Families"
date:   2019-08-27 09:12:00
categories: haskell
comments: true
---

In the past few months I have learnt a lot! Probably the coolest stuff has been about [Functional Dependencies](https://wiki.haskell.org/Functional_dependencies) and [Type Families](https://wiki.haskell.org/GHC/Type_families), so this is my attempt to explain it in order to gain a better understanding and hopefully help someone else out there as well.

So please be kind if you see any mistake, let me know and I'll try to fix it :)

### A motivating example

One of the fun applications I've worked on is [exchange-rates](https://github.com/gvolpe/exchange-rates), which uses the [RIO Monad](https://www.fpcomplete.com/blog/2017/07/the-rio-monad) (basically `ReaderT` + `IO`).

When defining dependencies using such effect is very common to do it using the [Has typeclass approach](https://www.fpcomplete.com/blog/2017/06/readert-design-pattern) (or how I prefer to call it, the *classy lenses Has pattern*) instead of passing the whole context / environment.

Following this approach, I have defined a polymorphic `Ctx` record that represents the application context (or dependencies). It looks as follows:

{% highlight haskell %}
data Ctx m = Ctx
  { ctxLogger :: Logger m
  , ctxCache :: Cache m
  , ctxForexClient :: ForexClient m
  }
{% endhighlight %}

If we continue with the `Has` approach we would get something like this for our `Logger m`:

{% highlight haskell %}
class HasLogger ctx where
  loggerL :: Lens' ctx (Logger m)

instance HasLogger (Ctx m) where
  loggerL = lens ctxLogger (\x y -> x { ctxLogger = y })
{% endhighlight %}

But... Oops, it doesn't compile!

{% highlight bash %}
Couldn't match type ‘m1’ with ‘m’
      ‘m1’ is a rigid type variable bound by
        the type signature for:
          loggerL :: forall (m1 :: * -> *). Lens' (Ctx m) (Logger m1)
        at src/Context.hs:27:3-9
      ‘m’ is a rigid type variable bound by
        the instance declaration
        at src/Context.hs:26:10-47
{% endhighlight %}

The reason is that the compiler has no way to know that the `m` in `Logger m` (declared in the type class) is the same as the `m` in `Ctx m` (declared in the instance), therefore the inferred type ends up being `Lens' (Ctx m) (Logger m1)`.

### Functional Dependencies to the rescue

We can fix it by introducing a language extension named [FunctionalDependencies](https://wiki.haskell.org/Functional_dependencies), introduced in the paper [Type Classes with Functional Dependencies](https://web.cecs.pdx.edu/~mpj/pubs/fundeps-esop2000.pdf) by Mark P. Jones in March 2000.

We need to change our type class definition as below:

{% highlight haskell %}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses  #-}

class HasLogger ctx m | ctx -> m where
  loggerL :: Lens' ctx (Logger m)

instance HasLogger (Ctx m) m where
  loggerL = lens ctxLogger (\x y -> x { ctxLogger = y })
{% endhighlight %}

Our type class has now two parameters, `ctx` and `m`, and in addition we define a *functional dependency* `ctx -> m`. This means that `ctx` uniquely determines the type of `m`, which constraints the possible instances and helps with type
inference.

> Notice the extensions we had to enable to make this compile.

##### Arithmetic example

Here's another example taken from the [Fun with Functional Dependencies](http://www.cse.chalmers.se/~hallgren/Papers/hallgren.pdf) paper by Thomas Hallgren. What's simpler that adding two values together?

{% highlight haskell %}
class Add a b c | a b -> c where
  add :: a -> b -> c

instance Add Zero b b
instance Add a b c => Add (Succ a) b (Succ c)
{% endhighlight %}

The functional dependency is pretty clear: given `a` and `b` we can add them together and produce `c`. So `a` and
`b` uniquely determine `c`.

Notice how we don't even need to define `add`, specifying the types is enough! If it's still not clear, bear with me and let's perform type substitution step by step (feel free to skip this part):

Given this instance, all we are saying is that:

{% highlight haskell %}
instance Add Zero b b where
{% endhighlight %}

- `a` is defined as `Zero`.
- `b` is defined as `b`.
- `c` is defined as `b`.

Since we now know the types of `a`, `b` and `c`, defining the `add` function becomes redundant:

{% highlight haskell %}
instance Add Zero b b where
  add Zero b = b
{% endhighlight %}

Clear now? Awesome! Let's try this out in the REPL:

{% highlight haskell %}
λ :t add (u::Three) (u::Zero)
Succ (Succ (Succ Zero))
{% endhighlight %}

> Where `u = undefined`, just a convenient type alias.

Functional Dependencies have proven to be very useful since it solves a real problem. But software evolves and so Type Families were created, the topic of the next section.

### Type Families

Type Families were introduced in the paper [Fun with type
functions](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/typefun.pdf?from=http%3A%2F%2Fresearch.microsoft.com%2F~simonpj%2Fpapers%2Fassoc-types%2Ffun-with-type-funs%2Ftypefun.pdf) by Oleg Kiselyov, Simon Peyton Jones and Chung-chieh Shan in May 2010.

This GHC extension allows functions on types to be expressed as straightforwardly as functions on values. This means
that our functions are executed at compile time, during type checking.

So here's how we can define our `HasLogger` class using Type Families instead:

{% highlight haskell %}
{-# LANGUAGE TypeFamilies #-}

import Data.Kind (Type)

class HasLogger ctx where
  type LoggerF ctx :: Type -> Type
  loggerL :: Lens' ctx (Logger (LoggerF ctx))

instance HasLogger (Ctx m) where
  type LoggerF (Ctx m) = m
  loggerL = lens ctxLogger (\x y -> x { ctxLogger = y })
{% endhighlight %}

Our class has once again a single parameter `ctx` and our functional dependency is now expressed as an *associated type* of the class (type family). It behaves like a function at the type level, so we can call `LoggerF` a type function.

Notice how we explicitly define the kind of our type function to be `Type -> Type` (formerly `* -> *`). If we don't do it the default inferred kind will just be `Type` (formerly `*`).

##### Arithmetic example

In a similar way, we can define the `Add` class using Type Families:

{% highlight haskell %}
class Add a b where
  type AddF a b :: Type
  add :: a -> b -> AddF a b

instance Add Zero b where
  type AddF Zero b = b

instance Add a b => Add (Succ a) b where
  type AddF (Succ a) b = Succ (AddF a b)
{% endhighlight %}

The `c` parameter defined before is now replaced by the `AddF a b` type function. Here we define the kind of the type
function as a good practice but it's not necessary.

And again, we can try this out in the REPL:

{% highlight haskell %}
λ :t add (u::Three) (u::Succ Zero)
Succ (Succ (Succ (Succ Zero)))
{% endhighlight %}

##### Polymorphic Mutable Ref

Furthermore, with Type Families we could define a polymorphic mutable ref class where `m` defines `Ref` (example taken from
the paper *Fun with type functions* linked above).

{% highlight haskell %}
class Mutation m where
  type Ref m :: Type -> Type
  newRef   :: a -> m (Ref m a)
  readRef  :: Ref m a -> m a
  writeRef :: Ref m a -> a -> m ()

instance Mutation IO where
  type Ref IO = IORef
  newRef   = newIORef
  readRef  = readIORef
  writeRef = writeIORef

instance Mutation (ST s) where
  type Ref (ST s) = STRef s
  newRef   = newSTRef
  readRef  = readSTRef
  writeRef = writeSTRef
{% endhighlight %}

Once the compiler knows what `m` is it's over. It'll know what the type of the mutable ref is as well. And as a bonus, type inference will work flawlessly.

{% highlight haskell %}
{% endhighlight %}

### Final Thoughts

Most use cases of `FunctionalDependencies` can be expressed using `TypeFamilies`, however there are some subtle differences that come to light only in complex scenarios.

Most library authors and developers prefer to use `TypeFamilies` nowadays. Its main advantage over `FunctionalDependencies` is speed but it's also possible to express many cases that require the extensions `TypeSynonymInstances`, `FlexibleInstances`, `MultiParamTypeClasses` and `UndecidableInstances` without them.

So when is it more convenient to use the former? You can find a more detailed comparison in the following articles:

- https://wiki.haskell.org/Functional_dependencies_vs._type_families
- https://gitlab.haskell.org/ghc/ghc/wikis/tf-vs-fd

Special thanks to [Dmitrii Kovanikov](https://twitter.com/ChShersh) for reviewing the first draft!
