#!/bin/bash
# ハンズオン H1〜H9 のコマンドを devcontainer の中で順に動かし、結果を results/ に書く（リハーサル用）
# 使い方: bash rehearsal/run.sh <段階…>   例: bash rehearsal/run.sh h1 h3 h4 h5 h6 h7 h8 h9
set +e
R=$(cd "$(dirname "$0")" && pwd); OUT=${OUT:-$R/../results}; mkdir -p "$OUT"
W=/tmp/work/hitokoto; DH=${DH_USER:?}; REPO=${DH_REPO:-hitokoto-rehearsal}
log() { echo "$*" >> "$LOG"; }
run() { echo "\$ $*" >> "$LOG"; local t0=$(date +%s); timeout ${TO:-600} bash -c "$*" >> "$LOG" 2>&1; local rc=$?; echo "[rc=$rc $(( $(date +%s)-t0 ))s]" >> "$LOG"; return $rc; }
stage() { rm -rf /tmp/work; mkdir -p /tmp/work; cp -r "$R/stages/$1/hitokoto" "$W"; cd "$W"; }
web() { sleep ${2:-4}; curl -s localhost:${1:-8000} | grep -E 'class="(banner|lead)[^"]*"|<footer>|<li>|placeholder|Welcome|こんにちは' | sed 's/^ *//' | head -8 >> "$LOG"; }

for S in "$@"; do LOG=$OUT/$S.log; : > "$LOG"; log "##### $S $(date -Is)"
case $S in
h1)
  run docker version; run docker compose version; run 'ls -la /usr/libexec/docker/cli-plugins /usr/local/lib/docker/cli-plugins 2>&1; which docker-compose; dpkg -l | grep -E "docker-(ce|compose|buildx)" '; run 'command -v python3 perl'; run docker buildx version; run 'docker info | grep -E "Server Version|Storage Driver|driver-type|Cgroup|Operating System|Total Memory|CPUs"'
  run docker run hello-world
  run "echo wrong-password | docker login -u $DH --password-stdin"
  run "printenv DH_TOKEN | docker login -u $DH --password-stdin"
  ;;
h3)
  run docker run -d --name web -p 8080:80 nginx:1.30; web 8080 2
  run docker ps; run 'docker logs web 2>&1 | tail -3'
  run "docker exec web sh -c \"echo '<h1>こんにちは</h1>' > /usr/share/nginx/html/index.html\""; web 8080 1
  run docker rm -f web; run docker run -d --name web -p 8080:80 nginx:1.30; web 8080 2
  run docker run -d --name web2 -p 8080:80 nginx:1.30
  run 'docker ps -a --format "{{.Names}} {{.Status}}"'; run docker rm web2
  run "docker run --rm python:3.14-slim python -c 'print(1+1)'"
  run "docker run --rm -e GREETING=こんにちは python:3.14-slim python -c \"import os; print(os.environ['GREETING'])\""
  run docker rm -f web; run docker image ls
  ;;
h4)
  stage H4_完成; cp "$R/stages/H3_完成/hitokoto/templates/index.html" templates/
  run docker build -t hitokoto:1.0 .
  run docker run -d --name app -p 8000:8000 hitokoto:1.0; sleep 4
  run 'docker ps -a --format "{{.Names}} {{.Status}}"'; run 'docker logs app 2>&1 | tail -4'; run docker rm app
  run docker run -d --name app -p 8000:8000 -e DB_HOST=none hitokoto:1.0; web
  cp "$R/stages/H4_完成/hitokoto/templates/index.html" templates/
  run 'docker build -t hitokoto:1.0 . 2>&1 | grep -E "CACHED|DONE|naming"'
  cp Dockerfile /tmp/Df; printf 'FROM python:3.14-slim\nWORKDIR /app\nCOPY . .\nRUN pip install -r requirements.txt\nEXPOSE 8000\nCMD ["fastapi", "run", "main.py", "--port", "8000"]\n' > Dockerfile
  run 'docker build -t hitokoto:order . 2>&1 | tail -2'; echo "<!-- 1 -->" >> templates/index.html
  run 'docker build -t hitokoto:order . 2>&1 | grep -E "CACHED|DONE [0-9.]+s$|RUN pip"'; cp /tmp/Df Dockerfile; cp "$R/stages/H4_完成/hitokoto/templates/index.html" templates/
  run docker run --rm hitokoto:1.0 ls -a /app; run docker history hitokoto:1.0; run 'docker images hitokoto'
  sed -i 's/^sqlalchemy/sqlalchmey/' requirements.txt; run 'docker build -t hitokoto:bad . 2>&1 | grep -E "ERROR|failed to solve|error"'; sed -i 's/^sqlalchmey/sqlalchemy/' requirements.txt
  run docker rm -f app
  ;;
