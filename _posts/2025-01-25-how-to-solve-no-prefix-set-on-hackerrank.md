---
layout: post
title: How to solve "No Prefix Set" on HackerRank
date: 2025-01-25 17:03 -0800
---
{% intro %}
The [challenge] is figure out whether any string in a set is a prefix of any
other string, and if so, to print the first string in the set which either is
the prefix of a previous string, or of which a previous string is a prefix.
And, as with many other HackerRank challenges, the real challenge is to do it
efficiently. Fortunately, in this case, the solution is simple: a data
structure called a [trie].
{% endintro %}

A trie (typically pronounced "try" or "tree") is a particular type of tree
where each character of a string[^seq] is a child of the node for the previous
character. For example, given the strings:

 - abc
 - abcdef
 - abcxyz
 - aqrs

 We get a trie that looks like:

![trie0]

In this example, any node that represents the end of a string is marked with a
double circle.

In practice, tries for strings are typically implemented as nodes with
children stored in arrays large enough to handle any character that may appear
in the string. A trie node for lower-case alphabetical characters might look
like:

{% codeblock lang:c++ %}
struct Node {
    unique_ptr<Node> children[26];
};
{% endcodeblock %}

And the node for the string ``"foo"`` would be addressed as:

{% codeblock lang:c++ %}
root->children['f' - 'a']
    ->children['o' - 'a']
    ->children['o' - 'a']
{% endcodeblock %}

To solve our challenge, we simply need to build a trie of each of our input
strings. As we do so, if we come to any node for a complete string while
building the entry for a given node, we know that we've already come across a
prefix for it. Likewise, if the final node for an entry already has children,
we know we've already come across a string for which the current entry is a
prefix. In either case, we print the failing entry and quit.

If we build the entire trie without coming across any failure cases, we know
that there are no prefixes in teh input set.

With all of that in mind, we can write our final code:

{% codeblock lang:c++ %}
using namespace std;

struct Node {
    // The number of full strings we've come across which end at this node
    uint count = 0;
    vector<unique_ptr<Node>> children{'k' - 'a'};
};

void noPrefix(vector<string> words) {
    Node root;
    for (auto& word : words) {
        Node* node = &root;
        for (char c : word) {
            if (!node->children[c - 'a']) {
                node->children[c - 'a'] = make_unique<Node>();
            }
            node = node->children[c - 'a'].get();
            // Fail if there is an existing node that's a prefix of this word
            if (node->count) {
                goto fail;
            }
        }
        // Fail if this word is a prefix of an existing node
        for (auto& child : node->children) {
            if (child) {
                goto fail;
            }
        }
        node->count++;
        continue;
    fail:
        cout << "BAD SET\n" << word;
        return;
    }

    cout << "GOOD SET\n";
}
{% endcodeblock %}


[challenge]: https://www.hackerrank.com/challenges/one-month-preparation-kit-no-prefix-set/problem
[trie]: https://en.wikipedia.org/wiki/Trie

[^seq]: Or, more generally, every element of a sequence, which need not be a
    character string.

[trie0]: {% link /assets/img/hackerrank/trie-0.png %}
{: .center .dark-mode-invert style="width: 20em" }
