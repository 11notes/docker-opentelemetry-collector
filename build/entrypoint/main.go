package main

import (
  "github.com/11notes/go-eleven"
)

const APP_CONFIG_ENV string = "OPENTELEMETRY_COLLECTOR_CONFIG"
const APP_CONFIG_FILE string = "/opentelemetry-collector/etc/config.yml"
const APP_BIN = "opentelemetry-collector"
const APP_CONFIG_SOURCE string = "/opentelemetry-collector/.source/APP_OTEL_BUILD.yml"

func main(){
	// copy source config
	eleven.Util.CopyFile(APP_CONFIG_SOURCE, APP_CONFIG_FILE)

	// write env to file if set
	eleven.Container.EnvToFile(APP_CONFIG_ENV, APP_CONFIG_FILE)

	// start app
	eleven.Container.Run("/usr/local/bin", APP_BIN, []string{"--config=file:" + APP_CONFIG_FILE}, []string{})
}