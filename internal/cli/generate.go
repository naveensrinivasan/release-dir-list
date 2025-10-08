package cli

import (
	"encoding/json"
	"fmt"

	"github.com/naveensrinivasan/release-dir-list/internal/downloader"
	"github.com/naveensrinivasan/release-dir-list/internal/generator"
	"github.com/spf13/cobra"
)

var (
	sourceURL  string
	outputDir  string
	projectName string
	skipDownload bool
)

func init() {
	rootCmd.AddCommand(generateCmd)
	
	generateCmd.Flags().StringVarP(&sourceURL, "url", "u", "https://www.python.org/ftp/python/3.14.0/", "Source URL to fetch files from")
	generateCmd.Flags().StringVarP(&outputDir, "output", "o", "releases", "Output directory for generated structure")
	generateCmd.Flags().StringVarP(&projectName, "project", "p", "python", "Project name for PyPI repository")
	generateCmd.Flags().BoolVar(&skipDownload, "skip-download", false, "Skip downloading files (use existing)")
}

var generateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate PyPI Simple repository structure",
	Long: `Downloads release files from a URL, categorizes them by OS,
calculates SHA256 checksums, and generates PyPI Simple format HTML indexes
for Linux, macOS, and Windows.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		LogInfo("Starting generation", map[string]string{
			"source": sourceURL,
			"output": outputDir,
			"project": projectName,
		})

		// Step 1: Parse the directory listing
		LogInfo("Parsing directory listing", nil)
		files, err := downloader.ParseDirectoryListing(sourceURL)
		if err != nil {
			LogError("Failed to parse directory listing", err)
			return fmt.Errorf("failed to parse directory: %w", err)
		}
		LogDebug("Found files", map[string]int{"count": len(files)})

		// Step 2: Categorize files by OS
		LogInfo("Categorizing files by OS", nil)
		categorized := downloader.CategorizeFiles(files)
		LogInfo("Categorization complete", map[string]any{
			"linux": len(categorized.Linux),
			"mac": len(categorized.Mac),
			"windows": len(categorized.Windows),
		})

		// Step 3: Download files and calculate checksums
		var artifacts map[string][]generator.Artifact
		if !skipDownload {
			LogInfo("Downloading files and calculating checksums", nil)
			artifacts, err = downloader.DownloadAndHash(sourceURL, categorized, outputDir)
			if err != nil {
				LogError("Failed to download files", err)
				return fmt.Errorf("failed to download: %w", err)
			}
		} else {
			LogInfo("Skipping download, using existing files", nil)
			artifacts = convertToArtifacts(categorized, sourceURL)
		}

		// Step 4: Generate PyPI Simple HTML structure
		LogInfo("Generating PyPI Simple repository structure", nil)
		err = generator.GeneratePyPIStructure(outputDir, projectName, artifacts)
		if err != nil {
			LogError("Failed to generate structure", err)
			return fmt.Errorf("failed to generate structure: %w", err)
		}

		// Output result as JSON
		result := map[string]any{
			"success": true,
			"output_directory": outputDir,
			"project": projectName,
			"platforms": map[string]int{
				"linux": len(artifacts["linux"]),
				"mac": len(artifacts["mac"]),
				"windows": len(artifacts["windows"]),
			},
		}
		
		output, _ := json.Marshal(result)
		fmt.Println(string(output))
		
		return nil
	},
}

func convertToArtifacts(categorized downloader.CategorizedFiles, baseURL string) map[string][]generator.Artifact {
	artifacts := make(map[string][]generator.Artifact)
	
	for _, file := range categorized.Linux {
		artifacts["linux"] = append(artifacts["linux"], generator.Artifact{
			Filename: file,
			URL:      baseURL + file,
			SHA256:   "", // Will need to calculate later
		})
	}
	
	for _, file := range categorized.Mac {
		artifacts["mac"] = append(artifacts["mac"], generator.Artifact{
			Filename: file,
			URL:      baseURL + file,
			SHA256:   "",
		})
	}
	
	for _, file := range categorized.Windows {
		artifacts["windows"] = append(artifacts["windows"], generator.Artifact{
			Filename: file,
			URL:      baseURL + file,
			SHA256:   "",
		})
	}
	
	return artifacts
}

