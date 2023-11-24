SHELL=/bin/bash

NGX_LOG_DIR:=/var/log/nginx
MYSQL_LOG_DIR:=/var/log/mysql
NGX_LOG:="$(NGX_LOG_DIR)/access.log"
MYSQL_LOG="$(MYSQL_LOG_DIR)/mysql-slow.log"


PROJECT_ROOT:=/home/isucon/webapp
BUILD_DIR:=/home/isucon/webapp/go
BUILD_CMD:=go build -o isucondition main.go

BENCH_DIR:=/home/isucon/bench
SERVICE_NAME:=isucondition.go.service
BENCH_CMD:=./bench -all-addresses 127.0.0.11 -target 127.0.0.11:443 -tls -jia-service-url http://127.0.0.1:4999

# ALP_MATCH:="/api/player/player/[-0-9a-z]+","/api/player/competition/[-0-9a-z]+/ranking","/api/organizer/competition/[-0-9a-z]+/score","/api/organizer/player/[-0-9a-z]+/disqualified","/api/organizer/competition/[-0-9a-z]+/finish"
ALP_MATCH:="/api/condition/[-0-9a-z]+","/api/isu/[-0-9a-z]+/icon","/api/isu/[-0-9a-z]+/graph","/api/isu/[-0-9a-z]+","/isu/[-0-9a-z]+/graph","/isu/[-0-9a-z]+/condition","/isu/[-0-9a-z]+"

.PHONY: bench
bench: before build restart 
	$(eval cw := $(shell pwd))
	cd $(BENCH_DIR); \
	$(BENCH_CMD) | tee $(cw)/logs/bench_log.txt

.PHONY: bench-dev
bench-dev: before slow-on build restart 
	$(eval cw := $(shell pwd))
	cd $(BENCH_DIR); \
	$(BENCH_CMD) | tee $(cw)/logs/bench_log.txt

.PHONY: build
build:
	cd $(BUILD_DIR); \
	$(BUILD_CMD)

.PHONY: restart
restart:
	sudo systemctl restart $(SERVICE_NAME)

.PHONY: status
status:
	sudo systemctl status $(SERVICE_NAME)

.PHONY: log
log:
	sudo journalctl -u $(SERVICE_NAME) -n50 -f

.PHONY: before
before:
	$(eval when := $(shell date "+%Y%m%d-%H%M%S"))
	mkdir -p logs/$(when)
	@if [ -f $(NGX_LOG) ]; then \
		sudo mv -f $(NGX_LOG) logs/$(when)/ ; \
	fi

	@if [ -f $(MYSQL_LOG) ]; then \
		sudo mv -f $(MYSQL_LOG) logs/$(when)/ ; \
	fi

	@$(eval FILE_COUNT=$(shell find logs -maxdepth 1 -name "*.txt" | wc -l))
	@if [ $(FILE_COUNT) -le 1 ]; then \
		rm -rf logs/$(when) ; \
	else \
		find logs -maxdepth 1 -type f | xargs -I% mv % logs/$(when)/ ; \
	fi

	sudo systemctl restart nginx
	sudo systemctl restart mysql

.PHONY: pprof
pprof:
	go tool pprof -seconds 60 -png -output logs/pprof.png http://localhost:3000/debug/pprof/profile 


.PHONY: slow-on
slow-on:
	sudo mysql -uroot -proot -e "set global slow_query_log_file = '$(MYSQL_LOG)'; set global long_query_time = 0; set global slow_query_log = ON;"

.PHONY: slow-off
slow-off:
	sudo mysql -uroot -proot -e "set global slow_query_log = OFF;"

.PHONY: slow
slow: 
	sudo pt-query-digest $(MYSQL_LOG) | tee logs/slow-query.txt

.PHONY: alp
alp:
	sudo alp json --file $(NGX_LOG) -m $(ALP_MATCH) -r --sort sum | tee logs/alp.txt

.PHONY: alpq
alpq:
	sudo alp json --file $(NGX_LOG) -m $(ALP_MATCH) -r -q --sort sum | tee logs/alpq.txt


.PHONY: setup
setup:
	curl https://github.com/TodorokiKohei.keys >> ~/.ssh/authorized_keys
	chmod 600 ~/.ssh/authorized_keys
	ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519  -N ""
	chmod 600 ~/.ssh/id_ed25519.pub
	cp .gitconfig ~/.gitconfig
	cp .vimrc ~/.vimrc
	cp .tmux.conf ~/.tmux.conf
	cp config ~/.ssh/config
	sudo chown -R isucon:root /etc/nginx
	sudo chown -R isucon:root /etc/mysql
	sudo chmod -R 777 $(NGX_LOG_DIR)
	sudo chmod -R 777 $(MYSQL_LOG_DIR)
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
	tar -xzvf alp_linux_amd64.tar.gz
	sudo install alp /usr/local/bin/alp
	rm alp alp_linux_amd64.tar.gz
	sudo apt install percona-toolkit -y
	mkdir logs
	cat ~/.ssh/id_ed25519.pub


.PHONY: conf
conf:
	cd $(PROJECT_ROOT)/configs; \
	sudo cp etc/systemd/system/$(SERVICE_NAME) /etc/systemd/system/ ; \
	sudo cp etc/nginx/nginx.conf /etc/nginx/
	sudo systemctl daemon-reload 

.PHONY: anal
anal: slow alp 

