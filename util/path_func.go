package util

import (
	"os"
	"path/filepath"
)

// FullPathWithEnv constructs and returns the full path using the specified go variable and environment variable
func FullPathWithEnv(variable, envarName string) string {
	var prefix string

	// Find the specified environment variable value
	if value := os.Getenv(envarName); value != "" {
		prefix = value
	}

	return filepath.Join(prefix, variable)
}
