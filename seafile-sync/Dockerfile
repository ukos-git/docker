FROM ubuntu:bionic
RUN apt-get update && \
	apt-get install --assume-yes \
		software-properties-common && \
	add-apt-repository --yes --update \
		ppa:seafile/seafile-client && \
	apt-get install --assume-yes \
		seafile-cli && \
	apt-get clean

RUN mkdir -p /seafile/client
RUN seaf-cli init \
		-d "/seafile/client"
RUN ln -s /root/.ccnet /seafile/ccnet
RUN mkdir -p /seafile/sync
WORKDIR /seafile
ENTRYPOINT seaf-cli start && sleep 5 && seaf-cli sync \
		-l $SEAFILE_LIBRARY \
		-s $SEAFILE_DOMAIN \
		-d $SEAFILE_DIRECTORY \
		-u $SEAFILE_USER \
		-p $SEAFILE_PASSWORD && \
        while seaf-cli status &>/dev/null;do sleep 5;done
