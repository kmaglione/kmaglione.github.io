---
layout: post
title: "Add-on performance testing via power usage"
date: 2013-09-20 14:18
comments: true
categories:
  - Mozilla
  - Add-ons
  - Performance
---

{% intro %}
We've struggled for a long time to programmatically measure the
objective performance impact of add-ons on Firefox. While a perfect
solution is still far off, we've recently started down an
interesting new avenue: automatically measuring the impact of
add-ons on the computer power consumption during test runs. This
turns out to be a surprisingly useful proxy for performance
overhead, since power consumption is directly affected by the amount
of real work a CPU and GPU have to do, as well as total application
runtime. Thanks to hardware donations from Intel, we've begun a
preliminary set of automated test runs against a subset of the most
popular Firefox add-ons. The results so far have been promising,
with numbers generally well in line with our expectations.
{% endintro %}

Methodology
-----------

Our initial methodology involves running Firefox, via a 
[simple test harness](https://github.com/kmaglione/power-tests), 
while collecting power usage data via Intel's 
[Power Gadget](http://software.intel.com/en-us/articles/intel-power-gadget-20)
software. During the test runs, the test harness performs a number
of common tasks, including loading a series of URLs in tabs, closing
all tabs, and finally performing garbage and cycle collection to
clean up any unused memory. For our initial series of tests, we've
done 5 runs per add-on, graphing the results with the median total
power consumption, in order to minimize the impact from uncontrolled
factors.

We've taken a few precautions in order to prevent tainted
data, including:

- Running Firefox once after the initial add-on install and throwing
  away the results, in order to prevent interference from first-run
  initialization tasks.
- Disabling Firefox update and reporting services.
- Disabling Windows system services such as the search indexer,
  screen saver, and system updates.
- Disabling power management features such as adaptive screen
  brightness, screen dimming, CPU scaling, and system suspend.
- Disabling the Adobe Flash plugin.

For future runs, we'd like to take a number of other precautions to
tighten the margin of error, including:

- More aggressive disabling of Windows services and background
  tasks.
- Monitoring of CPU usage of other processes during the run, to weed
  out outliers.
- Using a more standardized set of web pages for the test runs, in
  order to prevent interference due to network issues and content
  which changes throughout the runs (such as some runs using
  animated advertisements and others using static images).
- Performing a larger number of runs per add-on, and interspersing
  single runs for each add-on with those of others, rather than
  performing all runs for a single add-on in series.
- Mark garbage and cycle collection pauses in output graphs.
- Use custom initialization code to ensure add-ons are in a state
  similar to what we would expect in the wild.

Results
-------

**Please note:** *These results are preliminary and do not
necessarilly indicate that any of the add-ons in question should be
used or avoided.*

An overview of a subset of the first results is pretty telling:

[![Power test results][boxplot]][boxplot]

There's a fairly wide margin of error, but even so there are some
clear outliers, with NoScript clearly improving performance, and
FastestFox and AnonymoX clearly hurting it. A detailed overview of
the results gives some more insight:

### Baseline

Let's start with an overview of the baseline results:

[![Baseline results][baseline]][baseline]

Here you see a chart of the current and cumulative power
consumption, where the `x` axis is seconds since the start of the
process. The colored bands indicate the time from when we start to
load a URL until the load event fires, for each of the following
URLs:

1. http://ruby-doc.org/stdlib-2.0.0/
2. https://www.google.com/search?num=50&hl=en&site=&tbm=isch&source=hp&biw=1918&bih=978&q=mozilla&oq=&gs_l=
3. https://en.wikipedia.org/wiki/Mahler
4. http://www.youtube.com/
5. http://www.smbc-comics.com/
6. http://slashdot.org/

The three plot lines at the end of the graph indicate the time from
when we begin removing tabs, the time when we begin garbage and
cycle collection, and the time when we ask the browser to quit,
respectively.

The power use spike between the load of URLs 3 and 4 is consistent
across all add-ons tested, and most likely represents a garbage
collection cycle.

### NoScript

We see a subtle, but substantial, difference in the NoScript
results:

[![NoScript results][noscript]][noscript]

Not only are load times for pages substantially shorter, but power
consumption during and shortly after page load is also markedly
lower. The lack of page scripts, in this case, essentially negates
the performance impact they would normally cause. In many cases
this makes for significantly less reflow during page load, less external
media loads such as sharing widgets, and less time away from the
main event loop while page code is running. While this doesn't tell
us much about the overhead of NoScript code itself, it does suggest
that it's more than balanced by its impact on overall performance, in
the absence of user whitelisting. In ordinary use, most of these
benefits are likely lost due to the whitelisting of scripts from
trusted sites.

### AnonymoX

In the case of AnonymoX, the primary impact seems to be from
drawn-out load time:

[![AnonymoX results][anonymox]][anonymox]

Since the primary function of the add-on is to route all traffic
through an anonymizing proxy, we expect load times to suffer, and
therefore overall power consumption to increase as well. While this
may not be avoidable by the add-on, the raw numbers mirror the very
real performance impact of the add-on. This suggests that even for
unusual cases, the results of these tests may be useful in providing
us data that we can use to warn users that the add-on may impact
performance, so that they can make an informed decision about whether
to install it.

### AutoPager

AutoPager seems to tell a different story still:

[{% img center /assets/img/power-tests/autopager.svg 800 400 "AutoPager results" "AutoPager results" %}](/assets/img/power-tests/autopager.svg)

Here we don't see a significant effect on load time, but we do see a
noticeable power usage increase after the load event fires. This
suggests that the add-on is doing a considerable amount of work
after page load, which is a fairly common pattern in add-ons, and
may suggest avenues for improvement.

Conclusions
-----------

The results are still preliminary, and the testing procedure needs
to be refined and broadened, but the clear and consistent outliers
in the results strongly suggest that this is a fruitful avenue for
assessing the performance impact of our top add-ons. With expanded
testing, this process may be an important tool to find and address
the most significant add-on-related performance impacts to our user
base.

[boxplot]: {% link /assets/img/power-tests/boxplot.svg %} "Power test results"
{: .center width="800px" height="1100px"}
[baseline]: {% link /assets/img/power-tests/baseline.svg %} "Baseline results"
{: .center width="800px" height="400px"}
[noscript]: {% link /assets/img/power-tests/noscript.svg %} "NoScript results"
{: .center width="800px" height="400px"}
[anonymox]: {% link /assets/img/power-tests/anonymox.svg %} "AnonymoX results"
{: .center width="800px" height="400px"}
