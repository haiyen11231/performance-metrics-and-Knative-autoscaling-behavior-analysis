package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"runtime"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	pb "github.com/performance-metrics-and-Knative-autoscaling-behavior-analysis/proto/pb"
	"google.golang.org/grpc"
)

var (
	requestCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_requests_total",
			Help: "Total number of requests received by the worker function",
		},
		[]string{"status"},
	)

	requestLatency = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "worker_request_latency_ms",
		Help:    "Request latency in milliseconds",
		Buckets: prometheus.ExponentialBuckets(1, 2, 15),
	})
)

func init() {
	prometheus.MustRegister(requestCounter, requestLatency)
}

// func RecordRequest(status string) {
// 	requestCounter.WithLabelValues(status).Inc()
// }

// func ObserveRequestLatency(durationMilliseconds float64) {
// 	requestLatency.Observe(durationMilliseconds)
// }

type server struct {
	pb.UnimplementedLoadWorkerServer
}

// Simulate CPU work for a fixed duration (busy-spin)
func busySpinInMs(ms int64) {
	start := time.Now()
	for {
		_ = runtime.NumGoroutine() // cheap op -> preventing the compiler from removing an empty loop -> ensuring busy-spin actually consumes CPU
		if time.Since(start) >= time.Duration(ms)*time.Millisecond {
			return
		}
	}
}

func (s *server) InvokeWorker(ctx context.Context, req *pb.WorkRequest) (*pb.WorkResponse, error) {
	start := time.Now()
	spinInMs := req.GetDurationMs()
	busySpinInMs(spinInMs)
	latency := time.Since(start).Milliseconds()

	requestCounter.WithLabelValues("success").Inc()
	requestLatency.Observe(float64(latency))

	return &pb.WorkResponse{
		Message: fmt.Sprintf("processed in %d ms by Worker ✅", spinInMs),
	}, nil
}

func main() {
	var (
		grpcPort   = flag.Int("grpc-port", 50051, "gRPC server port")
		metricsPort = flag.Int("worker-metrics-port", 2112, "worker Prometheus metrics port")
	)
	flag.Parse()

	// Start worker Prometheus metrics server
	http.Handle("/metrics", promhttp.Handler())
	go func() {
		addr := fmt.Sprintf(":%d", *metricsPort)
		log.Printf("starting worker metrics endpoint at %s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Fatalf("failed to start worker metrics server: %v", err)
		}
	}()

	// Start gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *grpcPort))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	grpcServer := grpc.NewServer()
	pb.RegisterLoadWorkerServer(grpcServer, &server{})
	log.Printf("Worker gRPC server listening on %v; PID %d", lis.Addr(), os.Getpid())
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
