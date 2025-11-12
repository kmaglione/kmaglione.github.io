---
layout: post
title: How to solve "Matrix Layer Rotation" on HackerRank
katex: true
date: 2025-01-31 19:44 -0800
---
{% intro %}
The [challenge] is to split a matrix into concentric rings, and rotate each
ring a certain number of places to the left. To do that, all we really need to
do is figure out how to look at each ring as if it were a flat array. That can
be broken down into two challenges: the mathematics, and the code.
{% endintro %}

### The mathematics

We're given a matrix $$\mathbf{M}$$ of width $$w$$ and height $$h$$. We want to convert
a ring of that matrix inset $$r$$ rows and columns into a flat sequence $$a$$.
For instance, given a $$7 \times 6$$ matrix and an offset $$r=1$$:

$$
\gdef\ca#1{ {\color{royalblue}#1}}
\gdef\cb#1{ {\color{plum}#1}}
\gdef\cc#1{ {\color{cyan}#1}}
\gdef\cd#1{ {\color{goldenrod}#1}}
\gdef\ce#1{ {#1}}

\mathbf{M} =
\left[
\begin{matrix}
\ce{z} & \ce{z} & \ce{z} & \ce{z} & \ce{z} & \ce{z} & \ce{z} \\
\ce{z} & \ca{a_0} & \ca{a_1} & \ca{a_2} & \ca{a_3} & \cb{b_0} & \ce{z} \\
\ce{z} & \cd{d_2} & \ce{z} & \ce{z} & \ce{z} & \cb{b_1} & \ce{z} \\
\ce{z} & \cd{d_1} & \ce{z} & \ce{z} & \ce{z} & \cb{b_2} & \ce{z} \\
\ce{z} & \cd{d_0} & \cc{c_3} & \cc{c_2} & \cc{c_1} & \cc{c_0} & \ce{z} \\
\ce{z} & \ce{z} & \ce{z} & \ce{z} & \ce{z} & \ce{z} & \ce{z}
\end{matrix}
\right]
$$

we want the flat sequence:

$$
\gdef\ca#1{ {\color{royalblue}#1}}
\gdef\cb#1{ {\color{plum}#1}}
\gdef\cc#1{ {\color{cyan}#1}}
\gdef\cd#1{ {\color{goldenrod}#1}}
\gdef\ce#1{ {#1}}
a_{0\dots 13} =
\{ \ca{a_0}, \ca{a_1}, \ca{a_2}, \ca{a_3}, \cb{b_0}, \cb{b_1}, \cb{b_2},
\cc{c_0}, \cc{c_1}, \cc{c_2}, \cc{c_3}, \cd{d_0}, \cd{d_1}, \cd{d_2} \}
$$

To construct that sequence, we need matrix coordinates $$x(n)$$ and $$y(n)$$
for each value of $$a_n$$ such that we can define $$a$$ as:

$$
\begin{equation}
a_n = m_{y(n)x(n)}
\end{equation}
$$

Let's start by defining the widths of the horizontal segments ($$a$$ and
$$c$$) and the heights of the vertical segments ($$b$$ and $$d$$) as $$w'$$
and $$h'$$ respectively:

$$
\begin{align}
w' &= w - 2r - 1 \\
h' &= h - 2r - 1 \\
\end{align}
$$

We can use those either to calculate the $$x$$ and $$y$$ offset of each $$n$$
individually:

$$
\begin{align}
x(n) &= r +
\begin{cases}
n  & \text{if } n < w' \\
w' & \text{if } n \ge w' \text{ and } n < w'+h' \\
2w' + h' - n\quad\! & \text{if } n \ge w'+h' \text{ and } n < 2w'+h' \\
0 & \text{if } n \ge 2w'+h'
\end{cases}
\\
y(n) &= r +
\begin{cases}
0  & \text{if } n < w' \\
n - w' & \text{if } n \ge w' \text{ and } n < w'+h' \\
h' & \text{if } n \ge w'+h' \text{ and } n < 2w'+h' \\
2(w' + h') - n & \text{if } n \ge 2w'+h'
\end{cases}
\end{align}
$$

Or we can calculate them somewhat more simply by looking at each segment
in sequence, keeping track of the value of $$n$$ relative to its start, and
incrementing and decrementing $$x$$ and $$y$$ as appropriate:

{% codeblock lang:c++ %}
size_t x = r;
size_t y = r;

