FROM golang:1.22.3-alpine3.20
RUN apk add -U make gcc musl-dev bash curl git
COPY . .
RUN set
RUN make all
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl
