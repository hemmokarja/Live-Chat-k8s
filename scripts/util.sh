#!/bin/bash

check_commands() {
  for cmd in terraform aws helm kubectl docker curl openssl; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "$cmd is missing! Please install before use. Exiting."
      exit 1
    fi
  done
}

check_aws_env() {
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set as environment" \
      "variables! Exiting." >&2
    exit 1
  fi
}