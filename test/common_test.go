package test

import (
	"os"
	"path/filepath"
	"testing"
)

func getKubeConfigPath(t *testing.T) string {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatal(err)
	}
	return filepath.Join(home, ".kube", "config")
}
