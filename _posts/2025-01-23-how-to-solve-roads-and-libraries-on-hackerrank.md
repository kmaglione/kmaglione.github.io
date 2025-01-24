---
layout: post
title: How to solve "Roads and Libraries" on HackerRank
date: 2025-01-23 20:20 -0800
---
{% intro %}
This [challenge] boils down to a route finding problem: starting from any city
with a library, what's the least number of roads we need to travel we need to
travel to get to any other city that can be reached by road. It has the minor
complications that we need to group cities into clusters that are all reachable
from each other, and decide where in that cluster to build libraries, but
those are both quite easy to handle if we use [Dijkstra's algorithm][dijkstra].
{% endintro %}

Dijkstra's algorithm, in its most basic form, calculates to shortest distance
from a given node in a graph to every other node in the graph. If we're
looking for the shortest path to a specific node, we would typically stop
traversing the graph as soon as we visit that node it. The rest of the time,
we would typically stop traversing the graph as soon as we run out of
unvisited nodes that we've found any path to, meaning that the remainder must
be unreachable from the starting node. In our case, though, we simply continue
traversing the entire graph, no matter what.

Rather than choose a specific starting node, and setting its cost to 0, as
would be typical, we'll simply add all cities to the queue of unvisited nodes.
Any time we come to a city with a cost of `Infinity` (as will be the case for
the first node we process), we know we have a city not reachable from any
previous city cluster. Since this city is in a new cluster, we choose to build
a new library there, and set its cost to the cost of building a new library.
Since the only requirement is that a library be reachable from any city,
regardless of how far it is, it doesn't matter where we choose to build the
library. The total cost will be the same. From there, we continue with
Dijkstra's algorithm as normal. The cost of reaching each neighboring node
will be the cost of building the road.

At the end, we simply add up the costs we've calculated for each city minus
the cost of its cheapest neighbor (if there is a cheaper neighbor), and we
have our result.

The one final complication, though, lies in the priority queue that we need in
order to process unvisited nodes. We need a priority queue which allows us to
efficiently adjust the priority of nodes already in the queue as we walk the
graph. The `heap` and `priority_queue` utilities in C++'s STL don't allow for
that. Boost's `Heap` class in principle does, but in the interests of avoiding
external dependencies, we simply implement our own.

The final code looks like this:

{% codeblock lang:c++ %}
using namespace std;

struct City {
    static constexpr ulong Infinity = ULONG_MAX;

    bool visited = false;
    // The current index of the city in the PriorityQueue's heap.
    int index = 0;
    // The list of neighbor cities reachable by road from this one.
    vector<City*> neighbors;
    // The total cost to reach this city from another city with a library,
    // or to build a library in it if it wasn't already reachable from a
    // city with a library.
    ulong cost = Infinity;

    bool operator<(City& other) {
        return cost < other.cost;
    }
    bool operator<=(City& other) {
        return cost <= other.cost;
    }

    static bool less(City* a, City* b) {
        return *a < *b;
    }
};

template<typename T>
class PriorityQueue {
    vector<T*> heap;

  public:
    /**
     * Append the given node to the back of the queue. No rebalancing is
     * performed. The node must have a priority of Infinity.
     */
    void append(T* node) {
        assert(node->cost == T::Infinity);
        node->index = heap.size();
        heap.push_back(node);
    }

    void reserve(size_t size) {
        return heap.reserve(size);
    }

    size_t size() const {
        return heap.size();
    }

    /**
     * Swap the given nodes and update their indices.
     */
    void swapNodes(T* a, T* b) {
        swap(heap[a->index], heap[b->index]);
        swap(a->index, b->index);
    }

    /**
     * Rebalance the tree after the given node is moved or has its
     * priority changed.
     */
    void rebalance(T* node) {
        bool found = false;
        int i = node->index;
        while (i > 0) {
            int parent = (i - 1) / 2;
            if (*heap[parent] <= *heap[i]) {
                break;
            }
            found = 1;
            swapNodes(heap[i], heap[parent]);
            i = parent;
        }
        if (!found) {
            while (i < heap.size()) {
                int c1 = 2 * i + 1;
                int c2 = 2 * i + 2;
                if (c1 < heap.size() &&
                      *heap[c1] < *heap[i] &&
                      *heap[c1] < *heap[c2]) {
                    swapNodes(heap[c1], heap[i]);
                    i = c1;
                } else if (c2 < heap.size() && *heap[c2] < *heap[i]) {
                    swapNodes(heap[c2], heap[i]);
                    i = c2;
                } else {
                    break;
                }
            }
        }
    }

    T* popMin() {
        T* result = heap[0];
        if (heap.size() > 1) {
            swapNodes(heap.front(), heap.back());
            heap.pop_back();
            rebalance(heap.front());
        } else {
            heap.pop_back();
        }
        result->visited = true;
        result->index = -1;
        return result;
    }
};


long roadsAndLibraries(int n, int c_lib, int c_road,
                       vector<vector<int>> cityPairs) {
    // If libraries are the same price as roads or cheaper, it will always
    // be cheapest to build a library in a city rather than to repair any
    // roads.
    if (c_lib <= c_road) {
        return long(c_lib) * n;
    }

    // Add bi-directional links between each city in each of the the given
    // city pairs.
    vector<City> cities(n);
    for (auto& pair : cityPairs) {
        City& a = cities[pair[0] - 1];
        City& b = cities[pair[1] - 1];
        a.neighbors.push_back(&b);
        b.neighbors.push_back(&a);
    }

    // Add each city to the priority queue of cities yet to be visited.
    PriorityQueue<City> pqueue;
    pqueue.reserve(n);
    for (uint i = 0; i < cities.size(); i++) {
        auto& city = cities[i];
        pqueue.append(&city);
    }

    while (pqueue.size()) {
        City* city = pqueue.popMin();

        // If the node's cost is Infinity, it was unreachable from any
        // city previously processes. Set its initial cost to the cost
        // of a library, to serve as the library for any other city
        // reachable from this one.
        if (city->cost == City::Infinity) {
            city->cost = c_lib;
        }

        // Figure out the total cost to reach a neighboring city via this
        // one, and update the cost of any unvisited neighbors if it's
        // lower than their current cost.
        ulong cost = city->cost + c_road;
        for (City* neighbor : city->neighbors) {
            if (!neighbor->visited && neighbor->cost > cost) {
                neighbor->cost = cost;
                pqueue.rebalance(neighbor);
            }
        }
    }

    // Figure out the total cost of all library and road constructions.
    double cost = 0;
    for (City& city : cities) {
        cost += city.cost;

        // If we have a neighbor with a lower cost than ours, it means
        // that we are connected to a library via that city. Subtract the
        // cost of the cheapest neighbor city from the total to end up
        // with just the cost of constructing the link.
        auto minNeighbor = min_element(city.neighbors.begin(),
                                       city.neighbors.end(),
                                       City::less);
        if (minNeighbor != city.neighbors.end() &&
            (*minNeighbor)->cost < city.cost) {
            cost -= (*minNeighbor)->cost;
        }
    }

    return cost;
}
{% endcodeblock %}


[challenge]: https://www.hackerrank.com/challenges/one-month-preparation-kit-torque-and-development/problem
[dijkstra]: https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm "Dijkstra's algorithm"
