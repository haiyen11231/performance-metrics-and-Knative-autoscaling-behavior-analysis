gen:
	protoc --go_out=./proto/pb --go-grpc_out=./proto/pb proto/*.proto

	#protoc --proto_path=proto proto/*.proto --go_out=proto/pb --go-grpc_out=proto/pb
	# --go_out=plugins=grpc:. worker.proto

clean:
	rm ./proto/pb/*.go

server:
	go run server/worker.go

client:
	go run client/load_driver.go