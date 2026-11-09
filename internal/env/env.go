package env

import (
	"errors"
	"os"
)

type Config struct {
	Bucket    string
	AccessKey string
	SecretKey string
}

var ErrMissingEnv = errors.New("Не заданы переменные окружения")

func Load() (*Config, error) {
	for _, v := range []string{"BUCKET", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"} {
		if os.Getenv(v) == "" {
			return nil, ErrMissingEnv
		}
	}
	return &Config{
		Bucket:    os.Getenv("BUCKET"),
		AccessKey: os.Getenv("AWS_ACCESS_KEY_ID"),
		SecretKey: os.Getenv("AWS_SECRET_ACCESS_KEY"),
	}, nil
}
