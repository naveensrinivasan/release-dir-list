package cli

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	outputFormat string
	logLevel     string
)

// Execute runs the root command
func Execute() error {
	return rootCmd.Execute()
}

var rootCmd = &cobra.Command{
	Use:   "release-tool",
	Short: "Generate PyPI Simple repository structure from releases",
	Long: `A tool to generate PyPI Simple repository format from release files.
Supports multiple platforms (Linux, macOS, Windows) and generates
separate repository structures for Nexus proxy.`,
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&outputFormat, "output-format", "f", "json", "Output format (json, text)")
	rootCmd.PersistentFlags().StringVarP(&logLevel, "log-level", "l", "info", "Log level (debug, info, warn, error)")
}

// JSONLog represents a structured log entry
type JSONLog struct {
	Level   string `json:"level"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

// LogInfo logs an info message
func LogInfo(message string, data any) {
	log := JSONLog{
		Level:   "info",
		Message: message,
		Data:    data,
	}
	output, _ := json.Marshal(log)
	fmt.Fprintln(os.Stderr, string(output))
}

// LogError logs an error message
func LogError(message string, err error) {
	log := JSONLog{
		Level:   "error",
		Message: message,
		Data:    map[string]string{"error": err.Error()},
	}
	output, _ := json.Marshal(log)
	fmt.Fprintln(os.Stderr, string(output))
}

// LogDebug logs a debug message
func LogDebug(message string, data any) {
	if logLevel == "debug" {
		log := JSONLog{
			Level:   "debug",
			Message: message,
			Data:    data,
		}
		output, _ := json.Marshal(log)
		fmt.Fprintln(os.Stderr, string(output))
	}
}

