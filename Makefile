
export PATH:=$(PATH):$(shell npm bin)
SHELL:=bash

SCSS_FILES=$(wildcard scss/*.scss)
CSS_FILES=$(wildcard dist/*[!n].css) # *.css, but not *.min.css
MIN_CSS_FILES=$(CSS_FILES:.css=.min.css)

ENVIRONMENT=$(shell if test -r .env && which jq >/dev/null 2>&1; then jq -r .environment .env; fi)
NEXT_VERSION=$(shell git tag | awk '{ sub(/^v/, ""); if (0 + $$1 > max) max = $$1; } END { printf "%.1f", max + 0.1 }')
NEXT_TAG=v$(NEXT_VERSION)
CURRENT_VERSION=$(shell git describe --tags | sed -e 's/^v//')
CURRENT_TAG=$(shell git describe --tags)

# detect GNU and BSD sed (GNU supports --version)
SED_OPTS=$(shell if sed --version >/dev/null 2>&1; then echo '-i -e'; else echo '-i "" -E'; fi)

JS_SOURCE=jssrc
ELM_SOURCE=src
DIST=dist
SERVICE_WORKER=$(DIST)/service-worker.js

DOCKER_REGISTRY=eu.gcr.io/proforto-team-sso
SERVERREGEX=[v]oting-booth
DOCKER_REPO=voting-booth
DOCKERPORTS=-p 4201:4201

KUBE_NAMESPACE=voting-booth
KUBE_CONTEXT=voting-booth
KUBE_DEPLOYMENT=voting-booth
KUBE_RESTART_PATCH=$(shell node kubernetes/restartdate_patch.js)

.DEFAULT_GOAL:=help

############################################################################
##@ Generic:

# automatic self-documentation
.PHONY: help # See https://tinyurl.com/makefile-autohelp
help: ## display this help
	@awk -v tab=24 'BEGIN { FS = ":.*## "; buffer = ""; color = "\033[36m"; nocolor = "\033[0m"; indent = "  "; usage(); } function trim(str) { gsub(/[ \t]+$$/, "", str); gsub(/^[ \t]+/, "", str); return str; } function spout(target, desc) { split(trim(target), fields, " "); for (i in fields) printf "%s%s%-" tab "s%s%s\n", indent, color, trim(fields[i]), nocolor, desc; } function usage() { printf "\nUsage:\n%smake %s<target>%s\n\nRecognized targets:\n", indent, color, nocolor; } /\\$$/ { gsub(/\\$$/, ""); buffer = buffer $$0; next; } buffer { $$0 = buffer $$0; buffer = ""; } /^[-a-zA-Z0-9*/%_. ]+:.*## / { pad = sprintf("\n%" tab "s" indent, ""); gsub(/\\n/, pad); spout($$1, $$2); } /^##@ / { gsub(/\\n/, "\n"); printf "\n%s\n", substr($$0, 5) } END { print "" }' $(MAKEFILE_LIST) # v1.54

############################################################################
##@ Development:

.PHONY: install
install: npm-install elm-install ## install all dependencies

node_modules: package.json
	npm install
	touch $@

.PHONY: npm-install
npm-install: node_modules ## install all npm dependencies

elm-stuff: elm-package.json
	npx elm package install
	touch $@

.PHONY: elm-install
elm-install: elm-stuff ## install all elm dependencies

.PHONY: build-elm
build-elm: ## compile elm files to javascript
	npx elm-make $(ELM_SOURCE)/Main.elm --yes --output $(JS_SOURCE)/Elm.js

.PHONY: build-bundle
build-bundle: ## bundle javascript files
	if [ "$(ENVIRONMENT)" = development ]; then                          \
		browserify $(JS_SOURCE)/app.js -o $(JS_SOURCE)/bundle.js;    \
	else                                                                 \
		browserify $(JS_SOURCE)/app.js                               \
			-g [ envify --NODE_ENV $${ENVIRONMENT:-production} ] \
			-g uglifyify -o $(JS_SOURCE)/bundle.js;              \
	fi

.PHONY: build-js-minify
build-js-minify:
	uglifyjs $(JS_SOURCE)/bundle.js                                           \
		--compress "pure_funcs=['F2','F3','F4','F5','F6','F7','F8','F9']" \
		--mangle --output $(DIST)/bundle.js

