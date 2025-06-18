.PHONY: build-runtime test-runtime

build-runtime:
	docker build -t weasyprint-runtime ./docker/weasyprint-runtime

test-runtime:
	./docker/scalingo-runtime/test.sh
