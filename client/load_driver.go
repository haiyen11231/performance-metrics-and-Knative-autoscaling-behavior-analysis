package main

import (
	"context"
	"log"
	"time"

	pb "github.com/performance-metrics-and-Knative-autoscaling-behavior-analysis/proto/pb"
	"google.golang.org/grpc"
)

func main() {
	conn, err := grpc.Dial("localhost:50051", grpc.WithInsecure(), grpc.WithBlock())

	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}

	defer conn.Close()

	client := pb.NewLoadWorkerClient(conn)

	// Requests per second
	rps := 5
	// Duration for each busy-spin
	duration := 1 * time.Second

	for {
		start := time.Now()
		for i := 0; i < rps; i++ {
			go func() {
				req := &pb.WorkRequest{DurationMs: int64(duration / time.Millisecond)}
				startReq := time.Now()
				_, err := client.InvokeWorker(context.Background(), req)

				if err != nil {
					log.Printf("could not invoke worker: %v", err)
				}

				latency := time.Since(startReq)
				log.Printf("E2E latency: %v", latency)
			}()
		}

		time.Sleep(time.Second - time.Since(start))
	}
}
