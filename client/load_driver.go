package main

import (
	"context"
	"log"
	"time"

	pb "github.com/performance-metrics-and-Knative-autoscaling-behavior-analysis/proto/pb"
	"google.golang.org/grpc"
)

// Generates requests and records latency
func main() {
	log.Println("Client started")
    log.Println("Connecting to target: worker:50051")

	conn, err := grpc.Dial("worker:50051", grpc.WithInsecure(), grpc.WithBlock())

	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}

	defer conn.Close()

	log.Println("Connected successfully")

	client := pb.NewLoadWorkerClient(conn)

	// Requests per second
	rps := 5
	// Duration for each busy-spin
	duration := 1 * time.Second
	// Test duration in seconds
	testDuration := 10 * time.Second
	end := time.Now().Add(testDuration)

	ticker := time.NewTicker(time.Second / time.Duration(rps))
	defer ticker.Stop()

	for time.Now().Before(end) {
		<-ticker.C
		go func() {
			req := &pb.WorkRequest{DurationMs: int64(duration / time.Millisecond)}
			startReq := time.Now()
			_, err := client.InvokeWorker(context.Background(), req)
			latency := time.Since(startReq)
			if err != nil {
				log.Printf("could not invoke worker: %v", err)
			} else {
				log.Printf("E2E latency: %v", latency)
			}
		}()
	}
}
