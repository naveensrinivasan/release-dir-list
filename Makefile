.PHONY: help build test clean nexus-start nexus-stop nexus-logs nexus-password nexus-clean generate-python

help:
	@echo "Release Tool Commands:"
	@echo "  make build           - Build the release-tool binary"
	@echo "  make test            - Run tests"
	@echo "  make clean           - Clean build artifacts and temp files"
	@echo "  make generate-python - Generate Python 3.14.0 test structure"
	@echo ""
	@echo "Nexus Repository Manager Commands:"
	@echo "  make nexus-start     - Start Nexus container"
	@echo "  make nexus-stop      - Stop Nexus container"
	@echo "  make nexus-logs      - View Nexus logs"
	@echo "  make nexus-password  - Get initial admin password"
	@echo "  make nexus-clean     - Stop and remove all data"

build:
	@echo "Building release-tool..."
	@go build -o bin/release-tool ./cmd/release-tool
	@echo "Binary created at: bin/release-tool"

test:
	@echo "Running tests..."
	@go test -v ./...

clean:
	@echo "Cleaning up..."
	@rm -rf bin/
	@rm -rf releases/temp-downloads/
	@echo "Cleanup complete"

generate-python:
	@echo "Generating Python 3.14.0 PyPI repository structure..."
	@./bin/release-tool generate \
		--url https://www.python.org/ftp/python/3.14.0/ \
		--output releases \
		--project python \
		--log-level debug

nexus-start:
	@echo "Starting Nexus Repository Manager..."
	@docker compose up -d
	@echo ""
	@echo "Nexus is starting up. This may take 1-2 minutes..."
	@echo "Access Nexus at: http://localhost:8081"
	@echo ""
	@echo "To get the initial admin password, run: make nexus-password"

nexus-stop:
	@echo "Stopping Nexus..."
	@docker compose down

nexus-logs:
	@docker compose logs -f nexus

nexus-password:
	@echo "Waiting for Nexus to initialize..."
	@sleep 5
	@echo "Initial admin password:"
	@docker compose exec nexus cat /nexus-data/admin.password 2>/dev/null || echo "Nexus is still starting up. Wait a minute and try again."

nexus-clean:
	@echo "WARNING: This will delete all Nexus data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "Nexus data cleaned."; \
	fi
