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

So, what's the solution? Well, fortunately, it's fairly simple: we break the
result array down into a binary tree of sub-ranges. For each range presented
to us in our input, we add the given value to the smallest number of
sub-ranges that completely cover the given range. At the end, we recursively
walk the tree and, for each leaf node, add together the values of it and all
of its ancestors. In the end, we could construct a complete array of all of
the final values, but since the problem is only interested in the maximum
value of any element, that's all we need to keep track of.

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


[challenge]: https://www.hackerrank.com/challenges/one-month-preparation-kit-crush/problem


[tree0]: {% link /assets/img/array-manipulation/tree-0.png %}
{: .center .dark-mode-invert }
[tree1]: {% link /assets/img/array-manipulation/tree-1.png %}
{: .center .dark-mode-invert }
[tree2]: {% link /assets/img/array-manipulation/tree-2.png %}
{: .center .dark-mode-invert }
