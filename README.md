# TA Training - Huckle Yeh

## 目錄結構簡介

```txt
environment-hhjj55013/
├── docker.sh         # Docker 管理腳本
├── Dockerfile        # Mutipile stage 建置
├── script/
│   └── eman.sh       # Docker 開發輔助工具
├── lab0/             # C/C++/SystemC/Verilog 範例程式
└── ...
```

## 使用流程

1. 用 `./docker.sh build` 建置 docker image
2. 用 `./docker.sh run` 啟動 container 並掛載本機目錄
3. 進入 docker container 後用 `cd /home/devuser/work/script`
4. 執行 `./eman.sh` 指令輔助開發與測試

## `docker.sh`

指令：`./docker.sh {build|run|clean|rebuild} [options]`

| Command  | Description |
| -------- | ----------- |
| build    | 第一次建立 image |
| rebuild  | 重建 image |
| run      | 啟動 container |
| clean    | 清除 image 和 container |

| Options  | Description | Default |
| -------- | ----------- | ------- |
| -i | Docker image name | aoc2026-env |
| -c | Docker container name | aoc2026-container |
| -u | Username inside the container | Auto detect |
| -h | Hostname inside container | aoc2026-docker |
| -m | Mount local path into container | `<path in local PC>:<path in docker container>` |
| -a | Override architecture | Auto detect |

1. 建置映像檔：自動建構多階段 Docker 開發環境，包含 Verilator、SystemC、Python、Miniconda 等工具。
2. 啟動/重啟/移除容器：方便在 Mac/Linux 上快速啟動、重啟或清除開發容器。
3. 掛載本機目錄：可將本機資料夾掛載到容器，方便同步程式碼。

### Example

```bash
# 建立 Docker 映像檔（第一次使用）
./docker.sh build --image-name aoc2026-env

# 重新建置映像檔（有 Dockerfile 變更時）
./docker.sh rebuild --image-name aoc2026-env

# 啟動並進入容器
./docker.sh run --image-name aoc2026-env --cont-name aoc2026-container --username devuser --mount /Users/你的帳號/Documents:/home/devuser/work

# 停止並移除容器與映像檔
./docker.sh clean --image-name aoc2026-env --cont-name aoc2026-container
```

## `eman.sh`

1. 查詢編譯器版本：快速顯示 GCC、Make、Verilator 版本。
2. 編譯範例程式：自動編譯並執行 C/C++ 或 Verilator 範例。

```bash
# 顯示所有可用指令
eman help

# 查詢 GCC 與 Make 版本
eman c-compiler-version

# 編譯並執行 C/C++ 範例（需在有 Makefile 的目錄下）
eman c-compiler-example

# 查詢 Verilator 版本
eman check-verilator

# 編譯並執行 Verilator 範例（需在有 Makefile 的目錄下）
eman verilator-example
```
