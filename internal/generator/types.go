package generator

// Artifact represents a release artifact with metadata
type Artifact struct {
	Filename string
	URL      string
	SHA256   string
	Size     int64
}

