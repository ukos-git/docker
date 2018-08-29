# vim: set noet ts=4
FROM debian:stable

RUN apt-get update

# iputils
RUN apt-get install --assume-yes \
	dnsutils \
	iputils-ping \
	netcat-openbsd

RUN apt-get clean
