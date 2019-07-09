include ./scripts/system/Makefile

dep:
	# install dependencies
	@GO111MODULE=on go mod vendor -v
	@GO111MODULE=on go mod download

test:
	# running tests with output coverage at ./c.out
	@go test ./... -cover -coverprofile c.out

binary:
	# builds main binary
	@$(MAKE) _binary ARCH=$(SYS_ARCH) OS=$(SYS_OS) BIN_EXT=$(BIN_EXT) BIN_NAME=semver
	cp ./bin/semver-$(SYS_OS)-$(SYS_ARCH)$(BIN_EXT) ./bin/semver$(BIN_EXT)
binaries:
	# builds all binaries
	@$(MAKE) _binaries BIN_NAME=semver \
		& $(MAKE) _binaries BIN_NAME=bump \
		& $(MAKE) _binaries BIN_NAME=get \
		& wait
_binaries:
	# generic method to build binaries for all oses/architectures
	@$(MAKE) _binary ARCH=amd64 OS=linux BIN_NAME=${BIN_NAME}
	@$(MAKE) _binary ARCH=amd64 OS=darwin BIN_NAME=${BIN_NAME}
	@$(MAKE) _binary ARCH=386 OS=windows BIN_NAME=${BIN_NAME} BIN_EXT=$(BIN_EXT)
_binary:
	# generic method to build a binary
	@cd ./cmd/semver && go generate
	@CGO_ENABLED=0 \
		GO111MODULE=on \
		GOARCH=${ARCH} \
		GOOS=${OS} \
		go build -mod vendor -v -a \
			-ldflags "-extldflags '-static'" \
			-o ./bin/${BIN_NAME}-${OS}-${ARCH}${BIN_EXT} \
			./cmd/${BIN_NAME}

run_bump:
	# runs the bump application in development
	@go run ./cmd/bump ${ARGS}
run_get:
	# runs the get application in development
	@go run ./cmd/get ${ARGS}
run_semver:
	# runs the semver application in development
	@go run ./cmd/semver ${ARGS}

image:
	# builds the main docker image
	@$(MAKE) _image IMAGE_NAME=semver TARGET=semver
images:
	# builds all docker images for all binaries
	# do it sequentially so that we have caches
	@$(MAKE) _image IMAGE_NAME=semver-get TARGET=get
	@$(MAKE) _image IMAGE_NAME=semver-bump TARGET=bump
	@$(MAKE) _image IMAGE_NAME=semver TARGET=semver
_image:
	# driver function for building images
	@docker build \
		--file ./build/Dockerfile \
		--tag usvc/${IMAGE_NAME}:latest \
		--target ${TARGET} \
		.

publish_image: image
	# publishes main docker image
	@$(MAKE) _publish_image IMAGE_NAME=semver
publish_images: images
	# publishes the docker image
	@$(MAKE) _publish_image IMAGE_NAME=semver \
		& $(MAKE) _publish_image IMAGE_NAME=semver-bump \
		& $(MAKE) _publish_image IMAGE_NAME=semver-get \
		& wiat
_publish_image:
	# driver function for publishing images
	@docker tag usvc/${IMAGE_NAME}:latest usvc/${IMAGE_NAME}:$$(docker run usvc/semver:latest -v | cut -f 3 -d ' ' | sed -e 's/v//g')
	@docker push usvc/${IMAGE_NAME}:latest
	@docker push usvc/${IMAGE_NAME}:$$(docker run usvc/semver:latest -v | cut -f 3 -d ' ' | sed -e 's/v//g')

publish_github:
	# publish repository to github
	@git remote get-url origin > ./.publish_github
	@git remote set-url origin git@github.com:usvc/semver.git
	@git push origin master --tags
	@git remote set-url origin $$(cat ./.publish_github)
	@rm -rf ./.publish_github