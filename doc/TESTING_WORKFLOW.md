# Інструкції для тестування GitHub Actions Workflow

## Перевірка перед тестуванням

### 1. Перевірка синтаксису YAML

```bash
# Перевірити синтаксис workflow
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/docker-build-push.yml'))"
```

### 2. Перевірка образу в Helm чарті

```bash
# Перевірити, що образ правильно формується
helm template kbot kbot/ | grep "image:"
```

Очікуваний результат: `image: "ghcr.io/yehormaksymchuk/kbot:latest-amd64"`

## Тестування GitHub Actions Workflow

### Варіант 1: Push до main (автоматичний)

1. Змерджити гілку `feature/helm-chart` в `main`:
```bash
git checkout main
git merge feature/helm-chart
git push origin main
```

2. Перевірити GitHub Actions:
   - Відкрити https://github.com/YegorMaksymchuk/prometheus-bot/actions
   - Знайти workflow "Build and Push Docker Image"
   - Перевірити, що workflow успішно виконався

3. Перевірити образ в GHCR:
   - Відкрити https://github.com/YegorMaksymchuk/prometheus-bot/pkgs/container/prometheus-bot
   - Переконатися, що образ `latest` доступний

### Варіант 2: Manual trigger (workflow_dispatch)

1. Відкрити https://github.com/YegorMaksymchuk/prometheus-bot/actions
2. Вибрати workflow "Build and Push Docker Image"
3. Натиснути "Run workflow"
4. Вибрати гілку та натиснути "Run workflow"

### Варіант 3: Створення тегу

```bash
# Створити тег
git tag v1.0.0
git push origin v1.0.0
```

Це автоматично запустить workflow та створить образ з тегом `v1.0.0`.

## Перевірка доступності образу

### Pull образу локально

```bash
# Автентифікуватися в GHCR (якщо образ приватний)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull образу
docker pull ghcr.io/yehormaksymchuk/prometheus-bot:latest

# Перевірити
docker images | grep prometheus-bot
```

### Тестування деплою з новим образом

```bash
# Встановити Helm чарт
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token

# Перевірити, що под використовує правильний образ
kubectl get pods -n kbot -o jsonpath='{.items[0].spec.containers[0].image}'
```

Очікуваний результат: `ghcr.io/yehormaksymchuk/kbot:latest-amd64`

## Troubleshooting

### Проблема: Workflow не запускається

**Рішення:**
- Перевірити, що файл знаходиться в `.github/workflows/`
- Перевірити синтаксис YAML
- Перевірити права доступу до репозиторію

### Проблема: Помилка при push до GHCR

**Рішення:**
- Перевірити, що `GITHUB_TOKEN` має права `packages: write`
- Перевірити, що назва репозиторію lowercase
- Перевірити permissions в workflow

### Проблема: Образ не знайдено при деплої

**Рішення:**
- Перевірити, що образ публічний (або налаштувати imagePullSecrets)
- Перевірити правильність назви образу в values.yaml
- Перевірити доступність образу: `docker pull ghcr.io/yehormaksymchuk/prometheus-bot:latest`

## Очікуваний результат

Після успішного виконання workflow:

1. ✅ Образ доступний за адресою: `ghcr.io/yehormaksymchuk/prometheus-bot:latest`
2. ✅ Multi-arch підтримка (amd64, arm64)
3. ✅ Helm чарт використовує правильну назву образу
4. ✅ Деплой працює без помилки InvalidImageName
