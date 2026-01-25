# Автоматизація процесу релізу

## Огляд

Процес створення GitHub релізу з Helm чартом автоматизовано через Make targets та GitHub Actions workflow.

## Використання Make targets

### Основний target

```bash
make release RELEASE_TAG=v1.0.0
```

Це виконає всі кроки:
1. Генерація release notes
2. Запакування Helm чарту
3. Створення GitHub релізу
4. Завантаження Helm пакету

### Окремі targets

```bash
# Тільки запакувати чарт
make release-package

# Тільки згенерувати release notes
make release-notes RELEASE_TAG=v1.0.0

# Створити реліз (потребує попередньо запакованого чарту)
make release-create RELEASE_TAG=v1.0.0 RELEASE_TITLE="My Release"

# Завантажити пакет до існуючого релізу
make release-upload RELEASE_TAG=v1.0.0
```

### Параметри

- `RELEASE_TAG` - git tag для релізу (за замовчуванням: v1.0.0)
- `RELEASE_TITLE` - назва релізу (за замовчуванням: Release $(RELEASE_TAG))
- Версія чарту автоматично читається з `kbot/Chart.yaml`

## Використання GitHub Actions

### Manual trigger

1. Відкрити https://github.com/YegorMaksymchuk/prometheus-bot/actions
2. Вибрати workflow "Create Release"
3. Натиснути "Run workflow"
4. Заповнити параметри:
   - **version**: Версія чарту (наприклад, 0.1.0)
   - **release_tag**: Git tag (наприклад, v1.0.0)
   - **release_title**: Назва релізу (опційно)
   - **prerelease**: Чи це pre-release (опційно, за замовчуванням false)
5. Натиснути "Run workflow"

### Процес виконання

Workflow виконує:
1. **prepare-release job**:
   - Checkout коду
   - Встановлення Helm
   - Оновлення версії в Chart.yaml (якщо вказано)
   - Валідація чарту (`helm lint`)
   - Запакування чарту
   - Генерація release notes з шаблону

2. **create-release job**:
   - Створення git tag (якщо не існує)
   - Створення GitHub релізу з release notes
   - Завантаження Helm пакету
   - Виведення URL до пакету

### Результат

Після успішного виконання:
- GitHub реліз створено
- Helm пакет завантажено
- Git tag створено
- URL до пакету виведено в логах

**Формат URL:**
```
https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz
```

## Release Notes Template

Шаблон `RELEASE_NOTES_TEMPLATE.md` базується на task5.md та містить:

- Привітання та анонс релізу
- Опис Helm чарту
- Плейсхолдери для автоматичної заміни:
  - `${CHART_VERSION}` - версія чарту
  - `${RELEASE_TAG}` - git tag
  - `${RELEASE_URL}` - URL до Helm пакету
  - `${INSTALL_INSTRUCTION}` - команда встановлення

## Приклади використання

### Локальний реліз через Make

```bash
# Створити реліз v1.0.0
make release RELEASE_TAG=v1.0.0

# Створити реліз з кастомною назвою
make release RELEASE_TAG=v1.0.0 RELEASE_TITLE="First Production Release"
```

### Реліз через GitHub Actions

1. Відкрити Actions → Create Release → Run workflow
2. Ввести:
   - version: `0.1.0`
   - release_tag: `v1.0.0`
   - release_title: `First Release`
3. Натиснути Run workflow

## Перевірка релізу

```bash
# Перевірити список релізів
gh release list

# Переглянути деталі релізу
gh release view v1.0.0

# Завантажити пакет
gh release download v1.0.0
```

## Troubleshooting

### Помилка: GitHub CLI не встановлено

**Помилка:**
```
Error: GitHub CLI (gh) is not installed
```

**Рішення:**
```bash
# macOS
brew install gh

# Linux - дивіться https://github.com/cli/cli/blob/trunk/docs/install_linux.md
# Windows - дивіться https://github.com/cli/cli/blob/trunk/docs/install_windows.md

# Після встановлення автентифікуйтеся
gh auth login
```

**Альтернатива:** Використайте GitHub Actions workflow (не потребує локального встановлення `gh`)

### Помилка: GitHub CLI не автентифіковано

**Помилка:**
```
Warning: GitHub CLI is not authenticated
```

**Рішення:**
```bash
gh auth login
# Слідуйте інструкціям на екрані
```

### Помилка: Реліз вже існує

**Рішення:**
- Використати `make release-upload` для оновлення
- Або видалити існуючий реліз: `gh release delete v1.0.0`

### Помилка: envsubst не знайдено

**Рішення:**
- На macOS: `brew install gettext`
- На Linux: `sudo apt-get install gettext-base`
- Make target має fallback на sed, якщо envsubst недоступний

## Структура файлів

```
prometheus-bot/
├── Makefile                    # Release targets
├── RELEASE_NOTES_TEMPLATE.md   # Шаблон release notes
├── RELEASE_NOTES.md            # Згенеровані release notes (gitignored)
├── kbot-*.tgz                  # Запакований чарт (gitignored)
└── .github/
    └── workflows/
        └── release.yml         # GitHub Actions workflow
```
