# GCP API Gateway
## GCP Project ID
### GCP API Gateway のログに対して、project_id タグをセットする。
resource "datadog_logs_custom_pipeline" "gcp_apigateway" {
  name       = "GCP API Gateway"
  is_enabled = "true"
  filter {
    query = "source:gcp.apigateway.googleapis.com/gateway"
  }

  # Project ID をタグ化する
  ## Parse PubSub subscriptions
  processor {
    grok_parser {
      name       = "PubSub Subscription 名から GCP Project ID を取る"
      is_enabled = "true"
      source     = "subscription"
      samples    = ["projects/PROJECT_NAME/subscriptions/xxxx"]
      grok {
        match_rules   = <<EOL
rule_1 projects/%%{data:data.resource.labels.project_id}/subscriptions.*
EOL
        support_rules = ""
      }
    }
  }

  ## project_id のタグ化
  processor {
    attribute_remapper {
      name                 = "Attribute data.resource.labels.project_id をタグ化する"
      is_enabled           = "true"
      source_type          = "attribute"
      sources              = ["data.resource.labels.project_id"]
      target_type          = "tag"
      target               = "project_id"
      preserve_source      = "true"
      override_on_conflict = "false"
    }
  }

  # Date をセット
  processor {
    date_remapper  {
      name                 = "data.timestamp をログのタイムスタンプにセットする"
      is_enabled           = "true"
      sources              = ["data.timestamp"]
    }
  }

  # data.httpRequest.latency を duration(ナノ秒)にセット
  processor {
    grok_parser {
      name       = "data.httpRequest.latency を duration(ナノ秒) にセット"
      is_enabled = "true"
      source     = "data.httpRequest.latency"
      samples    = ["13.986s"]
      grok {
        match_rules   = <<EOL
rule_1 %%{notSpace:duration:scale(1000000000)}s
EOL
            support_rules = ""
      }
    }
  }

  # Remap request method
  processor {
    attribute_remapper {
      name                 = "data.httpRequest.requestMethod を http.method にマッピング"
      is_enabled           = "true"
      source_type          = "attribute"
      sources              = ["data.httpRequest.requestMethod"]
      target_type          = "attribute"
      target               = "http.method"
      target_format        = "string"
      preserve_source      = "true"
      override_on_conflict = "false"
    }
  }

  # Remap data.httpRequest.requestUrl to URL
  processor {
    attribute_remapper {
      name                 = "data.httpRequest.requestUrl を http.url にマッピング"
      is_enabled           = "true"
      source_type          = "attribute"
      sources              = ["data.httpRequest.requestUrl"]
      target_type          = "attribute"
      target               = "http.url"
      target_format        = "string"
      preserve_source      = "true"
      override_on_conflict = "false"
    }
  }

  # URL をパースする
  processor {
    url_parser {
      name                     = "data.httpRequest.requestUrl を URL パースして http.url_detail にセット"
      is_enabled               = "true"
      sources                  = ["data.httpRequest.requestUrl", "http.url"]
      target                   = "http.url_details"
      normalize_ending_slashes = "true"
    }
  }

  # HTTP Status Code をリマップする
  processor {
    attribute_remapper {
      name                 = "data.httpRequest.status を http.status_code にマッピング"
      is_enabled           = "true"
      source_type          = "attribute"
      sources              = ["data.httpRequest.status","data.jsonPayload.httpRequest.status"]
      target_type          = "attribute"
      target               = "http.status_code"
      target_format        = "integer"
      preserve_source      = "true"
      override_on_conflict = "false"
    }
  }

  # http.status_code から http.status_code_class を生成する
  processor {
    category_processor {
      name       = "http.status_code から http.status_code_class を生成する"
      is_enabled = "true"
      target     = "http.status_code_class"
      category {
        filter {
          query = "@http.status_code:[200 TO 299]"
        }
        name = "2xx"
      }
      category {
        filter {
          query = "@http.status_code:[300 TO 399]"
        }
        name = "3xx"
      }
      category {
        filter {
          query = "@http.status_code:[400 TO 499]"
        }
        name = "4xx"
      }
      category {
        filter {
          query = "@http.status_code:[500 TO 599]"
        }
        name = "5xx"
      }
    }
  }

  # http.status_code から http.status_category を生成する
  processor {
    category_processor {
      name       = "http.status_code から http.status_category を生成する"
      is_enabled = "true"
      target     = "http.status_category"
      category {
        name = "OK"
        filter {
          query = "@http.status_code:[200 TO 299]"
        }
      }
      category {
        name = "notice"
        filter {
          query = "@http.status_code:[300 TO 399]"
        }
      }
      category {
        name = "warning"
        filter {
          query = "@http.status_code:[400 TO 499]"
        }
      }
      category {
        name = "error"
        filter {
          query = "@http.status_code:[500 TO 599]"
        }
      }
    }
  }

  # http.status_category をログステータスにマッピング
  processor {
    status_remapper {
      name       = "http.status_category をログステータスにマッピング"
      is_enabled = "true"
      sources    = ["http.status_category"]
    }
  }
}
