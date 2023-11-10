NGX_LOG_DIR:=/var/log/nginx
MYSQL_LOG_DIR:=/var/log/mysql
NGX_LOG:="$(NGX_LOG_DIR)/access.log"
MYSQL_LOG="$(MYSQL_LOG_DIR)/mysql-slow.log"

SQLITE_LOG=$(BUILD_DIR)/sqlite.log

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

ALP_MATCH:="/api/player/player/[-0-9a-z]+","/api/player/competition/[-0-9a-z]+/ranking","/api/organizer/competition/[-0-9a-z]+/score","/api/organizer/player/[-0-9a-z]+/disqualified","/api/organizer/competition/[-0-9a-z]+/finish"

.PHONY: bench
bench: before build restart 
	cd $(BENCH_DIR); \
	./bench -target-addr 127.0.0.1:443

.PHONY: bench-dev
bench-dev: before slow-on build restart 
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

	@if [ -f $(SQLITE_LOG) ]; then \
		sudo mv -f $(SQLITE_LOG) logs/$(when)/ ; \
	fi

	@if ls logs/* 1> /dev/null 2>&1; then \
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
	sudo alp json --file $(NGX_LOG) -m $(ALP_MATCH) -r | tee logs/alp.txt

.PHONY: alpq
alpq:
	sudo alp json --file $(NGX_LOG) -m $(ALP_MATCH) -r -q | tee logs/alpq.txt


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
	sudo apt install percona-toolkit
	mkdir logs
	cat ~/.ssh/id_ed25519.pub


.PHONY: conf
conf:
	cd $(PROJECT_ROOT)/configs; \
	sudo cp etc/systemd/system/$(SERVICE_NAME) /etc/systemd/system/ ; \
	sudo cp etc/nginx/nginx.conf /etc/nginx/
	sudo systemctl daemon-reload 

.PHONY: duckdb
duckdb:
	duckdb -c "select statement,avg(query_time) as avg_time, sum(query_time) as sum_time, count(statement) as count from read_json_auto('/home/isucon/webapp/go/sqlite.log') group by statement order by sum_time desc;" | tee logs/duckdb.txt

.PHONY: anal
anal: slow alp duckdb

