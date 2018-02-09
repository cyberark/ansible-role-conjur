FROM golang:1.8

# Go dep!
RUN go get -u github.com/golang/dep/...

# build directories
RUN mkdir /go/src/conjur-env
WORKDIR /go/src/conjur-env

# ensure
ADD . /go/src/conjur-env
RUN dep ensure
