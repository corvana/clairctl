FROM alpine:3.5 as builder

ENV GOPATH=/go
ENV PATH=${GOPATH}/bin:${PATH}
ARG DOCKER_VERSION=${DOCKER_VERSION:-latest}
ARG CLAIRCTL_VERSION=${CLAIRCTL_VERSION:-v1.2.8.1}
ARG CLAIRCTL_COMMIT=

RUN apk add --update curl \
 && apk add --virtual build-dependencies go gcc build-base glide git \
 && curl https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz -o docker.tgz \
 && tar xfvz docker.tgz --strip 1 -C /usr/bin/ docker/docker \
 && rm -f docker.tgz \
 && adduser clairctl -D

ADD ./ ${GOPATH}/src/github.com/jgsqware/clairctl
WORKDIR ${GOPATH}/src/github.com/jgsqware/clairctl

RUN glide install -v
RUN go get -u github.com/jteeuwen/go-bindata/...
RUN go generate ./clair
RUN go build -o /usr/local/bin/clairctl -ldflags "-X github.com/jgsqware/clairctl/cmd.version=${CLAIRCTL_VERSION}-${CLAIRCTL_COMMIT}"

FROM alpine:3.5
RUN apk --no-cache add ca-certificates \
 && adduser clairctl -D \
 && mkdir -p /reports \
 && chown -R clairctl:clairctl /reports /tmp \
 && echo $'clair:\n\
  port: 6060\n\
  healthPort: 6061\n\
  uri: http://clair\n\
  priority: Low\n\
  report:\n\
    path: /reports\n\
    format: html\n\
clairctl:\n\
  port: 44480\n\
  tempfolder: /tmp'\
    > /home/clairctl/clairctl.yml \
 && chown -R clairctl:clairctl /home/clairctl

COPY --from=builder /usr/local/bin/clairctl /usr/bin/docker /usr/bin/

USER clairctl

WORKDIR /home/clairctl/

EXPOSE 44480

CMD ["/usr/sbin/crond", "-f"]

VOLUME ["/tmp/", "/reports/"]
