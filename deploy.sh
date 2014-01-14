middleman build
cd build
aws s3 cp --recursive . s3://blog.julienpellet.com/ --region us-east-1 --acl public-read
