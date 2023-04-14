#!/bin/ksh
# Installing Instana Agent on AIX machine
# Author - Chan Yong Jia
# 04-Mar-2023
#---------------------------------------------------------------
# 1. Pre-req check
#   - check if java exist or installed (Y)
#   - check if system already installed instana agent (Y)
#   - check if user has correct permission (Y)
# 2. Untar file to desire location
# 3. Write configuration.yaml
# 4. Start instana agent
#---------------------------------------------------------------
# set -o xtrace

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
DEFAULT_JDK_PATH="/usr/java8_64"
INSTANA_AGENT_KEY=
INSTANA_DOWNLOAD_KEY=
INSTANA_AGENT_HOST=
INSTANA_AGENT_PORT=1444
OS_BIT=$(getconf KERNEL_BITMODE)
MINISERVE_HOST=116.86.78.183
MINISERVE_PORT=8080
MINISERVE_USERNAME=user
MINISERVE_PASSWORD=password
INSTANA_AGENT_ZONE="AIX Server Zone"

############################################################
# Program Variables                                        #
############################################################
verbose=0
agent_install_path="$HOME/instana"
instana_config_zone=
instana_config_tag=
silent=0

############################################################
# Usage                                                    #
############################################################
usage() {
	echo "Setup Instana Agent using automated script."
	echo ""
	echo "Syntax: setup-airgap.ksh -i"
	echo ""
	echo "options:"
	echo "-h        Print this Help."
	echo "-v        Verbose mode."
	echo "-i        Start installation script in interactive mode."
	echo ""
}

info() {
	if [ "$verbose" -eq 1 ]; then
		print "${BLUE}[INFO]${NC} $1"
	fi
}

err() {
	if [ "$verbose" -eq 1 ]; then
		print "${RED}[ERROR]${NC} $1"
	fi
}

success() {
	if [ "$verbose " -eq 1 ]; then
		print "${GREEN} $1 ${NC}"
	fi
}

set_java_home() {
	echo "export JAVA_HOME=$1" >>~/.profile
	echo "export PATH=\$PATH:\$JAVA_HOME/bin" >>~/.profile
	info "JAVA_HOME env is set. Resetting env."
	. ~/.profile
	java_home_set=$(echo $JAVA_HOME)
	info "New environment variable set, JAVA_HOME=$java_home_set"
}

check_java_home() {
	java_home_set=$(echo $JAVA_HOME)
	if [ -z "$java_home_set" ]; then
		info "JAVA_HOME is not set."
		info "Instana Agent required JAVA_HOME env set to work correctly."
		if [ -e "$DEFAULT_JDK_PATH" ]; then
			print " JDK is found in default location (/usr/java8_64)."
			print " Would you like to set it as JAVA_HOME env? (y/n)"
			print -n "> "
			read opt

			if [ $opt == "y" ] || [ $opt == "Y" ]; then
				set_java_home $DEFAULT_JDK_PATH
			fi
		else
			print " JDK is not found in default location."
			print " Please provide the JDK/JRE path to set as JAVA_HOME env."
			print -n "> "
			read java_path

			while [[ ! -e "$java_path" ]]; do
				print " Invalid path."
				print " Please provide the JDK/JRE path to set as JAVA_HOME env."
				print -n "> "
				read java_path
			done
			info "Path is valid."
			set_java_home $java_path
		fi

	else
		info "JAVA_HOME env is set."
		info "JAVA_HOME=$JAVA_HOME"
	fi
}

check_process_exist() {
	psup=$(ps -ef | grep "$1" | egrep -v grep | wc -l)
	if [ "$psup" -gt 0 ]; then
		info "$1 is already existed and running now."
		info "Quit installation."
		print "$1 is already running."
	fi
}

check_root_privileges() {
	if [ -n "$(groups | grep -E 'sudo|sys|system' 2>/dev/null)" ]; then
		print " User has sudo privileges."
	else
		print " User do not have sudo privileges, re-run again with sudo."
		exit
	fi
}

