---
title: Once upon a time, a REDIS::TIMEOUTERROR
date: 2014-01-10
tags: Redis, nosql, AWS, Ruby on Rails
---

This is the story about three issues I encounter with Redis on a high traffic application, each time gradually degrading the performances until Redis and the app were not usable anymore.

READMORE

<center>
# A REDIS::TIMEOU<font color='red'>TERROR</font>
</center>

Once upon a time, I was working on an app allowing more than 100 golf clubs to manage the availabilities of their golf courses. This was a ruby on rails app hosted on AWS.

The clubs had a client application which was pulling continuously on the API of this web app in order to know their availabilities, what they sold and what is still free. This client app was from a time before webhooks.

The availabilities were pre-calculated and stored in redis in order to avoid to calculate everything each time someone wanted to list availabilities on multiple clubs on multiple days.

On this app, we were using Redis for :

* caching processed information (golf course availabilities)
* rails cache for views and partials
* background worker queues (sidekiq)

After the last 200 days of uptime since the last modification, here are some stats from the Redis server :

* 19 billion calls to Redis in 200 days (1070 calls per second average)
* 4Gb in memory
* 1.5 million keys actually used for availabilities

## RTFM

Few weeks after using this app in production, we had a lot of Redis::TimeoutError which was the only source of bug we had in the API and the web application. The app was pretty much broken.

Due to a zero budget load test and a lack of reading the Redis documentation, I missed these two parts :

> The use of Redis persistence with EC2 EBS volumes is discouraged since EBS performance is usually poor. Use ephemeral storage to persist and then move your persistence files to EBS when possible.

> Even if you have persistence disabled, Redis will need to perform RDB saves if you use replication.

The backup and the replication we had setup were dumping the full data set on disk regularly, triggering a lot of I/O which were avidly stolen by the EC2 hypervisor and slowing heavily the Redis server. Most of the requests were going in timeout when this was happening.

The solution was to stop doing the backup of the Redis DB : all the data in Redis was recalculable with some other data in Postgres. The Redis replication to a slave server was gone too, we just made sure that we would recalculate everything if the things were going wrong.

See the app response time and error rate after the change (vertical bar):
![Removing Redis from EBS](images/redis_ttl/1-remove-redis-from-EBS.png)

## Splitting the Redis server

After one month of peace on this application, the same exception Redis::TimeoutError popped again.

While we were monitoring the server was saw that the main load was coming from the numerous cached partials of a calendar view.

Splitting the Redis server was the next approach to avoid having the web views impacting the clients API.

```ruby
# cat config/initializers/redis.rb
$redis = Redis.new host: 'ec2-xxx...', port: 6379, driver: :hiredis
$redis_rails_cache = Redis.new host: 'ec2-yyy...', port: 6379, driver: :hiredis
```
It worked again and the client was happy again. See the app response time:
![Splitting Redis in two](images/redis_ttl/3-after-split-redis-cache-and-availabilities_app-response-time.png)

## RTFM #2

Once again, two month later, we had heaps of exceptions. The Redis *MONITOR* command is showing some very slow requests, expiring keys with a wildcard, using the *KEYS* command.

The Redis documentation is actually stating that :

> KEYS (...) should only be used in production environments with extreme care. It may ruin performance when it is executed against large databases.

What we were doing is that each time we had a new information regarding the clubs availabilities (new booking, price change, ...), we were expiring many full sets of keys. The fix here was to stop expiring the keys manually and to let them expire after some time (was 14 days here). The actual ID of the availabilities would just need to change when a new information is added, incrementing the namespace of the cached value.

More data will be in memory, but the CPU will almost do nothing after this. The Redis server went from 95% of CPU use to 0.05%.

CPU load of the Redis server around the fix :
![CPU after fix](images/redis_ttl/4-redis-wildcard-invalidation_load-average.png)

Redis server after the storm:
![New Relic - one month later](images/redis_ttl/6-redis-1-month-later.png)

