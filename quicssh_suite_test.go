package quicssh_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestQuicSsh(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "QuicSsh Suite")
}
