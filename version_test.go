package main

import (
    "os"
    "regexp"
    "strings"
    "testing"
)

func TestEmbeddedVersionMatchesReleaseVersion(t *testing.T) {
    raw, err := os.ReadFile("VERSION")
    if err != nil { t.Fatal(err) }
    version := strings.TrimSpace(string(raw))
    if version != appVersion {
        t.Fatalf("EXE version %q != VERSION file %q", appVersion, version)
    }
    if !regexp.MustCompile(`^v[0-9]+\.[0-9]+\.[0-9]+(?:-rc\.[0-9]+)?$`).MatchString(version) {
        t.Fatalf("Invalid version: %q", version)
    }
}
