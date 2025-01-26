---
layout: post
title: How to solve "Lego Blocks" on HackerRank
katex: true
date: 2025-01-25 16:33 -0800
---
{% intro %}
The [challenge] is to find the number of possible walls of width $$w$$ and
height $$h$$ made up of 4 different width Lego blocks, with no complete
vertical breaks anywhere within. It turns out that there are actually two
challenges here: one mathmatical and one technological. Let's start with the
mathematical one.
{% endintro %}

### The mathmatical challenge

The mathmatical challenge is fairly straightforward: how do we calculate the
number of possible walls of a given dimension in linear time. To solve it, we
break each row into successively narrower rows, and calculate its possible
permutations based on the possible permutations for the next narrower rows.
For complete walls, we do something similar, which I describe later on.

First, we need to find the number of permutations for a row $$r_w$$ of width
$$w$$. To get a row of any given width, we can add an $$n$$-width to each row
that is $$n$$ narrower. Since we have 4 block widths from 1 to 4, we can find
the number of permutations for a given row width by adding together the number
of permutations for each of the 4 narrower widths:

$$
\begin{align}
\left\{r_w\right\}_{w=1}^4 &= \left\{1, 2, 4, 8\right\} \\
\left\{r_w\right\}_{w=5}^{\infty} &= \left\{  \sum_{n=w-4}^{w-1}r_n \right\}
\end{align}
$$

Now, we need to find the total number of possible permutations, $$t_w$$, for a
wall of width $$w$$ and height $$h$$, as well as the number of invalid
($$i_w$$) and valid ($$v_w$$) ones. The total number of permutations is simply
the number of row permutations, $$r_w$$, to the power $$h$$, and number of
valid permutations is simply the difference between the number of total
permutations and the number of invalid ones:

$$
\begin{align}
t_w &= r_w^h \\
v_w &= t_w - i_w
\end{align}
$$

To find the number of invalid permutations (that is, permutations with a
complete vertical break anywhere in the middle), we take advantage of the fact
that a wall of width $$w$$ with a continuous break at width $$n$$ is
equivalent to two adjacent walls, one of width $$n$$ and one of width $$w-n$$.
The total number of permutations for the two adjacent walls is the product of
the number of possible permutations for the left wall and the number of
possible permutations for the right. The total number of invalid permutations
for a wall of width $$w$$ is the sum of the possible permutations for walls
with breaks of each narrower width from $$1$$ to $$w - 1$$:

$$
\begin{equation}
i_w= \sum_{n=1}^{w-1} v_n t_{w - n}
\end{equation}
$$

where $$v_n$$ is the number of permutations for the left portion and $$t_{w -
n}$$ is the number for the right. The left portion need consider only valid
permutations, since breaks at width $$w<n$$ <!-- --> will already have been
accounted for in the right side of narrower walls, where we always count the
total number of permutations.

### The technological challenge

The technological challenge is a bit unfortunate, since it depends on
semantics that aren't documented anywhere in the problem specification: the
input sets contain queries which will cause integer overflows of the 32 bit
data types used by the boilerplate code, and the expected results depend on
those overflows being mitigated by taking the result of each mathmatical
operation $$10^9+7$$. Moreover, the modulo operation is expected to always
return a positive value, which is not guaranteed by the C++ ``%`` operator. So
we need to define our own ``mod`` function which makes any negative result
positive by adding the divisor to it:

{% codeblock lang:c++ %}
constexpr long MOD = 1e9 + 7;

long mod(long val, long div) {
    long res = val % div;
    if (res < 0) {
        res += div;
    }
    return res;
}
{% endcodeblock %}

To add one more wrinkle, among the operations we need to do that may overflow
is exponentiation and, in order to get the expected result, the exponentiation
function needs to mod its intermediate results at every step, rather than only
at the end. The C++ ``pow`` function does not allow for this, so we need to
again define our own:

{% codeblock lang:c++ %}
long powMod(long base, long exp) {
    long result = base;
    for (int i = 1; i < exp; i++) {
        result = mod(result * base, MOD);
    }
    return result;
}
{% endcodeblock %}

### The final result

With all of that taken care of, we should now be able to put together our
final result:

{% codeblock lang:c++ %}
int legoBlocks(int n, int m) {
    // Calculate the number of possible permutations for rows of a given width
    // (starting at 0). For a row of each given width, we can add an n-width
    // block to each permutation that is n elements narrower.
    vector<long> rowPermutations({1, 1, 2, 4});
    rowPermutations.reserve(m + 1);
    for (int i = rowPermutations.size(); i <= m; i++) {
        auto end = rowPermutations.end();
        rowPermutations.push_back(mod(reduce(end - 4, end), MOD));
    }

    // Calculate the number of total permutations for each wall width.
    vector<long> permutations;
    permutations.reserve(m + 1);
    for (int i = 0; i <= m; i++) {
        permutations[i] = powMod(rowPermutations[i], n);
    }

    // Find the number of invalid permutations for each wall width. Each
    // complete veritcal break at width n is equivalent to a wall of width n
    // next to a wall of width m-n. To find the total number of permutations
    // with that vertical break, we multiple the number of possible
    // permutations in the left wall by the number of possible permutations in
    // the right.
    vector<long> invalid;
    invalid.reserve(m + 1);
    for (int i = 0; i <= m; i++) {
        long count = 0;
        for (int j = 1; j < i; j++) {
            // For the left portion of the wall, consider only valid
            // permutations, since invalid permutations in this portion will
            // already have been accounted for in the right portions of
            // previous iterations.
            long left = permutations[j] - invalid[j];
            count += mod(left * permutations[i - j], MOD);
        }
        invalid.push_back(count % MOD);
    }

    return mod(permutations[m] - invalid[m], MOD);
}
{% endcodeblock %}


[challenge]: https://www.hackerrank.com/challenges/one-month-preparation-kit-lego-blocks/problem
