# Secure Key Generation Tools for Kadena

## Overview

This repository provides tools for doing high security key generation.  It is
designed to allow the user to supply their own entropy and generate ED25519
keys deterministically.  This allows key generation to be easily verified on
completely separate hardware.

These tools were inspired by
[Diceware](http://world.std.com/~reinhold/diceware.html) and the [Glacier
Protocol](https://glacierprotocol.org/) For more in-depth information about
secure handling of cryptocurrency keys, see those sources.

## Generating Secure Keys

IMPORTANT NOTE: Make sure you test any keys you generate to make sure they
work and you can get money out of them before you put significant amounts of
money under their control.

The way you pick random numbers (also known as entropy) for passwords, keys,
etc is very important to their security.  Machines tend to be really good at
being predictable and doing the same thing over and over again and not so good
at being unpredictable.  One of the most obviously secure ways to get good
entropy is to generate it yourself using a good physical source such as
[casino grade
dice](https://www.amazon.com/X-lion-Grade-Casino-Purple-Yellow/dp/B07RLTF7W1/ref=sr_1_3?dchild=1&keywords=casino+grade+dice&qid=1573337904&sr=8-3).
Regular dice have biases and are not good enough when security really matters.
Casino grade dice are carefully manufactured to be as unbiased as possible.

### Entropy from Dice

This package provides a tool called `keygen` that gives you everything you
need to generate high quality entropy from standard 6-sided casino dice.  It
is composed of three very simple sub-commands:

* `d2h` for converting dice rolls into hex numbers
* `h2e` for converting hex into binary bytes of raw entropy
* `keys` for converting raw entropy into an ED25519 public/private key pair

To generate keys in one command, run:

```
keygen d2h | keygen h2e | keygen keys
```

Then type your dice rolls into stdin and hit CTRL-d when you're done. ED25519
keys require 256 bits (32 bytes) of entropy. So your raw entropy file needs to
be at least 32 bytes. Remaining bytes will be ignored. Rolling two 6-sided dice
yields 5 bits of entropy (2^5 = 32 and there are 36 different ways to roll two
dice). Therefore you will need to make at least 103 dice rolls to generate one
key. This library errs on the side of conservatism so depending on how they land
you may need to do a few more rolls.

### Entropy from `/dev/urandom`

If for some reason you cannot use dice, you can still use this tool to
generate keys from any other source of entropy.  Here's how you can generate
keys using `/dev/urandom` as your source of entropy.

```
dd if=/dev/urandom bs=32 count=1 | result/bin/keygen keys
```

## FAQ

### Why isn't it one convenient command?

This was done in an effort to make the process as transparent and manually
verifiable as possible. The process could have been split into one more step of
converting from dice rolls to binary first and then to hex in a separate step.
