FROM golang:1.21.6-alpine3.19
RUN apk add -U make gcc musl-dev bash curl git
COPY . .
RUN set
RUN make all
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.31.4/bin/linux/amd64/kubectl && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl
