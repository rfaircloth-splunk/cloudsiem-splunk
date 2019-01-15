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
FROM debian:stretch-slim


LABEL version="1.0.0"
LABEL description="Cloudsiem build for splunk"
LABEL maintainer="rfaircloth@splunk.com"

ENV DEBIAN_FRONTEND=noninteractive

COPY install.sh /install.sh
RUN /install.sh && rm -rf /install.sh

ENV SPLUNK_ROLE=splunk_standalone \
    SPLUNK_HOME=/opt/splunk \
    SPLUNK_USER=splunk \
    CONTAINER_ARTIFACT_DIR=/opt/container_artifact

# Setup users and download Splunk
RUN mkdir -p ${CONTAINER_ARTIFACT_DIR}


# Setup users and download Splunk
COPY ./splunk /opt/splunk

RUN groupadd -r splunk \
    && useradd -r -m -g splunk splunk \
    && chown -R splunk:splunk /opt/splunk \
    && (cd /opt && tar -cvzf /opt/splunk/splunk_etc.tgz splunk/etc) \
    && rm -Rf /opt/splunk/etc/* \
    && chown splunk:splunk /opt/splunk/splunk_etc.tgz

COPY [ "common-files/entrypoint.sh", "common-files/checkstate.sh", "common-files/createdefaults.py","dumbinit.sh", "/sbin/" ]
EXPOSE 4001 8000 8065 8088 8089 8191 9887 9997

VOLUME [ "/opt/splunk/etc", "/opt/splunk/var" ]

HEALTHCHECK --interval=30s --timeout=30s --start-period=3m --retries=5 CMD /sbin/checkstate.sh || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/sbin/dumbinit.sh"]
