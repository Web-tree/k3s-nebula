package test

import (
	"crypto/tls"
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestLonghorn(t *testing.T) {
	t.Parallel()

	kubeConfigPath := getKubeConfigPath(t)
	options := k8s.NewKubectlOptions("", kubeConfigPath, "longhorn-system")

	t.Run("TestNamespace", func(t *testing.T) {
		t.Parallel()
		_, err := k8s.GetNamespaceE(t, options, "longhorn-system")
		assert.NoError(t, err, "Namespace longhorn-system should exist")
	})

	t.Run("TestPods", func(t *testing.T) {
		t.Parallel()
		expectedPods := []string{"longhorn-manager", "longhorn-ui"}
		for _, podNamePrefix := range expectedPods {
			pods := k8s.ListPods(t, options, metav1.ListOptions{})
			found := false
			for _, pod := range pods {
				if strings.HasPrefix(pod.Name, podNamePrefix) {
					found = true
					k8s.WaitUntilPodAvailable(t, options, pod.Name, 10, 5*time.Second)
					break
				}
			}
			assert.True(t, found, "Pod with prefix %s should exist in longhorn-system namespace", podNamePrefix)
		}
	})

	t.Run("TestStorageClass", func(t *testing.T) {
		t.Parallel()
		// Using kubectl directly to avoid dependency issues with storagev1
		output, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "sc", "longhorn", "-o", "jsonpath={.metadata.annotations.storageclass\\.kubernetes\\.io/is-default-class}")
		assert.NoError(t, err, "StorageClass longhorn should exist")
		assert.Equal(t, "true", output, "Longhorn should be default storage class")
	})

	t.Run("TestConnectivity", func(t *testing.T) {
		t.Parallel()
		tlsConfig := &tls.Config{InsecureSkipVerify: true}
		url := "https://longhorn.example.com"
		http_helper.HttpGetWithRetryWithCustomValidation(
			t,
			url,
			tlsConfig,
			30,
			5*time.Second,
			func(statusCode int, body string) bool {
				return statusCode == 200
			},
		)
	})
}
