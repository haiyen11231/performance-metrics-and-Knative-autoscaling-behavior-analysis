package main

import (
	"context"
	"log"
	"net"
	"time"

	pb "github.com/performance-metrics-and-Knative-autoscaling-behavior-analysis/proto/pb"
	"google.golang.org/grpc"
)

type Server struct {
	pb.UnimplementedLoadWorkerServer
}

// Simulates load and responds
func (s *Server) InvokeWorker(ctx context.Context, req *pb.WorkRequest) (*pb.WorkResponse, error) {
	duration := time.Duration(req.DurationMs) * time.Millisecond
	end := time.Now().Add(duration)

	for time.Now().Before(end) {
		// Busy-spin loop
	}

	return &pb.WorkResponse{Message: "Acknowledged"}, nil

	// start := time.Now()
    // end := start.Add(time.Duration(req.DurationMs) * time.Millisecond)
    // for time.Now().Before(end) {
    //     // busy spin
    // }
    // elapsed := time.Since(start).Milliseconds()
    // return &pb.WorkResponse{Message: fmt.Sprintf("Processed in %d ms", elapsed)}, nil
}

func main() {
	// Setting up a TCP listener on port 50051
	lis, err := net.Listen("tcp", ":50051")

	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	// Creating a pointer to an instance of 'Server' struct
	// that is defined to implement 'LoadWorkerServer' interface generated from '.proto' file
	server := &Server{}
	// Creating a gRPC server
	grpcServer := grpc.NewServer()
	// Registering the 'Server' instance (LoadWorker service implementation) with the gRPC server
	pb.RegisterLoadWorkerServer(grpcServer, server)
	log.Printf("Server listening at %v", lis.Addr())

	// Starting the gRPC server, blocking the current goroutine & starting handling incoming connections
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
