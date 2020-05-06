#! /bin/bash

instances() {
	aws ec2 describe-instances --filters "Name=tag:product,Values=cloud-native" \
					     "Name=tag:environment,Values=cicd" \
		--query "Reservations[].Instances[?LaunchTime>='$(date --date='-2 hours' '+%Y-%m-%dT%H:%M')'].InstanceId" \
		--output text
}

instances="$(instances)"
echo "Found the following instances to cleanup: $instances"

for instance in $instances; do
	# Note we don't filter out terminated instances, so the above command can fail
	echo "Deleting instance: $instance"
	aws ec2 terminate-instance "$instance" || true
done
