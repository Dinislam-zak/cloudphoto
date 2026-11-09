package store

import (
	"context"
	"errors"
	"io"
	"sort"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

const albumsPrefix = "album/"

type Store struct {
	client *s3.Client
	bucket string
}

func New(client *s3.Client, bucket string) *Store {
	return &Store{client: client, bucket: bucket}
}

func albumPrefix(album string) string {
	return albumsPrefix + album + "/"
}

func markerKey(album string) string {
	return albumPrefix(album)
}

func (s *Store) ListAlbums(ctx context.Context) ([]string, error) {
	paginator := s3.NewListObjectsV2Paginator(s.client, &s3.ListObjectsV2Input{
		Bucket:    aws.String(s.bucket),
		Prefix:    aws.String(albumsPrefix),
		Delimiter: aws.String("/"),
	})
	var albums []string
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		for _, p := range page.CommonPrefixes {
			if p.Prefix == nil {
				continue
			}
			name := strings.TrimPrefix(*p.Prefix, albumsPrefix)
			name = strings.TrimSuffix(name, "/")
			if name != "" {
				albums = append(albums, name)
			}
		}
	}
	sort.Strings(albums)
	return albums, nil
}

func (s *Store) AlbumExists(ctx context.Context, album string) (bool, error) {
	resp, err := s.client.ListObjectsV2(ctx, &s3.ListObjectsV2Input{
		Bucket:  aws.String(s.bucket),
		Prefix:  aws.String(albumPrefix(album)),
		MaxKeys: aws.Int32(1),
	})
	if err != nil {
		return false, err
	}
	return len(resp.Contents) > 0, nil
}

func (s *Store) ListPhotos(ctx context.Context, album string) ([]string, error) {
	prefix := albumPrefix(album)
	paginator := s3.NewListObjectsV2Paginator(s.client, &s3.ListObjectsV2Input{
		Bucket: aws.String(s.bucket),
		Prefix: aws.String(prefix),
	})
	var photos []string
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, err
		}
		for _, obj := range page.Contents {
			if obj.Key == nil {
				continue
			}
			key := *obj.Key
			if key == prefix {
				continue
			}
			photos = append(photos, strings.TrimPrefix(key, prefix))
		}
	}
	sort.Strings(photos)
	return photos, nil
}

func (s *Store) EnsureAlbum(ctx context.Context, album string) error {
	exists, err := s.AlbumExists(ctx, album)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}
	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(markerKey(album)),
		Body:   strings.NewReader(""),
	})
	return err
}

func (s *Store) UploadPhoto(ctx context.Context, album, filename string, body io.Reader) error {
	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(albumPrefix(album) + filename),
		Body:        body,
		ContentType: aws.String("image/jpeg"),
	})
	return err
}

func (s *Store) DownloadPhoto(ctx context.Context, album, filename string, w io.Writer) error {
	resp, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(albumPrefix(album) + filename),
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, err = io.Copy(w, resp.Body)
	return err
}

func (s *Store) PhotoExists(ctx context.Context, album, filename string) (bool, error) {
	_, err := s.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(albumPrefix(album) + filename),
	})
	if err != nil {
		var nf *types.NotFound
		if errors.As(err, &nf) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (s *Store) DeletePhoto(ctx context.Context, album, filename string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(albumPrefix(album) + filename),
	})
	return err
}

func (s *Store) DeleteAlbum(ctx context.Context, album string) error {
	prefix := albumPrefix(album)
	paginator := s3.NewListObjectsV2Paginator(s.client, &s3.ListObjectsV2Input{
		Bucket: aws.String(s.bucket),
		Prefix: aws.String(prefix),
	})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return err
		}
		if len(page.Contents) == 0 {
			continue
		}
		var ids []types.ObjectIdentifier
		for _, obj := range page.Contents {
			if obj.Key != nil {
				ids = append(ids, types.ObjectIdentifier{Key: obj.Key})
			}
		}
		if len(ids) == 0 {
			continue
		}
		_, err = s.client.DeleteObjects(ctx, &s3.DeleteObjectsInput{
			Bucket: aws.String(s.bucket),
			Delete: &types.Delete{Objects: ids},
		})
		if err != nil {
			return err
		}
	}
	return nil
}
