terraform {
  required_providers {
    datadog = {
      source = "datadog/datadog"
    }
  }
  required_version = ">= 0.13"
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}
