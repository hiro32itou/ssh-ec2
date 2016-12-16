#!/bin/bash

# Environment settings
SSH_COMMAND="ssh"
DEFAULT_SSH_KEY_DIR="~/.ssh"
DEFAULT_SSH_USER="ec2-user"
DEFAULT_SSH_PORT="22"
DESCRIBE_COMMAND=$(cat << _EOL_
aws ec2
  --output text
    describe-instances
  --query
    'sort_by(Reservations[].Instances[].{InstanceId:InstanceId,Tags:Tags[?Key==\`Name\`].Value|[0],InstanceType:InstanceType,State:State.Name,Ip:PublicIpAddress,Key:KeyName},&Tags)'
  --filter
    'Name=instance-state-name,Values=running'
_EOL_
)

# Show usage function
usage_exit() {
  cat << _EOL_ > /dev/stdout
[1;39mUsage:[0;39m 
  $0 [-u user_name] [-p port_number] [-k key_installed_path]
[1;39mEx.:[0;39m
  [1;34m# Don't set arguments[0;39m
  $0
  [1;34m# Set 'user_name' argument[0;39m
  $0 -u hoge
  [1;34m# Set 'port_number' argument[0;39m
  $0 -p 22022
  [1;34m# Set 'key_installed_path' argument[0;39m
  $0 -k `pwd`/.ssh
  [1;34m# Set 'user_name' & 'key_installed_path' arguments[0;39m
  $0 -u hoge -k `pwd`/.ssh
  [1;34m# Set all arguments[0;39m
  $0 -u hoge -p 22022 -k `pwd`/keys
_EOL_
  exit 1
}

# Check default environments
[ ! -n "${SSH_USER}" ]    && SSH_USER=${DEFAULT_SSH_USER}
[ ! -n "${SSH_PORT}" ]    && SSH_PORT=${DEFAULT_SSH_PORT}
[ ! -n "${SSH_KEY_DIR}" ] && SSH_KEY_DIR=${DEFAULT_SSH_KEY_DIR}

# Check arguments
while getopts u:p:k:h OPT
do
  case $OPT in
    u)  SSH_USER=${OPTARG}
        ;;
    p)  SSH_PORT=${OPTARG}
        ;;
    k)  SSH_KEY_DIR=${OPTARG}
        ;;
    h)  usage_exit
        ;;
    \?) usage_exit
        ;;
  esac
done
shift $((OPTIND - 1))

expr "${SSH_PORT}" + 1 >/dev/null 2>&1
if [ $? -lt 2 ]; then
  if [ ${SSH_PORT} -le 0 ]; then
    echo -e "\033[4;31m[Error] port_number range error. (port_number: [1 - 65535])\033[0;39m"
    usage_exit
  fi
else
  echo -e "\033[4;31m[Error] port_number not 'Numeric'.\033[0;39m"
  usage_exit
fi

# Declare internal environments
IP=()
KEY=()
COUNT=1
IFS=$'\n'
SSH_EXEC_CMD=""

# Get EC2 instances
SERVER_LIST=$(eval ${DESCRIBE_COMMAND})

# Create server list
for line in ${SERVER_LIST}; do
  IFS=$'\t'
  set -- ${line}
  IP=("${IP[@]}" $3)
  KEY=("${KEY[@]}" $4)
  LIST=${LIST}"${COUNT}: $6 $3 $5 $1 $2\n"
  (( COUNT++ ))
done
RET=$(echo -e "${LIST}" | column -t -s " ")

# Show server list
if type peco > /dev/null 2>&1 ; then
  SELECTED="$(echo ${RET} | peco)"
  IFS=$':'
  set -- ${SELECTED}
  ITEM=$1
else
  echo ${RET}
  echo -n "number? : "
  read ITEM
fi

# Assemble command
if expr "${ITEM}" : '[0-9]*' > /dev/null ; then
  if [ 1 -le "${ITEM}" -a "${ITEM}" -le ${COUNT} ]; then
    (( ITEM-- ))
    SSH_EXEC_CMD="${SSH_COMMAND} -i ${SSH_KEY_DIR}/${KEY[${ITEM}]}.pem ${SSH_USER}@${IP[${ITEM}]} -p ${SSH_PORT}"
#    SSH_EXEC_CMD="${SSH_EXEC_CMD} -p ${SSH_PORT}"
  fi
fi

# Execute ssh command
[ -n "${SSH_EXEC_CMD}" ] && echo -e "\033[4;33m${SSH_EXEC_CMD}\033[0;39m" && eval ${SSH_EXEC_CMD}
