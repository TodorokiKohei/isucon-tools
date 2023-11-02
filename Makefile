NGX_DIR:=/var/log/nginx
MYSQL_DIR:=/var/log/mysql
NGX_LOG:="$(NGX_DIR)/access.log"
MYSQL_LOG="$(MYSQL_DIR)/"

DB_HOST:=127.0.0.1
DB_PORT:=3306
DB_USER:=isucon
DB_PASS:=isucon
DB_NAME:=isuports

PROJECT_ROOT:=/home/isucon/webapp
BUILD_DIR:=/home/isucon/webapp/go
BENCH_DIR:=/home/isucon/bench

BIN_NAME:=isuports
SERVICE_NAME:=isuports.service

.PHONY: bench
bench: before build restart 
	cd $(BENCH_DIR); \
	./bench -target-addr 127.0.0.1:443

.PHONY: build
build:
	cd $(BUILD_DIR); \
	make isuports

.PHONY: restart
restart:
	sudo systemctl restart $(SERVICE_NAME)

.PHONY: status
status:
	sudo systemctl status $(SERVICE_NAME)

.PHONY: log
log:
	sudo journalctl -u $(SERVICE_NAME) -n10 -f

.PHONY: before
before:
	$(eval when := $(shell date "+%s"))
	mkdir -p ~/logs/$(when)
	@if [ -f $(NGX_LOG) ]; then \
		sudo mv -f $(NGX_LOG) ~/logs/$(when)/ ; \
	fi
	# @if [ -f $(MYSQL_LOG) ]; then \
	# 	sudo mv -f $(MYSQL_LOG) ~/logs/$(when)/ ; \
	# fi
	sudo systemctl restart nginx
	# sudo systemctl restart mysql

.PHONY: pprof
pprof:
	go tool pprof -seconds 60 -png -output pprof.png http://localhost:3000/debug/pprof/profile 

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
	sudo chmod -R 777 $(NGX_DIR)
	sudo chmod -R 777 $(MYSQL_DIR)
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
	tar -xzvf alp_linux_amd64.tar.gz
	sudo install alp /usr/local/bin/alp
	cat ~/.ssh/id_ed25519