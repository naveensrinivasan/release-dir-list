package generator

import (
	"fmt"
	"html/template"
	"os"
	"path/filepath"
)

const rootIndexTemplate = `<!DOCTYPE html>
<html>
<head>
    <title>Simple Index</title>
</head>
<body>
    <h1>Simple Index</h1>
    <a href="{{.ProjectName}}/">{{.ProjectName}}</a>
</body>
</html>
`

const projectIndexTemplate = `<!DOCTYPE html>
<html>
<head>
    <title>Links for {{.ProjectName}}</title>
</head>
<body>
    <h1>Links for {{.ProjectName}}</h1>
{{range .Artifacts}}    <a href="{{.URL}}#sha256={{.SHA256}}">{{.Filename}}</a><br>
{{end}}</body>
</html>
`

type rootIndexData struct {
	ProjectName string
}

type projectIndexData struct {
	ProjectName string
	Artifacts   []Artifact
}

// GeneratePyPIStructure generates the PyPI Simple repository structure
func GeneratePyPIStructure(outputDir, projectName string, artifacts map[string][]Artifact) error {
	platforms := []string{"linux", "mac", "windows"}

	for _, platform := range platforms {
		// Create directory structure
		simpleDir := filepath.Join(outputDir, platform, "simple")
		projectDir := filepath.Join(simpleDir, projectName)

		if err := os.MkdirAll(projectDir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", projectDir, err)
		}

		// Generate root index.html
		rootIndexPath := filepath.Join(simpleDir, "index.html")
		if err := generateRootIndex(rootIndexPath, projectName); err != nil {
			return fmt.Errorf("failed to generate root index for %s: %w", platform, err)
		}

		// Generate project index.html
		projectIndexPath := filepath.Join(projectDir, "index.html")
		platformArtifacts := artifacts[platform]
		if err := generateProjectIndex(projectIndexPath, projectName, platformArtifacts); err != nil {
			return fmt.Errorf("failed to generate project index for %s: %w", platform, err)
		}
	}

	return nil
}

func generateRootIndex(path, projectName string) error {
	tmpl, err := template.New("root").Parse(rootIndexTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse template: %w", err)
	}

	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	data := rootIndexData{
		ProjectName: projectName,
	}

	if err := tmpl.Execute(file, data); err != nil {
		return fmt.Errorf("failed to execute template: %w", err)
	}

	return nil
}

func generateProjectIndex(path, projectName string, artifacts []Artifact) error {
	tmpl, err := template.New("project").Parse(projectIndexTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse template: %w", err)
	}

	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	data := projectIndexData{
		ProjectName: projectName,
		Artifacts:   artifacts,
	}

	if err := tmpl.Execute(file, data); err != nil {
		return fmt.Errorf("failed to execute template: %w", err)
	}

	return nil
}

