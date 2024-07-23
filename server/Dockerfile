FROM golang:1.22 as builder

# Install protobuf compiler
RUN apt-get update && apt-get install -y protobuf-compiler

# Install protoc-gen-go and protoc-gen-go-grpc
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Set the working directory inside the container
WORKDIR /app

# Copy the go.mod and go.sum files to the container
COPY go.mod go.sum ./

# Download all dependencies specified in go.mod and go.sum
RUN go mod download

# Set the working directory for the protobuf files and server source code
WORKDIR /app/proto

# Copy the protobuf files to the container
COPY proto/ ./

# Generate Go code from protobuf definitions
RUN protoc --go_out=./pb --go-grpc_out=./pb *.proto

# Set the working directory for the server source code
WORKDIR /app/server

# Copy the server source code to the container
COPY server/ ./

# Build the server application binary for Linux (amd64 architecture)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /worker worker.go

# Use a minimal image for running the server
FROM alpine:latest

# Copy the built binary from the builder stage to the final image
COPY --from=builder /worker /worker

# Set the entrypoint to run the server application
ENTRYPOINT ["/worker"]