.PHONY: build-js-minify-prod
build-js-minify-prod: ## minify javascript bundle (unless on development)
	if [ "$(ENVIRONMENT)" = development ]; then            \
		cp $(JS_SOURCE)/bundle.js $(DIST)/bundle.js;   \
	else                                                   \
		make build-js-minify;                          \
	fi

%.min.css: %.css
	@# descend into the directory in order to prevent corrupting URLs in CSS
	cd $(<D); cleancss $(<F) > $(@F)

.PHONY: build-css
build-css: $(SCSS_FILES) ## compile scss files to css files
	for i in $(SCSS_FILES); do sass $$i > dist/`basename $${i%.scss}.css`; done

.PHONY: build-css-minify
build-css-minify: build-css $(MIN_CSS_FILES) ## minify all css files

.PHONY: build
build: version build-elm build-bundle build-js-minify-prod build-css-minify ## all of the build steps above

.PHONY: prod
prod: ## mark environment as 'production'
	cp .env.production .env

.PHONY: devel
devel: ## mark environment as 'development'
	cp .env.development .env

.PHONY: version
version: ## update the version file with the current git tag name
	-which git >/dev/null 2>&1 \
		&& echo "document.addEventListener('DOMContentLoaded', function () { var versionNode = document.getElementById('version'); versionNode.innerHTML = '$(CURRENT_TAG)' + versionNode.innerHTML; });" > $(JS_SOURCE)/version.js

.PHONY: bump
bump: ## increment the version in the serviceworker by 0.0.1
	perl -i'' -pe 's/^(const version = .v\d+\.\d\.)(\d+)(.;)/$$1 . ($$2 + 1) . $$3/e' $(SERVICE_WORKER)

.PHONY: service-worker-only-bumped
service-worker-only-bumped: # tests changes in service worker: (0 == only bumped version, 1 == other changes)
	@git diff $(SERVICE_WORKER) | awk '                                              \
		BEGIN { ats = 0; pluses = 0; pluslines = "expected" }                    \
		/^@/ { ats++ }                                                           \
		/^+/ {                                                                   \
			pluses++;                                                        \
			if (!/^+const version =/ && !/^+++ .*service-worker.js/) {       \
				pluslines = "unexpected"                                 \
			}                                                                \
		}                                                                        \
		END { exit !(ats == 1 && pluses == 2 && pluslines == "expected") }       \
	'

.PHONY: unbump
unbump: service-worker-only-bumped ## restore service-worker to 'un-bumped' version
	git checkout $(SERVICE_WORKER)

.PHONY: tag
tag: ## create git tag, next in line (with 0.1 increments) and push to repo
	sed $(SED_OPTS) "s/^(const version = ')v[^']*(';)/\1$(NEXT_TAG).0\2/" $(SERVICE_WORKER)
	sed $(SED_OPTS) 's/^(  "version": ")[^"]*(",)/\1$(NEXT_VERSION).0\2/' package.json
	git commit $(SERVICE_WORKER) package.json -m 'Updated files with new tag'
	git tag $(NEXT_TAG)
	make version
	git push
	git push --tags

.PHONY: rmtag
rmtag: ## remove a tag erroneously created (current tag only)
	git push origin --delete $(CURRENT_TAG)
	git tag --delete $(CURRENT_TAG)

############################################################################
##@ Webserver:

.PHONY: show-err
show-err: # iTerm2 tab coloring
	@printf '\033]6;1;bg;red;brightness;128\a'
	@printf '\033]6;1;bg;green;brightness;0\a'

.PHONY: show-busy
show-busy: # iTerm2 tab coloring
	@printf '\033]6;1;bg;red;brightness;128\a'
	@printf '\033]6;1;bg;green;brightness;128\a'

.PHONY: show-ok
show-ok: # iTerm2 tab coloring
	@printf '\033]6;1;bg;red;brightness;0\a'
	@printf '\033]6;1;bg;green;brightness;128\a'

.PHONY: show-none
show-none: # iTerm2 tab coloring
	@printf '\033]6;1;bg;*;default\a'

.PHONY: start
start: build ## start the webserver
	npm start

.PHONY: stop
stop: ## stop the webserver
	npm stop

.PHONY: status
status: ## show the webserver status
	@ps -ef | grep -s $(SERVERREGEX) || true

