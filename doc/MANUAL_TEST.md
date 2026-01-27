# Інструкція для ручного тестування Helm чарту

## Передумови

1. Kubernetes кластер доступний (minikube, kind, k3d, або інший)
2. `kubectl` налаштовано та підключено до кластера
3. `helm` встановлено
4. Docker образ `ghcr.io/yegormaksymchuk/prometheus-bot:latest` доступний (або змініть в values.yaml)

## Розгортання в локальному кластері (k3d)

### Створення локального кластера k3d

```bash
# Створити новий k3d кластер
k3d cluster create kbot-demo

# Перевірити підключення
kubectl cluster-info
kubectl get nodes
```

### Перевірка доступних тегів образу

Перед встановленням чарту переконайтеся, що образ доступний:

```bash
# Перевірити доступність образу з тегом latest (multi-arch)
docker pull ghcr.io/yegormaksymchuk/prometheus-bot:latest

# Перевірити інформацію про образ
docker inspect ghcr.io/yegormaksymchuk/prometheus-bot:latest

# Перевірити доступні теги через GitHub API (якщо маєте доступ)
# Або через веб-інтерфейс: https://github.com/yegormaksymchuk/prometheus-bot/pkgs/container/prometheus-bot
```

**Важливо**: GitHub Container Registry пушить multi-arch образи з тегом `latest` (без суфіксу архітектури). Тег `latest-amd64` не існує.

## Крок 1: Перевірка кластера

```bash
kubectl cluster-info
kubectl get nodes
```

## Крок 2: Створення namespace

```bash
# Створити namespace kbot
kubectl create namespace kbot

# Перевірити
kubectl get namespace kbot
```

## Крок 3: Створення Secret з Telegram токеном

```bash
cd /Users/yehormaksymchuk/sources/prometheus/05_Kubernetes_in_action/05_Task/prometheus-bot

# Отримати токен з .env
TELE_TOKEN=$(grep TELE_TOKEN .env | cut -d'=' -f2)

# Створити Secret в namespace kbot
kubectl create secret generic kbot-secret \
    --from-literal=tele-token="$TELE_TOKEN" \
    --namespace=kbot

# Перевірити
kubectl get secret kbot-secret -n kbot
kubectl describe secret kbot-secret -n kbot
```

## Крок 4: Встановлення Helm чарту

### Варіант 1: З використанням значень за замовчуванням (рекомендовано)

```bash
# Встановити чарт в namespace kbot з значеннями за замовчуванням
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token \
    --wait --timeout 5m
```

### Варіант 2: З явними значеннями (рекомендовано для multi-arch образів)

```bash
# Варіант 2a: Використання repository + name (БЕЗ суфіксу архітектури)
# Це правильний спосіб для multi-arch образів з GitHub Container Registry
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set image.repository=ghcr.io/yegormaksymchuk \
    --set image.name=prometheus-bot \
    --set image.tag=latest \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token

# Варіант 2b: Використання повного шляху в repository (БЕЗ суфіксу архітектури)
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set image.repository=ghcr.io/yegormaksymchuk/prometheus-bot \
    --set image.name="" \
    --set image.tag=latest \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```

**Примітка**: Для multi-arch образів (як `latest` з GitHub Container Registry) НЕ встановлюйте `arch` або встановіть `arch=""`. Суфікс архітектури додається тільки якщо `arch` явно встановлено (наприклад, `arch="amd64"`).

## Крок 5: Перевірка статусу

```bash
# Перевірити под
kubectl get pods -l app.kubernetes.io/name=kbot -n kbot

# Перевірити deployment
kubectl get deployment kbot -n kbot

# Перевірити service
kubectl get svc kbot -n kbot

# Перевірити всі ресурси
kubectl get all -l app.kubernetes.io/name=kbot -n kbot

# Перевірити namespace
kubectl get all -n kbot
```

## Крок 6: Перевірка логів

```bash
# Отримати ім'я поду
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=kbot -n kbot -o jsonpath='{.items[0].metadata.name}')

# Переглянути логи
kubectl logs $POD_NAME -n kbot

# Стежити за логами
kubectl logs -f $POD_NAME -n kbot
```

## Крок 7: Перевірка змінної середовища

```bash
# Перевірити, що TELE_TOKEN встановлено
kubectl exec $POD_NAME -n kbot -- env | grep TELE_TOKEN

# Перевірити значення (без виведення)
kubectl exec $POD_NAME -n kbot -- sh -c 'echo $TELE_TOKEN | cut -c1-20'
```

