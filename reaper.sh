#!/bin/bash
# this script removes any instances which have been terminated but no message was recieved on the lifecycle queue.
echo "reaper: Removing terminated instances which are unhealthy in the swarm"
