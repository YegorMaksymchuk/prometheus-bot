# Інструкції для створення GitHub релізу

## Передумови

1. Встановіть GitHub CLI: `brew install gh` (macOS) або з [офіційного сайту](https://cli.github.com/)
2. Автентифікуйтеся: `gh auth login`
3. Переконайтеся, що ви знаходитесь в гілці `main` або змерджте гілку `feature/helm-chart` в `main`

## Кроки створення релізу

### 1. Змерджте гілку в main (якщо ще не зроблено)

```bash
git checkout main
git merge feature/helm-chart
git push origin main
```

### 2. Створіть GitHub реліз

```bash
gh release create v1.0.0 \
  --title "First Release" \
  --notes "First release of prometheus-bot with Helm chart support" \
  kbot-0.1.0.tgz
```

Або інтерактивно:

```bash
gh release create
```

### 3. Перевірте реліз

```bash
gh release list
```

### 4. Завантажте Helm пакет (якщо не додано при створенні)

```bash
gh release upload v1.0.0 kbot-0.1.0.tgz
```

## URL до Helm пакету

Після створення релізу, URL буде:
```
https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz
```

## Встановлення чарту

```bash
# З GitHub релізу
helm install kbot https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz

# Або з локального файлу
helm install kbot ./kbot-0.1.0.tgz
```

## Перед встановленням

Створіть Kubernetes Secret з Telegram токеном:

```bash
kubectl create secret generic kbot-secret --from-literal=tele-token=<YOUR_TELEGRAM_TOKEN>
```
