The project  dit029-twitter-miner inputs api stream from twitter into riak node. It takes sample API and parses it so the hashtags become keys, and retweet_count, favorite_count and language become values then inputs using riakc into riak nodes. 

The project twitter-miner-for-counting inputs api stream from twitter into riak node. It takes sample API and parses it so there is a unique tweet id as key and tag as value.This also inputs data into riak node using riakc. 

For both projects the bucket names are the dates that the code will be running. i.e. everyday the application will run twice, inputing data in the days bucket. 

twitterminer.config wich holds secret keys for the twitter account. It also requires the riak node and public port. 

