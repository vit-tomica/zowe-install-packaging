#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

#
# Your JCL must invoke it like this:
#
# //        EXEC PGM=BPXBATSL,REGION=0M,TIME=NOLIMIT,
# //  PARM='PGM /bin/sh &SRVRPATH/scripts/internal/run-zowe.sh'
#
#

checkForErrorsFound() {
  if [[ $ERRORS_FOUND > 0 ]]
  then
    # if -v passed in any validation failures abort
    if [ ! -z $VALIDATE_ABORTS ]
    then
      echo "$ERRORS_FOUND errors were found during validatation, please check the message, correct any properties required in ${ROOT_DIR}/scripts/internal/run-zowe.sh and re-launch Zowe"
      exit $ERRORS_FOUND
    fi
  fi
}

# If -v passed in any validation failure result in the script exiting, other they are logged and continue
while getopts ":v" opt; do
  case $opt in
    v)
      VALIDATE_ABORTS=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

export ROOT_DIR=$(cd $(dirname $0)/../../;pwd) #we are in <ROOT_DIR>/scripts/internal/run-zowe.sh

# New Cupids work - once we have PARMLIB/properties files removed properly this won't be needed anymore
USER_DIR={{user_dir}} # the workspace location for this instance. TODO Should we add this as a new to the yaml, or default it?
FILES_API_PORT={{files_api_port}} # the port the files api service will use
JOBS_API_PORT={{jobs_api_port}} # the port the files api service will use
JES_EXPLORER_UI_PORT={{jobs_ui_port}} # the port the jes explorer will use
MVS_EXPLORER_UI_PORT={{mvs_ui_port}} # the port the mvs explorer will use
USS_EXPLORER_UI_PORT={{uss_ui_port}} # the port the uss explorer will use
DISCOVERY_PORT={{discovery_port}} # the port the discovery service will use
CATALOG_PORT={{catalog_port}} # the port the api catalog service will use
GATEWAY_PORT={{gateway_port}} # the port the api gateway service will use
VERIFY_CERTIFICATES={{verify_certificates}} # boolean saying if we accept only verified certificates
STC_NAME={{stc_name}}

# details to be read from higher level entry that instance PARMLIB/prop file?
KEY_ALIAS={{key_alias}}
KEYSTORE={{keystore}}
TRUSTSTORE={{truststore}}
KEYSTORE_PASSWORD={{keystore_password}}
KEYSTORE_KEY={{keystore_key}}
KEYSTORE_CERTIFICATE={{keystore_certificate}}
ZOSMF_PORT={{zosmf_port}}
ZOSMF_IP_ADDRESS={{zosmf_host}}  #TODO LATER - SH: once all components converted, remove - replaced by ZOSMF_HOST to allow hostname, or ip address
ZOSMF_HOST={{zosmf_host}} # The hostname, or ip address where z/OS MF is running
ZOWE_IP_ADDRESS={{zowe_ip_address}}
ZOWE_EXPLORER_HOST={{zowe_explorer_host}}
ZOWE_JAVA_HOME={{java_home}}
ZOWE_NODE_HOME={{node_home}}

LAUNCH_COMPONENT_GROUPS=GATEWAY,DESKTOP

LAUNCH_COMPONENTS=""

export ZOWE_PREFIX={{zowe_prefix}}{{zowe_instance}}
ZOWE_API_GW=${ZOWE_PREFIX}AG
ZOWE_API_DS=${ZOWE_PREFIX}AD
ZOWE_API_CT=${ZOWE_PREFIX}AC
ZOWE_DESKTOP=${ZOWE_PREFIX}DT
ZOWE_EXPL_UI_JES=${ZOWE_PREFIX}UJ
ZOWE_EXPL_UI_MVS=${ZOWE_PREFIX}UD
ZOWE_EXPL_UI_USS=${ZOWE_PREFIX}UU

# Make sure ROOT DIR and USER DIR are accessible and writable to the user id running this
mkdir -p ${USER_DIR}/
. ${ROOT_DIR}/scripts/utils/validate-directory-is-writable.sh ${USER_DIR}
checkForErrorsFound

# Make sure Java and Node are available on the Path
. ${ROOT_DIR}/scripts/utils/configure-java.sh
. ${ROOT_DIR}/scripts/utils/configure-node.sh
checkForErrorsFound

