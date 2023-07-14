FROM ubuntu:jammy
ENV DEBIAN_FRONTEND noninteractive

RUN <<EOF
apt-get update
apt-get install --yes --quiet --no-install-recommends \
libvips-tools libyaml-syck-perl libmongodb-perl
apt-get clean
EOF

ADD ./../components/pixelgecko /opt/pixelgecko
COPY ./../image_components/pixelgecko/pixelgecko.yml /etc/

WORKDIR /opt/pixelgecko
ENTRYPOINT ["perl", "pixelgecko.pl", "--watch"]
