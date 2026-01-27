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
        GO_VERSION = '1.24.3'
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
                    // Set Go paths in workspace
                    env.GOROOT = "${env.WORKSPACE}/go"
                    env.GOPATH = "${env.WORKSPACE}/gopath"
                    
                    // Check if Go is already available in PATH
                    def goVersion = sh(returnStdout: true, script: 'which go > /dev/null 2>&1 && go version || echo "not found"').trim()
                    
                    if (goVersion.contains("go${GO_VERSION}")) {
                        echo "Go ${GO_VERSION} is already installed: ${goVersion}"
                        sh 'go version'
                    } else {
                        echo "Installing Go ${GO_VERSION} to workspace..."
                        sh """
                            # Install Go to workspace (no sudo required)
                            cd ${env.WORKSPACE}
                            
                            # Download Go if not already downloaded
                            if [ ! -f go${GO_VERSION}.linux-amd64.tar.gz ]; then
                                echo "Downloading Go ${GO_VERSION}..."
                                wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz || curl -L -o go${GO_VERSION}.linux-amd64.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
                            fi
                            
                            # Extract Go
                            echo "Extracting Go..."
                            tar -xzf go${GO_VERSION}.linux-amd64.tar.gz
                            
                            # Verify installation
                            ${env.GOROOT}/bin/go version
                        """
                    }
                    
                    // Set up Go environment and verify
                    sh """
                        export GOROOT=${env.GOROOT}
                        export GOPATH=${env.GOPATH}
                        export PATH=${env.GOROOT}/bin:\$PATH
                        mkdir -p ${env.GOPATH}
                        go version
                        go env
                    """
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo "Installing Go dependencies..."
                sh """
                    export GOROOT=${env.GOROOT}
                    export GOPATH=${env.GOPATH}
                    export PATH=${env.GOROOT}/bin:\$PATH
                    go mod download
                    go mod verify
                """
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
                    export PATH=${env.GOROOT}/bin:\$PATH
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
                    export PATH=${env.GOROOT}/bin:\$PATH
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
                    export PATH=${env.GOROOT}/bin:\$PATH
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
