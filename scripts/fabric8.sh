#!/bin/bash

#set -e

if [ -z $FABRIC_ORIGINAL_MASTER ]; then
	echo "FABRIC_ORIGINAL_MASTER has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME ]; then
	echo "FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_ENSEMBLE_CONTAINER_NAME ]; then
	echo "FABRIC_ENSEMBLE_CONTAINER_NAME has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_START_ARG ]; then
	echo "FABRIC_START_ARG has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_JOINED ]; then
	echo "FABRIC_JOINED has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_USER ]; then
	echo "FABRIC_USER has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_PASSWD ]; then
	echo "FABRIC_PASSWD has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $FABRIC_ROLE ]; then
	echo "FABRIC_ROLE has not been set, something is wrong with the pod"
	exit 1
fi
if [ -z $ZK_PASSWD ]; then
	echo "ZK_PASSWD has not been set, something is wrong with the pod"
	exit 1
fi

echo "Starting Fuse"
nohup ./bin/fuse $START_ARG & process=$!
echo "Sleeping 60"
sleep 60

if [ "$FABRIC_ORIGINAL_MASTER" == "true" ] && [ "$FABRIC_JOINED" == "false" ]; then
	count=0
	while :
	do
		echo "Master Client Check"
		./bin/client "version"; return=$?
		echo "Process Return " $return
		if [ $return -eq 0 ]; then
			sleep 15
			./bin/client "fabric:create --wait-for-provisioning --verbose --clean --new-user mrobson --new-user-role admin --new-user-password password --zookeeper-password passwd --resolver manualip --manual-ip ${FABRIC_ENSEMBLE_CONTAINER_NAME}.default.endpoints.cluster.local" &
			export FABRIC_JOINED=true
			break
		else
			sleep 5
			(( count++ ))
			echo "Failures at " $count
			if [ $count == 60 ]; then
				echo "Failed to get a client session after 5 minutes, fabric join exiting on " $HOSTNAME
				exit 1
			fi
		fi
	done
	wait $process
elif [ "$FABRIC_ORIGINAL_MASTER" == "false" ] && [ "$FABRIC_JOINED" == "false" ]; then
	count=0
	while :
	do
		echo "Ensemble Master Check"
		curl=`curl -u ${FABRIC_USER}:${FABRIC_PASSWD} -s 'http://'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'.default.endpoints.cluster.local:8181/jolokia/exec/io.fabric8:type=ZooKeeper/read/!/fabric!/registry!/containers!/alive'`
		echo "Alive CURL " $curl
		if [ -z "$curl" ]; then
			echo ""
		else
rootEns=`echo $curl | python -c 'import json,sys,re,os
obj=json.load(sys.stdin)
for c in obj["value"]["children"]:
		if re.match(os.environ["FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME"], c):
					print c
					'`
			echo "Root Ensemble is " $rootEns
			provStatus=`curl -u ${FABRIC_USER}:${FABRIC_PASSWD} -s 'http://'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'.default.endpoints.cluster.local:8181/jolokia/exec/io.fabric8:type=ZooKeeper/read/!/fabric!/registry!/containers!/provision!/'$rootEns'!/result' | python -c "import json,sys;obj=json.load(sys.stdin);print obj['value']['stringData'];"`
			echo "Provisioning Status is " $provStatus
		fi
		if [ "$provStatus" == "success" ]; then
			./bin/client "version"; return=$?
			if [ $return -eq 0 ]; then
				sleep 15
				./bin/client "fabric:join --zookeeper-password passwd --resolver manualip --manual-ip ${FABRIC_ENSEMBLE_CONTAINER_NAME}.default.endpoints.cluster.local ${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}.default.endpoints.cluster.local:2181" &
				export FABRIC_JOINED=true
				break
			else
				sleep 5
				(( count++ ))
				if [ $count == 60 ]; then
					echo "Failed to get a client session after 5 minutes, fabric join exiting on " $HOSTNAME
					exit 1
				fi
			fi
		else
			sleep 10
			(( count++ ))
			if [ $count == 60 ]; then
				echo "Failed to get a valid fabric health check after 10 minutes, fabric join exiting on " $HOSTNAME
				exit 1
			fi
		fi
	done
	wait $process
else
	echo "Something is wrong, FABRIC_ORIGINAL_MASTER can only be true or false"
fi
