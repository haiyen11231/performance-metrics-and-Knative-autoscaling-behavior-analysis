# Performance metrics and Knative's autoscaling behavior analysis

This project focuses on analyzing Knative's autoscaling behavior through a custom setup and experimentation. The tasks include writing a **Load Driver program** and a **Worker function**, setting up a two-node Knative cluster, and measuring performance metrics during the process.

## Directory Structure

```plaintext
performance-metrics-and-Knative-autoscaling-behavior-analysis/
│
├── client/
│   ├── Dockerfile
│   └── load_driver.go
│
├── deployment/
│   ├── load-driver-service.yaml
│   └── worker-service.yaml
│
├── proto/
│   ├── pb/
│   │   ├── load_worker_grpc.pb.go
│   │   └── load_worker.pb.go
│   │
│   └── load_worker.proto
|
├── server/
│   ├── Dockerfile
│   └── worker.go
|
├── .gitignore
├── app.env
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

## Prerequisites

Before you begin, ensure that you have the following installed:

- **Go**
- **gRPC Tools** (Protocol Buffers and gRPC Go)
- **Make**
- **Docker**
- **Kubernetes**
- **Knative**

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/haiyen11231/performance-metrics-and-Knative-autoscaling-behavior-analysis.git
   cd performance-metrics-and-Knative-autoscaling-behavior-analysis
   ```

2. Create the app.env file:

Create a `app.env` file in the root directory of the project. This file should contain the environment variables required for the application to run. Here's a sample `app.env` file:

```env
PORT=port
```

Update the values with your own configuration:

- **`PORT`**: Define the port number on which the server will listen (e.g., 50051).

3. Install dependencies:

   ```bash
   go mod tidy
   ```

4. Start the development server:

   ```bash
   make server
   ```

5. Start the development client:

   ```bash
   make client
   ```
