# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
echo "################################"
echo "### Starting MPI Run Script ###"
echo "################################"

BASENAME="${0##*/}"
log () {
  echo "${BASENAME} - ${1}"
}
HOST_FILE_PATH="/tmp/hostfile"
AWS_BATCH_EXIT_CODE_FILE="/tmp/batch-exit-code"


usage () {
  if [ "${#@}" -ne 0 ]; then
    log "* ${*}"
    log
  fi
  cat <<ENDUSAGE
Usage:
export AWS_BATCH_JOB_NODE_INDEX=0
export AWS_BATCH_JOB_NUM_NODES=10
export AWS_BATCH_JOB_MAIN_NODE_INDEX=0
export AWS_BATCH_JOB_ID=string
./mpi-run.sh
ENDUSAGE

  error_exit
}

# Standard function to print an error and exit with a failing return code
error_exit () {
  log "${BASENAME} - ${1}" >&2
  log "${2:-1}" > $AWS_BATCH_EXIT_CODE_FILE
  kill  $(cat /tmp/supervisord.pid)
}

# Check what environment variables are set
if [ -z "${AWS_BATCH_JOB_NODE_INDEX}" ]; then
  usage "AWS_BATCH_JOB_NODE_INDEX not set, unable to determine rank"
fi

if [ -z "${AWS_BATCH_JOB_NUM_NODES}" ]; then
  usage "AWS_BATCH_JOB_NUM_NODES not set. Don't know how many nodes in this job."
fi

if [ -z "${AWS_BATCH_JOB_MAIN_NODE_INDEX}" ]; then
  usage "AWS_BATCH_MULTI_MAIN_NODE_RANK must be set to determine the master node rank"
fi

NODE_TYPE="child"
if [ "${AWS_BATCH_JOB_MAIN_NODE_INDEX}" == "${AWS_BATCH_JOB_NODE_INDEX}" ]; then
  log "Running synchronize as the main node"
  NODE_TYPE="main"
fi

# Check that necessary programs are available
# which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable."


# wait for all nodes to report
wait_for_nodes () {
  log "Running as master node"

  touch $HOST_FILE_PATH
  ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
  availablecores=$(nproc)
  log "master details -> $ip:$availablecores"
  echo "$ip slots=$availablecores" >> $HOST_FILE_PATH

  lines=$(uniq $HOST_FILE_PATH|wc -l)
  while [ "$AWS_BATCH_JOB_NUM_NODES" -gt "$lines" ]
  do
    log "$lines out of $AWS_BATCH_JOB_NUM_NODES nodes joined, will check again in 1 second"
    sleep 1
    lines=$(uniq $HOST_FILE_PATH|wc -l)
  done
  # Make the temporary file executable and run it with any given arguments
  log "All nodes successfully joined"
  # remove duplicates if there are any.
  awk '!a[$0]++' $HOST_FILE_PATH > ${HOST_FILE_PATH}-deduped
  cat $HOST_FILE_PATH-deduped
  log "executing main MPIRUN workflow"

  sleep 2
  cd $SCRATCH_DIR
  # RUN THE PROGRAM
  for i in 32 64 128 256 512
  do
    /opt/amazon/openmpi/bin/mpirun -np $i -hostfile ${HOST_FILE_PATH}-deduped -mca mtl ofi /NPB3.3.1/NPB3.3-MPI/bin/ft.C.$i
  done

  sleep 2

  log "done! goodbye, writing exit code to $AWS_BATCH_EXIT_CODE_FILE and shutting down my supervisord"
  echo "0" > $AWS_BATCH_EXIT_CODE_FILE
  kill  $(cat /tmp/supervisord.pid)
  exit 0
}


# Fetch and run a script
report_to_master () {
  # looking for masters nodes ip address calling the batch API
  # get own ip and num cpus
  #
  ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
  availablecores=$(nproc)
  log "I am a child node -> $ip:$availablecores, reporting to the master node -> ${AWS_BATCH_JOB_MAIN_NODE_PRIVATE_IPV4_ADDRESS}"
  until echo "$ip slots=$availablecores" | ssh ${AWS_BATCH_JOB_MAIN_NODE_PRIVATE_IPV4_ADDRESS} "cat >> /$HOST_FILE_PATH"
  do
    echo "Sleeping 5 seconds and trying again"
  done
  log "done! goodbye"
  exit 0
  }


# Main - dispatch user request to appropriate function
log $NODE_TYPE
case $NODE_TYPE in
  main)
    wait_for_nodes "${@}"
    ;;

  child)
    report_to_master "${@}"
    ;;

  *)
    log $NODE_TYPE
    usage "Could not determine node type. Expected (main/child)"
    ;;
esac
