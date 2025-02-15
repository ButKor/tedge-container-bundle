set dotenv-load

IMAGE := "tedge-container-bundle"
TEDGE_IMAGE := "tedge"
TEDGE_TAG := "1.2.0"
TAG := "latest"
ENV_FILE := ".env"

REGISTRY := "ghcr.io"
REPO_OWNER := "thin-edge"
DEFAULT_OUTPUT_TYPE := "registry,dest=" + IMAGE + ".tar"

RELEASE_VERSION := env_var_or_default("RELEASE_VERSION", `date +'%Y%m%d.%H%M'`)

# Initialize the device certificate
init *ARGS:
    ./scripts/manage.sh init {{ARGS}}

# Upload device certificate to Cumulocity IoT
upload *ARGS:
    CI=true ./scripts/manage.sh upload {{ARGS}}

# Start the compose project
start *ARGS:
    docker compose up --build {{ARGS}}

# Stop the compose project
stop *ARGS:
    docker compose down {{ARGS}}

# Enabling running cross platform tools when building container images
build-setup:
    docker run --privileged --rm tonistiigi/binfmt --install all

# Build the docker images
# Example:
#    just build registry latest
#    just build registry 1.2.0
# Use oci-mediatypes=false to improve compatibility with older docker verions, e.g. <= 19.0.x
# See https://github.com/docker/buildx/issues/1964#issuecomment-1644634461
build OUTPUT_TYPE=DEFAULT_OUTPUT_TYPE VERSION='latest': build-setup
    docker buildx build --platform linux/arm/v6,linux/arm/v7,linux/amd64,linux/arm64 --build-arg "TEDGE_IMAGE={{TEDGE_IMAGE}}" --build-arg "TEDGE_TAG={{TEDGE_TAG}}" -t "{{REGISTRY}}/{{REPO_OWNER}}/{{IMAGE}}:{{VERSION}}" -t "{{REGISTRY}}/{{REPO_OWNER}}/{{IMAGE}}:latest" -f Dockerfile --output=type="{{OUTPUT_TYPE}}",oci-mediatypes=false --provenance=false .

# Install python virtual environment
venv:
    [ -d .venv ] || python3 -m venv .venv
    ./.venv/bin/pip3 install -r tests/requirements.txt

# Format tests
format *ARGS:
    ./.venv/bin/python3 -m robotidy tests {{ARGS}}

# Run linter on tests
lint *ARGS:
    ./.venv/bin/python3 -m robocop --report rules_by_error_type --threshold W tests {{ARGS}}

# Run tests
test *ARGS='':
    ./.venv/bin/python3 -m robot.run --outputdir output {{ARGS}} tests

# Cleanup device and all it's dependencies
cleanup DEVICE_ID $CI="true":
    echo "Removing device and child devices (including certificates)"
    c8y devicemanagement certificates list -n --tenant "$(c8y currenttenant get --select name --output csv)" --filter "name eq {{DEVICE_ID}}" --pageSize 2000 | c8y devicemanagement certificates delete --tenant "$(c8y currenttenant get --select name --output csv)"
    c8y inventory find -n --owner "device_{{DEVICE_ID}}" -p 100 | c8y inventory delete
    c8y users delete -n --id "device_{{DEVICE_ID}}" --tenant "$(c8y currenttenant get --select name --output csv)" --silentStatusCodes 404 --silentExit

# Trigger a release (by creating a tag)
release:
    git tag -a "{{RELEASE_VERSION}}" -m "{{RELEASE_VERSION}}"
    git push origin "{{RELEASE_VERSION}}"
    @echo
    @echo "Created release (tag): {{RELEASE_VERSION}}"
    @echo