# Workaround Fix for node 8.16.1 that requires compatability mode for untagged files
export __UNTAGGED_READ_MODE=V6


if [[ $LAUNCH_COMPONENT_GROUPS == *"GATEWAY"* ]]
then
  LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS},files-api,jobs-api,api-mediation,explorer-jes,explorer-mvs,explorer-uss #TODO this is WIP - component ids not finalised at the moment
fi

if [[ $LAUNCH_COMPONENTS == *"api-mediation"* ]]
then
  # Create the user configurable api-defs
  STATIC_DEF_CONFIG_DIR=${USER_DIR}/api-mediation/api-defs
  mkdir -p ${STATIC_DEF_CONFIG_DIR}
fi

# Validate component properties if script exists
ERRORS_FOUND=0
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  VALIDATE_SCRIPT=${ROOT_DIR}/components/${i}/bin/validate.sh
  if [[ -f ${VALIDATE_SCRIPT} ]]
  then
    . ${VALIDATE_SCRIPT}
    retval=$?
    let "ERRORS_FOUND=$ERRORS_FOUND+$retval"
  fi
done

checkForErrorsFound

mkdir -p ${USER_DIR}/backups
# Make accessible to group so owning user can edit?
chmod -R 771 ${USER_DIR}

#Backup previous directory if it exists
if [[ -f ${USER_DIR}"/active_configuration.cfg" ]]
then
  PREVIOUS_DATE=$(cat ${USER_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
  mv ${USER_DIR}/active_configuration.cfg ${USER_DIR}/backups/backup_configuration.${PREVIOUS_DATE}.cfg
fi

NOW=$(date +"%y.%m.%d.%H.%M.%S")
# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
cat <<EOF >${USER_DIR}/active_configuration.cfg
VERSION=$(cat $ROOT_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
USER_DIR=${USER_DIR}
FILES_API_PORT=${FILES_API_PORT}
JOBS_API_PORT=${JOBS_API_PORT}
JES_EXPLORER_UI_PORT=${JES_EXPLORER_UI_PORT}
MVS_EXPLORER_UI_PORT=${MVS_EXPLORER_UI_PORT}
USS_EXPLORER_UI_PORT=${USS_EXPLORER_UI_PORT}
DISCOVERY_PORT=${DISCOVERY_PORT}
CATALOG_PORT=${CATALOG_PORT}
GATEWAY_PORT=${GATEWAY_PORT}
VERIFY_CERTIFICATES=${VERIFY_CERTIFICATES}
STC_NAME=${STC_NAME}
KEY_ALIAS=${KEY_ALIAS}
KEYSTORE=${KEYSTORE}
TRUSTSTORE=${TRUSTSTORE}
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
KEYSTORE_KEY=${KEYSTORE_KEY}
KEYSTORE_CERTIFICATE=${KEYSTORE_CERTIFICATE}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
ZOSMF_PORT=${ZOSMF_PORT}
ZOSMF_IP_ADDRESS=${ZOSMF_IP_ADDRESS}
ZOWE_IP_ADDRESS=${ZOWE_IP_ADDRESS}
ZOWE_EXPLORER_HOST=${ZOWE_EXPLORER_HOST}
ZOWE_JAVA_HOME=${ZOWE_JAVA_HOME}
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}
LAUNCH_COMPONENT_GROUPS=${LAUNCH_COMPONENT_GROUPS}
EOF

# Copy manifest into user_dir so we know the version for support enquiries/migration
cp ${ROOT_DIR}/manifest.json ${USER_DIR}

# Run setup/configure on components if script exists
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  CONFIGURE_SCRIPT=${ROOT_DIR}/components/${i}/bin/configure.sh
  if [[ -f ${CONFIGURE_SCRIPT} ]]
  then
    . ${CONFIGURE_SCRIPT}
  fi
done

for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  . ${ROOT_DIR}/components/${i}/bin/start.sh
done


# Start the desktop
if [[ $LAUNCH_COMPONENT_GROUPS == *"DESKTOP"* ]]
then
  cd $ROOT_DIR/zlux-app-server/bin && _BPX_JOBNAME=$ZOWE_DESKTOP ./nodeCluster.sh --allowInvalidTLSProxy=true &
fi
