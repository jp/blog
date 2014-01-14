---
title: Load testing a Facebook application
date: 2013-07-12
tags: load testing, Facebook, JMeter, Ruby on Rails
---

Creating hundreds of Facebook test users, creating random groups of test users, injecting them in JMeter and hammering the servers with them, that's what it is about.

READMORE

<center>
# Load testing a Facebook application
<sup>or how to destroy servers when developers are deploying</sup>
</center>

## Load testing tools - Weapons of mass destruction

Lot of people are using Selenium for his simplicity (record a behavior through
a proxy and replay it on a server).

But as we can see in the FAQ of this software : Selenium Grid is not designed for performance and load testing, but very efficient web acceptance/functional testing

Other easy options are the use of expensive paid services or DDOS software like LOIC.

Some services with free tests :

* [loadimpact.com](http://loadimpact.com)
* [blazemeter.com](http://blazemeter.com)

Most of the test services available can be really expensive while DDOS tools don't fit at all to a proper test plan.

The solution come from the Apache Software Foundation which is diffusing JMeter.

JMeter got the ability to test almost everything by creating very complex scenarii.

JMeter comes as a client/server application to easily enable distributed load testing. We can then launch tests from multiple instances properly configured to have extremely aggressive load tests.

[JMeter home page](http://jmeter.apache.org)

[JMeter user manual](http://jmeter.apache.org/usermanual/)

## Waves of "real" Facebook users

JMeter can imitate most of the behaviors of a normal browser but going through the authentication system of Facebook in an automated way is against the Terms&Conditions.

> You will not collect users' content or information, or otherwise access Facebook, using
> automated means (such as harvesting bots, robots, spiders, or scrapers) without our
> permission.

But Facebook have an API to automatically create and interact with test users. Can we assume that automated means are allowed with the test API ? ... Probably, but you might prefer to ask your lawyer before.

With this API you can :

* create fake users which can only interact with other test users on this app
* add existing test users to other apps
* make friend connections between the test users
* delete test users

## The forbidden scripting of the Facebook test API

Then I wrote some ruby scripts to manipulate this API. [The scripts are available on my Github account](https://github.com/jp/fb-ruby-script)

### App credential

Edit the app information with what you find in the FB dev interface for the app you want to load test. The scripts are made for a single app. The app credentials are stored in the file *fb_secret.rb*.
Just edit *APP_ID* and *APP_SECRET* to make them match to what should be inside.

### Test account generator

I used an account generator to create 500 test users (Facebook limit at this time).
Edit *fb\_account\_generator.rb* if you want to see if facebook gives more test users.
Note that RIG (Random Identity Generator) is used to generate the user names. Install with APT-GET or rig.sourceforge.net.
RIG is giving some nice generated identities which is much better than having user001 to user500.
Then run *fb\_account\_generator.rb* ... and wait.
Each created account is stored in an SQLite database with a model defined in lib.rb.


### Friend randomizer

We will need to test some processes involving friendships connections :

* know if a user is a friend of another user, then give him the right to access certain information
* get the list of all the user's friends who already have an account in the app

For each test user, the script randomize_friends.rb creates 10 to 100connections with other test users.

### CSV export

For an easy use of those accounts with JMeter, we need to export those
information in CSV, especially each access\_token.
The script read.rb output is formatted like this : "fb\_user\_id,access\_token"
Just save the output of read.rb as a CSV, this will be an efficient input for
JMeter.

### Freshen-up your data !!

The *access_token* is expiring like the *login_url* : regularly, after a badly
documented delay (1 or 2 hours depending on the line of the fb doc).
We can anyway refresh the tokens using the listing of all the test users
associated to the application. The refresh.rb script is there to do the job.

## Cheat a little – Hack your own code

You probably use some clean authentication system between your app and Facebook using auth cookies or signed requests but this is not going to fit properly with JMeter :

* JMeter can't execute JavaScript then can't get cookies from FB JS
SDK
* There is no reason to load test through Facebook canvas (forbidden & useless) and then to receiving the signed_request.

The solution is to create another authentication system, bypassing the other ones, by giving the access\_token as a GET parameter in the URL of each authenticated request during the load test.
This tweak can be a security issue as an access\_token can be used by anyone on any app : if someone get an access\_token from another app, he can use it to be identified on this application.

## JMeter – Strategy of the attack

This is the time to learn how to create a test plan with JMeter. See the JMeter doc here 
[Build test plan](http://jmeter.apache.org/usermanual/build-web-test-plan.html)
and this very complete blog post 
[Using JMeter](http://www.roseindia.net/jmeter/using-jmeter.shtml)

Now that you know almost everything about JMeter from the two previous links, let see how to use the CSV full of tokens.

We got a CSV file, full of fresh tokens, looking like that :

```
100003826346593,AAAE1TlpWcPkBANHTqUd4Jwd0z1kU...
100003813266408,AAAE1TlpWcPkBABTwp7JjJADmy3rZ...
100003840542108,AAAE1TlpWcPkBAMGTz5M6oAjSfBrV...
100003847922053,AAAE1TlpWcPkBACYysOavJhVaivqI...
100003837542073,AAAE1TlpWcPkBANBxwVOMYDPB3eZA...
100003812666280,AAAE1TlpWcPkBABBhtteoBZBUZC1c...
100003796676235,AAAE1TlpWcPkBAAZBCKNbReKTUe9k...
100003803036277,AAAE1TlpWcPkBADbOFDZBZCbXQ4Ik...
```

In JMeter, right click on the Thread Group and go to Add > Config Element > CSV Data Set Config.
We now got the following screen to setup the use of the CSV file for each
call in the Thread Group.

We got in this screen :

* filename : the absolute path of the CSV file that you are going to have
on each slave (to be explained a bit later)
* variables names : the name of the variables which are going to hold
the content of the CSV columns (here : fbid and token)

Resulting of this operation, we will have to variable set up on each HTTP
request made by JMeter : fbid and token.

At each new iteration of the test plan, the information from a new line will
be used.

![JMeter conf](images/fb_load_test/image00.png)

One of the request of the test plan will look like that:

![JMeter request](images/fb_load_test/image01.png)

In short : GET
https://my-so-much-awesome-website.com/friends.json?token=${token}
This test plan was pretty simple, based on GET and POST on 4 resources.
That was quite a complete test of the API : all the static assets were served
by a CDN.

## JMeter – An army of slaves

The JMeter FAQ recommends :

> the JMeter server to be reasonably close (network wise) to the
application server. By "reasonably close" I mean on the same Ethernet
segment or at least with no low speed links between them. The JMeter
User Manual provides reasonable information about doing this.

The Distributed testing manual Limitation :

> RMI cannot communicate across subnets without a proxy; therefore
neither can jmeter without a proxy.

Being in New Zealand and the servers at RackSpace or AWS anywhere around
the world does not match. No choice : we need to run JMeter from the same
type of cloud instance.

The FAQ also say that we shouldn't run JMeter on the target server, idea
which is obviously bad... especially after seeing the JMeter server swapping
after few minutes of test.

If this is quite easy to have a distant (any cloud server) JMeter slave
managed by a Master GUI in local (Resn network) through a SSH tunnel, it
starts to be complicated to have more than one slaves.

I considered running fully master and slaves on RackSpace network after
struggling a while.

In consequence of the firsts tries, we raised 1 master and 3 slaves, Ubuntu
servers - 1Gb of mem, on RackSpace Network to stress 3 load-balanced rails
servers, Centos - 2Gb of Mem.


## JMeter – Setup your slaves

The first step is to allow all the traffic between the master and the slaves.
JMeter is using multiple ports, one of them is randomized by default (it can
be fixed in JMeter conf).
For each slave's IP on the master and for the master's IP on each slave :

```
iptables -A INPUT -i <iface> -s <IP> -j ACCEPT
```

On RackSpace, iface was eth1 and the IPs were the eth1 IP of the slaves&master

Then we need to setup JMeter server properly because of the use of multiple
network interfaces in RackSpace instances.

Edit `/usr/share/jmeter/bin/jmeter.properties` and add :

```
server.rmi.localhostname=<eth1 IP> # internal iface
httpclient.localaddress=<eth0 IP> # external iface
```

Then we need to upload the CSV full of fresh token on each JMeter server.
This have to be done each time the tokens starts expiring ... which is quite
often so think about automating the deployment of the tokens file in a little
script.
My choice was to add the master public key in the .ssh/authorized_keys on
each slave and then executing this script before each test :

```
./read.rb > tokens.csv
scp tokens@slave1:/root/
scp tokens@slave2:/root/
scp tokens@slave3:/root/
```

When your test plan is done in the GUI you then need to save and upload it
to the JMeter master and launch the attack :

```
jmeter -n -t TEST_PLAN.jmx -R <slave1>,<slave2>,<slave3>
```

## NewRelic monitoring – Code optimization

JMeter offers different way to analyze the results of the test (tables, logs,
graphs). Most of them are hard to read and this is complicated to get
relevant and important information.
The following graph indicated properly how the load is raising against the
web server, but this kind of information is not fine enough to enable
debugging and optimization

![JMeter results](images/fb_load_test/image02.png)

To have more granularity analyzing the results of the test, we are going to
user NewRelic which is one of the best way to monitor apps and servers.
You can see in the following picture three consecutive tests, with only one
web server as target.
The first one is pretty slow (~300 Request per minute), and we can see in
the “slow transactions” multiple entries with HomeController#data.
After a quick check in this method, I replaced an horrible User.all.lenght by
User.count.
One commit and redeploy later, the server is now around 550rpm.

![New Relic graph](images/fb_load_test/image03.png)

## NewRelic monitoring – Apache optimization

We can see on the precious graph a spike in the response time at the start
of each new test. This spike is due to Apache which is taking some time to
create all the necessary processes to handle the flow of users.
This issue was solved after the following series of tests :

### Test architecture
4 JMeter slaves in RackSpace network
4 requests at each iteration of each test (index / data.json / friends.json /
upload.json)

### Initial test
3 Rails servers behind load balancer = 1650rpm
2 Rails servers behind load balancer = 1100rpm

### Conclusion
With the initial configuration, each server is handling 550rpm.

Adding a new identical server to the load balancer will improve the capacity by the same amount.

### Optimisation
Multiple tests were then performed and the apache configuration was slowly tweaked, in particular the number of Apache processes on the server.

In the initial test, the minumum number of apache processes was equal to the maximum number of apache processes, which is a good practice for dedicated web servers.

This was done by setting MaxClients to 710.

We calculated the optimum value for this by using this calculation and then
running a few more tests :

MaxClients = (Memory size – other processes mem use) / single httpd process mem size.

At the end of the tests, the optimal value for a 2GB instance was MaxClients
= 950.

### Final test
3 Rails servers behind load balancer = 2500rpm

2 Rails servers behind load balancer = 1650rpm

### Conclusion
The optimisation has enabled Apache to run more processes on each
instance and therefore us to handle more requests per minute – awesome!

###Keep Alive
We also tested tweaking the KeepAlive directive. The KeepAlive directive
allows Apache to keep open the socket between the client and the server.

In the last test, KeepAlive deactivated, servers handling 2500 rpm, other users timeout most
of the time.

KeepAlive activated, servers handling 2500rpm, other users working properly.
We will now run the servers with KeepAlive activated.

## And so what ?

THe important points I learn during this job :

* ability to repeat the exact same test as much as necessary
* change one and only one thing between two test
* optimize the number of Apache process for the memory available
* keep connections alive if each user must connect more than once
* load test / identify bottleneck / solve / start again

Result :

Load test helped to identify several issues and the average throughput available went from 300rpm
to 850rpm.