h5)
  stage H4_完成
  run docker network create hitokoto-net
  run docker run -d --name db --network hitokoto-net -v db-data:/var/lib/postgresql/data -e POSTGRES_PASSWORD=renshu-pass postgres:17; sleep 6
  run docker run -d --name app --network hitokoto-net -p 8000:8000 -e DB_HOST=db -e DB_PASSWORD=renshu-pass hitokoto:1.0; sleep 4
  run "curl -s -o /dev/null -w '%{http_code}\n' --data-urlencode 'text=はじめての書き込み' localhost:8000/"; web 8000 1
  run docker rm -f db; run docker run -d --name db --network hitokoto-net -v db-data:/var/lib/postgresql/data -e POSTGRES_PASSWORD=renshu-pass postgres:17; sleep 5
  run 'docker logs db 2>&1 | head -3'; web 8000 1
  run docker rm -f app; run docker run -d --name app --network hitokoto-net -p 8000:8000 -e DB_HOST=localhost -e DB_PASSWORD=renshu-pass hitokoto:1.0; web 8000 4
  run 'docker logs app 2>&1 | grep -E "^sqlalchemy|ERROR"'; run 'docker ps --format "{{.Names}} {{.Status}} {{.Ports}}"'
  run docker rm -f app; run docker run -d --name app --network hitokoto-net -p 8000:8000 -e DB_HOST=db -e DB_PASSWORD=renshu-pass -v ./templates:/app/templates hitokoto:1.0; sleep 4
  cp "$R/stages/H5_完成/hitokoto/templates/index.html" templates/; web 8000 1
  run docker rm -f app db; run docker network rm hitokoto-net; run docker volume rm db-data
  ;;
h6)
  stage H6_完成; cp .env.example .env; cp "$R/stages/H5_完成/hitokoto/templates/index.html" templates/
  run docker compose config -q; run docker compose up -d; run docker compose ps; sleep 4
  run "curl -s -o /dev/null --data-urlencode 'text=Compose から' localhost:8000/"; web
  cp compose.yaml /tmp/c.yaml
  perl -0pi -e 's/    healthcheck:.*?(\nvolumes:)/$1/s' compose.yaml; run 'grep -c healthcheck compose.yaml'
  run docker compose down; run docker compose up -d
  for k in 1 2 3; do
    cp /tmp/c.yaml compose.yaml; perl -0pi -e 's/    depends_on:\n      db:\n        condition: service_healthy\n/    depends_on:\n      - db\n/' compose.yaml; run 'grep -A1 depends_on compose.yaml'
    run docker compose down -v; run docker compose up -d; sleep 3; run 'docker compose logs app 2>&1 | grep -E "つながり|つながりました|Uvicorn running"'
    run 'docker compose logs db 2>&1 | grep -E "ready to accept|init"| head -4'
  done
  cp /tmp/c.yaml compose.yaml; run docker compose down -v; run docker compose up -d
  (docker compose watch > /tmp/watch.log 2>&1 &); sleep 15
  cp "$R/stages/H6_完成/hitokoto/templates/index.html" templates/; web 8000 5
  sed -i 's/title="ひとこと掲示板"/title="ひとこと掲示板 "/' main.py; sleep 10
  sed -i 's/^psycopg/psycopg/' requirements.txt; echo "" >> requirements.txt; sleep 60
  run 'grep -vE "^\s*$|^#[0-9]+ " /tmp/watch.log | tail -40'; pkill -f "compose watch"; sleep 2
  run "curl -s -o /dev/null -w '%{http_code}\n' --data-urlencode 'text=残るかな' localhost:8000/"
  run docker compose down; run docker compose up -d; web 8000 6
  run docker compose down -v; run docker compose up -d; web 8000 6; run docker compose down -v
  ;;
