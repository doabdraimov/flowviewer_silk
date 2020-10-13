#!/bin/bash

# Startup script for flowviewer-silk Docker container
# From https://docs.docker.com/engine/admin/multi-service_container/

# Start httpd2
echo `whoami`

# sudo /usr/sbin/httpd -D FOREGROUND &
./start_httpd.sh -D
status=$?
echo "httpd status: $?"
# if [ $status -ne 0 ]; then
#   echo "Failed to start httpd: $status"
#   exit $status
# fi

# Почемуто не удаляются файлы после перезапуска контейнера, удаляем вручную.(пока еще не разобрался почему это происходит)
sleep 5
$(ps ax | grep -v grep | grep httpd &> /dev/null)
HTTPD_STATUS=$?
if [[ "$HTTPD_STATUS" > 0 ]]; then
 echo "clearing /run/httpd/ directoryi and restarting httpd"
 rm -rf /run/httpd/*
 ./start_httpd.sh -D 
fi

# Start rwflowpack
./start_rwflowpack.sh start -D
status=$?
echo "rwflowpack status: $?"
#if [ $status -ne 0 ]; then
#  echo "Failed to start rwflowpack: $status"
#  exit $status
#fi

# Start FlowViewer programs
./start_flowviewer.sh -D
status=$?
echo "FlowViewer status: $?"
#if [ $status -ne 0 ]; then
#  echo "Failed to start FlowViewer: $status"
#  exit $status
#fi

while /bin/true; do
 $(ps ax | grep -v grep | grep httpd &> /dev/null)
 PROCESS_1_STATUS=$?

 $(ps ax | grep -v grep | grep rwflowpack &> /dev/null)
 PROCESS_2_STATUS=$?

 $(ps ax | grep -v grep | grep FlowMonitor &> /dev/null)
 PROCESS_3_STATUS=$?

 # If the greps above find anything, they will exit with 0 status
 # If they are not 0, then something is wrong

 if [[ "$PROCESS_1_STATUS" > 0 || "$PROCESS_2_STATUS" > 0 || "$PROCESS_3_STATUS" > 0 ]]; then
  echo "Status: httpd = '$PROCESS_1_STATUS' rwflowpack = '$PROCESS_2_STATUS' FlowViewer = '$PROCESS_3_STATUS'"
  exit -1 
 fi
 
 echo "Status: '$PROCESS_1_STATUS' '$PROCESS_2_STATUS' '$PROCESS_3_STATUS'"
 
 sleep 60
done