download_tarball_agent() {
	info "Download instana agent tarball."
	curl -L -o agent.tar.gz "http://${MINISERVE_USERNAME}:${MINISERVE_PASSWORD}@${MINISERVE_HOST}:${MINISERVE_PORT}/instana-agent-aix-ppc-${OS_BIT}bit.tar.gz"
}

create_installation_path() {
	if [ "$USER" == "root" ]; then
		agent_install_path="/instana"
	else
		agent_install_path="$HOME/instana"
	fi

	print " Where should Instana Agent install? default: $agent_install_path"
	print -n "> "
	read install_path
	if [ -n "$install_path" ]; then
		mkdir -p "$install_path"
		print "Installation path is created."
		agent_install_path=$install_path
	else
		info "Using default path. ($agent_install_path)"
		print " Using default path for Instana Agent installation ($agent_install_path)"
		mkdir -p $agent_install_path
	fi
}

untar_installer() {
	info "Starting to decompress tarball."
	print " Decompressing tarball..."
	# progress_bar "$agent_install_path/instana-agent/bin/start"
	gunzip -c agent.tar.gz | tar -xf - -C "$agent_install_path"
	print "Decompressed file to ${BLUE} ${agent_install_path} ${NC}."
}

set_agent_config() {
	info "Setting instana backend configuration"
	mkdir -p ./tmp
	print " Please fill up the following:"
	print " Instana Backend (default: $MINISERVE_HOST) "
	print -n "> "
	read instana_backend
	if [ -n "$instana_backend" ]; then
		INSTANA_AGENT_HOST=$instana_backend
	else
		INSTANA_AGENT_HOST=$MINISERVE_HOST
		info "Using default value. ($MINISERVE_HOST)"
		print " Using default value."
	fi
	echo "host=$INSTANA_AGENT_HOST" >>tmp/com.instana.agent.main.sender.Backend.cfg
	echo "" >>tmp/com.instana.agent.main.sender.Backend.cfg

	print " Instana Port (default: 1444) "
	print -n "> "
	read instana_port
	if [ -n "$instana_port" ]; then
		INSTANA_AGENT_PORT=$instana_port
	else
		INSTANA_AGENT_PORT=1444
		info "Using default value. (1444)"
		print " Using default value."
	fi
	echo "port=$INSTANA_AGENT_PORT" >>tmp/com.instana.agent.main.sender.Backend.cfg
	echo "" >>tmp/com.instana.agent.main.sender.Backend.cfg

	print " Instana Agent Key"
	print -n "> "
	read agent_key
	if [ -n "$agent_key" ]; then
		INSTANA_AGENT_KEY=$agent_key
	else
		while [[ -z "$agent_key" ]]; do
			print " Invalid input."
			print " Please Instana Agent Key to proceed."
			print -n "> "
			read agent_key
		done
		INSTANA_AGENT_KEY=$agent_key
	fi
	echo "key=$INSTANA_AGENT_KEY" >>tmp/com.instana.agent.main.sender.Backend.cfg
	echo "" >>tmp/com.instana.agent.main.sender.Backend.cfg

	mv tmp/com.instana.agent.main.sender.Backend.cfg "$agent_install_path/instana-agent/etc/instana/com.instana.agent.main.sender.Backend.cfg"

	print "Instana Backend configuration is set."
	print "${BLUE}
+---------------------------------------------------+
| Updated Backend Config file                       |
+---------------------------------------------------+${NC}"
	cat "$agent_install_path/instana-agent/etc/instana/com.instana.agent.main.sender.Backend.cfg"

	print ""
}

set_zone() {
	info "Setting configuration zone"
	print " Define the server zone (default: $INSTANA_AGENT_ZONE) "
	print -n "> "
	read zone
	if [ -n "$zone" ]; then
		INSTANA_AGENT_ZONE=$zone
	else		
		info "Using default value. ($INSTANA_AGENT_ZONE)"
		print " Using default value."
	fi
	INSTANA_ZONE=$INSTANA_AGENT_ZONE &&
		cat <<EOF >>${agent_install_path}/instana-agent/etc/instana/configuration-zone.yaml
# Hardware & Zone
com.instana.plugin.generic.hardware:
   enabled: true
   availability-zone: "${INSTANA_ZONE}"
EOF
}

