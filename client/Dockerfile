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

# Set the working directory for proto files
WORKDIR /app/proto
# Copy proto files
COPY proto/ ./
# Generate Go code from protobuf definitions
RUN protoc --go_out=./pb --go-grpc_out=./pb *.proto

# Set the working directory for the client source code
WORKDIR /app/client
# Copy client source code
COPY client/ ./

# Build the client application binary for Linux (amd64 architecture)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /load_driver load_driver.go

# Use a minimal image for running the client
FROM alpine:latest

# Copy the built binary from the builder stage to the final image
COPY --from=builder /load_driver /load_driver

# Set the entrypoint to run the client application
ENTRYPOINT ["/load_driver"]