h7)
  stage H6_完成
  run docker build -t $DH/$REPO:1.0 .; run docker images $DH/$REPO
  run docker push $DH/$REPO:1.0
  run docker rmi $DH/$REPO:1.0; run docker run -d --name app -p 8000:8000 -e DB_HOST=none $DH/$REPO:1.0; web
  run docker rm -f app
  cp "$R/stages/H7_完成/hitokoto/templates/base.html" templates/
  run docker build -t $DH/$REPO:1.1 .; run docker push $DH/$REPO:1.1
  run docker run -d --name app -p 8000:8000 -e DB_HOST=none $DH/$REPO:1.1; web; run docker rm -f app
  run "docker image inspect $DH/$REPO:1.1 --format '{{json .RepoDigests}}'"
  run docker tag $DH/$REPO:1.1 hitokoto:1.1; run docker push hitokoto:1.1
  run docker tag $DH/$REPO:1.1 someone-else-xyz/hitokoto:1.1; run docker push someone-else-xyz/hitokoto:1.1
  run docker logout; run docker tag $DH/$REPO:1.1 $DH/$REPO:1.1-logout; run docker push $DH/$REPO:1.1-logout
  if [ -n "$GHCR_TOKEN" ]; then
    run "printenv GHCR_TOKEN | docker login ghcr.io -u $GHCR_USER --password-stdin"
    G=ghcr.io/$(echo $GHCR_USER | tr A-Z a-z)/hitokoto-rehearsal
    run docker tag $DH/$REPO:1.1 $G:1.1; run docker push $G:1.1; run docker logout ghcr.io
  fi
  run "printenv DH_TOKEN | docker login -u $DH --password-stdin"
  ;;
h8)
  stage H7_完成
  run docker build -t hitokoto:1.1 .
  sed 's/python:3.14-slim/python:3.14/' Dockerfile > /tmp/Dfull; run docker build -f /tmp/Dfull -t hitokoto:full .
  cp "$R/stages/H8_完成/hitokoto/Dockerfile" "$R/stages/H8_完成/hitokoto/.dockerignore" .; cp "$R/stages/H8_完成/hitokoto/templates/base.html" templates/
  run docker build -t hitokoto:2.0 .; run docker images hitokoto
  run docker run -d --name app -p 8000:8000 -e DB_HOST=none hitokoto:2.0; sleep 3; run docker exec app whoami; web; run docker rm -f app
  run docker run --rm hitokoto:1.1 whoami; run docker run --rm hitokoto:2.0 ls -a /app
  cp .env.example .env; sed -i '/^\.env$/d' .dockerignore; run docker build -t hitokoto:secret .; run docker run --rm hitokoto:secret cat /app/.env; run 'docker history hitokoto:secret | head -8'
  cp "$R/stages/H8_完成/hitokoto/.dockerignore" .; run docker build -t hitokoto:2.0 .; run docker run --rm hitokoto:2.0 cat /app/.env
  if command -v docker-scout >/dev/null || docker scout version >/dev/null 2>&1; then
    TO=900 run docker scout quickview hitokoto:full; TO=900 run docker scout quickview hitokoto:1.1; TO=900 run docker scout quickview hitokoto:2.0
    TO=900 run 'docker scout cves --only-severity critical,high hitokoto:2.0 2>&1 | tail -30'
  fi
  mkdir -p $OUT/../tars; for t in full 1.1 2.0; do docker save hitokoto:$t -o $OUT/../tars/hitokoto_$t.tar; done
  run "ls -la $OUT/../tars"
  run docker tag hitokoto:2.0 $DH/$REPO:2.0; run docker push $DH/$REPO:2.0
  ;;
h9)
  run docker compose -f /tmp/work/hitokoto/compose.yaml down -v; run docker ps -a; run docker volume ls
  run docker system df; run docker system prune -a -f; run docker system df
  ;;
esac
log "##### end $S $(date -Is)"
done
