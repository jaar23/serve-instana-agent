#!/bin/bash

# exit on error
set -e

############################################################
# Colorize echo                                            #
############################################################
BLUE="\033[0;34m"
NC="\033[0m" # No Color
GREEN="\033[0;32m"
RED="\033[0;31m"

############################################################
# Environment Variables                                    #
############################################################
INSTANA_AGENT_KEY=
INSTANA_DOWNLOAD_KEY=
INSTANA_AGENT_HOST=
INSTANA_AGENT_PORT=1444
INSTANA_AGENT_RELEASE=
INSTANA_PACKAGE=static
MINISERVE_HOST=116.86.78.183
MINISERVE_PORT=8080
MINISERVE_USERNAME=user
MINISERVE_PASSWORD=password
PROC_TYPE=$(uname -p)
INSTANA_AGENT_ZONE="Linux Server Zone"

############################################################
# Program Variables                                        #
############################################################
exit_flag=0
verbose=0
sudo_privileges=0
user_group=$(getent group wheel)
if [ -z $user_group ]; then
  user_group=$(getent group sudo)
fi

############################################################
# Help                                                     #
############################################################
help() {
  # Display Help
  echo "Setup Instana Agent using automated script."
  echo
  echo "Syntax: setup-airgap.sh [--agentkey | --host | --port | --downloadkey | --zone | --verbose]"
  echo
  echo "options:"
  echo "-h --help         Print this Help."
  echo "-v --verbose      Verbose mode."
  echo "--agentkey        Set Instana Agent Key."
  echo "--downloadkey     Set Instana Download Key."
  echo "--host            Set Instana Backend ip address or hostname. "
  echo "--port            Set Instana Backend port, default 1444 "
  echo "--zone            Set Instana Agent manage to zone. "
  echo
}

print_env() {
  echo "Using Environment Variables to setup Instana Agent"
  echo
  echo "Instana Backend       : $INSTANA_AGENT_HOST:$INSTANA_AGENT_PORT"
  echo "Instana Agent Key     : $INSTANA_AGENT_KEY"
  echo "Instana Download Key  : $INSTANA_DOWNLOAD_KEY"
  echo "Processor Type        : $PROC_TYPE"
  echo "File Server Host      : $MINISERVE_HOST:$MINISERVE_PORT"
  echo "Miniserve Username    : $MINISERVE_USERNAME"
  echo "Miniserve Password    : $MINISERVE_PASSWORD"
  echo
}

service_exists() {
  local n=$1
  if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
    return 0
  else
    return 1
  fi
}

check_sudo() {
  if [ -n "$user_group" ]; then
    echo -e "${BLUE}[INFO]${NC} User has sudo privileges"
    sudo_privileges=1
  else
    echo -e "${BLUE}[INFO]${NC} User do not have sudo privileges, re-run again with sudo."
    sudo_privileges=0
    exit
  fi
}

prereq_check() {
  if service_exists instana-agent; then
    echo -e "${BLUE}[INFO]${NC} Skip setup due to instana agent is already exist."
  fi

  if [ -z "$INSTANA_AGENT_HOST" ]; then
    echo -e "${RED}[ERROR]${NC} Instana Backend is not set, re-run again with --host. "
    exit_flag=1
  fi

  if [ -z "$INSTANA_AGENT_KEY" ]; then
    echo -e "${RED}[ERROR]${NC} Instana Agent Key is not set, re-run again with --agentkey. "
    exit_flag=1
  fi

  if [ -z "$INSTANA_DOWNLOAD_KEY" ] && [ -n "$INSTANA_AGENT_KEY" ]; then
    echo -e "${BLUE}[INFO]${NC} Instana Download Key is not set, using the same value with Instana Agent Key."
    INSTANA_DOWNLOAD_KEY=$INSTANA_AGENT_KEY
  fi

  if [ -z "$INSTANA_DOWNLOAD_KEY" ] && [ -z "$INSTANA_AGENT_KEY" ]; then
    echo -e "${RED}[ERROR]${NC} Instana Download Key and Instana Agent Key are not set, re-run again with --agentkey and --downloadkey"
    exit_flag=1
  fi

  check_sudo
}

set_environment() {
  sudo cat <<EOF >>/etc/systemd/system/instana-agent.service.d/10-environment.conf
[Service]
Environment=INSTANA_KEY=$INSTANA_AGENT_KEY
Environment=INSTANA_HOST=$INSTANA_AGENT_HOST
Environment=INSTANA_PORT=$INSTANA_AGENT_PORT
EOF

  if [ "$verbose" -eq 1 ]; then
    echo -e "${BLUE}[INFO]${NC} systemd is set"
    cat /etc/systemd/system/instana-agent.service.d/10-environment.conf
  fi
}

