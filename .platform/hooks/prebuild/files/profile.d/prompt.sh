eb_env="$(/opt/elasticbeanstalk/bin/get-config container --key 'environment_name')"
instance_id="$(ec2-metadata --instance-id | grep -oP 'instance-id: \K(i-.*)')"
short_eb_env="${eb_env/rails-eb-/eb-}"
short_instance_id="${instance_id:2:4}"
PS1="[\u@${short_eb_env}-${short_instance_id} \w]\\$ "
