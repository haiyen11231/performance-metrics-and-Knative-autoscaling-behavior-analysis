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

build-server:
	docker build -t haiyen11231/lab-project-server:1.0 -f server/Dockerfile .

build-client:
	docker build -t haiyen11231/lab-project-client:1.0 -f client/Dockerfile .

push-server:
	docker push haiyen11231/lab-project-server:1.0

push-client:
	docker push haiyen11231/lab-project-client:1.0

deploy-server:
	kubectl apply -f deployment/worker-service.yaml

deploy-client:
	kubectl apply -f deployment/load-driver-service.yaml

all: gen build-server build-client push-server push-client deploy-server deploy-client