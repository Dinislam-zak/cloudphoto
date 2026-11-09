package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"cloudphoto/internal/env"
	"cloudphoto/internal/s3client"
	"cloudphoto/internal/store"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := env.Load()
	if err != nil {
		return err
	}
	args := os.Args[1:]
	if len(args) == 0 {
		return fmt.Errorf("Ошибка в аргументах")
	}
	cmd, rest := args[0], args[1:]
	switch cmd {
	case "list":
		return runList(cfg, rest)
	case "upload":
		return runUpload(cfg, rest)
	case "download":
		return runDownload(cfg, rest)
	case "delete":
		return runDelete(cfg, rest)
	case "mksite":
		return runMksite(cfg, rest)
	default:
		return fmt.Errorf("Ошибка в аргументах")
	}
}

func newStore(cfg *env.Config) (*store.Store, error) {
	ctx := context.Background()
	client, err := s3client.New(ctx, cfg.AccessKey, cfg.SecretKey)
	if err != nil {
		return nil, err
	}
	return store.New(client, cfg.Bucket), nil
}

func runList(cfg *env.Config, args []string) error {
	fs := flag.NewFlagSet("list", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	album := fs.String("album", "", "")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 {
		return fmt.Errorf("Ошибка в аргументах")
	}

	st, err := newStore(cfg)
	if err != nil {
		return err
	}
	ctx := context.Background()

	if *album == "" {
		albums, err := st.ListAlbums(ctx)
		if err != nil {
			return err
		}
		for _, a := range albums {
			fmt.Println(a)
		}
		return nil
	}

	exists, err := st.AlbumExists(ctx, *album)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("В фотоархиве нет альбома с именем %s", *album)
	}
	photos, err := st.ListPhotos(ctx, *album)
	if err != nil {
		return err
	}
	for _, p := range photos {
		fmt.Println(p)
	}
	return nil
}

func runUpload(cfg *env.Config, args []string) error {
	fs := flag.NewFlagSet("upload", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	album := fs.String("album", "", "")
	path := fs.String("path", ".", "")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 {
		return fmt.Errorf("Ошибка в аргументах")
	}
	if *album == "" || strings.Contains(*album, "/") {
		return fmt.Errorf("Ошибка в аргументах")
	}

	entries, err := os.ReadDir(*path)
	if err != nil {
		return fmt.Errorf("Каталог %s недоступен: %v", *path, err)
	}

	var photos []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		lower := strings.ToLower(name)
		if strings.HasSuffix(lower, ".jpg") || strings.HasSuffix(lower, ".jpeg") {
			photos = append(photos, name)
		}
	}
	if len(photos) == 0 {
		return fmt.Errorf("В каталоге %s нет фотографий", *path)
	}

	st, err := newStore(cfg)
	if err != nil {
		return err
	}
	ctx := context.Background()

	if err := st.EnsureAlbum(ctx, *album); err != nil {
		return fmt.Errorf("Не удалось создать альбом: %v", err)
	}

	for _, name := range photos {
		f, err := os.Open(filepath.Join(*path, name))
		if err != nil {
			return fmt.Errorf("Не удалось открыть %s: %v", name, err)
		}
		upErr := st.UploadPhoto(ctx, *album, name, f)
		f.Close()
		if upErr != nil {
			return fmt.Errorf("Не удалось загрузить %s: %v", name, upErr)
		}
	}
	return nil
}

func runDownload(cfg *env.Config, args []string) error {
	return fmt.Errorf("download: не реализовано")
}

func runDelete(cfg *env.Config, args []string) error {
	return fmt.Errorf("delete: не реализовано")
}

func runMksite(cfg *env.Config, args []string) error {
	return fmt.Errorf("mksite: не реализовано")
}
