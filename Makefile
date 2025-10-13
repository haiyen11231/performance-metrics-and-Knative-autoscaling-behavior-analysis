# Protobuf generation
gen:
	protoc --go_out=./proto/pb --go-grpc_out=./proto/pb proto/*.proto

clean:
	rm ./proto/pb/*.go

# Build and run locally
.PHONY: server client

server:
	go run server/worker.go

client:
	go run client/load_driver.go

REG := haiyen11231
WORKER_IMG := $(REG)/worker:2.0
DRIVER_IMG := $(REG)/load-driver:2.0

build:
	docker build -t $(WORKER_IMG) -f server/Dockerfile .
	docker build -t $(DRIVER_IMG) -f client/Dockerfile .

push:
	docker push $(WORKER_IMG)
	docker push $(DRIVER_IMG)

# deploy: push
# 	kubectl apply -f deployment/worker-service.yaml
# 	kubectl apply -f deployment/load-driver-service.yaml

# build-server:
# 	docker build -t haiyen11231/worker:2.0 -f server/Dockerfile .

# build-client:
# 	docker build -t haiyen11231/load-driver:2.0 -f client/Dockerfile .

# push-server:
# 	docker push haiyen11231/worker:2.0

# push-client:
# 	docker push haiyen11231/load-driver:2.0

# deploy-server:
# 	kubectl apply -f deployment/worker-service.yaml

# deploy-client:
# 	kubectl apply -f deployment/load-driver-service.yaml

# all: gen build-server build-client push-server push-client deploy-server deploy-client