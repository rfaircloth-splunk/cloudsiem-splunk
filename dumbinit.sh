#!/usr/bin/dumb-init /bin/bash
# Copyright 2018 Splunk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

export SPLUNK_HOME=/opt/splunk
APP=${APP^^}
ROLE=${ROLE^^}

splunkstop(){

  gosu splunk ${SPLUNK_HOME}/bin/splunk stop 2>/dev/null || true
}

trap splunkstop TERM
trap "echo HUP" HUP
trap splunkstop INT
trap splunkstop QUIT
trap "echo USR1; sleep 2; exit 0" USR1
trap "echo USR2" USR2


#Upgrade ETC
sh -c "echo 'starting' > ${CONTAINER_ARTIFACT_DIR}/splunk-container.state"
mkdir -p /opt/splunk/etc
tar -zxvf /opt/splunk/splunk_etc.tgz -C /opt

echo Starting Configuration
echo APP=$APP ROLE=$ROLE
if [ "$APP" = "SPLUNK" ]; then
  if [ ! -f /opt/splunk/etc/passwd ]; then
    echo setting admin credentials
    crudini --set /opt/splunk/etc/system/local/user-seed.conf user_info USERNAME $SPLUNK_ADMIN_USER
    crudini --set /opt/splunk/etc/system/local/user-seed.conf user_info PASSWORD $SPLUNK_ADMIN_PASSWORD
  fi
  #Disable UI checking for updated versions
  crudini --set /opt/splunk/etc/system/local/web.conf settings updateCheckerBaseURL 0

  crudini --set /opt/splunk/etc/system/local/server.conf general pass4SymmKey $SPLUNK_GEN_PASS4SYM

  if [ "$ROLE" = "SPLUNK-IDXC-MASTER" ]; then

      crudini --set /opt/splunk/etc/system/local/server.conf general site site0

      crudini --set /opt/splunk/etc/system/local/server.conf clustering mode master
      crudini --set /opt/splunk/etc/system/local/server.conf clustering pass4SymmKey $SPLUNK_IDXC_PASS4SYM
      crudini --set /opt/splunk/etc/system/local/server.conf clustering cluster_label MAIN
      crudini --set /opt/splunk/etc/system/local/server.conf clustering summary_replication true
      crudini --set /opt/splunk/etc/system/local/server.conf clustering multisite true
      crudini --set /opt/splunk/etc/system/local/server.conf clustering available_sites "site1, site2, site3"
      crudini --set /opt/splunk/etc/system/local/server.conf clustering site_replication_factor "origin:2, total:3"
      crudini --set /opt/splunk/etc/system/local/server.conf clustering site_search_factor "origin:1, total:2"
      crudini --set /opt/splunk/etc/system/local/server.conf clustering replication_factor 3
      crudini --set /opt/splunk/etc/system/local/server.conf clustering search_factor 2

      echo [default] >/opt/splunk/etc/master-apps/_cluster/local/indexes.conf
      crudini --set /opt/splunk/etc/master-apps/_cluster/local/indexes.conf "default" repFactor auto
      crudini --set /opt/splunk/etc/master-apps/_cluster/local/indexes.conf _introspection repFactor 0

      crudini --set /opt/splunk/etc/master-apps/_cluster/local/inputs.conf "splunktcp-ssl://9997" disabled false
      crudini --set /opt/splunk/etc/master-apps/_cluster/local/inputs.conf SSL serverCert \$SPLUNK_HOME/etc/auth/server.pem
      crudini --set /opt/splunk/etc/master-apps/_cluster/local/inputs.conf SSL requireClientCert false
      crudini --set /opt/splunk/etc/master-apps/_cluster/local/inputs.conf SSL sslPassword password


  fi

  if [ "$ROLE" = "SPLUNK-IDXC-SLAVE" ]; then
    mkdir -p /opt/splunk/var/indexes
    crudini --set /opt/splunk/etc/system/local/web.conf settings startwebserver false

    crudini --set /opt/splunk/etc/system/local/limits.conf scheduler saved_searches_disabled true

    crudini --set /opt/splunk/etc/system/local/server.conf general site site$SPLUNK_IDXC_SITE

    crudini --set /opt/splunk/etc/system/local/server.conf clustering mode slave
    crudini --set /opt/splunk/etc/system/local/server.conf clustering multisite true
    crudini --set /opt/splunk/etc/system/local/server.conf clustering master_uri $SPLUNK_IDXC_MASTER
    crudini --set /opt/splunk/etc/system/local/server.conf clustering pass4SymmKey $SPLUNK_IDXC_PASS4SYM

    crudini --set /opt/splunk/etc/system/local/server.conf "replication_port-ssl://9887" disabled false
    crudini --set /opt/splunk/etc/system/local/server.conf "replication_port-ssl://9887" requireClientCert false
    crudini --set /opt/splunk/etc/system/local/server.conf "replication_port-ssl://9887" serverCert \$SPLUNK_HOME/etc/auth/server.pem
    crudini --set /opt/splunk/etc/system/local/server.conf "replication_port-ssl://9887" password password
  fi

fi

chown -R splunk:splunk /opt/splunk
gosu splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
gosu splunk tail -n 0 -f ${SPLUNK_HOME}/var/log/splunk/splunkd_stderr.log &
wait
