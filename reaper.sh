#!/bin/bash
# this script removes any manager instances which have been terminated
# but no message was recieved on the lifecycle queue. This is to keep the quorm
# in a good state.
echo "reaper: Removing terminated instances which are unhealthy in the swarm"

export REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Get the node ids of the unavailable managers
DOWN_LIST=$(docker node inspect $(docker node ls --filter role=manager -q) | jq -r '.[] | select(.ManagerStatus.Reachability != "reachable") | .ID')

# there are no nodes down, exit now.
if [ -z "$DOWN_LIST" ]; then
    exit 0
fi

echo "reaper: Found some nodes that are unreachable. DOWN_LIST=$DOWN_LIST"

for NODE_ID in $DOWN_LIST; do

  INSTANCE_STATE=$(aws ec2 describe-instances --filters "Name=tag:node-id,Values=$NODE_ID" --region $REGION | jq -r ".Reservations[] | .Instances[] | .State.Name")
  if [[ "$INSTANCE_STATE" == "" ]] || [[ "$INSTANCE_STATE" == "terminated" ]]; then
    echo "reaper: Node $NODE_ID has a status of '"$INSTANCE_STATE"', remove it"
    docker node demote $NODE_ID
    docker node update --availability drain $NODE_ID
    docker node rm $NODE_ID
    echo "$NODE_ID should be removed now"
  else
      echo "reaper: Node $NODE_ID has status of '"$INSTANCE_STATE"', don't remove"
  fi
done
echo "reaper: Done"
