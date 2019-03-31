
<!-- README.md is generated from README.Rmd. Please edit that file -->

# otpr

[![Build
Status](https://travis-ci.org/marcusyoung/otpr.svg?branch=master)](https://travis-ci.org/marcusyoung/otpr)

## Overview

**otpr** is an R package that provides a simple wrapper for the
[OpenTripPlanner](https://www.opentripplanner.org/) (OTP) API. To use
**otpr** you will need a running instance of OTP. The purpose of the
package is to submit a query to the relevant OTP API resource, parse the
OTP response and return useful R objects.

This package will be useful to researchers and transport planners who
want to use OTP to generate trip data for accessibility analysis or to
derive variables for use in transportation models.

## Installation

``` r
# To install the development version from GitHub:
# install.packages("devtools")
devtools::install_github("marcusyoung/otpr")
```

## Getting started

``` r
library(otpr)
```

### Defining an OTP connection

The first step is to call `otp_connect()`, which defines the parameters
needed to connect to a router on a running OTP instance. The function
can also confirm that the router is
reachable.

``` r
# For a basic instance of OTP running on localhost with standard ports and a 'default' router
# this is all that's needed
otpcon <- otp_connect()
#> Router http://localhost:8080/otp/routers/default exists
```

### Distance between two points

To get the trip distance in metres between an origin and destination on
the street and/or path network use `otp_get_distance()`. You can specify
the required mode: CAR (default), BICYCLE or WALK are valid.

``` r
# Distance between Manchester city centre and Manchester airport by CAR
otp_get_distance(
  otpcon,
  fromPlace = c(53.48805,-2.24258),
  toPlace = c(53.36484,-2.27108)
)
#> $errorId
#> [1] "OK"
#> 
#> $distance
#> [1] 29207.19

# Now for BICYCLE
otp_get_distance(
  otpcon,
  fromPlace = c(53.48805,-2.24258),
  toPlace = c(53.36484,-2.27108),
  mode = "BICYCLE"
)
#> $errorId
#> [1] "OK"
#> 
#> $distance
#> [1] 16235.36
```

### Time between two points

To get the trip duration in minutes between an origin and destination
use `otp_get_times()`. You can specify the required mode: TRANSIT (all
available transit modes), BUS, RAIL, CAR, BICYCLE, and WALK are valid.
All the public transit modes automatically allow WALK. There is also the
option to combine TRANSIT with BICYCLE.

``` r
# Time between Manchester city centre and Manchester airport by BUS
otp_get_times(
  otpcon,
  fromPlace = c(53.48805,-2.24258),
  toPlace = c(53.36484,-2.27108),
  mode = "BUS"
)
#> $errorId
#> [1] "OK"
#> 
#> $duration
#> [1] 4084


# By default the date and time of travel is taken as the current system date and
# time. This can be changed using the 'date' and 'time' arguments
otp_get_times(
  otpcon,
  fromPlace = c(53.48805,-2.24258),
  toPlace = c(53.36484,-2.27108),
  mode = "TRANSIT",
  date = "11-25-2018",
  time = "08:00:00"
)
#> $errorId
#> [1] "OK"
#> 
#> $duration
#> [1] 2740
```

### Breakdown of time by mode, waiting time and transfers

To get more information about the trip when using transit modes,
`otp_get_times()` can be called with the ‘detail’ argument set to TRUE.
The trip duration is then further broken down by time on transit,
walking time (from/to and between stops), waiting time (when changing
transit vehicle or mode), and number of transfers (when changing transit
vehicle or
mode).

``` r
# Time between Manchester city centre and Manchester airport by TRANSIT with detail
otp_get_times(
  otpcon,
  fromPlace = c(53.48805,-2.24258),
  toPlace = c(53.36484,-2.27108),
  mode = "TRANSIT",
  date = "11-25-2018",
  time = "08:00:00",
  detail = TRUE
)
#> $errorId
#> [1] "OK"
#> 
#> $itineraries
#>                 start                 end duration walkTime transitTime
#> 1 2018-11-25 08:02:57 2018-11-25 08:48:37    45.67      7.9          31
#>   waitingTime transfers
#> 1        6.77         1
```

### Travel time isochrones

The `otp_get_isochrone()` function can be used to get one or more travel
time isochrones in GeoJSON format. These are only available for transit
or walking modes (OTP limitation). They can be generated either *from*
(default) or *to* the specified
location.

``` r
# 900, 1800 and 2700 second isochrones for travel *to* Manchester Airport by any transit mode
otp_get_isochrone(
  otpcon,
  location = c(53.36484, -2.27108),
  fromLocation = FALSE,
  cutoffs = c(900, 1800, 2700),
  mode = "TRANSIT"
)
```

## Learning more

The example function calls shown above can be extended by passing
additional parameters to the OTP API. Further information is available
in the documentation for each function:

``` r
# get help on using the otp_get_times() function
?otp_get_times
```

If you are new to OTP, then the best place to start is to work through
the tutorial, [OpenTripPlanner Tutorial - creating and querying your own
multi-modal route planner](https://github.com/marcusyoung/otp-tutorial).
This includes everything you need, including example data. The tutorial
also has examples of using **otpr** functions, and helps you get the
most from the package, for example using it to populate an
origin-destination matrix.

For more guidance on how **otpr**, in conjunction with OTP, can be used
to generate data for input into models, read [An automated framework to
derive model variables from open transport data using R, PostgreSQL and
OpenTripPlanner](https://eprints.soton.ac.uk/389728/).