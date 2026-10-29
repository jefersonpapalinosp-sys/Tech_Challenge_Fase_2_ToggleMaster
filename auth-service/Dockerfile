FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN gofmt -w *.go && \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/auth-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates && \
    addgroup -S -g 10001 app && \
    adduser -S -D -H -u 10001 -G app app
COPY --from=builder /out/auth-service /usr/local/bin/auth-service
USER 10001:10001
EXPOSE 8001
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://localhost:8001/health || exit 1
ENTRYPOINT ["/usr/local/bin/auth-service"]
