FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN gofmt -w *.go && \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/evaluation-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates && \
    addgroup -S -g 10001 app && \
    adduser -S -D -H -u 10001 -G app app
COPY --from=builder /out/evaluation-service /usr/local/bin/evaluation-service
USER 10001:10001
EXPOSE 8004
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://localhost:8004/health || exit 1
ENTRYPOINT ["/usr/local/bin/evaluation-service"]
