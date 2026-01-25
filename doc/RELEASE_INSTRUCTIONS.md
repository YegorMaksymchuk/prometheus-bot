# Інструкції для створення GitHub релізу

## Автоматизований процес (Рекомендовано)

Процес створення релізу автоматизовано через Make targets та GitHub Actions. Дивіться детальну документацію в `RELEASE_AUTOMATION.md`.

### Варіант 1: Локально через Make (потребує GitHub CLI)

```bash
# Встановити GitHub CLI (якщо ще не встановлено)
brew install gh
gh auth login

# Створити реліз
make release RELEASE_TAG=v1.0.0
```

Це автоматично:
1. Згенерує release notes з шаблону
2. Запакує Helm чарт
3. Створить GitHub реліз
4. Завантажить Helm пакет

### Варіант 2: Через GitHub Actions (Рекомендовано)

1. Відкрити: https://github.com/YegorMaksymchuk/prometheus-bot/actions/workflows/release.yml
2. Натиснути "Run workflow"
3. Заповнити параметри:
   - `version`: `0.1.0` (версія чарту)
   - `release_tag`: `v1.0.0` (git tag)
   - `release_title`: `First Release` (опційно)
   - `prerelease`: `false` (опційно)
4. Натиснути "Run workflow"

Workflow автоматично:
- Валідує та запаковує чарт
- Генерує release notes
- Створює git tag
- Створює GitHub реліз
- Завантажує Helm пакет

## Ручний процес (якщо потрібно)

### Передумови

1. Встановіть GitHub CLI: `brew install gh` (macOS) або з [офіційного сайту](https://cli.github.com/)
2. Автентифікуйтеся: `gh auth login`
3. Переконайтеся, що ви знаходитесь в гілці `main`

### Кроки створення релізу

#### 1. Запакувати Helm чарт

```bash
make release-package
# Або вручну:
helm package kbot
```

#### 2. Згенерувати release notes

```bash
make release-notes RELEASE_TAG=v1.0.0
# Або вручну відредагувати RELEASE_NOTES_TEMPLATE.md
```

#### 3. Створити GitHub реліз

```bash
gh release create v1.0.0 \
  --title "First Release" \
  --notes-file RELEASE_NOTES.md \
  kbot-0.1.0.tgz
```

#### 4. Перевірити реліз

```bash
gh release list
gh release view v1.0.0
```

#### 5. Завантажити Helm пакет (якщо не додано при створенні)

```bash
gh release upload v1.0.0 kbot-0.1.0.tgz --clobber
```

## URL до Helm пакету

Після створення релізу, URL буде:
```
https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz
```

## Встановлення чарту

### Перед встановленням

1. Створіть namespace:
```bash
kubectl create namespace kbot
```

2. Створіть Kubernetes Secret з Telegram токеном:
```bash
kubectl create secret generic kbot-secret \
    --from-literal=tele-token=<YOUR_TELEGRAM_TOKEN> \
    --namespace=kbot
```

### Встановлення

```bash
# З GitHub релізу
helm install kbot https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token

# Або з локального файлу
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```

### Перевірка

```bash
# Перевірити статус
kubectl get all -n kbot

# Переглянути логи
kubectl logs -l app.kubernetes.io/name=kbot -n kbot -f
```
