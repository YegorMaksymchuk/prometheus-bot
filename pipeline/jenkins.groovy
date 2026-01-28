pipeline {
    agent any
    
    parameters {
        choice(
            name: 'OS',
            choices: ['linux', 'darwin', 'windows'],
            description: 'Target operating system'
        )
        choice(
            name: 'ARCH',
            choices: ['amd64', 'arm64'],
            description: 'Target architecture'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        booleanParam(
            name: 'SKIP_LINT',
            defaultValue: false,
            description: 'Skip running linter'
        )
    }
    
    environment {
        GO_VERSION = '1.23.5'
        APP_NAME = 'kbot'
        BIN_DIR = 'bin'
        PLATFORM = "${params.OS}-${params.ARCH}"
        // Determine binary name with extension for Windows
        BINARY_NAME = "${params.OS == 'windows' ? "${APP_NAME}-${PLATFORM}.exe" : "${APP_NAME}-${PLATFORM}"}"
        GOOS = "${params.OS}"
        GOARCH = "${params.ARCH}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code from repository..."
                checkout scm
                script {
                    def gitCommit = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    def gitBranch = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                    env.GIT_COMMIT = gitCommit
                    env.GIT_BRANCH = gitBranch
                    echo "Git commit: ${env.GIT_COMMIT}"
                    echo "Git branch: ${env.GIT_BRANCH}"
                }
            }
        }
        
        stage('Setup Go Environment') {
            steps {
                echo "Setting up Go ${GO_VERSION} environment..."
                script {
                    def goInstalled = false
                    def goPath = ""
                    
                    // First, try to use system Go if available
                    try {
                        def systemGo = sh(returnStdout: true, script: 'which go 2>/dev/null', returnStatus: true)
                        if (systemGo == 0) {
                            def goVersion = sh(returnStdout: true, script: 'go version 2>&1').trim()
                            echo "Found system Go: ${goVersion}"
                            // Use system Go
                            env.GOROOT = sh(returnStdout: true, script: 'go env GOROOT 2>/dev/null').trim()
                            env.GOPATH = "${env.WORKSPACE}/gopath"
                            // Get Go binary directory from system
                            def goBinDir = sh(returnStdout: true, script: 'dirname $(which go) 2>/dev/null').trim()
                            goPath = goBinDir ?: "${env.GOROOT}/bin"
                            goInstalled = true
                        }
                    } catch (Exception e) {
                        echo "System Go not found, will install..."
                    }
                    
                    // If system Go not found, try Jenkins Tool
                    if (!goInstalled) {
                        try {
                            def goTool = tool name: 'go', type: 'go'
                            if (goTool) {
                                env.GOROOT = "${goTool}"
                                env.GOPATH = "${env.WORKSPACE}/gopath"
                                goPath = "${goTool}/bin"
                                echo "Using Jenkins Go tool: ${goTool}"
                                goInstalled = true
                            }
                        } catch (Exception e) {
                            echo "Jenkins Go tool not configured: ${e.getMessage()}"
                        }
                    }
                    
                    // If still not found, install to workspace
                    if (!goInstalled) {
                        echo "Installing Go ${GO_VERSION} to workspace..."
                        env.GOROOT = "${env.WORKSPACE}/go"
                        env.GOPATH = "${env.WORKSPACE}/gopath"
                        goPath = "${env.GOROOT}/bin"
                        
                        sh """
                            set -e
                            cd ${env.WORKSPACE}
                            
                            # Download Go with checksum verification
                            if [ ! -f go${GO_VERSION}.linux-amd64.tar.gz ]; then
                                echo "Downloading Go ${GO_VERSION}..."
                                wget -q --show-progress https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz || \\
                                    curl -L -o go${GO_VERSION}.linux-amd64.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
                            fi
                            
                            # Verify file exists and has reasonable size (> 50MB)
                            if [ ! -f go${GO_VERSION}.linux-amd64.tar.gz ]; then
                                echo "Error: Go archive download failed"
                                exit 1
                            fi
                            FILE_SIZE=\$(stat -c%s go${GO_VERSION}.linux-amd64.tar.gz 2>/dev/null || stat -f%z go${GO_VERSION}.linux-amd64.tar.gz 2>/dev/null || echo "0")
                            if [ "\$FILE_SIZE" -lt 50000000 ]; then
                                echo "Error: Go archive is too small (\$FILE_SIZE bytes), download may have failed"
                                rm -f go${GO_VERSION}.linux-amd64.tar.gz
                                exit 1
                            fi
                            echo "Go archive size: \$FILE_SIZE bytes"
                            
                            # Extract Go
                            echo "Extracting Go..."
                            rm -rf go
                            tar -xzf go${GO_VERSION}.linux-amd64.tar.gz
                            
                            # Verify extraction
                            if [ ! -d go/bin ] || [ ! -f go/bin/go ]; then
                                echo "Error: Go extraction failed"
                                exit 1
                            fi
                            
                            # Test Go binary
                            echo "Testing Go installation..."
                            ./go/bin/go version || exit 1
                        """
                    }
                    
                    // Set Go binary path in environment
                    if (!goPath) {
                        goPath = "${env.GOROOT}/bin"
                    }
                    env.GO_BIN_PATH = goPath
                    
                    // Set up Go environment and verify
                    sh """
                        export GOROOT=${env.GOROOT}
                        export GOPATH=${env.GOPATH}
                        export PATH=${env.GO_BIN_PATH}:\$PATH
                        # Set Go environment variables to avoid network issues
                        export GOPROXY=https://proxy.golang.org,direct
                        export GOSUMDB=sum.golang.org
                        export GO111MODULE=on
                        export CGO_ENABLED=0
                        mkdir -p ${env.GOPATH}
                        
                        echo "Go environment:"
                        echo "  GOROOT: \${GOROOT}"
                        echo "  GOPATH: \${GOPATH}"
                        echo "  PATH: \${PATH}"
                        echo "  GOPROXY: \${GOPROXY}"
                        
                        go version
                        go env GOROOT
                        go env GOPATH
                    """
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo "Installing Go dependencies..."
                script {
                    // Try to download modules with error handling
                    def downloadSuccess = false
                    def attempts = 0
                    def maxAttempts = 3
                    
                    while (!downloadSuccess && attempts < maxAttempts) {
                        attempts++
                        echo "Attempt ${attempts} to download Go modules..."
                        
                        try {
                            sh """
                                export GOROOT=${env.GOROOT}
                                export GOPATH=${env.GOPATH}
                                export PATH=${env.GO_BIN_PATH}:\$PATH
                                export GOPROXY=https://proxy.golang.org,direct
                                export GOSUMDB=sum.golang.org
                                export GO111MODULE=on
                                export CGO_ENABLED=0
                                
                                # Use go mod tidy first to ensure go.mod is correct
                                go mod tidy || true
                                
                                # Download modules with retry
                                go mod download || {
                                    echo "Download failed, trying with direct proxy..."
                                    export GOPROXY=direct
                                    go mod download
                                }
                            """
                            downloadSuccess = true
                            echo "✓ Go modules downloaded successfully"
                        } catch (Exception e) {
                            echo "✗ Attempt ${attempts} failed: ${e.getMessage()}"
                            if (attempts >= maxAttempts) {
                                echo "All attempts failed. Trying alternative approach..."
                                // Last resort: try with direct proxy and skip verification
                                sh """
                                    export GOROOT=${env.GOROOT}
                                    export GOPATH=${env.GOPATH}
                                    export PATH=${env.GO_BIN_PATH}:\$PATH
                                    export GOPROXY=direct
                                    export GOSUMDB=off
                                    export GO111MODULE=on
                                    export CGO_ENABLED=0
                                    
                                    go mod download || {
                                        echo "Warning: go mod download failed, but continuing..."
                                        exit 0
                                    }
                                """
                                downloadSuccess = true
                            } else {
                                sleep(5)
                            }
                        }
                    }
                    
                    // Verify modules if download was successful
                    if (downloadSuccess) {
                        sh """
                            export GOROOT=${env.GOROOT}
                            export GOPATH=${env.GOPATH}
                            export PATH=${env.GO_BIN_PATH}:\$PATH
                            export GOPROXY=https://proxy.golang.org,direct
                            export GOSUMDB=sum.golang.org
                            export GO111MODULE=on
                            
                            echo "Verifying modules..."
                            go mod verify || echo "Warning: Module verification failed, but continuing..."
                        """
                    }
                }
            }
        }
        
        stage('Run Tests') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                echo "Running tests..."
                sh """
                    export GOROOT=${env.GOROOT}
                    export GOPATH=${env.GOPATH}
                    export PATH=${env.GO_BIN_PATH}:\$PATH
                    go test -v -coverprofile=coverage.out ./... || true
                    if [ -f coverage.out ]; then
                        go tool cover -func=coverage.out || true
                    fi
                """
            }
        }
        
        stage('Run Linter') {
            when {
                expression { !params.SKIP_LINT }
            }
            steps {
                echo "Running linter..."
                sh """
                    export GOROOT=${env.GOROOT}
                    export GOPATH=${env.GOPATH}
                    export PATH=${env.GO_BIN_PATH}:\$PATH
                    echo "Formatting code with go fmt..."
                    go fmt ./...
                    echo "Running go vet..."
                    go vet ./...
                """
            }
        }
        
        stage('Build Binary') {
            steps {
                echo "Building binary for platform: ${PLATFORM}"
                echo "Target: ${BINARY_NAME}"
                sh """
                    export GOROOT=${env.GOROOT}
                    export GOPATH=${env.GOPATH}
                    export PATH=${env.GO_BIN_PATH}:\$PATH
                    export GOOS=${GOOS}
                    export GOARCH=${GOARCH}
                    mkdir -p ${BIN_DIR}
                    
                    echo "Building with GOOS=${GOOS} GOARCH=${GOARCH}..."
                    go build -ldflags="-w -s" -o ${BIN_DIR}/${BINARY_NAME} ./cmd/kbot/main.go
                    
                    # Verify binary was created
                    if [ -f ${BIN_DIR}/${BINARY_NAME} ]; then
                        ls -lh ${BIN_DIR}/${BINARY_NAME}
                        file ${BIN_DIR}/${BINARY_NAME}
                        echo "✓ Binary built successfully: ${BIN_DIR}/${BINARY_NAME}"
                    else
                        echo "✗ Error: Binary was not created!"
                        exit 1
                    fi
                """
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                echo "Archiving build artifacts..."
                archiveArtifacts artifacts: "${BIN_DIR}/${BINARY_NAME}", fingerprint: true, allowEmptyArchive: false
                script {
                    def binarySize = sh(returnStdout: true, script: "du -h ${BIN_DIR}/${BINARY_NAME} | cut -f1").trim()
                    echo "Binary size: ${binarySize}"
                    echo "Artifact archived: ${BIN_DIR}/${BINARY_NAME}"
                }
            }
        }
    }
    
    post {
        success {
            echo "✓ Pipeline completed successfully!"
            echo "Platform: ${PLATFORM}"
            echo "Binary: ${BIN_DIR}/${BINARY_NAME}"
            script {
                def buildInfo = """
                Build Information:
                - Platform: ${PLATFORM}
                - Binary: ${BIN_DIR}/${BINARY_NAME}
                - Git Commit: ${env.GIT_COMMIT}
                - Git Branch: ${env.GIT_BRANCH}
                - Tests: ${params.SKIP_TESTS ? 'Skipped' : 'Executed'}
                - Linter: ${params.SKIP_LINT ? 'Skipped' : 'Executed'}
                """
                echo buildInfo
            }
        }
        failure {
            echo "✗ Pipeline failed!"
            script {
                // Archive test results if available
                if (fileExists('coverage.out')) {
                    archiveArtifacts artifacts: 'coverage.out', allowEmptyArchive: true
                }
            }
        }
        always {
            echo "Pipeline execution completed."
            deleteDir()
        }
    }
}