## Крок 8: Перевірка опису поду

```bash
# Детальний опис поду
kubectl describe pod $POD_NAME -n kbot

# Перевірити конфігурацію deployment
kubectl get deployment kbot -n kbot -o yaml
```

## Крок 9: Тестування роботи (якщо образ доступний)

```bash
# Якщо под не запускається, перевірте події
kubectl get events -n kbot --sort-by='.lastTimestamp'

# Перевірте причину помилки
kubectl describe pod $POD_NAME -n kbot | grep -A 10 "Events:"
```

## Видалення тестового деплою

```bash
# Видалити Helm release
helm uninstall kbot -n kbot

# Видалити Secret (опційно)
kubectl delete secret kbot-secret -n kbot

# Видалити namespace (видалить всі ресурси)
kubectl delete namespace kbot

# Або перевірити, що все видалено
kubectl get all -n kbot
```

## Автоматичне тестування

Використайте готовий скрипт:

```bash
./test-deployment.sh
```

## Пояснення помилок

### Помилка: ImagePullBackOff з тегом `latest-amd64`

**Симптоми:**
```
Failed to pull image "ghcr.io/yegormaksymchuk/prometheus-bot:latest-amd64": 
ghcr.io/yegormaksymchuk/prometheus-bot:latest-amd64: not found
```

**Причина:**
- GitHub Container Registry пушить multi-arch образи з тегом `latest` (без суфіксу архітектури)
- Шаблон Helm чарту додавав суфікс `-amd64` навіть коли `arch` не встановлено
- Тег `latest-amd64` не існує в registry, тому Kubernetes не може підтягнути образ

**Рішення:**
Не встановлюйте `arch` або встановіть `arch=""` для multi-arch образів:
```bash
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set image.repository=ghcr.io/yegormaksymchuk \
    --set image.name=prometheus-bot \
    --set image.tag=latest \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```

### Помилка: Подвійний шлях `/prometheus-bot/prometheus-bot`

**Симптоми:**
```
Image: ghcr.io/yegormaksymchuk/prometheus-bot/prometheus-bot:latest-amd64
```

**Причина:**
- Ручне редагування deployment з додаванням назви образу до `repository`
- Якщо `repository` вже містить повний шлях (`ghcr.io/yegormaksymchuk/prometheus-bot`), а `name` також встановлено, виникає подвійний шлях

**Рішення:**
Використовуйте правильні параметри при встановленні чарту:
- Або `repository=ghcr.io/yegormaksymchuk` + `name=prometheus-bot`
- Або `repository=ghcr.io/yegormaksymchuk/prometheus-bot` + `name=""`

### Помилка: Образ не знайдено

**Симптоми:**
```
Error: ErrImagePull
ImagePullBackOff
```

**Причина:**
- Неправильний тег образу (наприклад, `latest-amd64` замість `latest`)
- Образ не існує в registry
- Проблеми з доступом до registry

**Рішення:**
1. Перевірте доступність образу локально:
   ```bash
   docker pull ghcr.io/yegormaksymchuk/prometheus-bot:latest
   ```

2. Перевірте правильність тегу в deployment:
   ```bash
   kubectl describe deployment kbot -n kbot | grep Image
   ```

3. Перевстановіть чарт з правильними параметрами (див. Крок 4)

## Можливі проблеми

### Проблема: Pod не може підтягнути образ

**Рішення**: Переконайтеся, що образ доступний:
```bash
# Перевірте доступність образу з тегом latest (multi-arch)
docker pull ghcr.io/yegormaksymchuk/prometheus-bot:latest

# Перевірте інформацію про образ
docker inspect ghcr.io/yegormaksymchuk/prometheus-bot:latest | grep -A 5 Arch
```

**Важливо**: Для multi-arch образів з GitHub Container Registry використовуйте тег `latest` БЕЗ суфіксу архітектури:
```bash
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set image.repository=ghcr.io/yegormaksymchuk \
    --set image.name=prometheus-bot \
    --set image.tag=latest \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```

Або змініть repository в values.yaml на локальний образ.

### Проблема: Secret не знайдено

**Рішення**: Перевірте назву та ключ:
```bash
kubectl get secrets -n kbot
kubectl describe secret kbot-secret -n kbot
```

### Проблема: TELE_TOKEN не встановлено

**Рішення**: Перевірте значення в values.yaml та перевстановіть чарт:
```bash
helm upgrade kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```
