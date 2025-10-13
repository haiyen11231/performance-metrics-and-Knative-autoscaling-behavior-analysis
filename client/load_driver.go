package main

import (
	"context"
	"encoding/csv"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	pb "github.com/performance-metrics-and-Knative-autoscaling-behavior-analysis/proto/pb"
	"google.golang.org/grpc"
)

var (
	clientRequestCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "load_driver_requests_total",
			Help: "Total number of requests made by load driver",
		},
		[]string{"status"},
	)

	clientRequestLatency = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "load_driver_request_latency_ms",
		Help:    "Load driver observing request latency in milliseconds",
		Buckets: prometheus.ExponentialBuckets(1, 2, 15),
	})
)

func init() {
	prometheus.MustRegister(clientRequestCounter, clientRequestLatency)
}

// Convert current time to milliseconds
func nowMs() int64 {
    return time.Now().UnixNano() / int64(time.Millisecond)
}

// Generate requests and record latency
func main() {
	// target (DNS name): worker.default.svc.cluster.local:50051 
	// if the worker is defined in deployment "networking.knative.dev/visibility: "cluster-local""
	// and load driver must run in-cluster

	// otherwise use the external DNS name with port 80 (http)
	// use Knative external URL: worker.default.192.168.1.240.sslip.io:80
	// but that will go through gateway and may add latency
	var (
		target    = flag.String("target", "worker.default.svc.cluster.local:50051", "target worker address")
		rps       = flag.Int("rps", 5, "requests per second")
		spinInMs    = flag.Int("spin-ms", 100, "worker busy spin in milliseconds - simulate CPU load")
		duration  = flag.Duration("duration", 12*time.Minute, "total duration to run")
		outFile   = flag.String("out", "/out/results.csv", "CSV output path (inside pod)")
		metricsPort = flag.Int("metrics-port", 2113, "load driver Prometheus metrics port")
	)
	flag.Parse()

	// Start load driver Prometheus metrics server
	http.Handle("/metrics", promhttp.Handler())
	go func() {
		addr := fmt.Sprintf(":%d", *metricsPort)
		log.Printf("starting load driver metrics endpoint at %s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Fatalf("failed to start load driver metrics server: %v", err)
		}
	}()

	// Connect to Worker via gRPC
	log.Println("Client started")
    log.Printf("Dialing %s ...", *target)
	conn, err := grpc.Dial(*target, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	log.Println("Connected successfully")
	client := pb.NewLoadWorkerClient(conn)

	// Setup CSV logging
	csvFile, err := os.Create(*outFile)
	if err != nil {
		log.Fatalf("failed to create output file: %v", err)
	}
	defer csvFile.Close()
	csvWriter := csv.NewWriter(csvFile)
	defer csvWriter.Flush()
	// Write CSV header
	_ = csvWriter.Write([]string{"timestamp_ms", "rps", "spin_ms", "seq", "latency_ms", "status"})

	// RPS-based ticker - pacing requests
	requestInterval := time.Duration(1e9 / *rps)
	ticker := time.NewTicker(requestInterval) // trigger a request every interval
	defer ticker.Stop()
	stop := time.After(*duration)

	var seq uint64
	var wg sync.WaitGroup
	var total uint64
	var failures uint64
	
	// Generate a steady stream of concurrent load at target RPS
	for {
		select {
		case <-stop:
			wg.Wait()
			log.Printf("Run finished: total=%d failures=%d", total, failures)
			return
		case t := <-ticker.C:
			wg.Add(1)
			seqVal := atomic.AddUint64(&seq, 1)
			atomic.AddUint64(&total, 1)
			go func(seq uint64, start time.Time) {
				defer wg.Done()
				ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
				defer cancel()
				
				// Invoke worker
				req := &pb.WorkRequest{
					DurationMs: int64(*spinInMs),
				}
				startReq := time.Now()
				_, err := client.InvokeWorker(ctx, req)
				latency := time.Since(startReq).Milliseconds()

				// Record metrics and log to CSV
				if err != nil {
					log.Printf("could not invoke worker: %v", err)
					clientRequestCounter.WithLabelValues("failure").Inc()
					atomic.AddUint64(&failures, 1)
					_ = csvWriter.Write([]string{
						fmt.Sprintf("%d", start.UnixNano()/int64(time.Millisecond)),
						fmt.Sprintf("%d", *rps),
						fmt.Sprintf("%d", *spinInMs),
						fmt.Sprintf("%d", seq),
						fmt.Sprintf("%d", latency),
						"failure",
					})
				} else {
					log.Printf("Request %d processed in %d ms", seq, latency)
					clientRequestCounter.WithLabelValues("success").Inc()
					_ = csvWriter.Write([]string{
						fmt.Sprintf("%d", start.UnixNano()/int64(time.Millisecond)),
						fmt.Sprintf("%d", *rps),
						fmt.Sprintf("%d", *spinInMs),
						fmt.Sprintf("%d", seq),
						fmt.Sprintf("%d", latency),
						"success",
					})
				}
				clientRequestLatency.Observe(float64(latency))
			}(seqVal, t)
		}
	}
}