set_zone() {
  INSTANA_ZONE=$INSTANA_AGENT_ZONE &&
    sudo cat <<EOF >>/opt/instana/agent/etc/instana/configuration-zone.yaml
# Hardware & Zone
com.instana.plugin.generic.hardware:
   enabled: true
   availability-zone: "${INSTANA_ZONE}"
EOF

  if [ "$verbose" -eq 1 ]; then
    echo -e "${BLUE}[INFO]${NC} Agent Zone is set"
    cat /opt/instana/agent/etc/instana/configuration-zone.yaml
  fi
}

set_tag() {
  sudo cat <<EOF >>/opt/instana/agent/etc/instana/configuration-host.yaml
# Host
com.instana.plugin.host:
  tags:
    - 'poc'
    - 'instana'
EOF

  if [ "$verbose" -eq 1 ]; then
    echo -e "${BLUE}[INFO]${NC} Agent Tag is set"
    cat /opt/instana/agent/etc/instana/configuration-host.yaml
  fi
}

install_rpm_agent() {
  sudo rpm -import Instana.gpg

  sudo yum install agent.rpm -y
  # sudo rpm -ivh agent.rpm
}

restart_agent() {

  sudo systemctl daemon-reload

  sudo systemctl enable instana-agent

  sudo systemctl restart instana-agent

}

downlod_rpm_agent() {
  curl -L -o agent.rpm http://${MINISERVE_USERNAME}:${MINISERVE_PASSWORD}@${MINISERVE_HOST}:${MINISERVE_PORT}/instana-agent-${INSTANA_PACKAGE}-${INSTANA_AGENT_RELEASE}.${PROC_TYPE}.rpm

  curl -L -o Instana.gpg http://${MINISERVE_USERNAME}:${MINISERVE_PASSWORD}@${MINISERVE_HOST}:${MINISERVE_PORT}/Instana.gpg
}

run_rpm_installer() {
  print_env

  prereq_check

  if [ $exit_flag -eq 1 ]; then
    exit
  fi

  downlod_rpm_agent

  install_rpm_agent

  set_environment

  set_zone

  restart_agent

  echo -e "${GREEN}[INFO]${NC} Installation of agent is done."
}

uninstall_agent() {
  check_sudo
  package=$(rpm -qa | grep instana-agent)
  echo "Please confirm you want to uninstall $package? (y/n)"
  read confirmation
  if [ $confirmation == "y" ] || [ $confirmation == "Y" ]; then
    echo -e "${BLUE}[INFO]${NC} Proceed to uninstall..."
    sudo systemctl stop instana-agent
    sudo systemctl disable instana-agent
    sudo rpm -e $package
    echo -e "${BLUE}[INFO]${NC} Successfully uninstall $package"
  else
    echo -e "${BLUE}[INFO]${NC} Quit uninstallation"
  fi
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

optspec=":hv-:"
while getopts "$optspec" option; do
  case $option in
  -)
    case "${OPTARG}" in
    env)
      print_env
      exit
      ;;
    agentkey)
      val="${!OPTIND}"
      OPTIND=$(($OPTIND + 1))
      INSTANA_AGENT_KEY=$val
      ;;
    host)
      val="${!OPTIND}"
      OPTIND=$(($OPTIND + 1))
      INSTANA_AGENT_HOST=$val
      ;;
    port)
      val="${!OPTIND}"
      OPTIND=$(($OPTIND + 1))
      INSTANA_AGENT_PORT=$val
      ;;
    downloadkey)
      val="${!OPTIND}"
      OPTIND=$(($OPTIND + 1))
      INSTANA_DOWNLOAD_KEY=$val
      ;;
    zone)
      val="${!OPTIND}"
      OPTIND=$(($OPTIND + 1))
      INSTANA_AGENT_ZONE=$val
      ;;      
    verbose)
      verbose=1
      ;;
    uninstall)
      uninstall_agent
      exit
      ;;
    help)
      help
      exit
      ;;
    *)
      help
      exit
      ;;
    esac
    ;;
  h) # display help
    help
    exit
    ;;
  v)
    verbose=1
    ;;
  \?)
    echo -e "${RED}[ERROR]${NC}  Invalid option"
    help
    exit
    ;;
  esac
done

run_rpm_installer
