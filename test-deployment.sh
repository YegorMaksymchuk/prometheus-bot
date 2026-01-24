#!/bin/bash

# Скрипт для тестування деплою Helm чарту kbot

set -e

echo "=== Тестування деплою Helm чарту kbot ==="

# Перевірка наявності .env файлу
if [ ! -f .env ]; then
    echo "Помилка: файл .env не знайдено"
    exit 1
fi

# Отримання токену з .env
TELE_TOKEN=$(grep TELE_TOKEN .env | cut -d'=' -f2)

if [ -z "$TELE_TOKEN" ]; then
    echo "Помилка: TELE_TOKEN не знайдено в .env файлі"
    exit 1
fi

echo "✓ Токен знайдено: ${TELE_TOKEN:0:20}..."

# Перевірка підключення до кластера
echo ""
echo "=== Перевірка кластера ==="
kubectl cluster-info || {
    echo "Помилка: не вдалося підключитися до кластера"
    echo "Переконайтеся, що кластер запущено та kubectl налаштовано"
    exit 1
}

kubectl get nodes
echo "✓ Кластер доступний"

# Створення namespace (опційно)
NAMESPACE="default"
echo ""
echo "=== Використання namespace: $NAMESPACE ==="

# Створення Secret з токеном
echo ""
echo "=== Створення Kubernetes Secret ==="
kubectl create secret generic kbot-secret \
    --from-literal=tele-token="$TELE_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret створено/оновлено"

# Перевірка Secret
kubectl get secret kbot-secret
echo "✓ Secret перевірено"

# Встановлення Helm чарту
echo ""
echo "=== Встановлення Helm чарту ==="
CHART_FILE="kbot-0.1.0.tgz"

if [ ! -f "$CHART_FILE" ]; then
    echo "Помилка: файл $CHART_FILE не знайдено"
    echo "Спробуйте: helm package kbot"
    exit 1
fi

# Видалення попереднього встановлення (якщо є)
helm uninstall kbot 2>/dev/null || echo "Чарт не встановлено, продовжуємо..."

# Встановлення чарту
helm install kbot ./$CHART_FILE \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token \
    --wait --timeout 5m

echo "✓ Helm чарт встановлено"

# Перевірка статусу
echo ""
echo "=== Перевірка статусу деплою ==="
kubectl get pods -l app.kubernetes.io/name=kbot
kubectl get svc -l app.kubernetes.io/name=kbot
kubectl get deployment -l app.kubernetes.io/name=kbot

# Очікування готовності подів
echo ""
echo "=== Очікування готовності подів ==="
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kbot --timeout=300s || {
    echo "Помилка: под не став готовим за 5 хвилин"
    echo "Перевірте логи: kubectl logs -l app.kubernetes.io/name=kbot"
    exit 1
}

echo "✓ Поди готові"

# Перевірка логів
echo ""
echo "=== Перевірка логів ==="
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=kbot -o jsonpath='{.items[0].metadata.name}')
echo "Под: $POD_NAME"
kubectl logs "$POD_NAME" --tail=20 || echo "Логи недоступні"

# Перевірка змінної середовища
echo ""
echo "=== Перевірка змінної середовища TELE_TOKEN ==="
kubectl exec "$POD_NAME" -- env | grep TELE_TOKEN && echo "✓ TELE_TOKEN встановлено" || echo "✗ TELE_TOKEN не знайдено"

# Фінальний статус
echo ""
echo "=== Фінальний статус ==="
kubectl get all -l app.kubernetes.io/name=kbot

echo ""
echo "=== Тестування завершено успішно! ==="
echo ""
echo "Для перегляду логів:"
echo "  kubectl logs -l app.kubernetes.io/name=kbot -f"
echo ""
echo "Для видалення деплою:"
echo "  helm uninstall kbot"
echo "  kubectl delete secret kbot-secret"