x += min(n, w_);
if (n > w_) {
    n -= w_;
    y += min(n, h_);

    if (n > h_) {
        n -= h_;
        x -= min(n, w_);

        if (n > w_) {
            n -= w_;
            y -= n;
        }
    }
}
{% endcodeblock %}

### C++ helper class

In C++, things will be easiest if we can simply treat each matrix ring as a
flat array. To do that, we need a helper class that we can initialize with a
matrix and an offset, and then access as an array:

{% codeblock lang:c++ %}
using Coord = tuple<size_t, size_t>;

class MatrixRing {
    vector<vector<int>>& matrix_;
    size_t offset_;
    size_t len_;
    size_t w_;
    size_t h_;

  public:
    MatrixRing(vector<vector<int>>& matrix, size_t offset)
        : matrix_(matrix), offset_(offset)
    {
        h_ = matrix.size() - 2 * offset - 1;
        w_ = matrix[0].size() - 2 * offset - 1;
        len_ = 2 * (w_ + h_);
    }

    size_t size() const { return len_; }

    Coord coord(size_t ord) const {
        ord %= len_;

        size_t x = offset_;
        size_t y = offset_;

        x += min(ord, w_);
        if (ord > w_) {
            ord -= w_;
            y += min(ord, h_);

            if (ord > h_) {
                ord -= h_;
                x -= min(ord, w_);

                if (ord > w_) {
                    ord -= w_;
                    y -= ord;
                }
            }
        }
        return {x, y};
    }

    int& operator[](size_t ord) {
        auto [x, y] = coord(ord);

        return matrix_[y][x];
    }

    const int& operator[](size_t ord) const {
        auto [x, y] = coord(ord);

        return matrix_[y][x];
    }
};
{% endcodeblock %}

This helper has the added feature of efficiently treating each ring as a
circle. Accessing elements past the end of the ring will simply circle back
around to the beginning.

Now, we *could* use this helper to solve the challenge without any further
modifications. However, as with many things in C++, it would benefit from
iterator support, which we can add fairly simply:

{% codeblock lang:c++ %}
template<typename MatrixRing>
class iterator_base {
    MatrixRing& ring_;
    size_t ord_;
public:
    using reference = decltype(declval<MatrixRing>()[0]);

    using iterator_category = std::random_access_iterator_tag;
    using value_type = std::decay_t<reference>;
    using difference_type = size_t;
    using pointer = std::remove_reference_t<reference>*;

    explicit iterator_base(MatrixRing& ring, size_t ord)
        : ring_(ring), ord_(ord)
    {}

    iterator_base& operator++() { ord_++; return *this; }
    iterator_base operator++(int) { iterator_base retval = *this; ++(*this); return retval; }

    iterator_base& operator--() { ord_--; return *this; }
    iterator_base operator--(int) { iterator_base retval = *this; --(*this); return retval; }

    iterator_base& operator+=(size_t val) { ord_ += val; return *this; }
    iterator_base operator+(size_t val) const { iterator_base retval = *this; retval += val; return retval; }

    iterator_base& operator-=(size_t val) { ord_ -= val; return *this; }
    iterator_base operator-(size_t val) const { iterator_base retval = *this; retval -= val; return retval; }

    bool operator==(const iterator_base& other) const { return ord_ == other.ord_; }
    bool operator!=(const iterator_base& other) const { return !(*this == other); }

    size_t operator-(const iterator_base& other) const { return ord_ - other.ord_; }

    reference operator*() const { return ring_[ord_]; }
};
using iterator = iterator_base<MatrixRing>;
using const_iterator = iterator_base<const MatrixRing>;

iterator begin() { return iterator(*this, 0); }
iterator end() { return iterator(*this, len_); }
const_iterator cbegin() const { return const_iterator(*this, 0); }
const_iterator cend() const { return const_iterator(*this, len_); }
{% endcodeblock %}

### The matrix rotation

With those helpers out of the way, the solution to the challenge becomes
fairly simple:

