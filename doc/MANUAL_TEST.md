# Інструкція для ручного тестування Helm чарту

## Передумови

1. Kubernetes кластер доступний (minikube, kind, k3d, або інший)
2. `kubectl` налаштовано та підключено до кластера
3. `helm` встановлено
4. Docker образ `ghcr.io/YegorMaksymchuk/kbot:latest-amd64` доступний (або змініть в values.yaml)

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

```bash
# Встановити чарт в namespace kbot
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token \
    --wait --timeout 5m

# Або з явними значеннями
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set image.repository=ghcr.io/YegorMaksymchuk \
    --set image.tag=latest \
    --set image.arch=amd64 \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```

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

## Можливі проблеми

### Проблема: Pod не може підтягнути образ

**Рішення**: Переконайтеся, що образ доступний:
```bash
docker pull ghcr.io/YegorMaksymchuk/kbot:latest-amd64
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
