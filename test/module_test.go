package module

import (
	"io/ioutil"
	"log"
	"math/rand"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func waitForEcsService(t *testing.T, region, cluster, service string) {
	for attempts := 1; attempts < 30; attempts++ {
		state := *aws.GetEcsService(t, region, cluster, service)

		if *state.PendingCount == 0 && *state.DesiredCount == *state.RunningCount {
			t.Logf(
				"Service \"%s\" started",
				service,
			)
			return
		}

		t.Logf(
			"Waiting for service \"%s\" to stabilise (attempt %d)",
			service,
			attempts,
		)
		time.Sleep(time.Second * 10)
	}

	t.Fatalf(
		"Service \"%s\" did not come up",
		service,
	)
}

// Elasticsearch domain names have stricter limitations which eliminate github.com/gruntwork-io/terratest/modules/random
// reference: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-createupdatedomains.html
func randomPrefix(stringLength int) string {
	const letters = "abcdefghijklmnopqrstuvwxyz"
	randomString := make([]byte, stringLength)
	for i := range randomString {
		randomString[i] = letters[rand.Intn(len(letters))]
	}
	return string(randomString)
}

func TestModule(t *testing.T) {
	// Get all the test configurations
	const region = "eu-west-1"
	var testConfigs []string
	files, err := ioutil.ReadDir("../examples/")
	if err != nil {
		log.Fatal(err)
	}
	for _, file := range files {
		if file.IsDir() {
			testConfigs = append(testConfigs, "../examples/"+file.Name())
		}
	}

	// Run tests on each test configuration
	for _, testSetup := range testConfigs {
		t.Run(testSetup, func(t *testing.T) {
			t.Parallel()

			resourcePrefix := randomPrefix(6)
			terraformOptions := &terraform.Options{
				TerraformDir: testSetup,
				Vars: map[string]interface{}{
					"name_prefix": resourcePrefix,
				},
			}
			defer terraform.Destroy(t, terraformOptions)
			terraform.InitAndApply(t, terraformOptions)

			waitForEcsService(t, region, resourcePrefix+"-jaeger", resourcePrefix+"-jaeger-collector")
			waitForEcsService(t, region, resourcePrefix+"-jaeger", resourcePrefix+"-jaeger-query")
		})
	}

}
