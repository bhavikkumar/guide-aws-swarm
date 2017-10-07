#!/bin/bash
# this script refreshes the swarm primary manager in dynamodb if it has changed.
# This comes from Docker for AWS
echo "refresh_leader: Running..."
export PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
export REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

IS_LEADER=$(docker node inspect self -f '{{ .ManagerStatus.Leader }}')

if [[ "$IS_LEADER" == "true" ]]; then
    # we are the leader, we only need to call once, so we only call from the current leader.
    CURRENT_MANAGER_IP=$(aws dynamodb get-item --region $REGION --table-name $DYNAMODB_TABLE --key '{"id":{"S": "primary_manager"}}' | jq -r '.Item.value.S')

    if [[ "$CURRENT_MANAGER_IP" != "$PRIVATE_IP" ]]; then
        echo "refreash_leader: Primary Manager has changed, updating dynamodb with new IP From $CURRENT_MANAGER_IP to $PRIVATE_IP"
        aws dynamodb put-item \
            --table-name $DYNAMODB_TABLE \
            --region $REGION \
            --item '{"id":{"S": "primary_manager"},"value": {"S":"'"$PRIVATE_IP"'"}}'

        # Just in case the join tokens have been rotated, we update them as well.
        MANAGER_TOKEN=$(docker swarm join-token manager | grep token | awk '{ print $2 }')
        WORKER_TOKEN=$(docker swarm join-token worker | grep token | awk '{ print $2 }')

        aws dynamodb put-item \
            --table-name $DYNAMODB_TABLE \
            --region $REGION \
            --item '{"id":{"S": "manager_join_token"},"value": {"S":"'"$MANAGER_TOKEN"'"}}'

        aws dynamodb put-item \
            --table-name $DYNAMODB_TABLE \
            --region $REGION \
            --item '{"id":{"S": "worker_join_token"},"value": {"S":"'"$WORKER_TOKEN"'"}}'
    else
      echo "refresh_leader: Primary manager ($CURRENT_MANAGER_IP) has not changed."
    fi
fi
echo "refresh_leader: Done"
