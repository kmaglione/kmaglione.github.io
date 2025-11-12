---
layout: post
title: How to solve "Array Manipulation" on HackerRank
katex: true
date: 2025-01-23 18:23 -0800
excerpt: |
  The Array Manipulation challenge, as presented, is fairly simple: for a
  set of ranges and values, add each value to each element of an array that
  falls within its given range. The difficulty comes from the scale: if
  there are 10^6 ranges that each span 10^6 elements, the simplest solution
  requires 1,000,000,000,000 (that's one quadrillion) additions and loop
  iterations. And that number of operations just will not complete in the 2
  second time limit for C++ submissions.
---
{% intro %}
The [Array Manipulation challenge][challenge], as presented, is fairly simple:
for a set of ranges and values, add each value to each element of an array that
falls within its given range. The difficulty comes from the scale: if there
are $$10^6$$ ranges that each span $$10^6$$ elements, the simplest solution
requires 1,000,000,000,000 (that's one quadrillion) additions and loop
iterations. And that number of operations just will not complete in the 2
second time limit for C++ submissions.
{% endintro %}

So, what's the solution? Well, fortunately, there are at least two, and
they're fairly simple.

### The binary tree approach

My preferred approach is to break the result array down into a binary tree of
sub-ranges. For each range presented to us in our input, we add the given
value to the smallest number of sub-ranges that completely cover the given
range. Once this is done, we can efficiently calculate the value of any
element of the final array by walking the tree from root to leaf and keeping a
sum of the values of each node we pass along the way. Since we're interested
in the maximum value of any element here, we'll recursively walk the entire
tree and keep track of the maximum value we calculate for any leaf.

To get an understanding of the tree model, let's look at some example
operations. Say we're given an 8 element array to work with. The initial tree
looks like this, with the plain nodes at the bottom of the tree representing
the sum of all of the ancestors for the leaf node it connects to:

![tree0]

Now, let's add our first range. If we add 13 to the elements in the range
$$[0, 6]$$, we end up with a tree that looks like this:

![tree1]

The range $$[0, 6]$$ can be completely covered by the three sub-ranges
$$[0, 3]$$, $$[4, 5]$$, and $$[6, 6]$$, so we add 13 to the value for each of
those nodes. None of their parents or children are modified. As you can see,
we only needed to perform 3 additions to cover a range of 7 nodes. The worst
case insertion complexity will generally be $$O(\log n)$$ with respect to the
width of the range.


For our second operation, let's add 19 to the elements in the range
$$[3, 6]$$:


![tree2]

This range is covered by the sub-ranges $$[3, 3]$$, $$[4, 5]$$, and
$$[6, 6]$$. The first of those has not been modified yet, so its value
becomes 19. The latter two were touched by the previous operation, so their values
become 32. The totals are updated accordingly, and we can see that the maximum
value for any leaf node is 32.

So, with that understanding, let's convert it from theory to code:

{% codeblock lang:c++ %}
using namespace std;

/**
 * Add the given value to the highest nodes in the given subtree required
 * to completely cover the given range.
 *
 * @param tree The binary tree of values for each sub-range.
 * @param node The index into the tree of the current node.
 * @param nodeStart The start of the range covered by the given node.
 * @param nodeEnd The end of the range covered by the given node.
 * @param start The start of the requested range.
 * @param end The end of the requested range.
 * @param val The value to add to the matching nodes.
 */
void add(vector<long>& tree,
         uint node, uint nodeStart, uint nodeEnd,
         uint start, uint end, int val) {
    // If the range ends before or starts after the range of this node,
    // we're done with this subtree.
    if (end < nodeStart || start > nodeEnd) {
        return;
    }

    // If the range of this node is completely contained in the requested
    // range, add the value to our value, and then we're done with this
    // subtree.
    if (nodeStart >= start && nodeEnd <= end) {
        tree[node] += val;
        return;
    }

    // The requested range overlaps with our range. Find the ranges of
    // our two child nodes and recurse.
    uint mid = (nodeStart + nodeEnd) / 2;
    add(tree, 2 * node + 1, nodeStart, mid, start, end, val);
    add(tree, 2 * node + 2, mid + 1, nodeEnd, start, end, val);
};

/**
 * Find the maximum value of the sum of each leaf node and all of its
 * ancestors for the given tree.
 *
 * @param tree The binary tree of values for each sub-range.
 * @param node The index in the tree of the current node.
 * @param acc The accumulated value of all ancestor nodes for the current
 *            node.
 */
long findMax(vector<long>& tree, uint node, long acc) {
    if (node >= tree.size()) {
        return acc;
    }

    acc += tree[node];

    return max(findMax(tree, 2 * node + 1, acc),
               findMax(tree, 2 * node + 2, acc));
}

long arrayManipulation(int n, vector<vector<int>> queries) {
    // Find the largest power of two greater than or equal to the requested
    // array size. This will be the number of leaf nodes in the tree.
    uint nelem = 1 << (uint)ceil(log2(n));
    // Find the total number of nodes in the tree.
    uint size = (nelem << 1) - 1;
    vector<long> tree(size, 0);

    // Process each query, adding the given value to the appropriate
    // sub-ranges in our binary tree.
    for (auto& query : queries) {
        auto [start, end, val] = reinterpret_cast<int(&)[3]>(query.front());
        add(tree, 0, 0, nelem - 1, start - 1, end - 1, val);
    }

    // Recurse the entire calculated tree and return the largest value
    // calculated for any leaf node.
    return findMax(tree, 0, 0);
}
{% endcodeblock %}

### The prefix sum array approach

The above approach allows us to efficiently find the value for any index in
the final array after we've completed the initial calculations. That feature
is often quite useful in the real world, but not technically necessary for
this problem. There is a simpler alternate approach that lacks efficient
random access that we could use here instead: the prefix sum array.

A prefix sum array, or partial sum array, is a transformation of an array
where each element stores the sum of the element at the same index in the
original array and all of the elements to its left:

{% codeblock lang:c++ %}
int values[5] { 1, 2, 3, 4, 5 };
int prefixSum[5];

partial_sum(begin(values), end(values),
            begin(prefixSum));
{% endcodeblock %}

After which `prefixSum` contains `{ 1, 3, 6, 10, 15 }`.

Or, mathematically, given a value array $$v$$, its prefix array $$p$$ is
defined as:

$$
\begin{equation}
p_i = \sum_{n=0}^i v_i
\end{equation}
$$

or, equivalently:

$$
\begin{align}
p_0 &= v_0 \\
\left\{ p_i \right\}_{i=1}^n &= \left\{ p_{i - 1} + v_i \right\}
\end{align}
$$

So, how is this useful in our challenge? Well, it turns out that the final result
array of all of our range additions is essentially a prefix sum array. For
example, let's say we want to add 3 to all elements in the range $$[1, 3]$$.
We can add 3 to element 1 in the `values` array and subtract it after element
3:

{% codeblock lang:c++ %}
int values[6] {};
int prefixSum[6];

values[1] += 3;
values[3 + 1] -= 3;

partial_sum(begin(values), end(values),
            begin(prefixSum));
{% endcodeblock %}

After which `prefixSum` contains `{ 0, 3, 3, 3, 0 }`.

The advantage of this approach is that we only need to perform two operations
for each ranged addition when we build the values array, and then one addition
for each element in the array to calculate the result. That gives us a total
complexity of $$O(n + m)$$ for $$m$$ ranged additions in an $$n$$ element
array, as opposed to a worst case complexity of $$O(n\cdot m)$$ if we added
the value to each element in the range for each query.

The final code here is markedly simpler but, again, at the expense of much
less efficient random access to the result:

{% codeblock lang:c++ %}
long arrayManipulation(int n, vector<vector<int>> queries) {
    vector<long> values(n, 0);

    for (auto& query : queries) {
        auto [start, end, val] = reinterpret_cast<int(&)[3]>(query.front());

        // Add the query value to the start of the range
        values[start - 1] += val;

        // Subtract the prefix value at the first element past the range
        if (end < n) {
            values[end] -= val;
        }
    }

    // Calculate the prefix sum for each index in the values array and keep
    // track of the maximum
    long maxVal = 0;
    long sum = 0;
    for (long val : values) {
        sum += val;
        maxVal = max(maxVal, sum);
    }

    return maxVal;
}
{% endcodeblock %}


[challenge]: https://www.hackerrank.com/challenges/one-month-preparation-kit-crush/problem


[tree0]: {% link /assets/img/array-manipulation/tree-0.svg %}
{: .center .dark-mode-invert style="width: 30em" }
[tree1]: {% link /assets/img/array-manipulation/tree-1.svg %}
{: .center .dark-mode-invert style="width: 30em" }
[tree2]: {% link /assets/img/array-manipulation/tree-2.svg %}
{: .center .dark-mode-invert style="width: 30em" }
