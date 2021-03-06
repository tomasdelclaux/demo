module prom-kafka-writer

go 1.13

require (
	github.com/golang/protobuf v1.3.2
	github.com/golang/snappy v0.0.1
	github.com/gorilla/mux v1.7.3
	github.com/grpc-ecosystem/grpc-gateway v1.11.3 // indirect
	github.com/prometheus/client_golang v1.2.1
	github.com/prometheus/common v0.7.0
	github.com/prometheus/prometheus v2.5.0+incompatible
	github.com/stretchr/testify v1.4.0
	go.uber.org/zap v1.12.0
	google.golang.org/genproto v0.0.0-20191028173616-919d9bdd9fe6 // indirect
	google.golang.org/grpc v1.24.0 // indirect
	gopkg.in/confluentinc/confluent-kafka-go.v1 v1.1.0
)