{% codeblock lang:c++ %}
void matrixRotation(vector<vector<int>> matrix, int r) {
    int h = matrix.size();
    int w = matrix[0].size();
    int m = min(w, h) / 2;

    // Rotate each ring r places to the left
    for (int i = 0; i < m; i++) {
        MatrixRing ring(matrix, i);

        // Factor out any complete rotations to figure out the number of
        // places we need to rotate
        int n = r % ring.size();

        // Figure out the starting position for the rotation.
        // We'll rotate left from this position, so element n becomes element
        // 0, n+1 becomes 1, ...
        auto start = ring.begin() + n;

        // Create a temporary array of the ring contents rotated n positions
        // to the left
        vector<int> rot(start, start + ring.size());

        // Copy the rotated values back into the ring
        copy(rot.begin(), rot.end(), ring.begin());
    }

    // Print the result
    for (auto& row : matrix) {
        for (auto& val : row) {
            cout << val << " ";
        }
        cout << endl;
    }
}
{% endcodeblock %}

### The complete code

{% codeblock lang:c++ %}
#include <bits/stdc++.h>
#include <iterator>

using namespace std;

using Coord = tuple<size_t, size_t>;

class MatrixRing {
    vector<vector<int>>& matrix_;
    size_t offset_;
    size_t len_;
    size_t w_;
    size_t h_;

  public:
    template<typename MatrixRing>
    class iterator_base {
        MatrixRing& ring_;
        size_t ord_;
    public:
        using reference = decltype(declval<MatrixRing>()[0]);

        using iterator_category = std::random_access_iterator_tag;
        using value_type = std::decay_t<reference>;
        using difference_type = size_t;
        using pointer = std::remove_reference_t<reference>*;

        explicit iterator_base(MatrixRing& ring, size_t ord)
            : ring_(ring), ord_(ord)
        {}

        iterator_base& operator++() { ord_++; return *this; }
        iterator_base operator++(int) { iterator_base retval = *this; ++(*this); return retval; }

        iterator_base& operator--() { ord_--; return *this; }
        iterator_base operator--(int) { iterator_base retval = *this; --(*this); return retval; }

        iterator_base& operator+=(size_t val) { ord_ += val; return *this; }
        iterator_base operator+(size_t val) const { iterator_base retval = *this; retval += val; return retval; }

        iterator_base& operator-=(size_t val) { ord_ -= val; return *this; }
        iterator_base operator-(size_t val) const { iterator_base retval = *this; retval -= val; return retval; }

        bool operator==(const iterator_base& other) const { return ord_ == other.ord_; }
        bool operator!=(const iterator_base& other) const { return !(*this == other); }

        size_t operator-(const iterator_base& other) const { return ord_ - other.ord_; }

        reference operator*() const { return ring_[ord_]; }
    };
    using iterator = iterator_base<MatrixRing>;
    using const_iterator = iterator_base<const MatrixRing>;

    iterator begin() { return iterator(*this, 0); }
    iterator end() { return iterator(*this, len_); }
    const_iterator cbegin() const { return const_iterator(*this, 0); }
    const_iterator cend() const { return const_iterator(*this, len_); }

    MatrixRing(vector<vector<int>>& matrix, size_t offset)
        : matrix_(matrix), offset_(offset)
    {
        h_ = matrix.size() - 2 * offset - 1;
        w_ = matrix[0].size() - 2 * offset - 1;
        len_ = 2 * (w_ + h_);
    }

    size_t size() const { return len_; }

    Coord coord(size_t ord) const {
        ord %= len_;

        size_t x = offset_;
        size_t y = offset_;

        x += min(ord, w_);
        if (ord > w_) {
            ord -= w_;
            y += min(ord, h_);

            if (ord > h_) {
                ord -= h_;
                x -= min(ord, w_);

                if (ord > w_) {
                    ord -= w_;
                    y -= ord;
                }
            }
        }
        return {x, y};
    }

    int& operator[](size_t ord) {
        auto [x, y] = coord(ord);

        return matrix_[y][x];
    }

    const int& operator[](size_t ord) const {
        auto [x, y] = coord(ord);

        return matrix_[y][x];
    }
};

void matrixRotation(vector<vector<int>> matrix, int r) {
    int h = matrix.size();
    int w = matrix[0].size();
    int m = min(w, h) / 2;

    for (int i = 0; i < m; i++) {
        MatrixRing ring(matrix, i);

        int n = r % ring.size();
        auto start = ring.begin() + n;

        vector<int> rot(start, start + ring.size());
        copy(rot.begin(), rot.end(), ring.begin());
    }

    for (auto& row : matrix) {
        for (auto& val : row) {
            cout << val << " ";
        }
        cout << endl;
    }
}
{% endcodeblock %}


[challenge]: https://www.hackerrank.com/challenges/matrix-rotation-algo/problem
