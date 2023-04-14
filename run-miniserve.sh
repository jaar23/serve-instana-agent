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

PORT=
AUTH_USERNAME=
AUTH_PASSWORD=
INSTANA_AGENT_RELEASE=20230215-2008
INSTANA_AGENT_KEY=

help() {
    # Display Help
    echo "Running miniserve server with arguments below:"
    echo
    echo "Syntax: run-miniserve.sh [--username | --password | --port ]"
    echo
    echo "options:"
    echo "-h                    Print this Help."
    echo "-u, --username        Username to login the server."
    echo "-p, --password        Password for the username."
    echo "-t, --port            Port number which exposing miniserve."
    echo "-a --agentkey         Instana Agent Key."
    echo -e "-r --release          Instana agent release version instana-agent-static-${BLUE}20230215-2008${NC}.x86_64"
    echo
}

optspec=":huprat-:"
while getopts "$optspec" option; do
    case $option in
    -)
        case "${OPTARG}" in
        username)
            val="${!OPTIND}"
            OPTIND=$(($OPTIND + 1))
            AUTH_USERNAME=$val
            ;;
        password)
            val="${!OPTIND}"
            OPTIND=$(($OPTIND + 1))
            AUTH_PASSWORD=$val
            ;;
        port)
            val="${!OPTIND}"
            OPTIND=$(($OPTIND + 1))
            PORT=$val
            ;;
        release)
            val="${!OPTIND}"
            OPTIND=$(($OPTIND + 1))
            INSTANA_AGENT_RELEASE=$val
            ;;
        agentkey)
            val="${!OPTIND}"
            OPTIND=$(($OPTIND + 1))
            INSTANA_AGENT_KEY=$val
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
    u)
        val="${!OPTIND}"
        OPTIND=$(($OPTIND + 1))
        AUTH_USERNAME=$val
        ;;
    p)
        val="${!OPTIND}"
        OPTIND=$(($OPTIND + 1))
        AUTH_PASSWORD=$val
        ;;
    t)
        val="${!OPTIND}"
        OPTIND=$(($OPTIND + 1))
        PORT=$val
        ;;
    r)
        val="${!OPTIND}"
        OPTIND=$(($OPTIND + 1))
        INSTANA_AGENT_RELEASE=$val
        ;;
    a)
        val="${!OPTIND}"
        OPTIND=$(($OPTIND + 1))
        INSTANA_AGENT_KEY=$val
        ;;
    \?)
        echo -e "${RED}[ERROR]${NC} Invalid option"
        help
        exit
        ;;
    esac
done

if [ -z "$PORT" ] && [ -z "$AUTH_USERNAME" ] && [ -z "$AUTH_PASSWORD" ]; then
    echo -e "${RED}[ERROR]${NC} Cannot start miniserve, due to variable is not set. "
    echo
    help
else
    HOST=$(curl -s ifconfig.me)
    PORT_AVAILABLE=$(echo $(ss -antl | grep "${PORT}"))
    if [ -n "$PORT_AVAILABLE" ]; then
        echo -e "${RED}[ERROR]${NC} Unable to start miniserve, due to port $PORT is not available."
        exit
    fi
    # enable line below for osx
    # echo $HOST
    # echo $PORT
    # echo $AUTH_USERNAME
    # echo $AUTH_PASSWORD
    # sed -i '' "s/MINISERVE_HOST=.*/MINISERVE_HOST=${HOST}/g" public/setup-airgap.sh
    # sed -i '' "s/MINISERVE_PORT=.*/MINISERVE_PORT=${PORT}/g" public/setup-airgap.sh
    # sed -i '' "s/MINISERVE_USERNAME=.*/MINISERVE_USERNAME=${AUTH_USERNAME}/g" public/setup-airgap.sh
    # sed -i '' "s/MINISERVE_PASSWORD=.*/MINISERVE_PASSWORD=${AUTH_PASSWORD}/g" public/setup-airgap.sh
    # sed -i '' "s/INSTANA_AGENT_RELEASE=.*/INSTANA_AGENT_RELEASE=${AGENT_RELEASE}/g" public/setup-airgap.sh
    # sudo ./miniserve-x86_64-darwin public --port $PORT --auth $AUTH_USERNAME:$AUTH_PASSWORD

    #enable line below for linux
    sed -i "s/MINISERVE_HOST=.*/MINISERVE_HOST=${HOST}/g" public/setup-airgap.sh
    sed -i "s/MINISERVE_PORT=.*/MINISERVE_PORT=${PORT}/g" public/setup-airgap.sh
    sed -i "s/MINISERVE_USERNAME=.*/MINISERVE_USERNAME=${AUTH_USERNAME}/g" public/setup-airgap.sh
    sed -i "s/MINISERVE_PASSWORD=.*/MINISERVE_PASSWORD=${AUTH_PASSWORD}/g" public/setup-airgap.sh
    sed -i "s/INSTANA_AGENT_RELEASE=.*/INSTANA_AGENT_RELEASE=${INSTANA_AGENT_RELEASE}/g" public/setup-airgap.sh


    sed -i "s/MINISERVE_HOST=.*/MINISERVE_HOST=${HOST}/g" public/setup-airgap.ksh
    sed -i "s/MINISERVE_PORT=.*/MINISERVE_PORT=${PORT}/g" public/setup-airgap.ksh
    sed -i "s/MINISERVE_USERNAME=.*/MINISERVE_USERNAME=${AUTH_USERNAME}/g" public/setup-airgap.ksh
    sed -i "s/MINISERVE_PASSWORD=.*/MINISERVE_PASSWORD=${AUTH_PASSWORD}/g" public/setup-airgap.ksh
    
    echo -e "${BLUE} Run the following command in the managed to server to install instana agent ${NC}"
    echo -e "RHEL: "
    echo -e "${BLUE} curl -L -o setup-airgap.sh http://${AUTH_USERNAME}:${AUTH_PASSWORD}@${HOST}:${PORT}/setup-airgap.sh && \
chmod +x setup-airgap.sh && sudo ./setup-airgap.sh --agentkey ${INSTANA_AGENT_KEY} --host ${HOST} ${NC}"
    echo 
    echo -e "AIX: "
    echo -e "${BLUE} curl -L -o setup-airgap.ksh http://${AUTH_USERNAME}:${AUTH_PASSWORD}@${HOST}:${PORT}/setup-airgap.ksh && \
chmod +x setup-airgap.ksh && sudo ./setup-airgap.ksh -i"
    sudo ./miniserve-x86_64-linux public --port $PORT --auth $AUTH_USERNAME:$AUTH_PASSWORD
fi