start_agent() {
	print " Starting Instana Agent."
	$agent_install_path/instana-agent/bin/start
	print " Instana Agent started."
}

progress_bar() {
	i=50
	print "[0--------20--------40-------60--------80-------100%]"
	print -n " "
	while [ $i -ge 0 ]; do
		print -n "#"
		if [ ! -e $1 ]; then
			sleep 1
			i=$(expr $i - 1)
		fi
	done
}

run_aix_installer() {
	if [ $silent -eq 1 ]; then
		print "silent install"
	elif [ $silent -eq 0 ]; then
		info "start installation."
		check_java_home
		info "JAVA_HOME test passed."
		check_process_exist "instana-agent"
		info "Process exisitence test passed."
		check_root_privileges
		info "Root privileges test passed."
		download_tarball_agent
		success "Tarball downloaded successfully"
		create_installation_path
		success "Installation path created successfully."
		untar_installer
		success "Untar file successfully."
		set_zone
		success "Set instana configuration zone successfully."
		set_agent_config
		success "Set Instana backend configuration successfully."
		start_agent
		success "Installation done..."
	else
		print "Quit instalation."
	fi
}

uninstall_agent() {
	if [ "$USER" == "root" ]; then
		agent_install_path="/instana"
	else
		agent_install_path="$HOME/instana"
	fi

	print "Stopping Instana Agent"
	if [ -e $agent_install_path/instana-agent/bin/stop ]; then
		$agent_install_path/instana-agent/bin/stop
	else
		info "No stop server script found."
		print " Instana Agent might not install in the default location. ($agent_install_path)"
		print " Please manually stop and remove the agent."
	fi

	print " Please confirm you want to uninstall Instana Agent in the following path ${BLUE}($agent_install_path)${NC}? (y/n)"
	print -n "> "
	read confirmation
	if [ $confirmation == "y" ] || [ $confirmation == "Y" ]; then
		info "Proceed to uninstall..."
		print "Uninstalling Instana Agent"
		sudo rm -rf $agent_install_path
		success "Successfully uninstall Instana Agent"
	else
		info "Quit uninstallation"
	fi
}

menu() {
	if [ $silent -eq 1 ]; then
		print "Not implemented..."
		# print "silent installation.. $@"
		# args=$@
		# pos=1
		# while test ${#} -gt 0
		# do
		# 	if [ "$1" == "-s" ]; then
		# 		silent=1
		# 	elif [ "$1" == "-v" ]; then
		# 		verbose=1
		# 	elif [ "$1" == "--host" ]; then
		# 		shift
		# 		echo $1
		# 	else 
		# 		echo $1
		# 	fi
		# done		
	else
		print "${BLUE}
+---------------------------------------------------+
| Instana Agent Installation on AIX                 |
+---------------------------------------------------+${NC}
 Install instana agent (1) 
 Uninstall instana agent (2)
 Quit (q)"
		print -n "> "
		read opt

		if [ $opt == 1 ]; then
			run_aix_installer
		elif [ $opt == 2 ]; then
			print "uninstall"
			uninstall_agent
		elif [ $opt == 'q' ] || [ $opt == 'Q' ]; then
			exit
		else
			err "Invalid option."
		fi
	fi
}

while getopts "hisv" arguments; do
	case $arguments in
	s)
		info "Start insaller in silent modes"
		silent=1
		;;
	i)
		info "Start installer in interactive mode."
		silent=0
		;;
	v)
		verbose=1
		info "log level is set to verbose."
		;;
	h) 
		usage
		exit;;
	\?)
		print "$OPTARG is not a valid option"
		usage
		exit
		;;
	esac
done

menu $@
