#!/bin/bash
# this script listens for termination events on the queue and gracefully removes
# managers and workers from the swarm.
export REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Read the messages from the termination lifecycle hook SQS queue.
MESSAGES=$(aws sqs receive-message --region $REGION --queue-url $LIFECYCLE_QUEUE --max-number-of-messages 10 --wait-time-seconds 10 )
COUNT=$(echo $MESSAGES | jq -r '.Messages | length')

# default to 0, if empty
COUNT="${COUNT:-0}"

for((i=0;i<$COUNT;i++)); do
  BODY=$(echo $MESSAGES | jq -r '.Messages['${i}'].Body')
  RECEIPT=$(echo $MESSAGES | jq --raw-output '.Messages['${i}'] .ReceiptHandle')
  LIFECYCLE=$(echo $BODY | jq --raw-output '.LifecycleTransition')
  INSTANCE=$(echo $BODY | jq --raw-output '.EC2InstanceId')

  # If it is a termination message we will handle it.
  if [[ $LIFECYCLE == 'autoscaling:EC2_INSTANCE_TERMINATING' ]]; then
        echo "Found a shutdown event for $INSTANCE"
        TOKEN=$(echo $BODY | jq --raw-output '.LifecycleActionToken')
        HOOK=$(echo $BODY | jq --raw-output '.LifecycleHookName')
        ASG=$(echo $BODY | jq --raw-output '.AutoScalingGroupName')

        $NODE_COUNT=$(docker node ls | wc -l | awk '{print $1-1}')
        if [[ $NODE_COUNT -gt 1]]; then
          # Get the node id and type from its tag
          NODE_ID=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE" "Name=key,Values=node-id" --region $REGION --output=json | jq -r .Tags[0].Value)
          NODE_TYPE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=swarm-node-type" --region $REGION --output=json | jq -r .Tags[0].Value)

          echo "Removing $NODE_ID which is a $NODE_TYPE from the swarm"
          if [ "$NODE_TYPE" == "manager" ] ; then
            docker node demote $NODE_ID
          fi
          docker node rm $NODE_ID
          echo "Removed $NODE_ID from the swarm"
        else
          # We are the last node in the cluster so we force remove ourselves.
          echo "This is the last node in the cluster, leaving the swarm"
          docker swarm leave --force
          # We need to remove the entries from dynamodb in this case since this could be a scale down to 0 event.
          echo "Cleaning up DynamoDB entries as there are no more nodes in the swarm"
          aws dynamodb delete-item \
              --table-name $DYNAMODB_TABLE \
              --region $REGION \
              --key '{"id":{"S": "primary_manager"}}'

          aws dynamodb delete-item \
              --table-name $DYNAMODB_TABLE \
              --region $REGION \
              --key '{"id":{"S": "manager_join_token"}}'

          aws dynamodb delete-item \
              --table-name $DYNAMODB_TABLE \
              --region $REGION \
              --key '{"id":{"S": "worker_join_token"}}'
          echo "Done cleaning up the DynamoDB table"
        fi

        echo "Delete the record from SQS"
        aws sqs delete-message --region $REGION --queue-url $QUEUE --receipt-handle $RECEIPT
        echo "Finished deleting the sqs record."

        # let autoscaler know it can continue with the termination.
        echo "Notifying autoscaling that it can continue"
        aws autoscaling complete-lifecycle-action --region $REGION --lifecycle-action-token $TOKEN --lifecycle-hook-name $HOOK --auto-scaling-group-name $ASG --lifecycle-action-result CONTINUE

        echo "Finished handling of instance termination"
  elif [[ $LIFECYCLE != 'autoscaling:EC2_INSTANCE_TERMINATING' ]]; then
      # There is a testing message on the queue at start we don't need, remove it, so it doesn't clog queue in future.
      echo "Message $LIFECYCLE isn't one we care about, remove it."
      aws sqs delete-message --region $REGION --queue-url $QUEUE --receipt-handle $RECEIPT
  fi
done