.PHONY: restart
restart: stop start ## restart the webserver

.PHONY: watch
watch: ## start the webserver. rebuild and restart if the source changes
	(                                                                       \
		trap 'make show-none unbump; exit' INT;                         \
		while make bump build && make show-ok || make show-err; do      \
			npm start &                                             \
			rm $(JS_SOURCE)/bundle.js.tmp-browserify-* 2>/dev/null; \
			fswatch --one-event $(ELM_SOURCE) $(JS_SOURCE)          \
				$(SERVICE_WORKER) tokenserver                   \
				$(SCSS_FILES) $(CSS_FILES);                     \
			make show-busy;                                         \
			echo 'Changes detected, rebuilding...';                 \
			npm stop;                                               \
		done                                                            \
	)

############################################################################
##@ Building and running in docker locally:

.PHONY: docker-build
docker-build: build ## build the docker image
	nice -n20 docker build -t $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest .

.PHONY: docker-status
docker-status: ## show the status of the docker image and containers
	@echo IMAGES
	@docker images | grep $(DOCKER_REPO) || echo none
	@echo CONTAINERS
	@docker ps -a  | grep $(DOCKER_REPO) || echo none

.PHONY: docker-tag
docker-tag: ## tag the :latest docker image with the current version
	docker image tag $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(CURRENT_VERSION)

.PHONY: docker-start
docker-start: ## start the docker container
	if docker ps -a | grep $(SERVERREGEX) >/dev/null 2>&1; then  \
		docker start $(DOCKER_REPO);                         \
	else                                                         \
		docker run --name $(DOCKER_REPO) $(DOCKERPORTS) -d   \
			-t $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest; \
	fi

.PHONY: docker-build-start
docker-build-start: docker-build docker-start ## build the docker image and start a container

.PHONY: docker-stop
docker-stop: ## stop the docker container
	-docker stop $(DOCKER_REPO)

.PHONY: docker-destroy
docker-destroy: docker-stop ## destroy the docker image and container
	-docker rm -f $(DOCKER_REPO)
	-docker rmi $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest

.PHONY: docker-shell
docker-shell: ## shell into the running docker container
	docker exec -it $(DOCKER_REPO) /bin/bash

.PHONY: docker-clean
docker-clean: ## remove all voting-booth docker images that are not :latest or current version
	docker images | awk -v current_version=$(CURRENT_VERSION) -v docker_repo=$(DOCKER_REPO) ' \
		$$0 ~ docker_repo && $$2 != "latest" && $$2 != current_version { print $$3 }      \
	' | xargs docker rmi

############################################################################
##@ Publishing and deployment on Kubernetes:

.PHONY: docker-push
docker-push: ## push the current image tag to docker repo
	docker push $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(CURRENT_VERSION)

.PHONY: kube-switch-context
kube-switch-context: ## switch kubernetes context to voting-booth
	kubectl config use-context $(KUBE_CONTEXT)

.PHONY: kube-edit-deployment
kube-edit-deployment: ## edit the deployment in an editor, to increment version number
	@echo "For redeployment, please replace the version number with: $(CURRENT_VERSION)"
	@read -p "Press Enter now to start your editor: " ans
	kubectl edit deployment $(KUBE_DEPLOYMENT) -n $(KUBE_NAMESPACE)

.PHONY: kube-advance-deployment
kube-advance-deployment: ## automatically update the deployment in kubernetes. replaces 'make kube-edit-deployment'
	env VISUAL= EDITOR="perl -i -wple 's{(image: $(DOCKER_REGISTRY)/$(DOCKER_REPO)):[.\d]+}{\$$1:$(CURRENT_VERSION)}'" \
		kubectl edit deployment $(KUBE_DEPLOYMENT) -n $(KUBE_NAMESPACE)

.PHONY: kube-restart-production
kube-restart-production: ## gracefully restart kubernetes pod
	kubectl patch deployment $(KUBE_DEPLOYMENT) -n $(KUBE_NAMESPACE) -p '$(KUBE_RESTART_PATCH)'

.PHONY: kube-deploy-production
kube-deploy-production: docker-build docker-tag docker-push kube-advance-deployment kube-restart-production \
## build docker image, tag it, push to docker repo and restart production pod

############################################################################

# vim: set list ts=8 sw=8 noet:
