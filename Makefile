all: build run
	@echo "Making all.."

build:
	@echo "Running xcodebuild:"
	xcodebuild -scheme velocity -derivedDataPath build build
	@echo "Moving binary.."
	cp -v build/Build/Products/Debug/velocity ./vlcty

run:
	./vlcty
