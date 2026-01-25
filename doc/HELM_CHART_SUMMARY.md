# Підсумок створення Helm чарту

## Виконані кроки

✅ **Створено гілку**: `feature/helm-chart`
✅ **Створено Helm чарт**: `kbot` версії 0.1.0
✅ **Налаштовано values.yaml**:
   - Секція `image` з repository, tag, arch
   - Секція `teleToken` з secretName та secretKey
✅ **Оновлено deployment.yaml**:
   - Назва контейнера: `{{ .Release.Name }}`
   - Образ: `{{ .Values.image.repository }}/{{ .Chart.Name }}:{{ .Values.image.tag }}-{{ .Values.image.arch | default "amd64" }}`
   - Змінна середовища TELE_TOKEN з Kubernetes Secret
✅ **Запаковано чарт**: `kbot-0.1.0.tgz`
✅ **Закомічено зміни** в git
✅ **Створено інструкції** для GitHub релізу

## Структура чарту

```
kbot/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── ...
```

## Налаштування values.yaml

```yaml
image:
  repository: ghcr.io/yehormaksymchuk
  tag: latest
  arch: amd64

teleToken:
  secretName: kbot-secret
  secretKey: tele-token
```

## Результат deployment

- **Namespace**: `kbot` (окремий namespace для ізоляції)
- **Назва контейнера**: `{{ .Release.Name }}` (буде `kbot` при встановленні)
- **Образ**: `ghcr.io/yehormaksymchuk/prometheus-bot:latest-amd64` (multi-arch: amd64, arm64)
- **Змінна середовища**: `TELE_TOKEN` з Secret `kbot-secret`, ключ `tele-token`
- **Service**: ClusterIP для внутрішнього доступу

## CI/CD

Автоматичний білд та push Docker образів налаштовано через GitHub Actions:

- **Workflow**: `.github/workflows/docker-build-push.yml`
- **Registry**: GitHub Container Registry (ghcr.io)
- **Тригери**: 
  - Push до main (тег `latest`)
  - Git tags (v*) - версійовані теги
  - Pull requests (тестування та білд без push)
  - Manual dispatch
- **Процес**:
  1. **Test Job**: Виконує `make test` та `make lint`
  2. **Build Job**: Білдить multi-arch Docker образ (linux/amd64, linux/arm64)
  3. **Push**: Пушує до GitHub Container Registry
- **Multi-arch**: Підтримка amd64 та arm64 платформ
- **Образ**: `ghcr.io/yehormaksymchuk/prometheus-bot:latest`
- **Кешування**: Використовує GitHub Actions cache для прискорення білдів

## Створення релізу

Процес створення релізу автоматизовано. Дивіться детальну документацію в `RELEASE_AUTOMATION.md`.

### Швидкий старт

**Варіант 1: Через Make (локально)**
```bash
# Встановити GitHub CLI (якщо потрібно)
brew install gh
gh auth login

# Створити реліз
make release RELEASE_TAG=v1.0.0
```

**Варіант 2: Через GitHub Actions (рекомендовано)**
1. Відкрити: https://github.com/YegorMaksymchuk/prometheus-bot/actions/workflows/release.yml
2. Натиснути "Run workflow"
3. Заповнити параметри та запустити

### Результат

Після створення релізу:
- Helm пакет доступний за URL: `https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz`
- Release notes автоматично згенеровані з шаблону
- Git tag створено автоматично

## Тестування

Чарт пройшов валідацію:
- `helm lint kbot` - успішно
- `helm template kbot kbot/` - генерує коректні маніфести

## Встановлення

```bash
# 1. Створити namespace
kubectl create namespace kbot

# 2. Створити Secret з Telegram токеном
kubectl create secret generic kbot-secret \
    --from-literal=tele-token=<YOUR_TOKEN> \
    --namespace=kbot

# 3. Встановити чарт
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token

# 4. Перевірити статус
kubectl get all -n kbot
kubectl logs -l app.kubernetes.io/name=kbot -n kbot
```

## Видалення

```bash
# Видалити Helm release
helm uninstall kbot -n kbot

# Видалити Secret (опційно)
kubectl delete secret kbot-secret -n kbot

# Видалити namespace (видалить всі ресурси)
kubectl delete namespace kbot
```

Детальні інструкції:
- `RELEASE_INSTRUCTIONS.md` - створення GitHub релізу
- `MANUAL_TEST.md` - детальне тестування деплою
- `TESTING_WORKFLOW.md` - тестування GitHub Actions workflow
