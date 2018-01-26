FROM golang:1.9.3-alpine

RUN apk update && apk add git
WORKDIR /
RUN go get github.com/gorilla/websocket
COPY server.go /

RUN adduser -D user
USER user

EXPOSE 8080

CMD ["go", "run", "server.go"]