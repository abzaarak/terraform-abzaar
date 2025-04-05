#!/usr/bin/env bash
set -euo pipefail

DOCKERHUB_USER="devopscloudycontainers"
IMAGE_NAME="terraform"
VERSIONS_FILE="versions.txt"
MAX_RETRIES=3
LOG_FILE="build.log"
CSV_FILE="build-metrics.csv"

# Dynamically set number of parallel jobs based on CPU cores
CPU_CORES=$(sysctl -n hw.logicalcpu)
JOBS=$(( CPU_CORES > 2 ? CPU_CORES - 2 : 1 ))

# 🖍️ Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# 🧾 Timestamped logger with optional prefix (used to group logs by version)
log() {
  local prefix="${2:-}"
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${prefix}${1}"
}

# 📋 Log output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1
log "${BLUE}📄 Logging to $LOG_FILE${RESET}"
log "${YELLOW}⏳ Spawning parallel builds... please wait...${RESET}"

# 📊 CSV Header
echo "version,duration_seconds,image_size_mb" > "$CSV_FILE"

# 🛡️ Ensure versions file exists
if [[ ! -f "$VERSIONS_FILE" ]]; then
  log "${RED}❌ Error: $VERSIONS_FILE not found!${RESET}"
  exit 1
fi

# 🔁 Push Docker image with retry logic
docker_push_with_retry() {
  local image="$1"
  local attempt=1

  until docker push "$image" > >(tee -a "$LOG_FILE" | grep -E 'Pushed|digest|error') 2>&1; do
    if (( attempt >= MAX_RETRIES )); then
      log "${RED}❌ Failed to push $image after $MAX_RETRIES attempts.${RESET}"
      return 1
    fi
    log "${YELLOW}🔁 Retrying push ($attempt)...${RESET}"
    sleep 5
    ((attempt++))
  done
}

# 🧱 Build & Test a single Terraform version
build_version() {
  local version="$1"
  local start_time end_time duration image_size image_size_mb

  [[ -z "$version" || "$version" =~ ^# ]] && return

  log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" "[${version}] "
  log "${BLUE}🔧 Building Terraform ${version}...${RESET}" "[${version}] "
  log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}" "[${version}] "

  start_time=$(date +%s)

  docker buildx build --pull --no-cache \
    --build-arg TERRAFORM_VERSION="${version}" \
    -t "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}" \
    -f Dockerfile.template . >> "$LOG_FILE" 2>&1

  end_time=$(date +%s)
  duration=$((end_time - start_time))
  log "${GREEN}✅ Build completed: ${version} (${duration}s)${RESET}" "[${version}] "

  log "${BLUE}📦 Pushing ${DOCKERHUB_USER}/${IMAGE_NAME}:${version}...${RESET}" "[${version}] "
  docker_push_with_retry "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}"

  image_size=$(docker image inspect "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}" --format='{{.Size}}' 2>/dev/null || echo "0")
  image_size_mb=$((image_size / 1024 / 1024))
  log "${BLUE}📐 Image size: ${image_size_mb} MB${RESET}" "[${version}] "
  echo "${version},${duration},${image_size_mb}" >> "$CSV_FILE"

  log "${BLUE}🧪 Testing ${version}...${RESET}" "[${version}] "
  (
    set +e

    if docker run --rm "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}" version \
      2>/dev/null | grep -v "Your version of Terraform is out of date" | grep -q "Terraform v${version}"; then
      log "${GREEN}✅ terraform ${version} is working as expected${RESET}" "[${version}] "
    else
      log "${RED}❌ terraform ${version} test failed${RESET}" "[${version}] "
    fi

    docker run --rm "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}" aws --version || log "${YELLOW}⚠️ awscli failed${RESET}" "[${version}] "
    docker run --rm "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}" tflint --version || log "${YELLOW}⚠️ tflint failed${RESET}" "[${version}] "
    docker run --rm "${DOCKERHUB_USER}/${IMAGE_NAME}:${version}" terraform-docs --version || log "${YELLOW}⚠️ terraform-docs failed${RESET}" "[${version}] "
  )

  log "${GREEN}✅ Finished Terraform ${version}${RESET}" "[${version}] "

  # 🔻 Optional separator for readability in terminal output
  echo -e "${BLUE}────────────────────────────────────────────${RESET}"
}

# 🧵 Parallel build loop
export -f build_version docker_push_with_retry log
export DOCKERHUB_USER IMAGE_NAME CSV_FILE LOG_FILE MAX_RETRIES

# 🚀 Run all builds in parallel with --tag to group logs by version
parallel --tag -j "$JOBS" build_version :::: "$VERSIONS_FILE"

log "${GREEN}🏁 All builds complete.${RESET}"
log "${BLUE}📊 Metrics saved to $CSV_FILE${RESET}"
