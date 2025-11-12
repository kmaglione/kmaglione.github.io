---
layout: post
title: How to solve "Insertion Sort Advanced Analysis" on HackerRank
katex: true
date: 2025-02-02 15:25 -0800
excerpt: |
    The challenge is essentially to figure out how inefficient it would be to
    insertion sort an array without actually doing an insertion sort. We can't get
    around actually sorting the array, so what we need is a sort method that has
    equivalent behavior to an insertion sort, but is much more efficient. The
    simplest answer is a binary search tree. A binary search tree remains sorted
    after every insertion, and can be flattened into an equivalent sorted array,
    so it has the relevant properties of an array during insertion sort. Unlike an
    array, however, it has O(log n) lookup complexity to find the insertion
    point, and worst case O(log n) complexity to rebalance the tree after
    insertion, as opposed to O(n) complexity for a flat array.
---
{% intro %}
The [challenge] is essentially to figure out how inefficient it would be to
insertion sort an array without actually doing an insertion sort. We can't get
around actually sorting the array, so what we need is a sort method that has
equivalent behavior to an insertion sort, but is much more efficient. The
simplest answer is a binary search tree. A binary search tree remains sorted
after every insertion, and can be flattened into an equivalent sorted array,
so it has the relevant properties of an array during insertion sort. Unlike an
array, however, it has $$O(\log n)$$ lookup complexity to find the insertion
point, and worst case $$O(\log n)$$ complexity to rebalance the tree after
insertion, as opposed to $$O(n)$$ complexity for a flat array.
{% endintro %}

### The red-black tree

In particular, we'll be using a [red–black tree][red-black-tree] modified to
keep track of the number of descendants of each node. Whenever we insert a new
element, we'll add up the number of elements to its left to figure out
its position in the sorted list. To do that, every time we take a right branch
when searching for the new element's insertion point, we add the number of
elements in the corresponding left branch, plus one for the parent.

For example, take the following tree where the red and black nodes are
existing elements and we want to insert the value `31`:

![tree-black]
![tree-white]

All of the nodes with double borders are less than `31`, and are to its left
both in the tree and in the sorted array. When we search for our insertion
point, we first come to the root, `37`, and take the left branch, since `31`
is less than `37`. Then we come to `23`, and take the right branch. Since
we're taking the right branch, we need to update our running total of nodes to
the left. We add 3 for node `12` and its children in the left branch, plus 1
for node `23`, which is also to the left of node `31`. Then we come to node
`29` and take the right branch again. Node `29` is to our left and has no left
child, so we add 1 to our running total. Our final count is 5, which we can
see matches the number of double-bordered nodes to our left in the
diagram.

### The `insertionSort` function

Let's assume we already have a `RBTree` class that implements a red--black
tree, and has an `insert` function that inserts an element into the tree and
returns its insertion index. Then the `insertionSort` function becomes
relatively simple:

{% codeblock lang:c++ %}
long insertionSort(vector<int> arr) {
    RBTree tree;

    // Insert each element into the tree, keeping track of the number of
    // shifts that would occur in an insertion sort
    long shifts = 0;
    for (uint i = 0; i < arr.size(); i++) {
        size_t idx = tree.insert(arr[i]);

        // This is the ith element we're inserting. Since the array is
        // 0-indexed, that means we inserted i elements before this, and
        // therefore had i elements in the tree before our insertion. We find
        // the number of elements to the right of us by subtracting our index
        // from the previous total number of elements, and add that to the
        // running count of shifts that an insertion sort would require.
        shifts += i - idx;
    }
    return shifts;
}
{% endcodeblock %}

*An important note*, however: the HackerRank boilerplate code has the
`insertionSort` function return an `int`, and therefore also stores that
return value in an `int`. Several of the test cases, however, have inputs that
cause a 32 bit signed integer to overflow. The `insertionSort` function,
therefore, needs to return a `long`, and the boilerplate code needs to be
modified to also store
the result in a `long`.

{% codeblock lang:diff %}
--- insertionSort.cpp
+++ insertionSort.cpp
@@ -45,7 +45,7 @@
             arr[i] = arr_item;
         }
 
-        int result = insertionSort(arr);
+        long result = insertionSort(arr);
 
         fout << result << "\n";
     }
{% endcodeblock %}

### The `RBTree` helper class

Now comes the complicated part. We need a red--black tree class that keeps
track of the size of each subtree along with the insertion point of every new
node. That isn't actually very hard to achieve if you have an existing
red--black tree helper to modify. We simply need to add a descendant count to
each node, increment it by one for each node we pass when looking for the
insertion point for a new node, and recalculate it whenever we rotate a node.

A stripped-down red--black tree class that only handles insertions, but is
sufficient for our purposes, follows. As stripped down as it is, it still
isn't particularly simple, but it can't be much simpler. Keeping the tree
balanced is vital to our success, since an unbalanced tree would be
essentially the same as a linked list in the worst case, and give us worst
case $$O(n^2)$$ complexity that would cause our submission to timeout.

