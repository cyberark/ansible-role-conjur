FROM golang:1.8

# Go dep!
RUN go get -u github.com/golang/dep/...

# build directories
RUN mkdir /go/src/conjur-fetch
WORKDIR /go/src/conjur-fetch

# ensure
ADD . /go/src/conjur-fetch
RUN dep ensure
