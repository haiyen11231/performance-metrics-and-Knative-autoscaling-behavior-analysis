# ===== Stage 1: Builder =====
FROM golang:1.23.4-alpine AS builder

WORKDIR /app

COPY . .
RUN go mod download

# Build the load_driver binary for Linux x86_64
RUN GOOS=linux GOARCH=amd64 go build -o load_driver ./client/load_driver.go

# ===== Stage 2: Runtime =====
FROM gcr.io/distroless/base-debian11

# Copy the compiled binary
COPY --from=builder /app/load_driver /load_driver

EXPOSE 2113

# Set the entrypoint to run the client application
ENTRYPOINT ["/load_driver"]


