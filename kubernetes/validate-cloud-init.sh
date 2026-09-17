#!/usr/bin/env bash
set -euo pipefail

# Общая карта нод — должна совпадать с instances.tf
NODES='{"master-1"="10.10.1.10","worker-1"="10.10.2.11","worker-2"="10.10.2.12","worker-3"="10.10.2.13","worker-4"="10.10.2.14"}'

render() {
  local host="$1" role="$2" out="$3"
  echo "jsonencode(templatefile(\"templates/cloud-init.yaml.tpl\", {hostname=\"$host\", role=\"$role\", k8s_minor=\"v1.34\", node_map=$NODES}))" \
    | terraform console | tail -n 1 \
    | python3 -c 'import json,sys; sys.stdout.write(json.loads(sys.stdin.read()))' \
    > "$out"
  echo "Рендер: $out"
}

render master-1 master rendered-master.yaml
render worker-1 worker rendered-worker.yaml

# 1. Чистый YAML-парсинг обеих версий
for f in rendered-master.yaml rendered-worker.yaml; do
  python3 -c "import yaml; yaml.safe_load(open('$f')); print('YAML OK: $f')"
done

# 2. Схема cloud-init (если cloud-init установлен на рабочей машине)
if command -v cloud-init >/dev/null; then
  cloud-init schema -c rendered-master.yaml --annotate
  cloud-init schema -c rendered-worker.yaml --annotate
else
  echo "cloud-init не установлен — проверка схемы пропущена (YAML уже валиден)"
fi