#!/usr/bin/env bash
# validate-cloud-init.sh — проверка user-data, извлечённого ИЗ ПЛАНА (tfplan).
#
# Принцип: terraform show -json tfplan — единственный источник истины.
# Мы проверяем ровно то, что будет реально применено при terraform apply,
# а не отдельную ручную ре-рендер-копию шаблона. Это убирает целый класс
# проблем с экранированием вывода terraform console.
#
# Требование: свежий tfplan (terraform plan -out=tfplan).

set -euo pipefail

if [ ! -f tfplan ]; then
  echo "tfplan не найден. Сначала: export YC_TOKEN=\$(yc iam create-token) && terraform plan -out=tfplan"
  exit 1
fi

# Убираем слепки прошлых прогонов
rm -f rendered-*.yaml

# План в JSON — во временном файле, чтобы не мусорить в каталоге
terraform show -json tfplan > /tmp/tfplan.json

python3 - <<'PYEOF'
import json, sys, yaml

plan = json.load(open('/tmp/tfplan.json'))
resources = plan['planned_values']['root_module']['resources']

rendered = []
for res in resources:
    if res['type'] != 'yandex_compute_instance':
        continue
    hostname = res['values']['hostname']
    user_data = res['values']['metadata']['user-data']
    fn = f'rendered-{hostname}.yaml'
    with open(fn, 'w') as fh:
        fh.write(user_data)
    rendered.append(fn)
    print(f'Рендер из плана: {fn}')

if not rendered:
    sys.exit('В плане не найдено yandex_compute_instance — tfplan устарел или пуст')

# Проверки каждого слепка
for fn in rendered:
    first = open(fn).readline().rstrip('\n')
    assert first == '#cloud-config', f'{fn}: первая строка {first!r}, ожидалась #cloud-config'
    data = yaml.safe_load(open(fn))
    assert isinstance(data, dict), f'{fn}: YAML-документ не является словарём — рендер сломан'
    print(f'YAML OK (маппинг, ключи: {", ".join(sorted(data))}): {fn}')

print(f'Всего отрендерено нод: {len(rendered)}')
PYEOF

# Схема cloud-init для каждой ноды
for f in rendered-*.yaml; do
  sudo cloud-init schema -c "$f" --annotate
done

echo "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ"