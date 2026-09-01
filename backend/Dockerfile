FROM golang:1.26.7-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o devboard-backend .

FROM alpine:3.24

RUN addgroup -S devboard && \
    adduser -S devboard -G devboard

WORKDIR /app

COPY --from=builder /app/devboard-backend ./devboard-backend

RUN chown devboard:devboard ./devboard-backend

USER devboard

EXPOSE 8080

ENTRYPOINT ["./devboard-backend"]
