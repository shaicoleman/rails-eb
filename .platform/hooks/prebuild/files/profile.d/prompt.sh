EB_ENV="$(/opt/elasticbeanstalk/bin/get-config container --key 'environment_name')"
EB_ENV_SHORT="${EB_ENV/rails-eb-/eb-}"
PS1="[\u@${EB_ENV_SHORT} \W]\\$ "
