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

- Install Helm
  https://helm.sh/docs/intro/install/

```
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

- Add the official Helm repositories for Prometheus and Grafana

```
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo add grafana https://grafana.github.io/helm-charts
   helm repo update
```

- Install kube-prometheus-stack
  This automatically installs Prometheus, Alertmanager, Grafana, ServiceMonitors for comprehensive Kubernetes monitoring.

```
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

- Verify pods:

```
kubectl get pods -n monitoring
```

- Port-forward to access dashboards locally:

```
bash scripts/port_forward.sh
```

kubectl --namespace monitoring get pods -l "release=monitoring"

Get Grafana 'admin' user password by running:

kubectl --namespace monitoring get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Access Grafana local instance:

export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
port forward on node 0, and then ssh tunel in local machine:

```
ssh -L 3000:127.0.0.1:3000 haiyen@pc786.emulab.net
ssh -L 9090:127.0.0.1:9090 haiyen@pc786.emulab.net
or
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 haiyen@pc786.emulab.net
```

then can access Grafana and Prometheus from local machine: Grafana: http://localhost:3000, Prometheus: http://localhost:9090

Grafana:

- Username:

```
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-user}" | base64 --decode
```

- Password:

```
 kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

whether using NodePort or port forwarding???
