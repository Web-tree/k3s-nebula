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

func TestArgoCD(t *testing.T) {
	t.Parallel()

	kubeConfigPath := getKubeConfigPath(t)
	options := k8s.NewKubectlOptions("", kubeConfigPath, "argocd")

	t.Run("TestNamespace", func(t *testing.T) {
		t.Parallel()
		_, err := k8s.GetNamespaceE(t, options, "argocd")
		assert.NoError(t, err, "Namespace argocd should exist")
	})

	t.Run("TestPods", func(t *testing.T) {
		t.Parallel()
		expectedPods := []string{"argocd-server", "argocd-repo-server", "argocd-application-controller"}
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
			assert.True(t, found, "Pod with prefix %s should exist in argocd namespace", podNamePrefix)
		}
	})

	t.Run("TestIngress", func(t *testing.T) {
		t.Parallel()
		ingress := k8s.GetIngress(t, options, "argocd-server")
		assert.NotNil(t, ingress, "Ingress argocd-server should exist")
	})

	t.Run("TestConnectivity", func(t *testing.T) {
		t.Parallel()
		tlsConfig := &tls.Config{InsecureSkipVerify: true}
		url := "https://argocd.example.com"
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
