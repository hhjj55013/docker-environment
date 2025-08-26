#!/bin/bash
set -e  # 發生錯誤時中斷 script

IMAGE_NAME="aoc2026-env"
CONTAINER_NAME="aoc2026-container"
USERNAME="$USER"
HOSTNAME="aoc2026-docker"
MOUNT_PATHS=()
ARCH=$(uname -m)  # 自動檢測當前架構

# 解析命令列參數
COMMAND=$1
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image-name|-i)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --cont-name|-c)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --username|-u)
            USERNAME="$2"
            shift 2
            ;;
        --mount|-m)
            MOUNT_PATHS+=("$2")
            shift 2
            ;;
        --hostname|-H)
            HOSTNAME="$2"
            shift 2
            ;;
        --arch|-a)
            ARCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 檢查必要參數
check_required_params() {
    if [[ -z "$IMAGE_NAME" ]]; then
        echo "Error: IMAGE_NAME is empty. Use --image-name or -i to specify."
        exit 1
    fi
    if [[ -z "$CONTAINER_NAME" ]]; then
        echo "Error: CONTAINER_NAME is empty. Use --cont-name or -c to specify."
        exit 1
    fi
}

# 建立 Docker image
build_image() {
    check_required_params
    echo "Detected architecture: $ARCH"

    if docker image inspect "$IMAGE_NAME" &>/dev/null; then
        echo "Image '$IMAGE_NAME' already exists."
        echo "Use './docker.sh rebuild' to rebuild."
    else
        echo "Building Docker image: $IMAGE_NAME..."
        docker build \
            --build-arg USERNAME="$USERNAME" \
            --build-arg TARGETARCH="$ARCH" \
            -t "$IMAGE_NAME" .
    fi
}

# 清除 container & image
clean_all() {
    check_required_params
    echo "Stopping and removing containers..."
    docker rm -f $(docker ps -aq --filter "name=$CONTAINER_NAME") 2>/dev/null || true
    echo "Removing image..."
    docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
}

get_container_status() {
    local name="$1"
    if docker ps -q -f name="^/${name}$" | grep -q .; then
        echo "running"
    elif docker ps -a -q -f name="^/${name}$" | grep -q .; then
        echo "exited"
    else
        echo "not_exist"
    fi
}

# 啟動 container
run_container() {
    check_required_params

    status=$(get_container_status "$CONTAINER_NAME")
    echo "Detected container status: $status"

    MOUNT_ARGS=()
    for mnt in "${MOUNT_PATHS[@]}"; do
        MOUNT_ARGS+=("-v" "$mnt")
    done

    case "$status" in
        running)
            echo "Container is running. Attaching..."
            docker exec -it "$CONTAINER_NAME" bash
            ;;
        exited)
            echo "Container exists but stopped. Starting..."
            docker start -ai "$CONTAINER_NAME"
            ;;
        not_exist)
            echo "Container not found. Creating..."
            docker run -it --name "$CONTAINER_NAME" \
                "${MOUNT_ARGS[@]}" \
                -e USER="$USERNAME" \
                "$IMAGE_NAME" bash
            ;;
        *)
            echo "Unknown container status: $status"
            exit 1
            ;;
    esac
}

# 主指令
case "$COMMAND" in
    build)
        build_image
        ;;
    run)
        build_image
        run_container
        ;;
    clean)
        clean_all
        ;;
    rebuild)
        clean_all
        build_image
        ;;
    *)
        echo "Usage: $0 {build|run|clean|rebuild} [options]"
        echo "Options:"
        echo "  --image-name, -i <name>   Docker image name                (default: $IMAGE_NAME)"
        echo "  --cont-name, -c <name>    Docker container name            (default: $CONTAINER_NAME)"
        echo "  --username, -u <name>     Username inside container        (default: $USERNAME)"
        echo "  --hostname, -H <name>     Hostname inside container        (default: $HOSTNAME)"
        echo "  --mount, -m <path>        Mount local path into container"
        echo "  --arch, -a <arch>         Override architecture            (default: $ARCH)"
        exit 1
        ;;
esac