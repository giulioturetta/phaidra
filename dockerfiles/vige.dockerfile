FROM debian:bullseye-20230919
ENV DEBIAN_FRONTEND noninteractive
RUN <<EOF
apt-get --quiet update
apt-get install --yes --quiet --no-install-recommends \
jq libxml-xpath-perl html2text
apt-get clean
EOF
COPY ./../third-parties/mongodb-mongosh_2.0.2_amd64.deb /
RUN <<EOF
dpkg -i mongodb-mongosh_2.0.2_amd64.deb
rm mongodb-mongosh_2.0.2_amd64.deb
EOF
RUN mkdir /opt/vige
WORKDIR /opt/vige
