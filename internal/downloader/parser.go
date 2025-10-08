package downloader

import (
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
)

// ParseDirectoryListing fetches and parses an HTML directory listing
func ParseDirectoryListing(url string) ([]string, error) {
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch directory listing: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// Parse HTML for file links
	// Pattern: <a href="filename">filename</a>
	re := regexp.MustCompile(`<a href="([^"]+)">`)
	matches := re.FindAllStringSubmatch(string(body), -1)

	var files []string
	for _, match := range matches {
		if len(match) > 1 {
			filename := match[1]
			// Skip parent directory and subdirectories
			if filename == "../" || strings.HasSuffix(filename, "/") {
				continue
			}
			// Skip signature and metadata files
			if strings.HasSuffix(filename, ".sig") || 
			   strings.HasSuffix(filename, ".crt") || 
			   strings.HasSuffix(filename, ".sigstore") ||
			   strings.HasSuffix(filename, ".spdx.json") {
				continue
			}
			files = append(files, filename)
		}
	}

	return files, nil
}

