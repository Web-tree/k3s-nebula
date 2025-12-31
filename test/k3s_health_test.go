package test

import (
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestK3sClusterHealth(t *testing.T) {
	t.Parallel()

	kubeConfigPath := getKubeConfigPath(t)

	t.Run("TestNodesReady", func(t *testing.T) {
		t.Parallel()
		options := k8s.NewKubectlOptions("", kubeConfigPath, "default")
		nodes := k8s.GetNodes(t, options)
		assert.GreaterOrEqual(t, len(nodes), 2, "Expected at least 2 nodes in the cluster")

		for _, node := range nodes {
			assert.True(t, k8s.IsNodeReady(node), "Node %s should be Ready", node.Name)
		}
	})

	t.Run("TestSystemPods", func(t *testing.T) {
		t.Parallel()
		kubeSystemOptions := k8s.NewKubectlOptions("", kubeConfigPath, "kube-system")
		// Check for critical system pods
		systemPods := []string{"coredns", "traefik", "metrics-server"}
		for _, podNamePrefix := range systemPods {
			pods := k8s.ListPods(t, kubeSystemOptions, metav1.ListOptions{})
			found := false
			for _, pod := range pods {
				if strings.HasPrefix(pod.Name, podNamePrefix) {
					found = true
					k8s.WaitUntilPodAvailable(t, kubeSystemOptions, pod.Name, 10, 5*time.Second)
					break
				}
			}
			assert.True(t, found, "Pod with prefix %s should exist in kube-system namespace", podNamePrefix)
		}
	})
}
