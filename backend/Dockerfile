# Stage 1 - Build Go application
FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o devboard-backend .


# Stage 2 - Small runtime image
FROM alpine:3.20

WORKDIR /app

RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

COPY --from=builder /app/devboard-backend ./devboard-backend

RUN chmod +x ./devboard-backend

USER appuser

EXPOSE 8080

ENTRYPOINT ["./devboard-backend"]
