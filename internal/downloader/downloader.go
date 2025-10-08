package downloader

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/naveensrinivasan/release-dir-list/internal/generator"
)

// DownloadAndHash downloads files and calculates their SHA256 checksums
func DownloadAndHash(baseURL string, categorized CategorizedFiles, outputDir string) (map[string][]generator.Artifact, error) {
	artifacts := make(map[string][]generator.Artifact)

	// Create temp directory for downloads
	tempDir := filepath.Join(outputDir, "temp-downloads")
	if err := os.MkdirAll(tempDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create temp directory: %w", err)
	}

	// Download Linux files
	for _, file := range categorized.Linux {
		artifact, err := downloadAndHashFile(baseURL, file, tempDir)
		if err != nil {
			return nil, fmt.Errorf("failed to download linux file %s: %w", file, err)
		}
		artifacts["linux"] = append(artifacts["linux"], artifact)
	}

	// Download Mac files
	for _, file := range categorized.Mac {
		artifact, err := downloadAndHashFile(baseURL, file, tempDir)
		if err != nil {
			return nil, fmt.Errorf("failed to download mac file %s: %w", file, err)
		}
		artifacts["mac"] = append(artifacts["mac"], artifact)
	}

	// Download Windows files
	for _, file := range categorized.Windows {
		artifact, err := downloadAndHashFile(baseURL, file, tempDir)
		if err != nil {
			return nil, fmt.Errorf("failed to download windows file %s: %w", file, err)
		}
		artifacts["windows"] = append(artifacts["windows"], artifact)
	}

	return artifacts, nil
}

func downloadAndHashFile(baseURL, filename, tempDir string) (generator.Artifact, error) {
	url := baseURL
	if !filepath.IsAbs(baseURL) && baseURL[len(baseURL)-1] != '/' {
		url += "/"
	}
	url += filename

	// Download file
	resp, err := http.Get(url)
	if err != nil {
		return generator.Artifact{}, fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return generator.Artifact{}, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	// Create temp file
	tempFile := filepath.Join(tempDir, filename)
	out, err := os.Create(tempFile)
	if err != nil {
		return generator.Artifact{}, fmt.Errorf("failed to create file: %w", err)
	}
	defer out.Close()

	// Calculate hash while downloading
	hash := sha256.New()
	multiWriter := io.MultiWriter(out, hash)

	size, err := io.Copy(multiWriter, resp.Body)
	if err != nil {
		return generator.Artifact{}, fmt.Errorf("failed to download file: %w", err)
	}

	checksum := hex.EncodeToString(hash.Sum(nil))

	return generator.Artifact{
		Filename: filename,
		URL:      url,
		SHA256:   checksum,
		Size:     size,
	}, nil
}

