# guide-aws-swarm
Docker swarm mode container which ensures dynamodb is up to date with the correct leader and also listens to termination lifecycle events.
This is based on docker4x/guide-aws which is used by Docker for AWS.

## Usage
On each swarm node run the following to ensure the swarm is always in a known state.
```
docker run -d --restart=always -e DYNAMODB_TABLE=$DYNAMODB_TABLE -e LIFECYCLE_QUEUE=$LIFECYCLE_QUEUE -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker depost/guide-aws-swarm
```