{% codeblock lang:c++ %}
#include <bits/stdc++.h>

using namespace std;

class RBTree {
  public:
    enum Color : uint8_t {
        Red,
        Black,
    };

    struct Node {
        Color color = Red;
        // The number of descentants of this node, exclusive of the node
        // itself
        uint descendants = 0;
        int data;

        unique_ptr<Node> left {};
        unique_ptr<Node> right {};
        Node* parent = nullptr;

        explicit Node(int data) : data(data) {}
    };

  private:
    unique_ptr<Node> root;

    // Returns the size of the sub-tree starting at the given node. That is,
    // the number of descendants plus 1 for the node itself. Returns 0 if the
    // node is null.
    static int tree_size(const unique_ptr<Node>& n) {
        return n ? 1 + n->descendants : 0;
    }

    // Returns a reference to the `unique_ptr` that owns this node. That will
    // either be the `root` member for the root node, or otherwise the
    // appropriate `left` or `right` member of its parent node.
    unique_ptr<Node>& node_handle(Node* n) {
        Node* parent = n->parent;
        if (parent == nullptr) {
            return root;
        }
        if (n == parent->left.get()) {
            return parent->left;
        }
        return parent->right;
    }

    // Rotates a node either right or left depending on the accessor functions
    // passed. Passing &Node::left for child 1 and &Node::right for child2 will
    // cause a right rotation, and the reverse will cause a left rotation.
    template<auto child1, auto child2>
    void rotate(Node* x) {
        unique_ptr<Node> y = std::move(invoke(child1, x));

        invoke(child1, x) = std::move(invoke(child2, y));
        // Update our descendant counts after changing a child node
        x->descendants = (tree_size(x->left) +
                          tree_size(x->right));

        if (invoke(child1, x)) {
            invoke(child1, x)->parent = x;
        }

        auto& handle = node_handle(x);

        Node* parent = x->parent;
        x->parent = y.get();
        y->parent = parent;

        invoke(child2, y) = std::move(handle);
        // Update our descendant counts after changing a child node
        y->descendants = (tree_size(y->left) +
                          tree_size(y->right));

        handle = std::move(y);
    }

    void rotateLeft(Node* x) {
        rotate<&Node::right, &Node::left>(x);
    }

    void rotateRight(Node* x) {
        rotate<&Node::left, &Node::right>(x);
    }

public:
    RBTree() {}

    // Insert the given value into the tree and return the number of nodes to
    // its left (equivalent to its index in a sorted array).
    size_t insert(int data) {
        Node* parent = nullptr;
        // The location where we'll be inserting the node. Either `root`, or
        // the null `left` or `right` member of another node.
        unique_ptr<Node>* pos = &root;
        // The insertion index of the node were the tree flattened into a
        // sorted array.
        size_t idx = 0;
        while (pos->get()) {
            parent = pos->get();
            if (parent) {
                // Increment the descendant count of every node we pass
                parent->descendants++;
            }
            if (data < (*pos)->data) {
                pos = &(*pos)->left;
            } else {
                // We're taking a right branch, so add a count of every node
                // to the left to the insertion index. That is, every node in
                // the current node's left branch plus one for the node itself
                idx += tree_size((*pos)->left) + 1;
                pos = &(*pos)->right;
            }
        }

        *pos = make_unique<Node>(data);
        Node* node = pos->get();

        node->parent = parent;
        if (!parent) {
            node->color = Black;
        }

        // Rebalance the tree after insertion.
        while (node != root.get() && node->parent->color == Red) {
            Node* grandparent = node->parent->parent;

            if (node->parent == grandparent->left.get()) {
                Node* uncle = grandparent->right.get();
                if (uncle && uncle->color == Red) {
                    node->parent->color = Black;
                    uncle->color = Black;
                    grandparent->color = Red;

                    node = grandparent;
                } else {
                    if (node == node->parent->right.get()) {
                        node = node->parent;
                        rotateLeft(node);
                    }

                    node->parent->color = Black;
                    grandparent->color = Red;

                    rotateRight(grandparent);
                }
            } else {
                Node* uncle = grandparent->left.get();
                if (uncle && uncle->color == Red) {
                    node->parent->color = Black;
                    uncle->color = Black;
                    grandparent->color = Red;

                    node = grandparent;
                } else {
                    if (node == node->parent->left.get()) {
                        node = node->parent;
                        rotateRight(node);
                    }

                    node->parent->color = Black;
                    grandparent->color = Red;

                    rotateLeft(grandparent);
                }
            }
        }
        root->color = Black;

        return idx;
    }
};
{% endcodeblock %}

[tree-black]: {% link /assets/img/hackerrank/rbtree-black.svg %}
{: .center .light-mode-only style="width: 30em" }
[tree-white]: {% link /assets/img/hackerrank/rbtree-white.svg %}
{: .center .dark-mode-only style="width: 30em" }

[challenge]: https://www.hackerrank.com/challenges/insertion-sort/problem
[red-black-tree]: https://en.wikipedia.org/wiki/Red%E2%80%93black_tree
