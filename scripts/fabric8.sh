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
if [ -z $PROJECT_NAME ]; then
	echo "PROJECT_NAME has not been set, something is wrong with the pod"
	exit 1
fi
if [ -n $MAVEN_LOCAL_REPO ]; then
echo 'io.fabric8.maven.localRepository = '${MAVEN_LOCAL_REPO} >> ./fabric/import/fabric/profiles/default.profile/io.fabric8.maven.properties
fi

echo "Starting Fuse"
./bin/fuse $START_ARG & process=$!
sleep 60

if [ "$FABRIC_ORIGINAL_MASTER" == "true" ]; then
	if [ -z $FABRIC_SERVER_BASE_CONTAINER_NAME ]; then
		echo "FABRIC_SERVER_BASE_CONTAINER_NAME has not been set, something is wrong with the pod"
		exit 1
	fi
	if [ -z $FABRIC_SIZE ]; then
		echo "FABRIC_SIZE has not been set, something is wrong with the pod"
		exit 1
	fi
	count=0
	while :
	do
		echo "Master Client Check"
		./bin/client "version"; return=$?
		if [ $return -eq 0 ]; then
			sleep 15
			./bin/client "fabric:create --wait-for-provisioning --verbose --clean --bootstrap-timeout 240000 --new-user ${FABRIC_USER} --new-user-role ${FABRIC_ROLE} --new-user-password ${FABRIC_PASSWD} --zookeeper-password ${ZK_PASSWD} --resolver manualip --manual-ip ${FABRIC_ENSEMBLE_CONTAINER_NAME}.${PROJECT_NAME}.svc.cluster.local"
			break
		else
			sleep 5
			(( count++ ))
			echo "Failed to get client session " $count " times."
			if [ $count == 60 ]; then
				echo "Failed to get a client session after 5 minutes, fabric create exiting on " $HOSTNAME
				exit 1
			fi
		fi
	done
	echo "Finished Fabric Creation"
	count=0
	while :
	do
	echo "Starting Ensemble Add"
	ENSEMBLE_STRING=
	aliveServers=`curl -u ${FABRIC_USER}:${FABRIC_PASSWD} -s 'http://'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'.'${PROJECT_NAME}'.svc.cluster.local:8181/jolokia/exec/io.fabric8:type=ZooKeeper/read/!/fabric!/registry!/containers!/alive'`
	echo "Alive Server are " $aliveServers
	if [[ "$aliveServers" =~ "children" ]]; then
servers=($(echo $aliveServers | python -c 'import json,sys,re,os
obj=json.load(sys.stdin)
srvs=""
for c in obj["value"]["children"]:
	srvs += str(c)+" "
print srvs
	'))
	fi

	if [ ${#servers[@]} -eq $FABRIC_SIZE ]; then
		for server in ${servers[@]}
		do

		if [ "$server" ]; then
			alive=`curl -u ${FABRIC_USER}:${FABRIC_PASSWD} -s 'http://'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'.'${PROJECT_NAME}'.svc.cluster.local:8181/jolokia/exec/io.fabric8:type=ZooKeeper/read/!/fabric!/registry!/containers!/alive!/'${server}''`

			if [[ "$alive" =~ "children" ]]; then
				provCurl=`curl -u ${FABRIC_USER}:${FABRIC_PASSWD} -s 'http://'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'.'${PROJECT_NAME}'.svc.cluster.local:8181/jolokia/exec/io.fabric8:type=ZooKeeper/read/!/fabric!/registry!/containers!/provision!/'${server}'!/result'`
				if [[ "$provCurl" =~ "children" ]]; then
					provStatus=`echo $provCurl | python -c "import json,sys;obj=json.load(sys.stdin);print obj['value']['stringData'];"`
					echo "Provisioning Status is " $provStatus
					if [ "$provStatus" == "success" ]; then
						ENSEMBLE_READY="true"
						if [[ "$server" =~ "${FABRIC_SERVER_BASE_CONTAINER_NAME}" ]]; then
							ENSEMBLE_ADD="false"
						else
							ENSEMBLE_ADD="true"
						fi
						if [ "$server" != "${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}" ] && [ "$ENSEMBLE_ADD" == "true" ]; then
							ENSEMBLE_STRING="$ENSEMBLE_STRING $server"
						fi
					else
						ENSEMBLE_READY="false"
						break
					fi
				else
					ENSEMBLE_READY="false"
					break
				fi
			else 
				echo "A node is not alive " ${s}
				ENSEMBLE_READY="false"
				break
			fi
		else
			ENSEMBLE_READY="false"
			break
		fi
		done
	else
		ENSEMBLE_READY="false"
	fi

	if [ "$ENSEMBLE_READY" == "true" ]; then
		if [ -z "$ENSEMBLE_STRING" ]; then
			echo "Ensemble is ready, but only has 1 node.  Do not need to run ensemble-add"
			break
		fi
		echo "Creating ensemble from string " $ENSEMBLE_STRING
		./bin/client "fabric:ensemble-add -f $ENSEMBLE_STRING"
		break
	else
		sleep 20
		(( count++ ))
		if [ $count == 60 ]; then
			echo "All Ensemble Servers Have Not Become Ready within 20 minutes, exiting"
			exit 1
		fi
	fi
	done
	wait $process
elif [ "$FABRIC_ORIGINAL_MASTER" == "false" ]; then
	count=0
	while :
	do
		echo "Ensemble Master Check"
		provCurl=`curl -u ${FABRIC_USER}:${FABRIC_PASSWD} -s 'http://'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'.'${PROJECT_NAME}'.svc.cluster.local:8181/jolokia/exec/io.fabric8:type=ZooKeeper/read/!/fabric!/registry!/containers!/provision!/'${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}'!/result'` 
		if [[ "$provCurl" =~ "children" ]]; then 
			provStatus=`echo $provCurl | python -c "import json,sys;obj=json.load(sys.stdin);print obj['value']['stringData'];"`
			echo "Provisioning Status is " $provStatus
		else
			provStatus=notset
		fi
		if [ "$provStatus" == "success" ]; then
			./bin/client "version"; return=$?
			if [ $return -eq 0 ]; then
				sleep 15
				./bin/client "fabric:join --zookeeper-password ${ZK_PASSWD} --resolver manualip --manual-ip ${FABRIC_ENSEMBLE_CONTAINER_NAME}.${PROJECT_NAME}.svc.cluster.local ${FABRIC_ENSEMBLE_ROOT_CONTAINER_NAME}.${PROJECT_NAME}.svc.cluster.local:2181"
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
			sleep 20
			(( count++ ))
			if [ $count == 60 ]; then
				echo "Failed to get a valid fabric health check after 20 minutes, fabric join exiting on " $HOSTNAME
				exit 1
			fi
		fi
	done
	wait $process
else
	echo "Something is wrong, FABRIC_ORIGINAL_MASTER can only be true or false"
fi
