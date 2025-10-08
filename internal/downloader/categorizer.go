package downloader

import (
	"strings"
)

// CategorizedFiles holds files categorized by operating system
type CategorizedFiles struct {
	Linux   []string
	Mac     []string
	Windows []string
}

// CategorizeFiles categorizes files by OS based on filename patterns
func CategorizeFiles(files []string) CategorizedFiles {
	var categorized CategorizedFiles

	for _, file := range files {
		lowerFile := strings.ToLower(file)

		switch {
		// macOS files
		case strings.Contains(lowerFile, "macos") || 
		     strings.Contains(lowerFile, "darwin") ||
		     strings.HasSuffix(lowerFile, ".pkg") ||
		     strings.HasSuffix(lowerFile, ".dmg"):
			categorized.Mac = append(categorized.Mac, file)

		// Windows files
		case strings.HasSuffix(lowerFile, ".exe") ||
		     strings.HasSuffix(lowerFile, ".msi") ||
		     (strings.HasSuffix(lowerFile, ".zip") && 
		      (strings.Contains(lowerFile, "win") || 
		       strings.Contains(lowerFile, "embed"))):
			categorized.Windows = append(categorized.Windows, file)

		// Linux files (tar.xz, tar.gz, tgz)
		case strings.HasSuffix(lowerFile, ".tar.xz") ||
		     strings.HasSuffix(lowerFile, ".tar.gz") ||
		     strings.HasSuffix(lowerFile, ".tgz"):
			// Exclude if it's specifically for another OS
			if !strings.Contains(lowerFile, "macos") && 
			   !strings.Contains(lowerFile, "win") {
				categorized.Linux = append(categorized.Linux, file)
			}

		// Default to Linux for other archives
		default:
			if strings.HasSuffix(lowerFile, ".tar") ||
			   strings.HasSuffix(lowerFile, ".bz2") ||
			   strings.HasSuffix(lowerFile, ".xz") {
				categorized.Linux = append(categorized.Linux, file)
			}
		}
	}

	return categorized
}

