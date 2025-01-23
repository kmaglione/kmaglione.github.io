---
layout: post
title: "Better extension performance with Promises"
date: 2015-01-27 12:29:21 -0800
excerpt:
  Performance can be very hard to get right. Added performance that
  comes at the cost of code clarity can be difficult to sustain, and
  even large investments into performance may be wasted if aimed at
  a poor target. While choosing where to aim your optimization efforts
  may never be easy, we've recently chosen to focus on one high gain
  problem area, for both Firefox and its add-ons, and have begun to
  adopt a coding style which makes gains in this area very nearly
  free.
comments: true
categories: 
  - Mozilla
  - Add-ons
  - Performance
  - Promises
---
{% blockquote Jon Bentley and Doug McIlroy %}
The key to performance is elegance, not battalions of special cases.
{% endblockquote %}

{% blockquote Donald Knuth %}
We should forget about small efficiencies, say about 97% of the time: premature optimization is the root of all evil.
{% endblockquote %}

*This is an unfinished blog post started some two-and-a-half years ago that is
unlikely to ever be finished properly. So I'm publishing it as-is in case
anyone finds it useful.*

{% intro %}
Performance can be very hard to get right. Added performance that
comes at the cost of code clarity can be difficult to sustain, and
even large investments into performance may be wasted if aimed at
a poor target. While choosing where to aim your optimization efforts
may never be easy, we've recently chosen to focus on one high gain
problem area, for both Firefox and its add-ons, and have begun to
adopt a coding style which makes gains in this area very nearly
free.
{% endintro %}

<!--more-->

While this article will focus mainly on the problem of synchronous
IO, the solutions we propose extend to many other areas, from
offloading work onto multiple threads, to easing interaction between
privileged browser code and asynchronous, sandboxed content
processes.

## The IO problem

In Firefox, all code which interacts with the UI must run on the
main thread. This means that while any JavaScript is running,
whether executing complex calculations, or blocking on IO, the UI of
the entire browser must remain essentially frozen[^e10s]. The result
is that long-running operations, or relatively short-running
operations which happen often, can lead to a laggy and unresponsive
browser. This can be such a significant problem that we have a
special name for it: jank.

There are many sources of jank, and many ways of addressing them,
but here we're going to focus on what's proven to be on of the most
significant, and easy to fix: IO pauses. These often come from
things you might think of as trivial, such as reading a config file
from disk. Or from things you think of as expensive, but difficult
to handle asynchronously, like SQL queries. Or even things you may
think of as madly expensive, but might do anyway, like network IO.

You'd be right to think most of these operations relatively cheap,
most of the time. But in aggregate, or in the unusual circumstances
which turn out to in fact be very common, they add up to produce a
noticeably sluggish UI.

## Asynchrony: The complicated solution

The solution to the IO problem is to perform operations
asynchronously. Often this can be fairly simple. Rather than reading
a file by calling a function that returns its contents, you use a
different function which returns them via a callback. Rather than
performing a synchronous `XMLHttpRequest`[^xhr], you use an
asynchronous request with a `load` event listener. But what happens
when you need to chain multiple IO operations that rely on the
previous operations' results?

{% codeblock lang:javascript %}
IO.readFile(CONFIG_FILE, function (data) {
    data = JSON.parse(data);

    var xhr = new XMLHttpRequest;
    xhr.open("GET", data.url);
    xhr.onload = function () {
        var url = QUERY_URL + this.response.user_id;
        var xhr = new XMLHttpRequest;
	xhr.open("GET", url);
	xhr.onload = function () {
            SQL.execute("INSERT INTO data (key, value) \
                         VALUES (?, ?)",
                        this.response.rows,
                        function (result) {
                SQL.execute("SELECT key, COUNT(1) \
                             FROM data GROUP BY key;",
                             [], function (result) {
                    for (let row of result)
                        countKey(row[0], row[1]);
                });
            })
	};
        xhr.responseType = "json";
	xhr.send();
    };
    xhr.responseType = "json";
    xhr.send();
});
{% endcodeblock %}

## Promises: The complicated made simple

The modern idea of promises arose out of the near ubiquitous need to
deal with complex, asynchronous operations. While the concept itself
is fairly simple, it goes a long way toward simplifying many
problems associated with coordinating multiple sequential
operations, wether in parallel, or in sequence, or any particular
vaguely-DAG-shaped flow you'd care do imagine.

In promise-based code, any function which operates asynchronously,
and might otherwise accept a callback or event listener, returns a
promise object instead. A promise object is, as its name suggests, a
promise to return a value. Any code with access to this object can
register to be notified when the value is available, or the
operation is complete.

Each of these promise objects will inevitably end up in one of two
states. Either the operation will complete successfully, in which
case we say it is *resolved*, or the operation will fail, in which
case we say it is *rejected*. In either case, the appropriate
handlers will be notified.

The above example, in promise-based code, would look something like:

