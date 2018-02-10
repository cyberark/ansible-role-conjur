package main

import (
	"fmt"
	"sync"
	"github.com/cyberark/summon/secretsyml"
	"github.com/cyberark/conjur-api-go/conjurapi"
	"os"
	"io/ioutil"
	"encoding/json"
	"encoding/base64"
)

type Provider interface {
	RetrieveSecret(string) ([]byte, error)
}

// example provider :)
type CatProvider struct {
}
func (CatProvider) RetrieveSecret(path string) ([]byte, error) {
	return ioutil.ReadFile(path)
}

// conjur provider
func NewProvider() (Provider, error) {
	return conjurapi.NewClientFromEnvironment(conjurapi.LoadConfig())
}

func main() {
	var (
		provider Provider
		err error
		secrets secretsyml.SecretsMap
	)

	secrets, err = secretsyml.ParseFromString(os.Getenv("SECRETSYML"), "", nil)
	if os.IsNotExist(err) {
		printAndExitIfError(fmt.Errorf("secrets.yml not found\n"))
	}
	printAndExitIfError(err)

	tempFactory := NewTempFactory("")
	// defer tempFactory.Cleanup()
	// no need to cleanup because we're injecting values to the environment

	type Result struct {
		key string
		bytes []byte
		error
	}

	// Run provider calls concurrently
	results := make(chan Result, len(secrets))
	var wg sync.WaitGroup

	// Lazy loading provider
	for _, spec := range secrets {
		if provider == nil && spec.IsVar() {
			provider, err = NewProvider()
			printAndExitIfError(err)
		}
	}

	for key, spec := range secrets {
		wg.Add(1)
		go func(key string, spec secretsyml.SecretSpec) {
			var (
				secretBytes []byte
				err error
			)

			if spec.IsVar() {
				secretBytes, err = provider.RetrieveSecret(spec.Path)

				if spec.IsFile() {
					fname := tempFactory.Push(secretBytes)
					secretBytes = []byte(fname)
				}
			} else {
				// If the spec isn't a variable, use its value as-is
				secretBytes = []byte(spec.Path)
			}

			results <- Result{key, secretBytes, err}
			wg.Done()
			return
		}(key, spec)
	}
	wg.Wait()
	close(results)

	secretsMap := make(map[string]string)
	for result := range results {
		if result.error != nil {
			printAndExitIfError(fmt.Errorf("error fetching variable - %s", result.error))
		} else {
			secretsMap[result.key] = string(result.bytes)
		}
	}

	encoder := base64.NewEncoder(base64.StdEncoding, os.Stdout)
	secretsJSON, err := json.Marshal(secretsMap)
	printAndExitIfError(err)

	// outputs base64 encoded secret map
	encoder.Write([]byte(secretsJSON))
	encoder.Close()
}

func printAndExitIfError(err error) {
	if err == nil {
		return
	}
	os.Stderr.Write([]byte(err.Error()))
	os.Exit(1)
}
