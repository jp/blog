---
title: Once upon a time, a REDIS:TIMEOUTERROR
date: 2014-01-10
tags: Redis, nosql, AWS, Ruby on Rails
---

<center>
### ONCE UPON A TIME
## A REDIS::TIMEOU<font color='red'>TERROR</font>
</center>

Once upon a time, I was working on an app allowing more than 100 golf clubs to manage the availabilities of their golf courses. This was a ruby on rails app hosted on AWS.

The clubs had a client application which was pulling continuously on the API of this web app in order to know their availabilities, what they sold and what is still free. This was from a time before webhooks.

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

```ruby
# cat config/initializers/redis.rb
$redis = Redis.new host: 'ec2-xxx...', port: 6379, driver: :hiredis
$redis_rails_cache = Redis.new host: 'ec2-yyy...', port: 6379, driver: :hiredis
```

Vestibulum id felis mi. Vestibulum a erat leo. Morbi euismod orci nunc, sed iaculis nunc volutpat id. Etiam tempor blandit felis in tincidunt. Mauris at consectetur dui. Praesent feugiat, neque et vulputate convallis, nisi nisi tempus libero, et congue augue odio nec tellus. Praesent consequat arcu a facilisis aliquet. Donec et laoreet lectus. Aliquam sollicitudin, nulla mollis posuere feugiat, sem justo pellentesque lorem, commodo scelerisque mauris eros eu eros. Vestibulum eget eleifend diam, fringilla pretium libero. Integer sapien odio, porttitor non dui sed, tincidunt mattis erat. Pellentesque velit erat, porta a volutpat congue, rhoncus consectetur risus. Maecenas dictum venenatis risus, nec gravida purus elementum vitae. Sed gravida tortor sed sapien ultricies, eu iaculis nisl pulvinar.

Suspendisse consectetur eros et euismod vehicula. Nullam sed justo tristique tortor porta auctor ac quis nibh. In accumsan tellus quis diam ultrices, mollis feugiat augue adipiscing. Nam dictum non nisl ut auctor. Mauris porta augue non turpis tempus aliquet. Maecenas sed bibendum dolor. Nulla tempor nibh non ultrices vulputate. Morbi leo leo, bibendum ac tincidunt ac, elementum vel arcu. Donec id tempus velit. Nulla in rhoncus arcu. Nulla diam enim, commodo sed arcu sit amet, laoreet ullamcorper velit. Nullam convallis congue libero.

Donec sagittis in dui sit amet rhoncus. Maecenas fringilla condimentum elit, a suscipit lacus malesuada vitae. Phasellus molestie, mauris ac condimentum vestibulum, leo justo aliquet risus, eu ornare enim justo a est. In vehicula euismod iaculis. Donec et fringilla diam, dapibus accumsan purus. Praesent vitae auctor quam. Sed sollicitudin quam at ipsum posuere, et consectetur erat faucibus. Vivamus pulvinar ante id sapien fringilla pretium. Proin aliquam dolor elit, sed ultricies tortor cursus eget. Nullam hendrerit mattis libero sed dictum. Fusce eget condimentum dui. Nulla vel imperdiet dolor. Integer id elit a lorem condimentum tempus vel et sem. Maecenas quis nunc sit amet urna euismod tempus id ut turpis. Aenean ac ipsum sed augue auctor dictum. Ut sollicitudin felis leo, ut adipiscing arcu feugiat sit amet.

In consequat blandit nibh, vel tincidunt odio convallis vel. Suspendisse faucibus felis et justo aliquam semper. In mollis, lacus ut fringilla varius, diam augue semper nunc, vel venenatis dolor orci et risus. Ut fringilla massa metus, a posuere tortor iaculis vitae. Nulla pulvinar hendrerit ipsum, ut malesuada sem lacinia vel. Sed placerat purus arcu, id placerat felis rutrum et. Praesent dignissim a mi eget mattis. Nam iaculis magna adipiscing scelerisque vulputate. In consectetur turpis eget rutrum ullamcorper. Praesent sit amet nibh in enim fermentum pulvinar. Praesent bibendum tristique diam. Nam tortor ante, tincidunt vel congue in, bibendum sit amet tellus. Nunc tellus leo, tempor in justo sed, vulputate mattis orci. Nam porttitor lectus luctus venenatis consectetur. Aenean tempor, neque sed pretium commodo, diam est cursus felis, interdum sodales lorem nulla in lectus. Aenean viverra facilisis commodo.

Suspendisse auctor ut urna a adipiscing. Nunc nec ante non magna fermentum ornare commodo vel sem. Sed placerat tristique diam sit amet lacinia. Suspendisse potenti. Vestibulum a aliquet ipsum. Fusce id nulla ligula. Sed egestas ullamcorper neque at vulputate. Cras felis nisl, molestie malesuada sem vel, varius dictum orci. Praesent volutpat consequat quam, eu tincidunt ligula suscipit in. Cras ultrices tellus in orci scelerisque, ut condimentum ipsum consectetur.

Integer cursus tincidunt tortor vel aliquam. Pellentesque imperdiet vulputate dignissim. Suspendisse ultricies sollicitudin est, eu vulputate est dapibus at. Praesent pretium sem felis, tincidunt hendrerit tortor aliquam et. Donec aliquam orci eu gravida eleifend. Aliquam eleifend ultricies nulla non mattis. Quisque sit amet mollis magna, sit amet semper odio. Integer dui neque, faucibus eget mauris convallis, fermentum tincidunt urna.