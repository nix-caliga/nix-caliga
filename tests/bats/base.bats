#!/usr/bin/env bats

@test "hostname is hello-world" {
  [ "$(hostnamectl hostname)" = "hello-world" ]
}