{% codeblock lang:javascript %}
IO.readFile(CONFIG_FILE).then(data => {
    data = JSON.parse(data);

    return HTTPRequest(data.url, { type: "json" });
}).then(response => {
    var url = QUERY_URL + response.user_id;

    return HTTPRequest(url, { type: "json" });
}).then(response => {
    return SQL.execute("INSERT INTO data (key, value) \
                        VALUES (?, ?)",
                       response.rows);
}).then(result => {
    return SQL.execute("SELECT key, COUNT(1) \
                        FROM data GROUP BY key;");
}).then(result => {
    for (let row of result)
        countKey(row[0], row[1]);
});
{% endcodeblock %}
{: #promise-example}

While the differences may appear superficial, the technique offers
several advantages over older callback- and event-based approaches.
In my opinion, though, the only benefits that really matter are:

* *Consistency*: In Promise-based code, all interfaces with return a
  result asynchronously follow the same pattern. Not only does this
  simplify API design and usage, and improve readability, but it also
  allows for the easy creation of utilities which would otherwise be
  extremely complicated.
  
  For instance, the [`Promise.all`] helper function consolidates an
  array of promises into a single promise which resolves once every
  promise in the array has resolved. This is possible regardless of
  the API used, or the type of object the promise returns.

* *Chaining*: Registering a promise handler has the side-effect of
  creating a new promise to report on the status of the handler
  itself. When the handler returns, this new promise is resolved
  with its return value. When it raises an error, the promise is
  rejected with that error. Most importantly, though, if the handler
  returns a `Promise` object, its _own_ promise is resolved or
  rejected when this new promise is resolved or rejected, with the
  same value.
  
  This behavior allows for the seamless construction of chains of
  promise handlers which may rely on the values generated by previous
  handlers, and for functions which return promises to trivially
  generate results which rely on such chains.

The combination of these two factors leads to a very flexible
approach with the power to simplify many types of problem.

### Promise basics

Standard promises are created by passing an arbitrary function to
the native `Promise` constructor[^js-promises]. The function is
executed immediately, with two further functions, `resolve` and
`reject`, as arguments. Calling one of these functions will cause
the promise to be resolved, or rejected, as appropriate.

The most basic promise looks something like this:

{% codeblock lang:javascript %}
var promise = new Promise((resolve, reject) => {
    // If we're good, resolve with an appropriate message.
    // Otherwise, reject with an inappropriate one.
    if (okay)
        resolve("All is well");
    else
        reject("The sky is falling!");
});
{% endcodeblock %}

Here, we create a very simple promise, which is immediately either
*resolved* if the variable `okay` is `true`, or otherwise
*rejected*.

To make any use of this result, we need to register a handler:

{% codeblock lang:javascript %}
promise.then(
    message => {
        // The promise has been resolved. Hurrah!
        // Tell our users "All is well"
        alert(message)
    },
    message => {
        // The promise has been rejected. Oh no!
        // Tell our users "The sky is falling!"
        alert(message);
        // Panic!
        commenceOrgies();
    });
{% endcodeblock %}

Or, to put it all together:

{% codeblock lang:javascript %}
new Promise((resolve, reject) => {
    if (okay)
        resolve("All is well");
    else
        reject("The sky is falling!");
}).then(message => {
            alert(message)
        },
        message => {
            alert(message);
            commenceOrgies();
        });
{% endcodeblock %}

Clearly, this example is silly. We could have more concisely written
the above as:

{% codeblock lang:javascript %}
if (okay)
    alert("All is well");
else {
    alert("The sky is falling!");
    commenceOrgies();
}
{% endcodeblock %}

The benefits will begin to become clear as our examples become more
complex.

#### Asynchronous resolution: A wrapper for `XMLHttpRequest`

For a more practical example, let's look at creating a wrapper for
a basic `XMLHttpRequest`, as used in the [example above](#promise-example):

{% codeblock lang:javascript %}
function HTTPRequest(url, options={}) {
    return new Promise((resolve, reject) => {
        var xhr = new XMLHttpRequest;

        // Register load and error handlers to resolve or reject our
        // promise.
        xhr.onload = event => { resolve(xhr.response) };
        xhr.onerror = reject;

        // Set up and send the request.
        xhr.open("GET", url);
        if (options.type)
            xhr.responseType = options.type;
        xhr.send();
    });
}
{% endcodeblock %}

This function returns a promise which is resolved or rejected only
after the request completes. We'd use it to fetch a simple document
as such:

{% codeblock lang:javascript %}
HTTPRequest("http://example.com").then(response => {
    console.log("Here's some HTML:", response);
});
{% endcodeblock %}

Here, we already see some improvement over the direct
`XMLHttpRequest` usage. It's much more concise, for a start. And
while we could achieve similar concision by passing success and
error callbacks, the familiar `.then(success, failure)` pattern
makes the behavior immediately clear to the reader.

The standardized interface also gives us some reusability benefits.
For instance, if we dispatch a number of requests and need to wait
for all of them to complete before proceeding, we can use the builtin
`Promise.all` method, without any additional work:

{% codeblock lang:javascript %}
var URLS = ["http://example.com/foo.json",
            "http://example.com/bar.json",
            "http://example.com/baz.json"];

// Dispatch the requests.
var requests = URLS.map(url => HTTPRequest(url, { type: "json" }));

// Wait for all of the requests to complete, collecting the results
// into a single array.
Promise.all(requests).then(responses => {
    responses.forEach((response, index) => {
        processResponse(URLS[index], response);
    });
});
{% endcodeblock %}

Moreover, we needn't restrict ourselves to only `HTTPRequest`
promises, but can use the same `Promises.all` call to wait for any
number of promises of unrelated types.

## Promise handlers in detail

Promise handlers added using the `.then()` method take two optional
functions as parameters, a success callback and a failure callback,
to be called when the promise is resolved or rejected, respectively.
In their simplest form, these handlers behave no different from
ordinary success and failure callbacks. However, the `.then()`
function also returns a promise, which is tied to the success or
failure of the handler itself.

If the success callback returns successfully, this promise will
resolve with its return value. Importantly, if the callback returns
a `Promise` itself, the two promises become linked, and the
handler's promise is accepted or rejected as if it were the returned
promise.

{% codeblock lang:javascript %}
// Create a promise which immediately resolves to `42`.
var promise = new Promise(accept => { accept(42) });

// Add a handler to this promise. Save the promise it returns.
var promise2 = promise.then(value => {
    // `value` should be `42` here. This is unfortunately not a prime
    // number, so let's fix that.
    return value + 1;
});

// Add a new handler to deal with the previous handler's return value.
var promise3 = promise2.then(value => {
    // Though, frankly, I've never trusted rational numbers,
    // so let's do something about that.
    return new Promise(accept => { accept(value / Math.E) });
});

// Alright. We probably have something sensible now.
// Add a handler and log it.
promise3.then(value => {
    console.log(value); // value = 43 / e ≅ 15.81881597037202
});
{% endcodeblock %}

Or, without the intermediate variables, as it would idiomatically be
written:

{% codeblock lang:javascript %}
new Promise(accept => { accept(42) }).then(value => {
    return value + 1;
}).then(value => {
    return new Promise(accept => { accept(value / Math.E) });
}).then(value => {
    console.log(value); // value = 43 / e ≅ 15.81881597037202
});
{% endcodeblock %}

If exceptions are raised by either the success or failure callbacks,
the handler's promise will be rejected, with the exception as the
reason. Likewise, the failure callback itself may return a
`Promise`, which will cause the handler's promise to be rejected
with its value as the reason.

If the handler is missing either a success or failure callback, then
success or failure of the parent promise is propagated directly to the
handler's promise.

## Thing!

The beauty of this approach is that it scales very easily to handle
complex flows. If, for instance, you need to handle a mix several
operations in parallel in series:

{% img center /assets/img/promise-dag.png 800 213 %}

The necessary promise code is simple:

{% codeblock lang:javascript %}
Foo().then(foo => {
    return Promise.all([
        Bar(foo),

        Promise.all([Baz(0, foo),
                     Baz(1, foo),
                     Baz(2, foo),
                     Baz(3, foo)])
               .then(bazzes => {
            return Promise.all([Quux(0, bazzes),
                                Quux(1, bazzes),
                                Quux(2, bazzes)]);
        })
    ]);
}).then(([bar, quuxes]) => {
    return MFBT(bar, quuxes);
});
{% endcodeblock %}


#### Footnotes
{: #footnotes}

[^e10s]:
    This situation will change somewhat with the introduction of
    [Multi-process Firefox](https://developer.mozilla.org/en-US/Firefox/Multiprocess_Firefox),
    commonly known as electrolysis or e10s. With e10s enabled, while
    all UI code must still run on the main thread, each content tab
    runs in its own process, with its own main UI thread. As a
    result, code blocking the main thread of a content tab will not
    interfere with the UI of the main browser itself, or of other
    tabs. 

[^xhr]:
    This is, in fact, a bit of a misnomer. A synchronous
    `XMLHttpRequest`, rather than actually blocking the main thread,
    initiates the network request and then continues processing
    events from the main event loop until it has a response. While
    this doesn't cause the same jank issues as hard blocking on IO,
    it does block interaction with the browser or content window
    that the request was initiated from, among other problems.
    
    Imagine, for instance, that while your `XMLHttpRequest` is
    waiting for its response, another task starts its own
    `XMLHttpRequest`. Your initial request will not return until the
    second request finishes. While this may seem contrived, there
    are other "blocking" functions which behave similarly, and this
    behavior does, in practice, lead to deadlocks.

[^js-promises]:
    There have been many, often incompatible, implementations of the
    promise concept in the past. For simplicity, here we focus
    solely on the more recent [ECMAScript Promises] standard.

[ECMAScript Promises]: http://people.mozilla.org/~jorendorff/es6-draft.html#sec-promise-objects

[`Promise.all`]: https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Promise/all

*[DAG]: Directed Acyclic Graph
