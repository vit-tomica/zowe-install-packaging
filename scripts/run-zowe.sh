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

# Your JCL must invoke it like this:
#
# //        EXEC PGM=BPXBATSL,REGION=0M,TIME=NOLIMIT,
# //  PARM='PGM /bin/sh &SRVRPATH/scripts/internal/run-zowe.sh' &CONFIG
# Where &CONFIG is the location of the zowe config.properties file

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

# Read in properties by executing, then export all the keys so we don't need to shell share
CONFIG_LOCATION=$1
. $CONFIG_LOCATION
while read -r line
do
    test -z "${line%%#*}" && continue      # skip line if first char is #
    key=${line%%=*}
    export $key
done < $CONFIG_LOCATION

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

LAUNCH_COMPONENTS=""

export ZOWE_PREFIX=${ZOWE_PREFIX}${ZOWE_INSTANCE}
ZOWE_DESKTOP=${ZOWE_PREFIX}DT
ZOWE_EXPL_UI_JES=${ZOWE_PREFIX}UJ
ZOWE_EXPL_UI_MVS=${ZOWE_PREFIX}UD
ZOWE_EXPL_UI_USS=${ZOWE_PREFIX}UU

# Make sure ROOT DIR and USER DIR are accessible and writable to the user id running this
mkdir -p ${USER_DIR}/
. ${ROOT_DIR}/scripts/utils/validateDirectoryIsWritable.sh ${USER_DIR}
checkForErrorsFound

DIR=`dirname $0`


if [[ $LAUNCH_COMPONENT_GROUPS == *"DESKTOP"* ]]
then
  cd $DIR/../../zlux-app-server/bin && _BPX_JOBNAME=$ZOWE_DESKTOP ./nodeCluster.sh --allowInvalidTLSProxy=true &
fi

if [[ $LAUNCH_COMPONENT_GROUPS == *"GATEWAY"* ]]
then
  LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS},files-api,jobs-api,api-mediation #TODO this is WIP - component ids not finalised at the moment
  _BPX_JOBNAME=$ZOWE_EXPL_UI_JES $DIR/../../jes_explorer/scripts/start-explorer-jes-ui-server.sh
  _BPX_JOBNAME=$ZOWE_EXPL_UI_MVS $DIR/../../mvs_explorer/scripts/start-explorer-mvs-ui-server.sh
  _BPX_JOBNAME=$ZOWE_EXPL_UI_USS $DIR/../../uss_explorer/scripts/start-explorer-uss-ui-server.sh
fi
 
if [[ $LAUNCH_COMPONENTS == *"api-mediation"* ]]
then
  # Create the user configurable api-defs
  STATIC_DEF_CONFIG_DIR=${USER_DIR}/api-mediation/api-defs
  mkdir -p ${STATIC_DEF_CONFIG_DIR}

  # Until ui explorers componentised will copy them from the old location
  cp ${ROOT_DIR}/components/api-mediation/api-defs/* ${STATIC_DEF_CONFIG_DIR}
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

# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
NOW=$(date +"%y.%m.%d.%H.%M.%S")
ZOWE_VERSION=$(cat $ROOT_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
cp $CONFIG_LOCATION ${USER_DIR}/active_configuration.properties
cat <<EOF >> ${USER_DIR}/active_configuration.cfg
VERSION=${ZOWE_VERSION}
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}
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
