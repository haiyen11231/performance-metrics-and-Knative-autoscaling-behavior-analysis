# ===== Stage 1: Builder =====
FROM golang:1.22.4-alpine AS builder

WORKDIR /app

COPY . .
RUN go mod download

# Build the worker binary for Linux x86_64
RUN GOOS=linux GOARCH=amd64 go build -o worker ./server/worker.go

# ===== Stage 2: Runtime =====
FROM gcr.io/distroless/base-debian11

# Copy the compiled binary
COPY --from=builder /app/worker /worker

EXPOSE 50051 2112 
# Set the entrypoint to run the server application
ENTRYPOINT ["/worker"]
