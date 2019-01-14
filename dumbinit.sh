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
gosu splunk tar -zxf /opt/splunk/splunk_etc.tgz -C /opt

if [ -d "/opt/splunk/inject/ca-certificates" ]; then
  # Control will enter here if $DIRECTORY exists.
  cp -R /opt/splunk/inject/ca-certificates/* /usr/local/share/ca-certificates/
  update-ca-certificates
fi

crudini --del /opt/splunk/etc/system/local/inputs.conf default host
crudini --del /opt/splunk/etc/system/local/server.conf general serverName

crudini --set /opt/splunk/etc/system/local/server.conf sslConfig sslVerifyServerCert true
crudini --set /opt/splunk/etc/system/local/server.conf sslConfig sslRootCAPath /etc/ssl/certs/ca-certificates.crt
crudini --set /opt/splunk/etc/system/local/server.conf sslConfig sendStrictTransportSecurityHeader true
mkdir -p /tmp/splunk/sslClientSessionPath
crudini --set /opt/splunk/etc/system/local/server.conf sslConfig sslClientSessionPath /tmp/splunk/sslClientSessionPath
crudini --set /opt/splunk/etc/system/local/server.conf sslConfig useSslClientSessionCache true
#serverCert
#sslPassword
#dhFile

crudini --set /opt/splunk/etc/system/local/web.conf settings enableSplunkWebSSL true
crudini --set /opt/splunk/etc/system/local/web.conf settings simple_error_page = true
#privKeyPath
#serverCert
#sslPassword

chown -R splunk:splunk /opt/splunk
gosu splunk /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
gosu splunk tail -n 0 -f ${SPLUNK_HOME}/var/log/splunk/splunkd_stderr.log &
wait
