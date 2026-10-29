package main

import (
	"testing"

	"github.com/redis/go-redis/v9"
)

func TestNewRedisClientStandalone(t *testing.T) {
	client, err := newRedisClient("redis://localhost:6379", false)
	if err != nil {
		t.Fatalf("newRedisClient retornou erro: %v", err)
	}
	defer client.Close()
	if _, ok := client.(*redis.Client); !ok {
		t.Fatalf("esperava *redis.Client, recebeu %T", client)
	}
}

func TestNewRedisClientClusterTLS(t *testing.T) {
	client, err := newRedisClient("rediss://:token@cluster.example.com:6379", true)
	if err != nil {
		t.Fatalf("newRedisClient retornou erro: %v", err)
	}
	defer client.Close()
	if _, ok := client.(*redis.ClusterClient); !ok {
		t.Fatalf("esperava *redis.ClusterClient, recebeu %T", client)
	}
}

func TestNewRedisClientRejectsInvalidClusterURL(t *testing.T) {
	if _, err := newRedisClient("http://cluster.example.com:6379", true); err == nil {
		t.Fatal("esperava erro para esquema inválido")
	}
}
